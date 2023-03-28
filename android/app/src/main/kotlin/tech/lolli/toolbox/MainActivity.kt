package tech.lolli.toolbox

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val binaryMessenger = flutterEngine.dartExecutor.binaryMessenger

        MethodChannel(binaryMessenger, "tech.lolli.toolbox/app_retain").apply {
            setMethodCallHandler { method, result ->
                if (method.method == "sendToBackground") {
                    moveTaskToBack(true)
                    result.success(null)
                } else {
                    result.notImplemented()
                }
            }
        }
    }
}
