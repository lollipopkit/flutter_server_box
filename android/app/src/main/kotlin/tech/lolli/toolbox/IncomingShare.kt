package tech.lolli.toolbox

import android.content.Context
import android.content.Intent
import android.net.Uri

/**
 * A `.sbxsrv` file handed to this app by another one.
 *
 * **Read here rather than in Dart, and that is the whole reason this exists.**
 * The URI is a `content://` one owned by whichever app sent it; opening it
 * needs the `ContentResolver` and the grant that came with the intent, and
 * `dart:io`'s `File` cannot do either. What crosses the channel is the text.
 *
 * **Held, not pushed.** A file open starts the activity, so the intent is
 * there before the Flutter engine is. The Dart side asks after its first frame
 * and again on every resume, which covers both a cold start and a file opened
 * while the app was already up.
 */
object IncomingShare {
    /**
     * A share payload is a couple of kilobytes. This is not a limit anything
     * legitimate approaches — it is here so something that merely matched the
     * intent filter cannot be read into memory whole.
     */
    private const val MAX_BYTES = 1 shl 20

    private var pending: String? = null

    @Synchronized
    fun accept(context: Context, intent: Intent?) {
        val uri = uriOf(intent) ?: return
        pending = read(context, uri) ?: return
    }

    /**
     * The payload waiting, if any. Cleared by the read, so a second resume
     * does not raise the same file again.
     */
    @Synchronized
    fun take(): String? {
        val out = pending
        pending = null
        return out
    }

    private fun uriOf(intent: Intent?): Uri? = when (intent?.action) {
        Intent.ACTION_VIEW -> intent.data
        @Suppress("DEPRECATION")
        Intent.ACTION_SEND -> intent.getParcelableExtra(Intent.EXTRA_STREAM) as? Uri
        else -> null
    }

    private fun read(context: Context, uri: Uri): String? = try {
        context.contentResolver.openInputStream(uri)?.use { stream ->
            // One byte past the cap, so "exactly at the limit" and "over it"
            // are distinguishable without reading the rest of the file.
            val buf = ByteArray(MAX_BYTES + 1)
            var filled = 0
            while (filled < buf.size) {
                val read = stream.read(buf, filled, buf.size - filled)
                if (read <= 0) break
                filled += read
            }
            if (filled > MAX_BYTES) null else String(buf, 0, filled, Charsets.UTF_8)
        }
    } catch (e: Exception) {
        android.util.Log.w("IncomingShare", "Cannot read $uri: ${e.message}")
        null
    }
}
