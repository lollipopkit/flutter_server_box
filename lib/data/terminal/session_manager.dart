import 'dart:async';
import 'dart:collection';
import 'dart:convert';

import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/foundation.dart';
import 'package:server_box/core/chan.dart';
import 'package:server_box/core/utils/coalesced.dart';
import 'package:server_box/data/store/stores.dart';
import 'package:server_box/data/terminal/android_service_policy.dart';
import 'package:server_box/data/terminal/ios_live_activity_policy.dart';
import 'package:xterm/core.dart' show ProgramState;

enum TermSessionStatus {
  connecting,
  connected,
  disconnected;

  @override
  String toString() {
    return name.capitalize;
  }
}

/// A running SSH terminal session shown in Android notifications and iOS Live
/// Activities.
class TermSessionInfo {
  final String id;
  final String title; // Usually the server name.
  final String subtitle; // Usually `user@host:port`.
  final int startTimeMs;
  final TermSessionStatus status;

  /// The most urgent thing the session's programs report (OSC 7501 and
  /// friends), and that in words. Null while they report nothing.
  final ProgramState? programState;
  final String? program;

  TermSessionInfo({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.startTimeMs,
    required this.status,
    this.programState,
    this.program,
  });

  TermSessionInfo copyWith({
    TermSessionStatus? status,
    (ProgramState?, String?)? program,
  }) => TermSessionInfo(
    id: id,
    title: title,
    subtitle: subtitle,
    startTimeMs: startTimeMs,
    status: status ?? this.status,
    programState: program == null ? programState : program.$1,
    program: program == null ? this.program : program.$2,
  );

  Map<String, Object> toJson() => {
    'id': id,
    'title': title,
    'subtitle': subtitle,
    'startTimeMs': startTimeMs,
    'status': status.toString(),
    'program': ?program,
  };
}

/// The sessions [TermSessionManager] shows, and which one is on screen: the
/// state alone, with nothing of the platforms it is pushed to.
///
/// Each change answers whether anything changed, which is what decides that
/// the notification and the Live Activity are told.
final class TermSessionRegistry {
  final _entries = <String, TermSessionEntry>{};
  String? _activeId;

  /// Every session, by id, in the order they were added.
  Map<String, TermSessionEntry> get entries => UnmodifiableMapView(_entries);

  /// The session on screen, for the iOS Live Activity.
  String? get activeId => _activeId;

  void add(TermSessionInfo info, VoidCallback disconnect, {bool setAsActive = false}) {
    _entries[info.id] = TermSessionEntry(info, disconnect, hasTerminalUI: true);
    if (setAsActive) _activeId = info.id;
  }

  bool updateStatus(String id, TermSessionStatus status) {
    final old = _entries[id];
    if (old == null || old.info.status == status) return false;
    _entries[id] = TermSessionEntry(
      old.info.copyWith(status: status),
      old.disconnect,
      hasTerminalUI: old.hasTerminalUI,
    );
    return true;
  }

  bool updateProgram(String id, ProgramState? state, String? text) {
    final old = _entries[id];
    if (old == null) return false;
    if (old.info.programState == state && old.info.program == text) return false;
    _entries[id] = TermSessionEntry(
      old.info.copyWith(program: (state, text)),
      old.disconnect,
      hasTerminalUI: old.hasTerminalUI,
    );
    return true;
  }

  /// The entry whose programs report the most urgent state, if any do.
  TermSessionEntry? get mostUrgentProgram {
    TermSessionEntry? best;
    for (final entry in _entries.values) {
      final state = entry.info.programState;
      if (state == null || entry.info.program == null) continue;
      final bestState = best?.info.programState;
      if (bestState == null || state.index < bestState.index) best = entry;
    }
    return best;
  }

  void remove(String id) {
    _entries.remove(id);
    if (_activeId == id) _activeId = _entries.keys.firstOrNull;
  }

  /// Marks [id] as the session on screen; answers whether it is a session.
  bool setActive(String id, {bool hasTerminal = true}) {
    _activeId = id;
    final old = _entries[id];
    if (old == null) return false;
    _entries[id] = TermSessionEntry(old.info, old.disconnect, hasTerminalUI: hasTerminal);
    return true;
  }

  /// Marks [id]'s terminal as hidden without making another one active.
  bool hideTerminal(String id) {
    final old = _entries[id];
    if (old == null) return false;
    _entries[id] = TermSessionEntry(old.info, old.disconnect, hasTerminalUI: false);
    if (_activeId == id) _activeId = null;
    return true;
  }

