package tech.lolli.toolbox

import android.Manifest
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import androidx.core.content.ContextCompat
import org.json.JSONObject

/**
 * File transfers in progress, as one ongoing notification.
 *
 * On Android 16 a Live Update: `ProgressStyle`, asking to be promoted, with the
 * percentage as the status bar chip. Earlier, a plain progress bar.
 *
 * The text arrives already localized: this is only posted while the app runs.
 */
object TransferNotification {
    private const val CHANNEL = "transfers"
    private const val ID = 1100

    /** See `AndroidSystemSync.transferHeartbeat`, which must stay well below this. */
    private const val TIMEOUT_MS = 30_000L

    /**
     * `Notification.EXTRA_REQUEST_PROMOTED_ONGOING`, which compileSdk 36 does
     * not declare yet; the key is the platform's own.
     * TODO: use the constant once compileSdk is 36.1 or later.
     */
    private const val EXTRA_REQUEST_PROMOTED_ONGOING = "android.requestPromotedOngoing"

    /** `{"title","text","progress":0..100 or -1,"chip"}`, or null to take it down. */
    fun update(context: Context, json: String?) {
        val nm = context.getSystemService(NotificationManager::class.java) ?: return
        if (json == null) {
            nm.cancel(ID)
            return
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU &&
            ContextCompat.checkSelfPermission(context, Manifest.permission.POST_NOTIFICATIONS) !=
            PackageManager.PERMISSION_GRANTED
        ) return
        val o = JSONObject(json)
        val progress = o.optInt("progress", -1).coerceIn(-1, 100)
        ensureChannel(context, nm)
        nm.notify(ID, build(context, o.optString("title"), o.optString("text"), progress, o.optString("chip")))
    }

    private fun build(context: Context, title: String, text: String, progress: Int, chip: String): Notification {
        val open = PendingIntent.getActivity(
            context,
            0,
            Intent(context, MainActivity::class.java),
            PendingIntent.FLAG_IMMUTABLE,
        )
        val b = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(context, CHANNEL)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(context)
        }
        b.setSmallIcon(R.drawable.ic_notification)
            .setContentTitle(title)
            .setContentText(text)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setShowWhen(false)
            .setCategory(Notification.CATEGORY_PROGRESS)
            .setContentIntent(open)
        // Ongoing and owned by no service: if the process dies, nothing else
        // takes it down. Dart reposts well inside this while a transfer runs.
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) b.setTimeoutAfter(TIMEOUT_MS)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.BAKLAVA) {
            b.setStyle(
                Notification.ProgressStyle()
                    .setProgressSegments(listOf(Notification.ProgressStyle.Segment(100)))
                    .setProgress(progress.coerceAtLeast(0))
                    .setProgressIndeterminate(progress < 0),
            )
            if (chip.isNotEmpty()) b.setShortCriticalText(chip)
            b.extras.putBoolean(EXTRA_REQUEST_PROMOTED_ONGOING, true)
        } else {
            b.setProgress(100, progress.coerceAtLeast(0), progress < 0)
        }
        return b.build()
    }

    private fun ensureChannel(context: Context, nm: NotificationManager) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        if (nm.getNotificationChannel(CHANNEL) != null) return
        // Default rather than low: a Live Update is only promoted from a
        // channel that may interrupt. Silent all the same: progress is not news.
        val channel = NotificationChannel(
            CHANNEL,
            context.getString(R.string.channel_transfers),
            NotificationManager.IMPORTANCE_DEFAULT,
        ).apply {
            setSound(null, null)
            enableVibration(false)
            setShowBadge(false)
        }
        nm.createNotificationChannel(channel)
    }
}
