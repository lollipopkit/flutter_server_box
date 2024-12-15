package tech.lolli.toolbox

import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.Manifest
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.appwidget.AppWidgetManager
import tech.lolli.toolbox.widget.HomeWidget

class MainActivity: FlutterFragmentActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val binaryMessenger = flutterEngine.dartExecutor.binaryMessenger

        MethodChannel(binaryMessenger, "tech.lolli.toolbox/main_chan").apply {
            setMethodCallHandler { method, result ->
                when (method.method) {
                    "sendToBackground" -> {
                        moveTaskToBack(true)
                        result.success(null)
                    }
                    "startService" -> {
                        reqPerm()
                        val serviceIntent = Intent(this@MainActivity, ForegroundService::class.java)
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                            startForegroundService(serviceIntent)
                        } else {
                            startService(serviceIntent)
                        }
                    }
                    "stopService" -> {
                        val serviceIntent = Intent(this@MainActivity, ForegroundService::class.java)
                        stopService(serviceIntent)
                        result.success(null)
                    }
                    "updateHomeWidget" -> {
                        val intent = Intent(this@MainActivity, HomeWidget::class.java)
                        intent.action = AppWidgetManager.ACTION_APPWIDGET_UPDATE
                        sendBroadcast(intent)
                        result.success(null)
                    }
                    else -> {
                        result.notImplemented()
                    }
                }
            }
        }
    }

    private fun reqPerm() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) return
        if (ContextCompat.checkSelfPermission(this, Manifest.permission.POST_NOTIFICATIONS)
            != PackageManager.PERMISSION_GRANTED) {
            ActivityCompat.requestPermissions(
                this,
                arrayOf(Manifest.permission.POST_NOTIFICATIONS),
                123,
            )
        }
    }
}

