package tech.lolli.toolbox

import android.app.Service
import android.content.Intent

import android.os.IBinder
import org.jetbrains.annotations.Nullable

class KeepAliveService : Service() {
    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        return START_STICKY
    }

    @Nullable
    override fun onBind(intent: Intent?): IBinder? {
        return null
    }
}