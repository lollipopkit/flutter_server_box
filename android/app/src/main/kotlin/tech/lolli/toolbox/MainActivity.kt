package tech.lolli.toolbox

import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.os.Bundle
import android.view.WindowManager
import android.Manifest
import android.content.BroadcastReceiver
import android.content.Context
import android.content.IntentFilter
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.appwidget.AppWidgetManager
import tech.lolli.toolbox.widget.HomeWidget

class MainActivity: FlutterFragmentActivity() {
    private lateinit var channel: MethodChannel
    private val ACTION_UPDATE_SESSIONS = "tech.lolli.toolbox.ACTION_UPDATE_SESSIONS"
    private val ACTION_DISCONNECT_SESSION = "tech.lolli.toolbox.ACTION_DISCONNECT_SESSION"
    private val ACTION_STOP_ALL_CONNECTIONS = "tech.lolli.toolbox.STOP_ALL_CONNECTIONS"
    private var stopAllReceiver: BroadcastReceiver? = null
    private var disableImpeller = false
    private var ownsFlutterEngine = false

    override fun onCreate(savedInstanceState: Bundle?) {
        val graphicsCompatibility = ImpellerCompatibility.check(this)
        disableImpeller = graphicsCompatibility.disableImpeller
        if (graphicsCompatibility.disableImpeller) {
            android.util.Log.w(
                "MainActivity",
                "Disabling Impeller: ${graphicsCompatibility.reason}",
            )
        }
        super.onCreate(savedInstanceState)
    }

    override fun provideFlutterEngine(context: Context): FlutterEngine? {
        if (!disableImpeller) return null
        val flutterEngine = FlutterEngine(context, arrayOf(ARG_DISABLE_IMPELLER), true, true)
        ownsFlutterEngine = true
        return flutterEngine
    }

    override fun shouldDestroyEngineWithHost(): Boolean {
        return ownsFlutterEngine || super.shouldDestroyEngineWithHost()
    }

    private companion object {
        const val ARG_DISABLE_IMPELLER = "--enable-impeller=false"
        const val PRIVACY_PREFS = "privacy_cover"
        const val KEY_PRIVACY_COVER = "enabled"
    }

    // --- Privacy cover ------------------------------------------------------
    //
    // FLAG_SECURE rather than a view laid over the content: the recents
    // thumbnail is captured by the system around onPause, and anything that has
    // to render a frame first may not be up in time. The flag is applied by the
    // window compositor, so there is no race to lose.
    //
    // This is not the same thing the iOS side does. There a blur really covers
    // the pixels; here the running UI is untouched and only the recents
    // thumbnail and screenshots are blocked. Flutter renders into a SurfaceView,
    // whose contents live on a separate surface that RenderEffect does not
    // reach, so an in-app blur would mean PixelCopy plus an async round trip —
    // exactly the race this avoids.

    private val privacyPrefs by lazy {
        getSharedPreferences(PRIVACY_PREFS, Context.MODE_PRIVATE)
    }

    /// Set from Dart while the biometric lock is pending, so that coming back to
    /// the foreground does not clear the flag before the lock screen is up.
    private var privacyLocked = false
    private var isForeground = false

    private var privacyCoverEnabled: Boolean
        get() = privacyPrefs.getBoolean(KEY_PRIVACY_COVER, false)
        set(value) = privacyPrefs.edit().putBoolean(KEY_PRIVACY_COVER, value).apply()

    private fun applyPrivacyCover(on: Boolean) {
        if (on) {
            window.setFlags(
                WindowManager.LayoutParams.FLAG_SECURE,
                WindowManager.LayoutParams.FLAG_SECURE,
            )
        } else {
            window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
        }
    }

    override fun onPause() {
        super.onPause()
        isForeground = false
        if (privacyCoverEnabled) applyPrivacyCover(true)
    }

