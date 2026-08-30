package tech.lolli.toolbox

import android.app.ActivityManager
import android.app.ApplicationExitInfo
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
import tech.lolli.toolbox.widget.WidgetStore

class MainActivity: FlutterFragmentActivity() {
    private lateinit var channel: MethodChannel
    private val ACTION_UPDATE_SESSIONS = "tech.lolli.toolbox.ACTION_UPDATE_SESSIONS"
    private val ACTION_DISCONNECT_SESSION = "tech.lolli.toolbox.ACTION_DISCONNECT_SESSION"
    private val ACTION_STOP_ALL_CONNECTIONS = "tech.lolli.toolbox.STOP_ALL_CONNECTIONS"
    private val INTERNAL_BROADCAST_PERMISSION = "tech.lolli.toolbox.permission.INTERNAL_BROADCAST"
    private var stopAllReceiver: BroadcastReceiver? = null
    private var disableImpeller = false
    private var ownsFlutterEngine = false
    private var notificationPermissionRequestInFlight = false

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
        const val NOTIFICATION_PERMISSION_REQUEST_CODE = 123
        const val NOTIFICATION_PERMISSION_PREFS = "notification_permission"
        const val KEY_NOTIFICATION_PERMISSION_REQUESTED = "requested"

        /**
         * The most tombstone this will carry across the method channel.
         *
         * Real ones run to tens of kilobytes; the ceiling is here so a
         * pathological record cannot be read into memory at launch, not
         * because 8 MiB is a size anything is expected to approach.
         */
        const val MAX_TOMBSTONE_BYTES = 8 * 1024 * 1024
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
                    // Why the process died last time, from the system rather
                    // than from anything this app managed to run on its way
                    // out. Covers the crashes Dart cannot see at all: a SIGSEGV
                    // in the Rust FFI, in proot, or in sqlite.
                    "lastExitInfo" -> {
                        // Off the main thread: an ANR trace is a full thread
                        // dump and routinely hundreds of KB, and the Dart side
                        // awaits this before the first frame. Reading it inline
                        // would stall the UI thread on a device that has just
                        // been shown to be struggling.
                        Thread {
                            val info = lastExitInfo()
                            runOnUiThread { result.success(info) }
                        }.start()
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
                    "stopService" -> {
                        try {
                            // Queue the stop behind any pending foreground start.
                            // Context.stopService can destroy the instance before
                            // that start reaches onStartCommand, leaving Android's
                            // foreground-service obligation outstanding.
                            val serviceIntent = Intent(this@MainActivity, ForegroundService::class.java).apply {
                                action = ForegroundService.ACTION_STOP_SERVICE
                            }
                            startService(serviceIntent)
                            result.success(null)
                        } catch (e: Exception) {
                            android.util.Log.e("MainActivity", "Failed to stop service: ${e.message}")
                            result.error("SERVICE_ERROR", e.message, null)
                        }
                    }
                    "updateHomeWidget" -> {
                        HomeWidget.broadcastUpdate(applicationContext)
                        result.success(null)
                    }
                    "publishWidgetServers" -> {
                        val payload = method.arguments as? String
                        if (payload == null) {
                            result.success(null)
                            return@setMethodCallHandler
                        }
                        WidgetStore.publish(applicationContext, payload)
                        // Every placed widget of either size, not just one: a
                        // republish can change a name, an address or a
                        // credential, and which widget was pointed at which
                        // server is not known here.
                        HomeWidget.broadcastUpdate(applicationContext)
                        result.success(null)
                    }
                    "widgetTokenState" -> {
                        result.success(WidgetStore.tokenState(applicationContext))
                    }
                    "updateSessions" -> {
                        try {
                            requestNotificationPermissionOnce()
                            if (!notificationsAllowed()) {
                                // Avoid starting/continuing service updates when notifications are blocked
                                result.error("NOTIFICATION_PERMISSION_DENIED", "Notification permission not granted", null)
                                return@setMethodCallHandler
                            }
                            val serviceIntent = Intent(this@MainActivity, ForegroundService::class.java)
                            serviceIntent.action = ACTION_UPDATE_SESSIONS
                            serviceIntent.putExtra("payload", method.arguments as String)
                            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O && !ForegroundService.isRunning) {
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

    private fun requestNotificationPermissionOnce() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) return

        if (notificationsAllowed()) return
        if (notificationPermissionRequestInFlight) return

        val permissionPrefs = getSharedPreferences(
            NOTIFICATION_PERMISSION_PREFS,
            Context.MODE_PRIVATE,
        )
        if (permissionPrefs.getBoolean(KEY_NOTIFICATION_PERMISSION_REQUESTED, false)) return

        // Record this before launching Android's permission activity. That
        // activity changes the Flutter lifecycle, which immediately causes
        // another session sync; without both guards every sync launches a new
        // permission activity until Android removes the task.
        notificationPermissionRequestInFlight = true
        permissionPrefs.edit().putBoolean(KEY_NOTIFICATION_PERMISSION_REQUESTED, true).apply()

        try {
            ActivityCompat.requestPermissions(
                this,
                arrayOf(Manifest.permission.POST_NOTIFICATIONS),
                NOTIFICATION_PERMISSION_REQUEST_CODE,
            )
        } catch (e: Exception) {
            notificationPermissionRequestInFlight = false
            // A failed launch did not ask the user anything, so allow a later
            // sync to make one genuine retry.
            permissionPrefs.edit().remove(KEY_NOTIFICATION_PERMISSION_REQUESTED).apply()
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

    /**
     * How the process ended last time, as the system recorded it.
     *
     * The only way to see a native crash from inside the app. A SIGSEGV in the
     * Rust FFI, in proot, or in sqlite takes the process with it, so nothing in
     * Dart runs afterwards and nothing is written -- but the system keeps a
     * record, and this reads it on the next launch.
     *
     * Deliberately not a signal handler. Collection happens out of process, so
     * no code runs inside a crashing app and no handler is installed for
     * SIGSEGV or SIGABRT -- which matters here beyond the usual reasons,
     * because the iOS Linux engine interrupts its guest threads with SIGUSR1
     * and a crash reporter fighting over signal disposition is a class of bug
     * this avoids entirely.
     *
     * Null below API 30, where the API does not exist.
     *
     * Two shapes of trace come back, and which one depends on the reason. ANR
     * hands over a thread dump as plain text and it is passed through as
     * `trace`. A native crash hands over a tombstone serialised as a protocol
     * buffer (API 31+); the bytes are passed through as `traceProto` and
     * decoded on the Dart side, which is where they can be tested against a
     * fixture without a device.
     */
    private fun lastExitInfo(): Map<String, Any?>? {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.R) return null
        return try {
            val am = getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
            // One record: the caller compares timestamps to decide whether it
            // has seen this one, and anything older it has seen already.
            val info = am.getHistoricalProcessExitReasons(packageName, 0, 1)
                .firstOrNull() ?: return null
            mapOf(
                "reason" to exitReasonName(info.reason),
                "timestamp" to info.timestamp,
                "description" to info.description,
                "status" to info.status,
                // Whether the app was in front when it died. A crash the user
                // was looking at and one that happened in the background are
                // different reports.
                "importance" to info.importance,
                "trace" to anrTrace(info),
                "traceProto" to tombstoneBytes(info),
            )
        } catch (e: Exception) {
            android.util.Log.e("MainActivity", "lastExitInfo: ${e.message}")
            null
        }
    }

    /** The ANR trace, which is text. Null for everything else. */
    private fun anrTrace(info: ApplicationExitInfo): String? {
        if (info.reason != ApplicationExitInfo.REASON_ANR) return null
        return try {
            // Kept in a global circular buffer, so another app's crash can
            // evict it and this is null often enough to be normal.
            info.traceInputStream?.bufferedReader()?.use { it.readText() }
        } catch (e: Exception) {
            null
        }
    }

    /**
     * The tombstone for a native crash, as the bytes the system wrote.
     *
     * Handed over undecoded on purpose. The `Tombstone` protobuf is read in
     * Dart, so the parser it needs is covered by `flutter test` against a
     * recorded fixture rather than only by a device that has to crash first --
     * and adding the protobuf runtime and its Gradle plugin here would put a
     * dependency and a code generator into the build that F-Droid rebuilds and
     * `androidReproducible` compares.
     *
     * API 31 is where the stream starts carrying this; on API 30 the reason is
     * recorded but there is no trace to go with it.
     */
    private fun tombstoneBytes(info: ApplicationExitInfo): ByteArray? {
        if (info.reason != ApplicationExitInfo.REASON_CRASH_NATIVE) return null
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S) return null
        return try {
            // Kept in a global circular buffer, so another app's crash can
            // evict it and this is null often enough to be normal.
            val stream = info.traceInputStream ?: return null
            // A tombstone carries memory dumps, every mapping and the tail of
            // the log buffers, so it is bounded rather than trusted to be
            // small -- this crosses a method channel at launch. The cap is far
            // above any real one; hitting it means something is wrong, and a
            // truncated protobuf is refused by the parser rather than
            // half-read.
            stream.use { readBounded(it, MAX_TOMBSTONE_BYTES) }
        } catch (e: Exception) {
            null
        }
    }

    /**
     * Everything the stream has, or null if there is more than [limit] of it.
     *
     * Null rather than the first [limit] bytes: a truncated protobuf is not a
     * shorter tombstone, it is one the parser has to refuse, so handing one
     * over would only move the failure.
     */
    private fun readBounded(stream: java.io.InputStream, limit: Int): ByteArray? {
        val out = java.io.ByteArrayOutputStream()
        val buf = ByteArray(16 * 1024)
        while (true) {
            val n = stream.read(buf)
            if (n < 0) break
            if (out.size() + n > limit) {
                android.util.Log.w("MainActivity", "tombstone over ${limit}B, dropped")
                return null
            }
            out.write(buf, 0, n)
        }
        return if (out.size() == 0) null else out.toByteArray()
    }

    /**
     * The reason as a name rather than an int, because the int is a platform
     * constant whose meaning is not obvious in a bug report pasted by a user.
     */
    private fun exitReasonName(reason: Int): String = when (reason) {
        ApplicationExitInfo.REASON_ANR -> "anr"
        ApplicationExitInfo.REASON_CRASH -> "crash"
        ApplicationExitInfo.REASON_CRASH_NATIVE -> "crash_native"
        ApplicationExitInfo.REASON_DEPENDENCY_DIED -> "dependency_died"
        ApplicationExitInfo.REASON_EXCESSIVE_RESOURCE_USAGE -> "excessive_resource_usage"
        ApplicationExitInfo.REASON_EXIT_SELF -> "exit_self"
        ApplicationExitInfo.REASON_INITIALIZATION_FAILURE -> "initialization_failure"
        ApplicationExitInfo.REASON_LOW_MEMORY -> "low_memory"
        ApplicationExitInfo.REASON_OTHER -> "other"
        ApplicationExitInfo.REASON_PERMISSION_CHANGE -> "permission_change"
        ApplicationExitInfo.REASON_SIGNALED -> "signaled"
        ApplicationExitInfo.REASON_USER_REQUESTED -> "user_requested"
        ApplicationExitInfo.REASON_USER_STOPPED -> "user_stopped"
        else -> "unknown($reason)"
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
            // `RECEIVER_NOT_EXPORTED` does not exist before API 33, and a bare
            // `registerReceiver` leaves this reachable by every app on the
            // device — for an action whose whole job is to disconnect every SSH
            // session. The signature-level permission is what restricts the
            // sender to this build.
            registerReceiver(stopAllReceiver, filter, INTERNAL_BROADCAST_PERMISSION, null)
        }
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == NOTIFICATION_PERMISSION_REQUEST_CODE) {
            notificationPermissionRequestInFlight = false
            if (grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED) {
                android.util.Log.i("MainActivity", "Notification permission granted")
                // The permission request is asynchronous and `updateSessions`
                // test the permission the moment after asking for it, so the
                // first attempt is always refused and nothing retries it. With
                // a session already open and no further lifecycle change
                // coming, the service stayed stopped and the process was free
                // to be frozen — despite the user having just said yes. Telling
                // Dart is what makes it ask again.
                if (::channel.isInitialized) {
                    try {
                        channel.invokeMethod("notificationPermissionGranted", null)
                    } catch (e: Exception) {
                        android.util.Log.e("MainActivity", "Failed to report the grant: ${e.message}")
                    }
                }
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
