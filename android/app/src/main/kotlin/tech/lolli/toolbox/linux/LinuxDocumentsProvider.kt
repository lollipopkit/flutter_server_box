package tech.lolli.toolbox.linux

import android.content.Context
import android.database.Cursor
import android.database.MatrixCursor
import android.os.CancellationSignal
import android.os.ParcelFileDescriptor
import android.provider.DocumentsContract
import android.provider.DocumentsContract.Document
import android.provider.DocumentsContract.Root
import android.provider.DocumentsProvider
import android.system.ErrnoException
import android.system.Os
import android.system.OsConstants
import android.webkit.MimeTypeMap
import tech.lolli.toolbox.R
import java.io.File
import java.io.FileNotFoundException

/**
 * Each installed Linux system as a root of the system file picker (#1583), so
 * files move between it and the rest of the phone without a network server.
 *
 * A system is a directory under `filesDir/linux` holding the marker the app
 * writes when it installs one — the layout `AndroidRootfs` scans. Its whole
 * tree is offered, `/` down, since that is where anything a user builds or
 * downloads inside it may be.
 *
 * A document id is `<system>:<guest path>`. Every access resolves that path
 * with [GuestPath], so links inside the rootfs point where they point for the
 * guest, and neither a link nor a crafted id reaches anything outside it.
 *
 * Resolved, then used as a path: a guest process swapping a checked directory
 * for a link in between is not guarded against, and does not need to be. The
 * guest runs as this app's uid under proot, which is no sandbox (it has the
 * host's `/proc`), so it can already reach everything this provider can.
 *
 * Only the system's picker can bind here: the manifest guards this provider
 * with `MANAGE_DOCUMENTS`, and another app gets a file only after the user
 * picks it there.
 */
class LinuxDocumentsProvider : DocumentsProvider() {
    companion object {
        /** `LinuxProfile.marker`. */
        private const val MARKER = ".installed"

        private val ROOT_PROJECTION = arrayOf(
            Root.COLUMN_ROOT_ID,
            Root.COLUMN_FLAGS,
            Root.COLUMN_ICON,
            Root.COLUMN_TITLE,
            Root.COLUMN_SUMMARY,
            Root.COLUMN_DOCUMENT_ID,
            Root.COLUMN_AVAILABLE_BYTES,
        )

        private val DOCUMENT_PROJECTION = arrayOf(
            Document.COLUMN_DOCUMENT_ID,
            Document.COLUMN_MIME_TYPE,
            Document.COLUMN_DISPLAY_NAME,
            Document.COLUMN_LAST_MODIFIED,
            Document.COLUMN_FLAGS,
            Document.COLUMN_SIZE,
        )

        private fun authority(context: Context) = "${context.packageName}.linux"

        /** Tells the picker the list of systems changed. */
        fun notifyRootsChanged(context: Context) {
            context.contentResolver.notifyChange(
                DocumentsContract.buildRootsUri(authority(context)),
                null,
            )
        }
    }

    private data class Doc(val system: String, val path: String) {
        val id get() = "$system:$path"
    }

    private val container get() = File(context!!.filesDir, "linux")

    override fun onCreate() = true

    // --- Roots ---

    override fun queryRoots(projection: Array<out String>?): Cursor {
        val cursor = MatrixCursor(projection ?: ROOT_PROJECTION)
        val ctx = context!!
        for (system in systems()) {
            val root = File(container, system)
            cursor.newRow().apply {
                add(Root.COLUMN_ROOT_ID, system)
                add(
                    Root.COLUMN_FLAGS,
                    Root.FLAG_SUPPORTS_CREATE or
                        Root.FLAG_SUPPORTS_IS_CHILD or
                        Root.FLAG_LOCAL_ONLY,
                )
                add(Root.COLUMN_ICON, R.mipmap.ic_launcher)
                add(Root.COLUMN_TITLE, ctx.getString(R.string.app_name))
                add(Root.COLUMN_SUMMARY, label(system))
                add(Root.COLUMN_DOCUMENT_ID, Doc(system, "/").id)
                add(Root.COLUMN_AVAILABLE_BYTES, root.usableSpace)
            }
        }
        cursor.setNotificationUri(
            ctx.contentResolver,
            DocumentsContract.buildRootsUri(authority(ctx)),
        )
        return cursor
    }

    /** The installed systems: directories carrying the marker. */
    private fun systems(): List<String> =
        container.listFiles()
            ?.filter { isSystem(it.name) }
            ?.map { it.name }
            ?.sorted()
            .orEmpty()

