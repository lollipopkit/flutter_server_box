package tech.lolli.toolbox.incoming

import android.app.Activity
import android.content.Intent
import android.net.Uri
import android.os.Bundle
import android.util.Log
import android.widget.ProgressBar
import android.widget.Toast
import androidx.core.content.IntentCompat
import org.json.JSONArray
import org.json.JSONObject
import tech.lolli.toolbox.MainActivity
import tech.lolli.toolbox.R

/**
 * Where another app's share (`SEND`, `SEND_MULTIPLE`) or text selection
 * (`PROCESS_TEXT`) lands.
 *
 * Not `MainActivity` itself: an app starts these in its own task, where a
 * `singleTop` activity is created afresh — a second `MainActivity`, with a
 * second engine running a second `main()` against the same stores. This one is
 * translucent, reads what was sent while it holds the grant to, leaves it in
 * [IncomingInbox], and brings the app's own task forward with
 * [ACTION_DELIVER].
 */
class IncomingActivity : Activity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // A recreation would read the same intent again.
        if (savedInstanceState != null) {
            finish()
            return
        }
        val text = textOf(intent)
        if (text != null) {
            if (text.isNotBlank()) deliver(JSONObject().put("kind", "text").put("text", text))
            finish()
            return
        }
        val uris = streamsOf(intent)
        if (uris.isEmpty()) {
            finish()
            return
        }
        setContentView(ProgressBar(this).apply { isIndeterminate = true })
        Thread {
            val batch = runCatching { IncomingFiles.copy(this, uris) }
            runOnUiThread {
                batch.fold(
                    onSuccess = { deliver(JSONObject().put("kind", "files").put("paths", JSONArray(it.paths))) },
                    onFailure = {
                        Log.w(TAG, "copy failed", it)
                        Toast.makeText(this, R.string.incoming_failed, Toast.LENGTH_LONG).show()
                    },
                )
                finish()
            }
        }.start()
    }

    private fun deliver(payload: JSONObject) {
        IncomingInbox.offer(this, payload.toString())
        // Reordered rather than cleared to: what is above `MainActivity` in
        // its task (a sign-in in progress, a picker awaiting its result) stays.
        startActivity(
            Intent(this, MainActivity::class.java)
                .setAction(ACTION_DELIVER)
                .addFlags(
                    Intent.FLAG_ACTIVITY_NEW_TASK or
                        Intent.FLAG_ACTIVITY_REORDER_TO_FRONT or
                        Intent.FLAG_ACTIVITY_SINGLE_TOP,
                ),
        )
    }

    private fun textOf(intent: Intent): String? = when (intent.action) {
        Intent.ACTION_PROCESS_TEXT -> intent.getCharSequenceExtra(Intent.EXTRA_PROCESS_TEXT)?.toString()
        Intent.ACTION_SEND -> intent.getCharSequenceExtra(Intent.EXTRA_TEXT)?.toString()
            ?.takeIf { streamsOf(intent).isEmpty() }
        else -> null
    }

    private fun streamsOf(intent: Intent): List<Uri> {
        val uris = mutableListOf<Uri>()
        when (intent.action) {
            Intent.ACTION_SEND ->
                IntentCompat.getParcelableExtra(intent, Intent.EXTRA_STREAM, Uri::class.java)?.let { uris.add(it) }
            Intent.ACTION_SEND_MULTIPLE ->
                IntentCompat.getParcelableArrayListExtra(intent, Intent.EXTRA_STREAM, Uri::class.java)
                    ?.let { uris.addAll(it) }
        }
        // ClipData is how a sender grants the read; it carries the same URIs.
        intent.clipData?.let { clip ->
            for (i in 0 until clip.itemCount) clip.getItemAt(i).uri?.let { if (it !in uris) uris.add(it) }
        }
        return uris
    }

    companion object {
        private const val TAG = "IncomingActivity"

        /**
         * Tells `MainActivity` the inbox has something. Carries nothing
         * itself: `MainActivity` is exported, and anything in the intent
         * could have been put there by any app.
         */
        const val ACTION_DELIVER = "tech.lolli.toolbox.INCOMING"
    }
}

/** One payload from [IncomingActivity], held in this process until Dart takes it. */
object IncomingInbox {
    private var pending: String? = null

    @Synchronized
    fun offer(context: android.content.Context, payload: String) {
        // An earlier batch nobody took is not going to be.
        pending?.let { discard(context, it) }
        pending = payload
    }

    @Synchronized
    fun take(): String? = pending.also { pending = null }

    private fun discard(context: android.content.Context, payload: String) {
        val paths = JSONObject(payload).optJSONArray("paths") ?: return
        val dirs = (0 until paths.length()).mapNotNull { java.io.File(paths.optString(it)).parentFile }.toSet()
        dirs.forEach { IncomingFiles.discardBatch(context, it) }
    }
}
