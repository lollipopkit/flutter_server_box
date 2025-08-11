import 'dart:convert';

import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/foundation.dart';
import 'package:server_box/core/chan.dart';
import 'package:server_box/data/model/server/server_private_info.dart';

/// Represents a running SSH terminal session for Android notifications and iOS Live Activities.
class TermSessionInfo {
  final String id;
  final String title; // e.g. server name
  final String subtitle; // e.g. user@ip:port
  final int startTimeMs;
  final String status; // connecting | connected | disconnected

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
        'status': status,
      };
}

/// Singleton to track active SSH sessions and sync to Android notifications.
abstract final class TermSessionManager {
  static final Map<String, _Entry> _entries = {};
  static String? _activeId; // For iOS Live Activity

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
    String status = 'connecting',
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

  static void updateStatus(String id, String status) {
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
      if (_entries.isEmpty) {
        MethodChans.stopService();
        await MethodChans.updateSessions(jsonEncode({'sessions': []}));
      } else {
        MethodChans.startService();
        final payload = jsonEncode({
          'sessions': _entries.values.map((e) => e.info.toJson()).toList(),
        });
        await MethodChans.updateSessions(payload);
      }
    }

    // iOS: update Live Activity for active session
    if (isIOS) {
      if (_entries.isEmpty) {
        await MethodChans.stopLiveActivity();
      } else {
        final id = _activeId ?? _entries.keys.first;
        final entry = _entries[id]!;
        final payload = jsonEncode({
          ...entry.info.toJson(),
          'hasTerminal': entry.hasTerminalUI,
        });
        // Start or update depending on existence is handled natively
        await MethodChans.updateLiveActivity(payload);
      }
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
}

class _Entry {
  final TermSessionInfo info;
  final VoidCallback? disconnect;
  final bool hasTerminalUI;
  _Entry(this.info, this.disconnect, {this.hasTerminalUI = true});
}
