import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/services.dart';
import 'package:server_box/data/res/misc.dart';
import 'package:server_box/data/res/store.dart';

abstract final class MethodChans {
  static const _channel = MethodChannel('${Miscs.pkgName}/main_chan');

  /// Where Android extracted this app's native libraries, or null elsewhere.
  ///
  /// The only directory an app is allowed to execute a file from — its own
  /// data directory is refused, which is the whole reason the Linux rootfs
  /// needs proot. Asked of the platform because nothing in Dart knows it.
  static Future<String?> nativeLibDir() async {
    if (!isAndroid) return null;
    try {
      return await _channel.invokeMethod<String>('nativeLibDir');
    } catch (e) {
      Loggers.app.warning('nativeLibDir', e);
      return null;
    }
  }

  /// Stops Android's terminal foreground service after its queued starts have
  /// been handled.
  static Future<void> stopService() async {
    if (!isAndroid) return;
    try {
      await _channel.invokeMethod('stopService');
    } catch (e, s) {
      Loggers.app.warning('Failed to stop Android terminal service', e, s);
    }
  }

  static Future<void> updateHomeWidget() async {
    if (!isIOS && !isAndroid) return;
    if (!Stores.setting.autoUpdateHomeWidget.fetch()) return;
    try {
      await _channel.invokeMethod('updateHomeWidget');
    } catch (e, s) {
      Loggers.app.warning('Failed to update home widget', e, s);
    }
  }

  /// Hand the home-screen widgets the current monitor server list and a
  /// read-only credential for each.
  ///
  /// The native side splits the payload: the list goes to a container the
  /// widget process reads directly (the iOS App Group, Android's shared
  /// preferences), and every `token` is moved into the platform credential
  /// store instead — see `WidgetSync` for why. It is a full replacement, so a
  /// server absent from [payload] has its stored token dropped as well.
  static Future<void> publishWidgetServers(String payload) async {
    if (!isIOS && !isAndroid) return;
    await _channel.invokeMethod('publishWidgetServers', payload);
  }

  /// Which servers the native side currently holds a widget token for, and
  /// until when — as JSON, `[{"id","endpoint","expiresAt"}]`.
  ///
  /// Never the token itself. The renewal decision needs the endpoint it
  /// belongs to and its deadline, and carrying the credential back across the
  /// channel to answer that would undo the point of storing it natively.
  ///
  /// Answers from the *platform*, not from a copy kept here, because those two
  /// come apart exactly where it matters: a reinstall empties the Keychain
  /// while a restored backup refills this app's own database, and a renewal
  /// decision made from the latter would skip every server whose credential no
  /// longer exists.
  static Future<String?> widgetTokenState() async {
    if (!isIOS && !isAndroid) return null;
    return await _channel.invokeMethod<String>('widgetTokenState');
  }

  /// Last pair pushed by [setIslandBrandColors], so that rebuilding the theme —
  /// which happens on every `MaterialApp` build — does not cross the channel
  /// each time.
  static (int, int)? _islandBrandColors;

  /// Colors for the app name drawn behind the Dynamic Island, as ARGB.
  ///
  /// Follows the theme rather than being fixed, so the badge in a screenshot
  /// matches the app the screenshot is of.
  static Future<void> setIslandBrandColors(int bg, int fg) async {
    if (!isIOS) return;
    if (_islandBrandColors == (bg, fg)) return;
    _islandBrandColors = (bg, fg);
    try {
      await _channel.invokeMethod('setIslandBrandColors', {'bg': bg, 'fg': fg});
    } catch (e, s) {
      _islandBrandColors = null;
      Loggers.app.warning('Failed to set island brand colors', e, s);
    }
  }

