import 'dart:async';
import 'dart:convert';

import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/foundation.dart';
import 'package:server_box/core/chan.dart';
import 'package:server_box/data/res/store.dart';
import 'package:server_box/data/ssh/android_service_policy.dart';

enum TermSessionStatus {
  connecting,
  connected,
  disconnected;

  @override
  String toString() {
    return name.capitalize;
  }
}

/// Represents a running SSH terminal session for Android notifications and iOS Live Activities.
class TermSessionInfo {
  final String id;
  final String title; // e.g. server name
  final String subtitle; // e.g. user@ip:port
  final int startTimeMs;
  final TermSessionStatus status;

  TermSessionInfo({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.startTimeMs,
    required this.status,
  });

  Map<String, Object> toJson() => {
    'id': id,
    'title': title,
    'subtitle': subtitle,
    'startTimeMs': startTimeMs,
    'status': status.toString(),
  };
}

/// Singleton to track active SSH sessions and sync to Android notifications.
abstract final class TermSessionManager {
  static final Map<String, _Entry> _entries = {};
  static String? _activeId; // For iOS Live Activity
  static Timer? _updateTimer; // Timer for iOS Live Activity updates
  static Future<void>? _syncing;
  static bool _syncDirty = false;
  static const _updateInterval = Duration(
    seconds: 5,
  ); // 5-second update interval

  static Future<void> init() async {
    if (isAndroid) {
      MethodChans.registerHandler(
        (id) async {
          _entries[id]?.disconnect?.call();
        },
        () {
          // Stop all connections when notification "Stop All" is pressed
          stopAllConnections();
        },
        // The first attempt to start the service raised the permission prompt
        // and was refused by the same call, because asking is asynchronous.
        // This is the answer arriving, and syncing is what asks again.
        _sync,
      );
    }
    if (isIOS) {
      // A Live Activity can outlive a killed process. Clear any orphan left
      // by the previous app run before new sessions can be registered.
      await MethodChans.stopLiveActivity();
    }
  }

  /// Called when Android notification "Stop All" button is pressed
  static void stopAllConnections() {
    // Disconnect all sessions
    final disconnectCallbacks = _entries.values
        .map((e) => e.disconnect)
        .where((cb) => cb != null)
        .toList();
    for (final disconnect in disconnectCallbacks) {
      disconnect!();
    }
    // Clear all entries
    _entries.clear();
    _activeId = null;
    // And stand down, rather than letting the keep-alive put the notification
    // straight back: pressing Stop All in the background would otherwise clear
    // every session and then start the service again for [_backgrounded], so
    // the one control the notification offers would appear not to work.
    _stoodDown = true;
    _sync();
  }

  /// Whether the user has asked, from the notification, to be left alone.
  ///
  /// Cleared on the next resume, not on the next connection: it is an answer
  /// about this trip to the background, and coming back to the app is what
  /// ends that.
  static var _stoodDown = false;

  /// Add a session record and push update to Android.
  static void add({
    required String id,
    required String title,
    /// What the title is not enough to tell apart — `user@ip:port` for a
    /// server. Empty where there is nothing to add, which is what a terminal
    /// on this device has.
    String subtitle = '',
    required int startTimeMs,
    required VoidCallback disconnect,
    TermSessionStatus status = TermSessionStatus.connecting,
    bool setAsActive = false,
  }) {
    final info = TermSessionInfo(
      id: id,
      title: title,
      subtitle: subtitle,
      startTimeMs: startTimeMs,
      status: status,
    );
    _entries[id] = _Entry(info, disconnect, hasTerminalUI: true);
    if (setAsActive) {
      _activeId = id;
    }
    _sync();
  }

  static void updateStatus(String id, TermSessionStatus status) {
    final old = _entries[id];
    if (old == null) return;
    if (old.info.status == status) return;
    _entries[id] = _Entry(
      TermSessionInfo(
        id: old.info.id,
        title: old.info.title,
        subtitle: old.info.subtitle,
        startTimeMs: old.info.startTimeMs,
        status: status,
      ),
      old.disconnect,
      hasTerminalUI: old.hasTerminalUI,
    );
    _sync();
  }

  static void remove(String id) {
    _entries.remove(id);
    if (_activeId == id) {
      _activeId = _entries.keys.firstOrNull;
    }
    _sync();
  }

  static void _sync() {
    _syncDirty = true;
    _syncing ??= _drainSync();
  }

  static Future<void> _drainSync() async {
    try {
      while (_syncDirty) {
        _syncDirty = false;
        await _syncLatest();
      }
    } finally {
      _syncing = null;
      if (_syncDirty) _syncing = _drainSync();
    }
  }

  /// Whether the app is out of the foreground, as `home.dart` reports it.
  ///
  /// Set on `inactive` rather than on `paused`, which is the whole reason this
  /// exists: `inactive` is delivered while the activity is still visible, and
  /// that is the last moment Android 12+ allows an app to *start* a foreground
  /// service. By `paused` the app is background and the call is refused.
  static var _backgrounded = false;

  static void setBackgrounded(bool value) {
    if (_backgrounded == value) return;
    _backgrounded = value;
    // Coming back to the app ends a stand-down: it was an answer about being
    // in the background, and the user is not there any more.
    if (!value) _stoodDown = false;
    _sync();
  }