    private fun isSystem(name: String): Boolean {
        if (name.isEmpty() || name.startsWith('.') || name.contains('/')) return false
        val dir = File(container, name)
        return !isLink(dir.path) && dir.isDirectory && File(dir, MARKER).isFile
    }

    /** The label the user gave it: the marker's third line. */
    private fun label(system: String): String =
        runCatching { File(File(container, system), MARKER).readLines() }
            .getOrNull()
            ?.getOrNull(2)
            ?.trim()
            ?.takeIf { it.isNotEmpty() }
            ?: system

    // --- Documents ---

    override fun queryDocument(documentId: String, projection: Array<out String>?): Cursor {
        val cursor = MatrixCursor(projection ?: DOCUMENT_PROJECTION)
        addRow(cursor, parse(documentId))
        return cursor
    }

    override fun queryChildDocuments(
        parentDocumentId: String,
        projection: Array<out String>?,
        sortOrder: String?,
    ): Cursor {
        val parent = parse(parentDocumentId)
        val dir = resolve(parent, followLast = true)
        if (!dir.isDirectory) throw FileNotFoundException(parentDocumentId)
        val cursor = MatrixCursor(projection ?: DOCUMENT_PROJECTION)
        // The rootfs's own top, however it was reached: a link to `/` is one.
        val atTop = dir.path == File(container, parent.system).path
        for (name in dir.list().orEmpty().sorted()) {
            // The app's own bookkeeping, hidden from the guest's `ls` as well.
            if (atTop && name == MARKER) continue
            addRow(cursor, Doc(parent.system, GuestPath.child(parent.path, name)))
        }
        cursor.setNotificationUri(
            context!!.contentResolver,
            childrenUri(parent),
        )
        return cursor
    }

    override fun openDocument(
        documentId: String,
        mode: String,
        signal: CancellationSignal?,
    ): ParcelFileDescriptor {
        val file = resolve(parse(documentId), followLast = true)
        if (file.isDirectory) throw FileNotFoundException("$documentId is a directory")
        return ParcelFileDescriptor.open(file, ParcelFileDescriptor.parseMode(mode))
    }

    /**
     * What a tree grant is checked against, so it compares where the two
     * documents actually are: `/root/up/etc` is not under `/root` when `up`
     * links to `/`, whatever the id says. As `ExternalStorageProvider` does
     * with canonical paths — which also means a link inside a granted tree
     * that points out of it is outside it, for reading and for deleting.
     */
    override fun isChildDocument(parentDocumentId: String, documentId: String): Boolean =
        runCatching {
            val parent = parse(parentDocumentId)
            val doc = parse(documentId)
            parent.system == doc.system && GuestPath.isWithin(
                resolve(parent, followLast = true).path,
                resolve(doc, followLast = true).path,
            )
        }.getOrDefault(false)

    override fun createDocument(
        parentDocumentId: String,
        mimeType: String,
        displayName: String,
    ): String {
        val parent = parse(parentDocumentId)
        val dir = resolve(parent, followLast = true)
        if (!dir.isDirectory) throw FileNotFoundException(parentDocumentId)
        val name = freeName(dir, checkName(displayName))
        val created = if (mimeType == Document.MIME_TYPE_DIR) {
            File(dir, name).mkdir()
        } else {
            File(dir, name).createNewFile()
        }
        if (!created) throw IllegalStateException("Could not create $name")
        notifyChildren(parent)
        return Doc(parent.system, GuestPath.child(parent.path, name)).id
    }

    override fun deleteDocument(documentId: String) {
        val doc = parse(documentId)
        if (doc.path == "/") throw UnsupportedOperationException("Cannot delete the root")
        deleteTree(resolve(doc, followLast = false))
        notifyChildren(Doc(doc.system, GuestPath.parent(doc.path)))
    }

    override fun renameDocument(documentId: String, displayName: String): String {
        val doc = parse(documentId)
        if (doc.path == "/") throw UnsupportedOperationException("Cannot rename the root")
        val file = resolve(doc, followLast = false)
        val name = checkName(displayName)
        val target = File(file.parentFile, name)
        if (exists(target.path)) throw IllegalStateException("$name already exists")
        if (!file.renameTo(target)) throw IllegalStateException("Could not rename to $name")
        val parent = Doc(doc.system, GuestPath.parent(doc.path))
        notifyChildren(parent)
        return Doc(doc.system, GuestPath.child(parent.path, name)).id
    }

    // --- Helpers ---

    private fun parse(documentId: String): Doc {
        val at = documentId.indexOf(':')
        if (at <= 0) throw FileNotFoundException(documentId)
        val system = documentId.substring(0, at)
        if (!isSystem(system)) throw FileNotFoundException(documentId)
        return Doc(system, GuestPath.normalize(documentId.substring(at + 1)))
    }

