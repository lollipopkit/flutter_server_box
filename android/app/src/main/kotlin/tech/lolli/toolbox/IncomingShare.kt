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

    /**
     * Reads whatever [intent] was opened for, and **takes it out of the
     * intent**.
     *
     * The second half is what stops a server being imported twice. Android
     * keeps the launch intent on the task: once the process is killed for
     * memory and the user reopens the app from Recents, `onCreate` runs again
     * with the *same* `ACTION_VIEW`, and without this it reads the same file
     * and offers the same import. Nothing downstream dedupes it -- a colliding
     * id is resolved by generating a new one, which is right for a share the
     * user really did send twice.
     *
     * Also refuses a relaunch from history outright, which is the same case
     * arriving before `onCreate` has had a chance to clear anything.
     */
    @Synchronized
    fun accept(context: Context, intent: Intent?) {
        if (intent == null) return
        if (intent.flags and Intent.FLAG_ACTIVITY_LAUNCHED_FROM_HISTORY != 0) return
        val uri = uriOf(intent) ?: return
        // Cleared whether or not the read works: a file this app cannot read
        // will not read any better the second time, and leaving it in place
        // means retrying on every resume from Recents forever.
        intent.data = null
        intent.action = Intent.ACTION_MAIN
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

    /**
     * `ACTION_VIEW` only, matching the one filter the manifest declares.
     *
     * There was an `ACTION_SEND` arm here for the share sheet, and it was
     * unreachable: nothing declares that action, so the app never appears in
     * one. Adding the filter is not the fix either -- a `.sbxsrv` is handed
     * over as `application/octet-stream`, and claiming that for `ACTION_SEND`
     * would put ServerBox in the share sheet of every binary file on the
     * device. Better to have the Kotlin and the manifest agree.
     */
    private fun uriOf(intent: Intent?): Uri? =
        if (intent?.action == Intent.ACTION_VIEW) intent.data else null

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