    override fun onResume() {
        super.onResume()
        isForeground = true
        if (!privacyLocked) applyPrivacyCover(false)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val binaryMessenger = flutterEngine.dartExecutor.binaryMessenger

        channel = MethodChannel(binaryMessenger, "tech.lolli.toolbox/main_chan")
        channel.setMethodCallHandler { method, result ->
                when (method.method) {
                    "sendToBackground" -> {
                        moveTaskToBack(true)
                        result.success(null)
                    }
                    // The one directory an app may execute a file from. Not
                    // reachable from Dart, and everything the Linux rootfs
                    // does depends on knowing it — see
                    // scripts/build-proot-android.sh.
                    "nativeLibDir" -> {
                        result.success(applicationInfo.nativeLibraryDir)
                    }
                    "isServiceRunning" -> {
                        result.success(ForegroundService.isRunning)
                    }
                    // Whether this app may post notifications at all. Without
                    // it there is no foreground service, and without that the
                    // system freezes the process the moment it is backgrounded
                    // — so "run in the background" is a switch that cannot do
                    // what it says. The settings page reads this to say so.
                    "notificationsAllowed" -> {
                        result.success(notificationsAllowed())
                    }
                    "openNotificationSettings" -> {
                        try {
                            val intent = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                                Intent(android.provider.Settings.ACTION_APP_NOTIFICATION_SETTINGS)
                                    .putExtra(android.provider.Settings.EXTRA_APP_PACKAGE, packageName)
                            } else {
                                Intent(android.provider.Settings.ACTION_APPLICATION_DETAILS_SETTINGS)
                                    .setData(android.net.Uri.fromParts("package", packageName, null))
                            }
                            startActivity(intent)
                            result.success(null)
                        } catch (e: Exception) {
                            android.util.Log.e("MainActivity", "Failed to open notification settings: ${e.message}")
                            result.error("SETTINGS_ERROR", e.message, null)
                        }
                    }
                    "setPrivacyBlur" -> {
                        privacyCoverEnabled = method.arguments as? Boolean ?: false
                        if (!privacyCoverEnabled) applyPrivacyCover(false)
                        result.success(null)
                    }
                    "setPrivacyBlurLocked" -> {
                        privacyLocked = method.arguments as? Boolean ?: false
                        // Only while frontmost: clearing it in the background
                        // would undo the cover on the recents thumbnail itself.
                        if (!privacyLocked && isForeground) applyPrivacyCover(false)
                        result.success(null)
                    }
                    "startService" -> {
                        try {
                            reqPerm()
                            if (!notificationsAllowed()) {
                                // Don't start foreground service without notification permission on API 33+
                                result.error("NOTIFICATION_PERMISSION_DENIED", "Notification permission not granted", null)
                                return@setMethodCallHandler
                            }
                            val serviceIntent = Intent(this@MainActivity, ForegroundService::class.java)
                            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                                startForegroundService(serviceIntent)
                            } else {
                                startService(serviceIntent)
                            }
                            result.success(null)
                        } catch (e: Exception) {
                            // Log error but don't crash
                            android.util.Log.e("MainActivity", "Failed to start service: ${e.message}")
                            result.error("SERVICE_ERROR", e.message, null)
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
                    "updateSessions" -> {
                        try {
                            if (!notificationsAllowed()) {
                                // Avoid starting/continuing service updates when notifications are blocked
                                result.error("NOTIFICATION_PERMISSION_DENIED", "Notification permission not granted", null)
                                return@setMethodCallHandler
                            }
                            val serviceIntent = Intent(this@MainActivity, ForegroundService::class.java)
                            serviceIntent.action = ACTION_UPDATE_SESSIONS
                            serviceIntent.putExtra("payload", method.arguments as String)
                            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                                startForegroundService(serviceIntent)
                            } else {
                                startService(serviceIntent)
                            }
                            result.success(null)
                        } catch (e: Exception) {
                            android.util.Log.e("MainActivity", "Failed to update sessions: ${e.message}")
                            result.error("SERVICE_ERROR", e.message, null)
                        }
                    }
                    else -> {
                        result.notImplemented()
                    }
                }
        }

        // Handle intent if launched via notification action
        handleActionIntent(intent)

        // Register broadcast receiver for stop all connections
        setupStopAllReceiver()
    }

    private fun reqPerm() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) return
        
        try {
            // Check if we already have the permission to avoid unnecessary prompts
            if (ContextCompat.checkSelfPermission(this, Manifest.permission.POST_NOTIFICATIONS)
                != PackageManager.PERMISSION_GRANTED) {
                // Check if we should show rationale
                if (ActivityCompat.shouldShowRequestPermissionRationale(this, Manifest.permission.POST_NOTIFICATIONS)) {
                    android.util.Log.i("MainActivity", "User previously denied notification permission")
                }
                
                ActivityCompat.requestPermissions(
                    this,
                    arrayOf(Manifest.permission.POST_NOTIFICATIONS),
                    123,
                )
            }
        } catch (e: Exception) {
            // Log error but don't crash
            android.util.Log.e("MainActivity", "Failed to request permissions: ${e.message}")
        }
    }

    private fun notificationsAllowed(): Boolean {
        return if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) {
            true
        } else {
            ContextCompat.checkSelfPermission(this, Manifest.permission.POST_NOTIFICATIONS) == PackageManager.PERMISSION_GRANTED
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        handleActionIntent(intent)
    }

    private fun handleActionIntent(intent: Intent?) {
        if (intent == null) return
        when (intent.action) {
            ACTION_DISCONNECT_SESSION -> {
                val sessionId = intent.getStringExtra("session_id")
                if (sessionId != null && ::channel.isInitialized) {
                    try {
                        channel.invokeMethod("disconnectSession", mapOf("id" to sessionId))
                    } catch (e: Exception) {
                        android.util.Log.e("MainActivity", "Failed to invoke disconnect: ${e.message}")
                    }
                }
            }
        }
    }

    private fun setupStopAllReceiver() {
        stopAllReceiver = object : BroadcastReceiver() {
            override fun onReceive(context: Context?, intent: Intent?) {
                if (intent?.action == ACTION_STOP_ALL_CONNECTIONS && ::channel.isInitialized) {
                    try {
                        channel.invokeMethod("stopAllConnections", null)
                    } catch (e: Exception) {
                        android.util.Log.e("MainActivity", "Failed to invoke stopAllConnections: ${e.message}")
                    }
                }
            }
        }
        val filter = IntentFilter(ACTION_STOP_ALL_CONNECTIONS)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            ContextCompat.registerReceiver(this, stopAllReceiver, filter, ContextCompat.RECEIVER_NOT_EXPORTED)
        } else {
            registerReceiver(stopAllReceiver, filter)
        }
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == 123) {
            if (grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED) {
                android.util.Log.i("MainActivity", "Notification permission granted")
            } else {
                android.util.Log.w("MainActivity", "Notification permission denied")
                // Optionally inform user about the limitation
            }
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        stopAllReceiver?.let {
            try {
                unregisterReceiver(it)
            } catch (e: Exception) {
                android.util.Log.e("MainActivity", "Failed to unregister receiver: ${e.message}")
            }
            stopAllReceiver = null
        }
    }
}
