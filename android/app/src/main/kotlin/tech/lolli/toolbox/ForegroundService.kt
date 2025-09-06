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
    private val NOTIFICATION_ID = 1000
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
                    // Notify Flutter to stop all connections before stopping service
                    val stopAllIntent = Intent("tech.lolli.toolbox.STOP_ALL_CONNECTIONS")
                    sendBroadcast(stopAllIntent)
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
                    ensureForeground(createMergedNotification(0, emptyList(), emptyList()))
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
                startForeground(NOTIFICATION_ID, notification)
                isFgStarted = true
            } else {
                val nm = getSystemService(NotificationManager::class.java)
                nm?.notify(NOTIFICATION_ID, notification)
            }
        } catch (e: Exception) {
            logError("Failed to start/update foreground", e)
        }
    }


    private fun createMergedNotification(count: Int, lines: List<String>, sessions: List<SessionItem>): Notification {
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

        // Use the earliest session's start time for chronometer
        val earliestStartTime = sessions.minOfOrNull { it.startWhen } ?: System.currentTimeMillis()

        val title = when {
            count == 0 -> "Server Box"
            count == 1 -> sessions.first().title
            else -> "SSH sessions: $count active"
        }

        val contentText = when {
            count == 0 -> "Ready for connections"
            count == 1 -> {
                val session = sessions.first()
                "${session.subtitle} · ${session.status}"
            }
            else -> "Multiple SSH connections active"
        }

        // For multiple sessions, show details in expanded view
        val style = if (count > 1) {
            val inbox = Notification.InboxStyle()
            val maxLines = 5
            val displayLines = if (lines.size > maxLines) {
                lines.take(maxLines) + "...and ${lines.size - maxLines} more"
            } else {
                lines
            }
            displayLines.forEach { inbox.addLine(it) }
            inbox.setBigContentTitle(title)
            inbox
        } else {
            null
        }

        val notification = builder
            .setContentTitle(title)
            .setContentText(contentText)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setWhen(earliestStartTime)
            .setUsesChronometer(true)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setContentIntent(pendingIntent)
            .addAction(android.R.drawable.ic_delete, "Stop All", stopPending)

        if (style != null) {
            notification.setStyle(style)
        }

        return notification.build()
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

        // Cancel any existing individual notifications (we only show merged notification now)
        val toCancel = postedIds.toSet()
        toCancel.forEach { nm.cancel(it) }
        postedIds.clear()
        notificationIdMap.clear()

        // Create merged notification content
        val summaryLines = sessions.map { "${it.title}: ${it.status}" }
        val mergedNotification = createMergedNotification(sessions.size, summaryLines, sessions)
        ensureForeground(mergedNotification)
    }

    private fun clearAll() {
        val nm = getSystemService(NotificationManager::class.java)
        nm?.cancel(NOTIFICATION_ID)
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