  /// Tell the native side whether to cover the app once it leaves the
  /// foreground, hiding its content from the app switcher.
  ///
  /// What "cover" means differs by platform, and deliberately so. iOS lays a
  /// real blur over the Flutter window. Android sets `FLAG_SECURE` instead:
  /// Flutter draws into a `SurfaceView` that `RenderEffect` cannot reach, and
  /// anything that has to render a frame races the system's recents capture,
  /// which the flag does not.
  ///
  /// Pushed on change *and* at launch: the native side answers this from its
  /// own persisted copy, which a reinstall or a restored backup leaves saying
  /// something different from the (synced) settings store.
  ///
  /// Answers whether the native side took it, rather than throwing, so that the
  /// launch-time push can ignore a failure while the switch does not. Storing a
  /// preference the platform never received would leave the user told they are
  /// covered when they are not.
  static Future<bool> setPrivacyBlur(bool enabled) async {
    if (!isIOS && !isAndroid) return true;
    try {
      await _channel.invokeMethod('setPrivacyBlur', enabled);
      return true;
    } catch (e, s) {
      Loggers.app.warning('Failed to set privacy blur', e, s);
      return false;
    }
  }

  /// Hold the cover in place after the app comes forward, until Flutter has
  /// decided whether a biometric lock is coming.
  ///
  /// Without it the cover comes off the moment the app is frontmost, and the
  /// real UI is on screen for however many frames it takes Flutter to hear
  /// about the lifecycle change at all.
  ///
  /// Cleared just before the lock screen is pushed — on iOS the cover is a view
  /// over the whole Flutter window, so it would otherwise hide that screen
  /// rather than protect it.
  static bool? _privacyBlurLocked;

  static Future<void> setPrivacyBlurLocked(bool locked) async {
    if (!isIOS && !isAndroid) return;
    if (_privacyBlurLocked == locked) return;
    _privacyBlurLocked = locked;
    try {
      await _channel.invokeMethod('setPrivacyBlurLocked', locked);
    } catch (e, s) {
      _privacyBlurLocked = null;
      Loggers.app.warning('Failed to set privacy blur lock', e, s);
    }
  }

  /// Starts or updates Android's terminal foreground service with [payload].
  ///
  /// The native side also owns the notification permission request, so one
  /// call describes the desired state instead of racing a separate start.
  static Future<void> updateSessions(String payload) async {
    if (!isAndroid) return;
    try {
      Loggers.app.info('Updating Android sessions: $payload');
      await _channel.invokeMethod('updateSessions', payload);
    } on PlatformException catch (e, s) {
      // A denied notification permission is a supported state: Android cannot
      // run the foreground service, and the settings page explains how to
      // enable it. Do not turn every ordinary session sync into a warning.
      if (e.code == 'NOTIFICATION_PERMISSION_DENIED') return;
      Loggers.app.warning('Failed to update Android sessions', e, s);
    } catch (e, s) {
      Loggers.app.warning('Failed to update Android sessions', e, s);
    }
  }

  /// Whether Android will let this app post notifications.
  ///
  /// Read by the settings page rather than acted on: without the permission
  /// there is no foreground service, and without that the system freezes the
  /// process as soon as it is backgrounded — so `bgRun` is a switch that cannot
  /// keep its promise, and saying nothing about it leaves the user with a
  /// connection that drops for no reason they can see (#1287).
  ///
  /// True off Android, where the question does not arise.
  static Future<bool> notificationsAllowed() async {
    if (!isAndroid) return true;
    try {
      return await _channel.invokeMethod('notificationsAllowed') == true;
    } catch (e, s) {
      Loggers.app.warning('Failed to read the notification permission', e, s);
      // Assumed granted: a failure here is this app's, and reporting it as the
      // user's problem would send them to a settings page to fix nothing.
      return true;
    }
  }

  /// Opens this app's notification settings, for the case above.
  static Future<void> openNotificationSettings() async {
    if (!isAndroid) return;
    try {
      await _channel.invokeMethod('openNotificationSettings');
    } catch (e, s) {
      Loggers.app.warning('Failed to open the notification settings', e, s);
    }
  }

