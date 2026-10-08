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

  /// Whether the plugin initialized: once, for the life of the process.
  static Future<bool>? _ready;

  /// Whether notifications are allowed, as last asked. Not cached when they
  /// are not: the user can allow them in the system settings at any time.
  static bool _allowed = false;
  static Future<bool>? _asking;
  static DateTime? _lastAsked;
  static const _askInterval = Duration(minutes: 1);

  /// What tapping each terminal's notification does: bring the terminal back.
  static final _reveal = <String, VoidCallback>{};

  /// How many times each terminal's notification has been cancelled.
  static final _cancels = <String, int>{};

  static const _minInterval = Duration(seconds: 3);
  static DateTime? _lastShown;
  static Timer? _flush;
  static final _pending = <String, ({String title, String body})>{};

  static const _channelId = 'program_status';

  static bool get _supported =>
      !kIsWeb &&
      (isAndroid || isIOS || isMacOS || isLinux || isWindows);

  /// Initializes the plugin once, and asks whether notifications are allowed
  /// — again on a later call while they are not, at most once per
  /// [_askInterval]. Called while the app is in front: on iOS a request made
  /// from the background is not shown.
  static Future<bool> prepare() async {
    if (!_supported) return false;
    if (!await (_ready ??= _init())) return false;
    if (_allowed) return true;
    final last = _lastAsked;
    if (_asking == null &&
        last != null &&
        DateTime.now().difference(last) < _askInterval) {
      return false;
    }
    _allowed = await (_asking ??= _ask());
    return _allowed;
  }

  static Future<bool> _ask() async {
    try {
      return await _requestPermission();
    } catch (e, s) {
      Loggers.app.warning('Program status notifications not allowed', e, s);
      return false;
    } finally {
      _lastAsked = DateTime.now();
      _asking = null;
    }
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
      return true;
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
      if (android == null) return false;
      // What the system settings say now, on every Android version; asking
      // only adds a prompt from 13 on.
      if (await android.areNotificationsEnabled() ?? false) return true;
      return await android.requestNotificationsPermission() ?? false;
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
    // A show already past the queue is waiting on [prepare]; this tells it
    // the notification is no longer wanted.
    _cancels[key] = (_cancels[key] ?? 0) + 1;
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

  /// Shows the terminal that has waited longest, and leaves the rest, each at
  /// its latest, for the next interval.
  static void _flushPending() {
    _flush = null;
    if (_pending.isEmpty) return;
    _lastShown = DateTime.now();
    final key = _pending.keys.first;
    final next = _pending.remove(key)!;
    unawaited(_show(key, next.title, next.body));
    if (_pending.isNotEmpty) _flush = Timer(_minInterval, _flushPending);
  }

  static Future<void> _show(String key, String title, String body) async {
    final cancels = _cancels[key];
    if (!await prepare()) return;
    if (_cancels[key] != cancels) return;
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