  /// Forgets every session.
  void clear() {
    _entries.clear();
    _activeId = null;
  }
}

/// Singleton to track active SSH sessions and sync to Android notifications.
abstract final class TermSessionManager {
  static var _registry = TermSessionRegistry();

  @visibleForTesting
  static TermSessionRegistry get registry => _registry;

  static Map<String, TermSessionEntry> get _entries => _registry.entries;
  static String? get _activeId => _registry.activeId;
  static Timer? _updateTimer; // Timer for iOS Live Activity updates
  static var _syncs = Coalesced(() => _push());

  /// What a drain pushes each time: the platforms, outside tests.
  static Future<void> Function() _push = _syncLatest;

  @visibleForTesting
  static set push(Future<void> Function() push) => _push = push;

  /// Back to how the process starts: no sessions, no flags, nothing pending.
  @visibleForTesting
  static void reset() {
    _registry = TermSessionRegistry();
    _updateTimer?.cancel();
    _updateTimer = null;
    _syncs.cancelPending();
    _syncs = Coalesced(() => _push());
    _push = _syncLatest;
    _stoodDown = false;
    _backgrounded = false;
    _transferring = false;
    _hasServers = false;
  }
  static const _updateInterval = Duration(
    seconds: 5,
  ); // 5-second update interval

  static Future<void> init() async {
    if (isAndroid) {
      MethodChans.registerHandler(
        (id) async {
          _entries[id]?.disconnect();
        },
        // Stop all connections when notification "Stop All" is pressed
        onStopAll: stopAllConnections,
        // The first attempt to start the service raised the permission prompt
        // and was refused by the same call, because asking is asynchronous.
        // This is the answer arriving, and syncing is what asks again.
        onNotificationPermissionGranted: _sync,
        onBackgrounded: setBackgrounded,
      );
      _pushKeepAlive();
      Stores.setting.bgRun.listenable().addListener(_pushKeepAlive);
    }
    if (isIOS) {
      // A Live Activity can outlive a killed process. Clear any orphan left
      // by the previous app run before new sessions can be registered.
      await MethodChans.stopLiveActivity();
      // Turning the switch off has to take the activity off the lock screen
      // now, not at the next five-second tick — it is a switch about what is
      // readable without unlocking the phone.
      //
      // Listened to here rather than acted on in the settings page, because
      // `StoreSwitch` runs its `callback` *before* writing the new value:
      // anything reading the setting from there reads the old one. A store
      // listener fires on the write.
      Stores.setting.liveActivity.listenable().addListener(syncLiveActivity);
    }
  }

  /// Called when Android notification "Stop All" button is pressed
  static void stopAllConnections() {
    // Disconnect all sessions, then forget them
    for (final disconnect in [for (final e in _entries.values) e.disconnect]) {
      disconnect();
    }
    _registry.clear();
    // And stand down, rather than letting the keep-alive put the notification
    // straight back: pressing Stop All in the background would otherwise clear
    // every session and then start the service again for [_backgrounded], so
    // the one control the notification offers would appear not to work.
    // In the foreground (the tile over the app) there is no keep-alive to give
    // up, and the flag would outlive this visit.
    _stoodDown = _backgrounded;
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
    _registry.add(info, disconnect, setAsActive: setAsActive);
    _sync();
  }

  static void updateStatus(String id, TermSessionStatus status) {
    if (_registry.updateStatus(id, status)) _sync();
  }

  /// What session [id]'s programs report, for the notification and the Live
  /// Activity: a program waiting is worth reading off the lock screen.
  static void updateProgram(String id, ProgramState? state, String? text) {
    if (_registry.updateProgram(id, state, text)) _sync();
  }

  static void remove(String id) {
    _registry.remove(id);
    _sync();
  }

  static void _sync() {
    unawaited(_syncs());
  }

  /// Re-decides whether a Live Activity should be up, after the setting that
  /// says so has changed.
  ///
  /// The sessions themselves are untouched, so nothing else here notices the
  /// switch moving — and the wrong half of that is the one that matters:
  /// turning it off with a terminal open would otherwise leave the activity on
  /// the lock screen until the session ended.
  static void syncLiveActivity() {
    if (!isIOS) return;
    _sync();
  }

