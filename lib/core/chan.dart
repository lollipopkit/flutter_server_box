import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/services.dart';
import 'package:server_box/data/res/misc.dart';
import 'package:server_box/data/res/store.dart';

abstract final class MethodChans {
  static const _channel = MethodChannel('${Miscs.pkgName}/main_chan');

  static void moveToBg() {
    _channel.invokeMethod('sendToBackground');
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

  static void updateHomeWidget() async {
    if (!isIOS && !isAndroid) return;
    if (!Stores.setting.autoUpdateHomeWidget.fetch()) return;
    await _channel.invokeMethod('updateHomeWidget');
  }

  /// Update Android foreground service notifications for SSH sessions
  /// The [payload] is a JSON string describing sessions list.
  static Future<void> updateSessions(String payload) async {
    if (!isAndroid) return;
    try {
      Loggers.app.info('Updating Android sessions: $payload');
      await _channel.invokeMethod('updateSessions', payload);
    } catch (_) {
      // ignore
    }
  }

  /// Query whether the Android foreground service is currently running.
  static Future<bool> isServiceRunning() async {
    if (!isAndroid) return false;
    try {
      final res = await _channel.invokeMethod('isServiceRunning');
      return res == true;
    } catch (_) {
      return false;
    }
  }

  // iOS Live Activities controls
  static Future<void> startLiveActivity(String payload) async {
    if (!isIOS) return;
    try {
      Loggers.app.info('Starting iOS Live Activity: $payload');
      await _channel.invokeMethod('startLiveActivity', payload);
    } catch (_) {}
  }

  static Future<void> updateLiveActivity(String payload) async {
    if (!isIOS) return;
    try {
      Loggers.app.info('Updating iOS Live Activity: $payload');
      await _channel.invokeMethod('updateLiveActivity', payload);
    } catch (_) {}
  }

  static Future<void> stopLiveActivity() async {
    if (!isIOS) return;
    try {
      Loggers.app.info('Stopping iOS Live Activity');
      await _channel.invokeMethod('stopLiveActivity');
    } catch (_) {}
  }

  /// Register a handler for native -> Flutter callbacks.
  /// Currently handles: `disconnectSession` with argument map {id: string}
  static void registerHandler(Future<void> Function(String id) onDisconnect) {
    _channel.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'disconnectSession':
          final args = call.arguments;
          final id = args is Map ? args['id'] as String? : args as String?;
          if (id != null && id.isNotEmpty) {
            await onDisconnect(id);
          }
          return;
        default:
          return;
      }
    });
  }
}