    private fun resolve(doc: Doc, followLast: Boolean): File {
        val root = File(container, doc.system).path
        val host = GuestPath.resolve(root, doc.path, followLast, ::readLink)
            ?: throw FileNotFoundException("Too many links: ${doc.id}")
        // The marker is the app's, however it is named — `/.installed`, or
        // through a link to `/` — and deleting it uninstalls the system.
        if (host == File(root, MARKER).path) throw FileNotFoundException(doc.id)
        return File(host)
    }

    private fun addRow(cursor: MatrixCursor, doc: Doc) {
        // What a link points to is what the picker shows, so `/bin` opens as a
        // directory. A dangling one is still listed, as a file to delete.
        val file = resolve(doc, followLast = true)
        val isDir = file.isDirectory
        val dirWritable = (if (isDir) file else file.parentFile)?.canWrite() == true
        val parentWritable = resolve(doc, followLast = false).parentFile?.canWrite() == true
        var flags = 0
        if (isDir) {
            if (dirWritable) flags = flags or Document.FLAG_DIR_SUPPORTS_CREATE
        } else if (file.canWrite()) {
            flags = flags or Document.FLAG_SUPPORTS_WRITE
        }
        if (doc.path != "/" && parentWritable) {
            flags = flags or Document.FLAG_SUPPORTS_DELETE or
                Document.FLAG_SUPPORTS_RENAME
        }
        cursor.newRow().apply {
            add(Document.COLUMN_DOCUMENT_ID, doc.id)
            add(Document.COLUMN_DISPLAY_NAME, if (doc.path == "/") label(doc.system) else GuestPath.name(doc.path))
            add(Document.COLUMN_MIME_TYPE, if (isDir) Document.MIME_TYPE_DIR else mimeOf(doc.path))
            add(Document.COLUMN_LAST_MODIFIED, file.lastModified())
            add(Document.COLUMN_FLAGS, flags)
            add(Document.COLUMN_SIZE, if (isDir) null else file.length())
        }
    }

    /** Removes [file], and a directory's contents first, never through a link. */
    private fun deleteTree(file: File) {
        if (!isLink(file.path) && file.isDirectory) {
            file.list()?.forEach { deleteTree(File(file, it)) }
        }
        if (!file.delete() && exists(file.path)) {
            throw IllegalStateException("Could not delete ${file.name}")
        }
    }

    private fun checkName(name: String): String {
        val trimmed = name.trim()
        if (trimmed.isEmpty() || trimmed == "." || trimmed == ".." ||
            trimmed.contains('/') || trimmed.contains('\u0000')
        ) {
            throw IllegalArgumentException("Invalid name: $name")
        }
        return trimmed
    }

    /** [name], or `name (n).ext` when that is taken, as the picker expects. */
    private fun freeName(dir: File, name: String): String {
        if (!exists(File(dir, name).path)) return name
        val dot = name.lastIndexOf('.').takeIf { it > 0 } ?: name.length
        val base = name.substring(0, dot)
        val ext = name.substring(dot)
        var n = 1
        while (true) {
            val candidate = "$base ($n)$ext"
            if (!exists(File(dir, candidate).path)) return candidate
            n++
        }
    }

    private fun mimeOf(path: String): String {
        val ext = GuestPath.name(path).substringAfterLast('.', "").lowercase()
        return MimeTypeMap.getSingleton().getMimeTypeFromExtension(ext)
            ?: "application/octet-stream"
    }

    private fun childrenUri(parent: Doc) =
        DocumentsContract.buildChildDocumentsUri(authority(context!!), parent.id)

    private fun notifyChildren(parent: Doc) {
        context!!.contentResolver.notifyChange(childrenUri(parent), null)
    }

    /**
     * [path]'s target, or null when it is not a link. A link that cannot be
     * read fails the lookup: passing it on as a plain path would let the
     * kernel resolve it against the phone's `/`.
     */
    private fun readLink(path: String): String? {
        if (!isLink(path)) return null
        return try {
            Os.readlink(path)
        } catch (e: ErrnoException) {
            throw FileNotFoundException("Unreadable link: ${e.message}")
        }
    }

    private fun isLink(path: String): Boolean =
        try {
            OsConstants.S_ISLNK(Os.lstat(path).st_mode)
        } catch (_: ErrnoException) {
            false
        }

    /** Whether anything is at [path], a dangling link included. */
    private fun exists(path: String): Boolean =
        try {
            Os.lstat(path)
            true
        } catch (_: ErrnoException) {
            false
        }
}
