import 'dart:async';
import 'dart:convert';

import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/foundation.dart';
import 'package:server_box/core/chan.dart';
import 'package:server_box/data/model/server/server_private_info.dart';

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
  static const _updateInterval = Duration(seconds: 5); // 5-second update interval

  static void init() {
    if (isAndroid) {
      MethodChans.registerHandler((id) async {
        _entries[id]?.disconnect?.call();
      });
    }
  }

  /// Add a session record and push update to Android.
  static void add({
    required String id,
    required Spi spi,
    required int startTimeMs,
    required VoidCallback disconnect,
    TermSessionStatus status = TermSessionStatus.connecting,
  }) {
    final info = TermSessionInfo(
      id: id,
      title: spi.name,
      subtitle: spi.oldId,
      startTimeMs: startTimeMs,
      status: status,
    );
    _entries[id] = _Entry(info, disconnect, hasTerminalUI: true);
    _activeId = id; // most recent as active
    _sync();
  }

  static void updateStatus(String id, TermSessionStatus status) {
    final old = _entries[id];
    if (old == null) return;
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

  static Future<void> _sync() async {
    // Android: update foreground service notifications
    if (isAndroid) {
      final isRunning = await MethodChans.isServiceRunning();
      if (_entries.isEmpty) {
        if (isRunning) {
          MethodChans.stopService();
        }
        await MethodChans.updateSessions(jsonEncode({'sessions': []}));
      } else {
        if (!isRunning) {
          MethodChans.startService();
        }
        final payload = jsonEncode({'sessions': _entries.values.map((e) => e.info.toJson()).toList()});
        await MethodChans.updateSessions(payload);
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
        _updateTimer ??= Timer.periodic(_updateInterval, (_) => _updateLiveActivity());
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
      // Multiple connections: show connection count
      final id = _activeId ?? _entries.keys.first;
      final entry = _entries[id];
      if (entry == null) return;
      final payload = jsonEncode({
        'id': 'multi_connections',
        'title': '$connectionCount connections',
        'subtitle': 'Multiple SSH sessions active',
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
      _entries[id] = _Entry(old.info, old.disconnect, hasTerminalUI: hasTerminal);
      _sync();
    }
  }

  /// Stop Live Activity when app is closed/terminated (iOS only).
  static Future<void> stopLiveActivityOnAppClose() async {
    if (!isIOS) return;

    // Cancel any running timers
    _updateTimer?.cancel();
    _updateTimer = null;

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
