import 'dart:async';

import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:server_box/core/extension/context/locale.dart';

/// System notifications for what a terminal's programs report while it is not
/// on screen — see `TerminalStatusAlerts` for what is worth one.
///
/// One notification per terminal, replaced by its next: a program going from
/// blocked to done is one thing to look at, not two. Shown at most once per
/// [_minInterval] across all terminals; what arrives sooner waits, and only
/// the latest for each terminal is kept.
abstract final class ProgramStatusAlerts {
  static final _plugin = FlutterLocalNotificationsPlugin();

  static Future<bool>? _ready;

  /// What tapping each terminal's notification does: bring the terminal back.
  static final _reveal = <String, VoidCallback>{};

  static const _minInterval = Duration(seconds: 3);
  static DateTime? _lastShown;
  static Timer? _flush;
  static final _pending = <String, ({String title, String body})>{};

  static const _channelId = 'program_status';

  static bool get _supported =>
      !kIsWeb &&
      (isAndroid || isIOS || isMacOS || isLinux || isWindows);

  /// Initializes the plugin and asks for permission, once. Called while the
  /// app is in front — on iOS a request made from the background is not shown,
  /// and is then not asked again.
  static Future<bool> prepare() {
    if (!_supported) return Future.value(false);
    return _ready ??= _init();
  }

  static Future<bool> _init() async {
    try {
      await _plugin.initialize(
        settings: InitializationSettings(
          android: const AndroidInitializationSettings('@mipmap/ic_launcher'),
          iOS: const DarwinInitializationSettings(
            requestAlertPermission: false,
            requestBadgePermission: false,
            requestSoundPermission: false,
          ),
          macOS: const DarwinInitializationSettings(
            requestAlertPermission: false,
            requestBadgePermission: false,
            requestSoundPermission: false,
          ),
          linux: LinuxInitializationSettings(defaultActionName: libL10n.open),
          windows: const WindowsInitializationSettings(
            appName: 'ServerBox',
            appUserModelId: 'Lollipopkit.ServerBox',
            guid: '5f3c4d6e-0b8a-4c51-9a2e-7d1f6b0c8e93',
          ),
        ),
        onDidReceiveNotificationResponse: (response) {
          final key = response.payload;
          if (key != null) _reveal[key]?.call();
        },
      );
      return await _requestPermission();
    } catch (e, s) {
      Loggers.app.warning('Program status notifications unavailable', e, s);
      return false;
    }
  }

  static Future<bool> _requestPermission() async {
    if (isAndroid) {
      final android = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      return await android?.requestNotificationsPermission() ?? false;
    }
    if (isIOS) {
      final ios = _plugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >();
      return await ios?.requestPermissions(alert: true, sound: true) ?? false;
    }
    if (isMacOS) {
      final macos = _plugin
          .resolvePlatformSpecificImplementation<
            MacOSFlutterLocalNotificationsPlugin
          >();
      return await macos?.requestPermissions(alert: true, sound: true) ??
          false;
    }
    return true;
  }

  /// Shows (or replaces) terminal [key]'s notification. [reveal] is run when
  /// it is tapped while the app is running.
  static void show({
    required String key,
    required String title,
    required String body,
    required VoidCallback reveal,
  }) {
    if (!_supported) return;
    _reveal[key] = reveal;
    _pending[key] = (title: title, body: body);
    final last = _lastShown;
    final wait = last == null
        ? Duration.zero
        : _minInterval - DateTime.now().difference(last);
    if (wait <= Duration.zero) {
      _flushPending();
    } else {
      _flush ??= Timer(wait, _flushPending);
    }
  }

  /// Takes terminal [key]'s notification away: it has been looked at, or is
  /// gone.
  static void cancel(String key, {bool forget = false}) {
    _pending.remove(key);
    if (forget) _reveal.remove(key);
    if (_ready == null) return;
    unawaited(_cancel(key));
  }

  static Future<void> _cancel(String key) async {
    if (!await _ready!) return;
    try {
      await _plugin.cancel(id: _idOf(key));
    } catch (e, s) {
      Loggers.app.warning('Failed to cancel a program status notification', e, s);
    }
  }

  static void _flushPending() {
    _flush = null;
    if (_pending.isEmpty) return;
    _lastShown = DateTime.now();
    final pending = Map.of(_pending);
    _pending.clear();
    for (final MapEntry(:key, :value) in pending.entries) {
      unawaited(_show(key, value.title, value.body));
    }
  }

  static Future<void> _show(String key, String title, String body) async {
    if (!await prepare()) return;
    try {
      await _plugin.show(
        id: _idOf(key),
        title: title,
        body: body,
        payload: key,
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId,
            l10n.programStatus,
            importance: Importance.high,
            priority: Priority.high,
            category: AndroidNotificationCategory.status,
          ),
          iOS: const DarwinNotificationDetails(threadIdentifier: _channelId),
          macOS: const DarwinNotificationDetails(threadIdentifier: _channelId),
        ),
      );
    } catch (e, s) {
      Loggers.app.warning('Failed to show a program status notification', e, s);
    }
  }

  /// A stable id per terminal, within what Android takes (a 32-bit int) and
  /// away from the foreground service's own.
  static int _idOf(String key) => 0x10000 + (key.hashCode & 0x3fffffff);
}