  /// Whether the process must stay out of the freezer right now.
  ///
  /// Two reasons, either of which is enough. Something is connected, which is
  /// what the notification is *for*. Or the app is in the background with
  /// [SettingStore.bgRun] on, which is what that switch has always said it
  /// means — "the program will try to run in the background" — and never did:
  /// it only kept the poll timer scheduled, and a frozen process runs no
  /// timers.
  ///
  /// The zero-connection case is deliberate. Dropping the service the moment
  /// the last connection goes is what made a background disconnect permanent:
  /// the app cannot start a foreground service from the background, so nothing
  /// was left running to reconnect with. Keeping it means a notification while
  /// backgrounded even with nothing connected, which is the cost of being able
  /// to come back.
  static bool get _serviceWanted =>
      _entries.isNotEmpty ||
      (_backgrounded && !_stoodDown && Stores.setting.bgRun.fetch());

  static Future<void> _syncLatest() async {
    // Android: update foreground service notifications
    if (isAndroid) {
      final wanted = _serviceWanted;
      // No query is needed for an update, and no stop is allowed while the app
      // is backgrounded. Apart from saving a platform round trip, that keeps an
      // empty state from starting a foreground service just to stop it again.
      final running = !wanted && !_backgrounded
          ? await MethodChans.isServiceRunning()
          : false;
      switch (decideAndroidSessionServiceAction(
        wanted: wanted,
        running: running,
        backgrounded: _backgrounded,
      )) {
        case AndroidSessionServiceAction.update:
          await MethodChans.updateSessions(
            jsonEncode({
              'sessions': _entries.values.map((e) => e.info.toJson()).toList(),
              // Tells the service that an empty list is not the same as
              // "nothing to do" while background execution is wanted.
              'keepAlive': wanted,
            }),
          );
        case AndroidSessionServiceAction.stop:
          // Serialized through the service itself, so a pending foreground
          // start is promoted before the stop command is handled.
          await MethodChans.stopService();
        case AndroidSessionServiceAction.none:
          break;
      }
    }

    // iOS: manage Live Activity timer
    if (isIOS) {
      if (_entries.isEmpty) {
        _updateTimer?.cancel();
        _updateTimer = null;
        await MethodChans.stopLiveActivity();
      } else {
        // Start timer if not already running
        _updateTimer ??= Timer.periodic(
          _updateInterval,
          (_) => _sync(),
        );
        // Immediately update for immediate feedback
        await _updateLiveActivity();
      }
    }
  }

  static Future<void> _updateLiveActivity() async {
    if (!isIOS || _entries.isEmpty) return;

    final connectionCount = _entries.length;

    if (connectionCount == 1) {
      // Single connection: show hostname
      final id = _activeId ?? _entries.keys.first;
      final entry = _entries[id];
      if (entry == null) return;
      final payload = jsonEncode({
        ...entry.info.toJson(),
        'hasTerminal': entry.hasTerminalUI,
        'connectionCount': connectionCount,
      });
      await MethodChans.updateLiveActivity(payload);
    } else {
      // Several at once: the count in the title, and which ones under it.
      //
      // The subtitle used to be a fixed "Multiple SSH sessions active", which
      // said SSH about whatever was open — two shells inside the Linux
      // userland on this device included, where nothing is connected to
      // anything. Their names say what they are without having to classify
      // them, and the widget holds them to one line.
      //
      // The title here is ignored: `LiveActivityManager` localizes it, so that
      // it follows the language the widget renders in rather than the one the
      // app was in when this ran.
      final id = _activeId ?? _entries.keys.first;
      final entry = _entries[id];
      if (entry == null) return;
      final payload = jsonEncode({
        'id': 'multi_connections',
        'title': '$connectionCount',
        'subtitle': _entries.values.map((e) => e.info.title).join(' · '),
        'startTimeMs': entry.info.startTimeMs,
        'status': TermSessionStatus.connected.toString(),
        'hasTerminal': entry.hasTerminalUI,
        'connectionCount': connectionCount,
      });
      await MethodChans.updateLiveActivity(payload);
    }
  }

  /// Mark which session is actively displayed in UI (for iOS Live Activity).
  static void setActive(String id, {bool hasTerminal = true}) {
    _activeId = id;
    final old = _entries[id];
    if (old != null) {
      _entries[id] = _Entry(
        old.info,
        old.disconnect,
        hasTerminalUI: hasTerminal,
      );
      _sync();
    }
  }

  /// Mark a session's terminal UI as hidden without promoting it to active.
  static void hideTerminal(String id) {
    final old = _entries[id];
    if (old == null) return;

    _entries[id] = _Entry(old.info, old.disconnect, hasTerminalUI: false);
    if (_activeId == id) {
      _activeId = null;
    }
    _sync();
  }

  /// Stop Live Activity when app is closed/terminated (iOS only).
  static Future<void> stopLiveActivityOnAppClose() async {
    if (!isIOS) return;

    // Cancel any running timers
    _updateTimer?.cancel();
    _updateTimer = null;

    await _syncing;

    // Stop the Live Activity
    await MethodChans.stopLiveActivity();
  }
}

class _Entry {
  final TermSessionInfo info;
  final VoidCallback? disconnect;
  final bool hasTerminalUI;
  _Entry(this.info, this.disconnect, {this.hasTerminalUI = true});
}
