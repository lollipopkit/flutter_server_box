package tech.lolli.toolbox

import android.app.*
import android.content.Intent
import android.os.Build
import android.os.IBinder

class ForegroundService : Service() {
    private val chanId = "ForegroundServiceChannel"

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            "ACTION_STOP_FOREGROUND" -> {
                stopForegroundService()
                return START_NOT_STICKY
            }
            else -> {
                val notification = createNotification()
                startForeground(1, notification)
                return START_STICKY
            }
        }
    }

    override fun onBind(intent: Intent): IBinder? {
        return null
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val serviceChannel = NotificationChannel(
                chanId,
                chanId,
                NotificationManager.IMPORTANCE_DEFAULT
            )
            val manager = getSystemService(NotificationManager::class.java)
            manager.createNotificationChannel(serviceChannel)
        }
    }

    private fun createNotification(): Notification {
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

        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, chanId)
                .setContentTitle("Server Box")
                .setContentText("Open the app")
                .setSmallIcon(R.mipmap.ic_launcher)
                .setContentIntent(pendingIntent)
                .addAction(android.R.drawable.ic_delete, "Stop", deletePendingIntent)
                .build()
        } else {
            Notification.Builder(this)
                .setContentTitle("Server Box")
                .setContentText("Open the app")
                .setSmallIcon(R.mipmap.ic_launcher)
                .setContentIntent(pendingIntent)
                .addAction(android.R.drawable.ic_delete, "Stop", deletePendingIntent)
                .build()
        }
    }

    fun stopForegroundService() {
        stopForeground(true)
        stopSelf()
    }
}