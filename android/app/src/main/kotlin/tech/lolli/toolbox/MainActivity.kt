package tech.lolli.toolbox

import android.content.Intent
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterFragmentActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val binaryMessenger = flutterEngine.dartExecutor.binaryMessenger

        MethodChannel(binaryMessenger, "tech.lolli.toolbox/app_retain").apply {
            setMethodCallHandler { method, result ->
                when (method.method) {
                    "sendToBackground" -> {
                        moveTaskToBack(true)
                        result.success(null)
                    }
                    "startService" -> {
                        val intent = Intent(this@MainActivity, KeepAliveService::class.java)
                        startService(intent)
                    }
                    else -> {
                        result.notImplemented()
                    }
                }
            }
        }
    }
}