  /// Query whether the Android foreground service is currently running.
  /// How the process ended last time, as Android recorded it.
  ///
  /// The only way this app can see a native crash: one takes the process with
  /// it, so nothing in Dart runs afterwards and nothing is written. The system
  /// keeps the record instead, and this reads it on the next launch.
  ///
  /// Null below API 30, and null when there is nothing recorded. Keys:
  /// `reason` (a name — `crash_native`, `anr`, `low_memory`,
  /// `user_requested`, …), `timestamp` (ms, and the only thing distinguishing
  /// one record from another), `description`, `status`, `importance`, and one
  /// of two traces: `trace`, a `String`, for an ANR, or `traceProto`, the
  /// bytes of a `Tombstone` protocol buffer, for a native crash on API 31+.
  /// Both are absent for every other reason, and either can be absent anyway —
  /// the traces live in a global circular buffer that another app's crash can
  /// evict.
  static Future<Map<String, Object?>?> lastExitInfo() async {
    if (!isAndroid) return null;
    try {
      final res = await _channel.invokeMapMethod<String, Object?>(
        'lastExitInfo',
      );
      return res;
    } catch (e, s) {
      Loggers.app.warning('Failed to read the last exit info', e, s);
      return null;
    }
  }

  /// What MetricKit has reported since this was last asked, on iOS and macOS.
  ///
  /// The counterpart to [lastExitInfo], for the platform that has no equivalent
  /// of it. Delivery is on the system's schedule — a payload arrives somewhere
  /// between the next launch and about a day later — so these accumulate and
  /// this hands over whatever has arrived, rather than answering "the last
  /// run". Cleared by the read.
  ///
  /// Each entry has `kind` (`crash` or `hang`), `appVersion`, `callStack`, and
  /// for a crash whichever of `signal`, `exceptionType`, `exceptionCode` and
  /// `terminationReason` the payload carried.
  static Future<List<Map<String, Object?>>> takeCrashDiagnostics() async {
    if (!isIOS && !isMacOS) return const [];
    try {
      final res = await _channel.invokeListMethod<Object?>(
        'takeCrashDiagnostics',
      );
      return [
        for (final e in res ?? const [])
          if (e is Map) e.cast<String, Object?>(),
      ];
    } catch (e, s) {
      Loggers.app.warning('Failed to read crash diagnostics', e, s);
      return const [];
    }
  }

  static Future<bool> isServiceRunning() async {
    if (!isAndroid) return false;
    try {
      final res = await _channel.invokeMethod('isServiceRunning');
      return res == true;
    } catch (e, s) {
      Loggers.app.warning(
        'Failed to check if Android service is running',
        e,
        s,
      );
      return false;
    }
  }

  // iOS Live Activities controls
  static Future<void> updateLiveActivity(String payload) async {
    if (!isIOS) return;
    try {
      Loggers.app.info('Updating iOS Live Activity: $payload');
      await _channel.invokeMethod('updateLiveActivity', payload);
    } catch (e, s) {
      Loggers.app.warning('Failed to update iOS Live Activity', e, s);
    }
  }

  static Future<void> stopLiveActivity() async {
    if (!isIOS) return;
    try {
      Loggers.app.info('Stopping iOS Live Activity');
      await _channel.invokeMethod('stopLiveActivity');
    } catch (e, s) {
      Loggers.app.warning('Failed to stop iOS Live Activity', e, s);
    }
  }

  /// Register a handler for native -> Flutter callbacks.
  /// Currently handles:
  /// - `disconnectSession` with argument map {id: string}
  /// - `stopAllConnections` with no arguments
  /// - `notificationPermissionGranted` with no arguments
  static void registerHandler(
    Future<void> Function(String id) onDisconnect, [
    VoidCallback? onStopAll,
    VoidCallback? onNotificationPermissionGranted,
  ]) {
    _channel.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'disconnectSession':
          final args = call.arguments;
          final id = args is Map ? args['id'] as String? : args as String?;
          if (id != null && id.isNotEmpty) {
            await onDisconnect(id);
          }
          return;
        case 'stopAllConnections':
          onStopAll?.call();
          return;
        // Android asks for the permission asynchronously, so the call that
        // triggered the prompt has already been refused by the time the user
        // answers it. This is the only edge that says the answer was yes, and
        // without acting on it the foreground service stays stopped until
        // something else happens to sync — see [updateSessions].
        case 'notificationPermissionGranted':
          onNotificationPermissionGranted?.call();
          return;
        default:
          return;
      }
    });
  }
}