  /// Whether the activity is paused, from its native `onPause`/`onResume`.
  ///
  /// `onPause` is the last moment Android 12+ lets an app *start* a foreground
  /// service; Flutter's `paused` comes later, from `onStop`. Flutter's
  /// `inactive` and `resumed` are not used: they also follow window focus, so
  /// a pulled-down notification shade would read as leaving.
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
  /// [SettingStore.bgRun] on and a server to keep, which is what that switch
  /// has always said it means — "the program will try to run in the
  /// background" — and never did:
  /// it only kept the poll timer scheduled, and a frozen process runs no
  /// timers.
  ///
  /// The zero-connection case is deliberate. Dropping the service the moment
  /// the last connection goes is what made a background disconnect permanent:
  /// the app cannot start a foreground service from the background, so nothing
  /// was left running to reconnect with. Keeping it means a notification while
  /// backgrounded even with nothing connected, which is the cost of being able
  /// to come back.
  ///
  /// A file transfer in progress is a third: it runs on this process, and a
  /// frozen one leaves it, and its notification, standing still. Stop All
  /// does not end it, and the native side keeps the service up for it.
  static bool get _serviceWanted =>
      _entries.isNotEmpty ||
      _transferring ||
      (_backgrounded && !_stoodDown && _keepAliveWanted);

  static var _transferring = false;

  /// Whether any file transfer is running, as `AndroidSystemSync` sees them.
  static void setTransferring(bool value) {
    if (_transferring == value) return;
    _transferring = value;
    _sync();
  }

  static var _hasServers = false;

  /// Whether any server is configured, as `AndroidSystemSync` sees them.
  static void setHasServers(bool value) {
    if (_hasServers == value) return;
    _hasServers = value;
    _pushKeepAlive();
    _sync();
  }

  /// Keeping the process alive in the background is for the servers: their
  /// status and their reconnects. With none there is nothing to keep.
  static bool get _keepAliveWanted =>
      _hasServers && Stores.setting.bgRun.fetch();

  /// The native side starts the keep-alive on `onPause` from this: the
  /// `activityPaused` round trip can land after the app is background.
  static void _pushKeepAlive() {
    if (!isAndroid) return;
    unawaited(MethodChans.setKeepAliveInBackground(_keepAliveWanted));
  }

  static Future<void> _syncLatest() async {
    // Android: update foreground service notifications
    if (isAndroid) {
      final wanted = _serviceWanted;
      // No query is needed for an update, and no stop is allowed while the app
      // is backgrounded, unless stood down. Apart from saving a platform round
      // trip, that keeps an empty state from starting a foreground service just
      // to stop it again.
      final mayStop = !_backgrounded || _stoodDown;
      final running = !wanted && mayStop
          ? await MethodChans.isServiceRunning()
          : false;
      switch (decideAndroidSessionServiceAction(
        wanted: wanted,
        running: running,
        backgrounded: _backgrounded,
        stoodDown: _stoodDown,
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
      switch (decideIosLiveActivityAction(
        hasSessions: _entries.isNotEmpty,
        enabled: Stores.setting.liveActivity.fetch(),
      )) {
        case IosLiveActivityAction.stop:
          _updateTimer?.cancel();
          _updateTimer = null;
          await MethodChans.stopLiveActivity();
        case IosLiveActivityAction.update:
          // Start timer if not already running
          _updateTimer ??= Timer.periodic(_updateInterval, (_) => _sync());
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
      final program = entry.info.program;
      final payload = jsonEncode({
        ...entry.info.toJson(),
        // In place of the address: what the session is doing is the more
        // useful line on a lock screen, and the widget has one.
        'subtitle': ?program,
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
        'subtitle': switch (_registry.mostUrgentProgram) {
          final urgent? => '${urgent.info.title}: ${urgent.info.program}',
          null => _entries.values.map((e) => e.info.title).join(' · '),
        },
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
    if (_registry.setActive(id, hasTerminal: hasTerminal)) _sync();
  }

  /// Mark a session's terminal UI as hidden without promoting it to active.
  static void hideTerminal(String id) {
    if (_registry.hideTerminal(id)) _sync();
  }
}

/// One session as [TermSessionRegistry] holds it.
class TermSessionEntry {
  final TermSessionInfo info;
  final VoidCallback disconnect;
  final bool hasTerminalUI;
  TermSessionEntry(this.info, this.disconnect, {this.hasTerminalUI = true});
}
