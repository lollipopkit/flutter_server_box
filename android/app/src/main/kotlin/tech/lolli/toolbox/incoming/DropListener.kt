package tech.lolli.toolbox.incoming

import android.app.Activity
import android.util.Log
import android.view.DragEvent
import android.view.View
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel

/**
 * Files dropped onto the app from another window (desktop mode, split screen).
 *
 * Replaces `desktop_drop`'s own listener, which releases the drop's read grant
 * before anything has read the files and hands Dart `content://` URIs where it
 * expects paths. This keeps the grant until the files are copied in
 * ([IncomingFiles]) and answers on the plugin's channel with paths, so its
 * `DropTarget` widgets work unchanged.
 *
 * TODO: remove once desktop_drop reads the files before releasing the grant.
 */
class DropListener(
    private val activity: Activity,
    messenger: BinaryMessenger,
    private val onFailed: (Throwable) -> Unit,
) : View.OnDragListener {
    /** `desktop_drop`'s channel: `entered`/`updated` [x, y] in px, `exited`, `performOperation` [paths]. */
    private val channel = MethodChannel(messenger, "desktop_drop")

    override fun onDrag(view: View, event: DragEvent): Boolean {
        when (event.action) {
            DragEvent.ACTION_DRAG_STARTED -> return true
            DragEvent.ACTION_DRAG_ENTERED -> channel.invokeMethod("entered", listOf(event.x.toDouble(), event.y.toDouble()))
            DragEvent.ACTION_DRAG_LOCATION -> channel.invokeMethod("updated", listOf(event.x.toDouble(), event.y.toDouble()))
            DragEvent.ACTION_DRAG_EXITED -> channel.invokeMethod("exited", null)
            DragEvent.ACTION_DROP -> return drop(event)
        }
        return true
    }

    private fun drop(event: DragEvent): Boolean {
        val clip = event.clipData
        val uris = (0 until (clip?.itemCount ?: 0)).mapNotNull { clip?.getItemAt(it)?.uri }
        if (uris.isEmpty()) {
            channel.invokeMethod("exited", null)
            return false
        }
        val grant = activity.requestDragAndDropPermissions(event)
        Thread {
            val result = runCatching { IncomingFiles.copy(activity, uris) }
            activity.runOnUiThread {
                grant?.release()
                result.fold(
                    onSuccess = { channel.invokeMethod("performOperation", it.paths) },
                    onFailure = {
                        Log.w("DropListener", "copy failed", it)
                        channel.invokeMethod("exited", null)
                        onFailed(it)
                    },
                )
            }
        }.start()
        return true
    }
}
