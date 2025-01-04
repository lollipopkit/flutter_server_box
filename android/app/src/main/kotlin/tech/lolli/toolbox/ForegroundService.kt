package tech.lolli.toolbox

import android.app.*
import android.content.Intent
import android.os.Build
import android.os.IBinder
import android.util.Log
import java.io.File
import java.util.*

class ForegroundService : Service() {
    private val chanId = "ForegroundServiceChannel"

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

            // Create notification before starting foreground
            val notification = createNotification()
            
            // Use try-catch for startForeground
            try {
                startForeground(1, notification)
            } catch (e: Exception) {
                logError("Failed to start foreground", e)
                stopSelf()
                return START_NOT_STICKY
            }

            return when (action) {
                "ACTION_STOP_FOREGROUND" -> {
                    stopForegroundService()
                    START_NOT_STICKY
                }
                else -> {
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

    private fun createNotification(): Notification {
        try {
            val notificationIntent = Intent(this, MainActivity::class.java)
            val pendingIntent = PendingIntent.getActivity(
                this,
                0,
                notificationIntent,
                PendingIntent.FLAG_IMMUTABLE
            )

            val deleteIntent = Intent(this, ForegroundService::class.java).apply {
                action = "ACTION_STOP_FOREGROUND"
            }
            val deletePendingIntent = PendingIntent.getService(
                this,
                0,
                deleteIntent,
                PendingIntent.FLAG_IMMUTABLE
            )

            val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                Notification.Builder(this, chanId)
            } else {
                Notification.Builder(this)
            }

            return builder
                .setContentTitle("Server Box")
                .setContentText("Running in background")
                .setSmallIcon(R.mipmap.ic_launcher)
                .setContentIntent(pendingIntent)
                .addAction(android.R.drawable.ic_delete, "Stop", deletePendingIntent)
                .build()
        } catch (e: Exception) {
            logError("Error creating notification", e)
            // Return a basic notification as fallback
            return Notification.Builder(this)
                .setContentTitle("Server Box")
                .setSmallIcon(R.mipmap.ic_launcher)
                .build()
        }
    }

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
    }
}