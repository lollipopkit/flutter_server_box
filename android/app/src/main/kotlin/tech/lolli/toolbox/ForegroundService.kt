package tech.lolli.toolbox

import android.app.*
import android.content.Intent
import android.os.Build
import android.os.IBinder
import android.util.Log
import org.json.JSONArray
import org.json.JSONObject
import java.io.File
import java.util.*

class ForegroundService : Service() {
    companion object {
        @Volatile
        var isRunning: Boolean = false
    }
    private val chanId = "ForegroundServiceChannel"
    private val GROUP_KEY = "ssh_sessions_group"
    private val SUMMARY_ID = 1000
    private val ACTION_STOP_FOREGROUND = "ACTION_STOP_FOREGROUND"
    private val ACTION_UPDATE_SESSIONS = "tech.lolli.toolbox.ACTION_UPDATE_SESSIONS"
    private val ACTION_DISCONNECT_SESSION = "tech.lolli.toolbox.ACTION_DISCONNECT_SESSION"

    private var isFgStarted = false
    private val postedIds = mutableSetOf<Int>()
    // Stable mapping from session-id -> notification-id to avoid hash collisions
    private val notificationIdMap = mutableMapOf<String, Int>()
    private val nextNotificationId = java.util.concurrent.atomic.AtomicInteger(2001)

    private fun logError(message: String, error: Throwable? = null) {
        Log.e("ForegroundService", message, error)
        try {
            val logFile = File(getExternalFilesDir(null), "server_box.log")
            val timestamp = java.text.SimpleDateFormat("yyyy-MM-dd HH:mm:ss", Locale.US).format(Date())
            val logMessage = "$timestamp [ForegroundService] ERROR: $message\n${error?.stackTraceToString() ?: ""}\n"
            logFile.appendText(logMessage)
        } catch (e: Exception) {
            Log.e("ForegroundService", "Failed to write log", e)
        }
    }

    override fun onCreate() {
        super.onCreate()
        Log.d("ForegroundService", "Service onCreate")
        isRunning = true
        createNotificationChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU &&
                androidx.core.content.ContextCompat.checkSelfPermission(
                    this, android.Manifest.permission.POST_NOTIFICATIONS
                ) != android.content.pm.PackageManager.PERMISSION_GRANTED
            ) {
                Log.w("ForegroundService", "Notification permission denied. Stopping service.")
                stopForegroundService()
                return START_NOT_STICKY
            }

            if (intent == null) {
                Log.w("ForegroundService", "onStartCommand called with null intent")
                stopForegroundService()
                return START_NOT_STICKY
            }

            val action = intent.action
            Log.d("ForegroundService", "onStartCommand action=$action")

