package tech.lolli.toolbox.incoming

import android.content.ContentResolver
import android.content.Context
import android.net.Uri
import android.provider.OpenableColumns
import java.io.File
import java.io.IOException
import java.util.UUID

/**
 * Files another app handed over (a share, a drop), copied in while the grant
 * to read them lasts.
 *
 * Copied rather than passed on as URIs or descriptors: a drop's grant ends
 * with `DragAndDropPermissions.release`, a share's with the activity, and the
 * transfer that reads the file runs later, on another isolate, and asks for it
 * by path. Some providers hand out pipes, which have no size and cannot be
 * read twice.
 *
 * Each batch gets a directory of its own under [DIR], which the Dart side
 * deletes once its transfers end; [purgeStale] takes what a killed process
 * left behind.
 */
object IncomingFiles {
    const val DIR = "incoming"

    /** Kept free on top of what the files need, so a copy cannot fill the disk. */
    private const val SPACE_MARGIN = 64L * 1024 * 1024

    private const val STALE_MS = 24L * 60 * 60 * 1000

    class Batch(val dir: File, val paths: List<String>)

    /**
     * Copies [uris] into a new batch directory. All or nothing: a failure
     * removes what was copied and throws.
     */
    @Throws(IOException::class, SecurityException::class)
    fun copy(context: Context, uris: List<Uri>): Batch {
        val resolver = context.contentResolver
        for (uri in uris) refuseUnsafe(context, uri)
        val metas = uris.map { meta(resolver, it) }
        val root = File(context.cacheDir, DIR)
        val known = metas.sumOf { it.size ?: 0L }
        if (known + SPACE_MARGIN > context.cacheDir.usableSpace) {
            throw IOException("not enough space for $known bytes")
        }
        val dir = File(root, UUID.randomUUID().toString())
        if (!dir.mkdirs()) throw IOException("mkdir ${dir.path}")
        try {
            val taken = mutableSetOf<String>()
            val paths = uris.mapIndexed { i, uri ->
                val out = File(dir, unique(sanitize(metas[i].name ?: uri.lastPathSegment), taken))
                val input = resolver.openInputStream(uri) ?: throw IOException("no stream for $uri")
                input.use { src -> out.outputStream().use { copyBounded(src, it, dir) } }
                out.path
            }
            return Batch(dir, paths)
        } catch (e: Throwable) {
            deleteTree(dir)
            throw e
        }
    }

    /** Watches the free space as it goes: a pipe has no size to check up front. */
    private fun copyBounded(src: java.io.InputStream, dst: java.io.OutputStream, dir: File) {
        val buf = ByteArray(256 * 1024)
        var sinceCheck = 0L
        while (true) {
            val n = src.read(buf)
            if (n < 0) return
            dst.write(buf, 0, n)
            sinceCheck += n
            if (sinceCheck >= 32L * 1024 * 1024) {
                sinceCheck = 0
                if (dir.usableSpace < SPACE_MARGIN) throw IOException("out of space")
            }
        }
    }

    /**
     * Refuses what would read this app's own data on another app's say-so.
     *
     * A `file://` URI is never sent legitimately since Android 7, and one
     * naming this app's private directory would be read with this app's
     * rights. A `content://` URI of a provider in this package is the same
     * thing by another route.
     */
    private fun refuseUnsafe(context: Context, uri: Uri) {
        if (uri.scheme != ContentResolver.SCHEME_CONTENT) {
            throw SecurityException("refused scheme ${uri.scheme}")
        }
        val authority = uri.authority ?: throw SecurityException("no authority")
        val provider = context.packageManager.resolveContentProvider(authority, 0)
        if (provider == null || provider.packageName == context.packageName) {
            throw SecurityException("refused authority $authority")
        }
    }

    private class Meta(val name: String?, val size: Long?)

    private fun meta(resolver: ContentResolver, uri: Uri): Meta = try {
        resolver.query(
            uri,
            arrayOf(OpenableColumns.DISPLAY_NAME, OpenableColumns.SIZE),
            null,
            null,
            null,
        )?.use { c ->
            if (!c.moveToFirst()) return@use null
            val name = c.getColumnIndex(OpenableColumns.DISPLAY_NAME)
                .takeIf { it >= 0 && !c.isNull(it) }?.let { c.getString(it) }
            val size = c.getColumnIndex(OpenableColumns.SIZE)
                .takeIf { it >= 0 && !c.isNull(it) }?.let { c.getLong(it) }
            Meta(name, size)
        } ?: Meta(null, null)
    } catch (e: Exception) {
        Meta(null, null)
    }

    /** One path segment, whatever the sender called it. */
    fun sanitize(raw: String?): String {
        val base = raw.orEmpty()
            .substringAfterLast('/')
            .substringAfterLast('\\')
            .filter { it >= ' ' && it != '\u007f' }
            .trim()
        val name = if (base.isEmpty() || base == "." || base == "..") "file" else base
        return truncateUtf8(name, 255)
    }

    /** At most [max] bytes, cut before the extension so the type survives. */
    private fun truncateUtf8(name: String, max: Int): String {
        if (max <= 0) return ""
        if (name.toByteArray().size <= max) return name
        val dot = name.lastIndexOf('.')
        val ext = if (dot > 0 && name.length - dot <= 16) name.substring(dot) else ""
        var stem = name.substring(0, name.length - ext.length)
        while (stem.isNotEmpty() && (stem + ext).toByteArray().size > max) {
            stem = stem.dropLast(1)
        }
        return stem + ext
    }

    /** [name], or `name (2).ext` and onwards when the batch already has it. */
    fun unique(name: String, taken: MutableSet<String>): String {
        if (taken.add(name)) return name
        val dot = name.lastIndexOf('.')
        val (stem, ext) = if (dot > 0) name.substring(0, dot) to name.substring(dot) else name to ""
        var n = 2
        while (true) {
            // The suffix is kept and the stem cut to make room: cutting the
            // whole candidate could cut the suffix off, back to a taken name.
            val tail = " ($n)$ext"
            val candidate = truncateUtf8(stem, 255 - tail.toByteArray().size).trimEnd() + tail
            if (taken.add(candidate)) return candidate
            n++
        }
    }

    /** Removes [dir] if it is one of this app's batches, and nothing else. */
    fun discardBatch(context: Context, dir: File) {
        val root = File(context.cacheDir, DIR).canonicalFile
        if (dir.canonicalFile.parentFile == root) deleteTree(dir)
    }

    /** Batches older than a day: their transfers ended in a process now gone. */
    fun purgeStale(context: Context) {
        val root = File(context.cacheDir, DIR)
        val cutoff = System.currentTimeMillis() - STALE_MS
        root.listFiles()?.forEach { if (it.lastModified() < cutoff) deleteTree(it) }
    }

    /**
     * A batch is flat: files this wrote, nothing to descend into. `delete`
     * removes a link rather than what it names, so nothing outside is reached.
     */
    private fun deleteTree(dir: File) {
        dir.listFiles()?.forEach { it.delete() }
        dir.delete()
    }
}
