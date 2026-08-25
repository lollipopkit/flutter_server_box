import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/services.dart';
import 'package:server_box/data/model/server/server_private_info.dart';
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

  /// Issue #662
  static void startService() {
    if (Stores.setting.fgService.fetch() != true) return;
    _channel.invokeMethod('startService');
  }

  /// Issue #662
  static void stopService() {
    if (Stores.setting.fgService.fetch() != true) return;
    _channel.invokeMethod('stopService');
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

  /// Point the iOS lock-screen accessory widget at a server's Go-compat
  /// `/status` URL, or clear it with `null`.
  ///
  /// The widget reads this out of the App Group container, which no Dart code
  /// ever wrote — so every install has been showing "url is nil" on the
  /// accessory families since they were added.
  static Future<void> setAccessoryWidgetUrl(String? url) async {
    if (!isIOS) return;
    try {
      await _channel.invokeMethod('setAccessoryWidgetUrl', url);
    } catch (e, s) {
      Loggers.app.warning('Failed to set accessory widget url', e, s);
    }
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

  /// Tell the native side whether to blur the app once it leaves the
  /// foreground, hiding its content in the app switcher.
  ///
  /// Pushed on change *and* at launch: the native side answers this from its
  /// own `UserDefaults` copy, which a reinstall or a restored backup leaves
  /// saying something different from the (synced) settings store.
  static Future<void> setPrivacyBlur(bool enabled) async {
    if (!isIOS) return;
    try {
      await _channel.invokeMethod('setPrivacyBlur', enabled);
    } catch (e, s) {
      Loggers.app.warning('Failed to set privacy blur', e, s);
    }
  }

  /// Re-derive the accessory widget's URL from the chosen server.
  ///
  /// Run at launch as well as on change: the App Group container goes away
  /// with the app, while the choice lives in the (backed up, synced) settings
  /// store, so a reinstall has to re-publish it.
  static Future<void> syncAccessoryWidgetUrl() async {
    if (!isIOS) return;
    final id = Stores.setting.accessoryWidgetServerId.fetch();
    final spi = id.isEmpty ? null : Stores.server.fetchOneRaw(id);
    await setAccessoryWidgetUrl(spi?.monitorStatusUrl);
  }

  /// Update Android foreground service notifications for SSH sessions
  /// The [payload] is a JSON string describing sessions list.
  static Future<void> updateSessions(String payload) async {
    if (!isAndroid) return;
    try {
      Loggers.app.info('Updating Android sessions: $payload');
      await _channel.invokeMethod('updateSessions', payload);
    } catch (e, s) {
      Loggers.app.warning('Failed to update Android sessions', e, s);
    }
  }

  /// Query whether the Android foreground service is currently running.
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
  static void registerHandler(
    Future<void> Function(String id) onDisconnect, [
    VoidCallback? onStopAll,
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
        default:
          return;
      }
    });
  }
}