            return when (action) {
                ACTION_STOP_FOREGROUND -> {
                    clearAll()
                    stopForegroundService()
                    START_NOT_STICKY
                }
                ACTION_UPDATE_SESSIONS -> {
                    val payload = intent.getStringExtra("payload") ?: "{}"
                    handleUpdateSessions(payload)
                    START_STICKY
                }
                else -> {
                    // Default bring up foreground with placeholder
                    ensureForeground(createSummaryNotification(0, emptyList()))
                    START_STICKY
                }
            }
            
        } catch (e: Exception) {
            logError("Error in onStartCommand", e)
            stopSelf()
            return START_NOT_STICKY
        }
    }

    override fun onBind(intent: Intent?): IBinder? {
        return null
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val manager = getSystemService(NotificationManager::class.java)
            if (manager == null) {
                Log.e("ForegroundService", "Failed to get NotificationManager")
                return
            }
            val serviceChannel = NotificationChannel(
                chanId,
                "ForegroundServiceChannel",
                NotificationManager.IMPORTANCE_DEFAULT
            ).apply {
                description = "For foreground service"
            }
            manager.createNotificationChannel(serviceChannel)
        }
    }

    private fun ensureForeground(notification: Notification) {
        try {
            if (!isFgStarted) {
                startForeground(SUMMARY_ID, notification)
                isFgStarted = true
            } else {
                val nm = getSystemService(NotificationManager::class.java)
                nm?.notify(SUMMARY_ID, notification)
            }
        } catch (e: Exception) {
            logError("Failed to start/update foreground", e)
        }
    }

    private fun createSummaryNotification(count: Int, lines: List<String>): Notification {
        val notificationIntent = Intent(this, MainActivity::class.java)
        val pendingIntent = PendingIntent.getActivity(
            this, 0, notificationIntent, PendingIntent.FLAG_IMMUTABLE
        )
        val stopIntent = Intent(this, ForegroundService::class.java).apply { action = ACTION_STOP_FOREGROUND }
        val stopPending = PendingIntent.getService(this, 0, stopIntent, PendingIntent.FLAG_IMMUTABLE)

        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, chanId)
        } else {
            Notification.Builder(this)
        }

        val inbox = Notification.InboxStyle()
        lines.forEach { inbox.addLine(it) }

        return builder
            .setContentTitle("SSH sessions: $count active")
            .setContentText(if (lines.isNotEmpty()) lines.first() else "Running")
            .setSmallIcon(R.mipmap.ic_launcher)
            .setStyle(inbox)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setGroup(GROUP_KEY)
            .setGroupSummary(true)
            .setContentIntent(pendingIntent)
            .addAction(android.R.drawable.ic_delete, "Stop", stopPending)
            .build()
    }

    private fun handleUpdateSessions(payload: String) {
        val nm = getSystemService(NotificationManager::class.java)
        if (nm == null) {
            logError("NotificationManager null")
            return
        }

        val sessions = mutableListOf<SessionItem>()
        try {
            val obj = JSONObject(payload)
            val arr: JSONArray = obj.optJSONArray("sessions") ?: JSONArray()
            for (i in 0 until arr.length()) {
                val s = arr.optJSONObject(i) ?: continue
                val id = s.optString("id")
                val title = s.optString("title")
                val sub = s.optString("subtitle")
                val whenMs = s.optLong("startTimeMs", System.currentTimeMillis())
                val status = s.optString("status", "connected")
                if (id.isNotEmpty()) {
                    sessions.add(SessionItem(id, title, sub, whenMs, status))
                }
            }
        } catch (e: Exception) {
            logError("Failed to parse payload", e)
        }

        // Clear if empty
        if (sessions.isEmpty()) {
            clearAll()
            return
        }

        // Build per-session notifications
        val currentIds = mutableSetOf<Int>()
        val summaryLines = mutableListOf<String>()
        sessions.forEach { s ->
            // Assign a stable, collision-resistant id per session for this service lifecycle
            val nid = notificationIdMap.getOrPut(s.id) { nextNotificationId.getAndIncrement() }
            currentIds.add(nid)
            summaryLines.add("${s.title}: ${s.status}")

            val disconnectIntent = Intent(this, MainActivity::class.java).apply {
                action = ACTION_DISCONNECT_SESSION
                putExtra("session_id", s.id)
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP)
            }
            val disconnectPending = PendingIntent.getActivity(
                this, nid, disconnectIntent, PendingIntent.FLAG_IMMUTABLE
            )

            val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                Notification.Builder(this, chanId)
            } else {
                Notification.Builder(this)
            }

            val noti = builder
                .setContentTitle(s.title)
                .setContentText("${s.subtitle} · ${s.status}")
                .setSmallIcon(R.mipmap.ic_launcher)
                .setWhen(s.startWhen)
                .setUsesChronometer(true)
                .setOngoing(true)
                .setOnlyAlertOnce(true)
                .setGroup(GROUP_KEY)
                .addAction(android.R.drawable.ic_media_pause, "Disconnect", disconnectPending)
                .build()

            nm.notify(nid, noti)
        }

        // Cancel stale ones
        val toCancel = postedIds - currentIds
        toCancel.forEach { nm.cancel(it) }
        // Clean up id mappings for canceled notifications to prevent growth
        if (toCancel.isNotEmpty()) {
            val keysToRemove = notificationIdMap.filterValues { it in toCancel }.keys
            keysToRemove.forEach { notificationIdMap.remove(it) }
        }
        postedIds.clear()
        postedIds.addAll(currentIds)

        // Post/update summary and ensure foreground
        val maxSummaryLines = 5
        val truncated = summaryLines.size > maxSummaryLines
        val displaySummaryLines = if (truncated) {
            summaryLines.take(maxSummaryLines) + "...and ${summaryLines.size - maxSummaryLines} more"
        } else {
            summaryLines
        }
        val summary = createSummaryNotification(sessions.size, displaySummaryLines)
        ensureForeground(summary)
    }

    private fun clearAll() {
        val nm = getSystemService(NotificationManager::class.java)
        nm?.cancel(SUMMARY_ID)
        postedIds.forEach { id -> nm?.cancel(id) }
        postedIds.clear()
        isFgStarted = false
    }

    data class SessionItem(
        val id: String,
        val title: String,
        val subtitle: String,
        val startWhen: Long,
        val status: String,
    )

    private fun stopForegroundService() {
        try {
            stopForeground(true)
        } catch (e: Exception) {
            logError("Error stopping foreground", e)
        }
        stopSelf()
        Log.d("ForegroundService", "ForegroundService stopped")
    }

    override fun onDestroy() {
        super.onDestroy()
        Log.d("ForegroundService", "Service onDestroy")
        isRunning = false
    }
}
