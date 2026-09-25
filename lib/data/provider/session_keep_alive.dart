import 'dart:async';

import 'package:clock/clock.dart';
import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:server_box/data/res/store.dart';

part 'session_keep_alive.g.dart';

/// A session whose idle time has run out, with the notice offering to keep it
/// on screen.
@immutable
final class SessionExpiry {
  const SessionExpiry({
    required this.id,
    required this.name,
    required this.host,
    this.deadline,
  });

  final String id;

  /// What the session shows — a guest, a remote desktop profile.
  final String name;

  /// The server it goes through.
  final String host;

  /// When it closes. Null while the app itself is off screen: the countdown
  /// starts when the notice can be seen, not before.
  final DateTime? deadline;

  @override
  bool operator ==(Object other) =>
      other is SessionExpiry &&
      other.id == id &&
      other.name == name &&
      other.host == host &&
      other.deadline == deadline;

  @override
  int get hashCode => Object.hash(id, name, host, deadline);

  @override
  String toString() => 'SessionExpiry($id, deadline: $deadline)';
}

/// Closes a remote session some time after it leaves the screen, rather than
/// the moment it does.
///
/// The one place this is decided, for every kind of session there is: the
/// remote desktop tab's, a guest's graphical console
/// (`RemoteDesktopSessions` registers both) and a guest's text console
/// (`VirtTextConsoles`). Each owner says what its session is called, how to
/// close it, and whether it is on screen; nothing here knows what a session
/// is.
///
/// - Off screen, a session waits [timeout] — `remoteSessionIdleTimeout`, read
///   when it is needed so a change applies to sessions already waiting. Never
///   (0) means it waits until it is closed.
/// - Then it is put in [state] for [grace]: the notice with the countdown and
///   "Keep alive". Keeping it starts a full [timeout] again; coming back to it
///   withdraws the notice; neither, and it is closed by its owner's own close.
/// - The app off screen holds the countdown, and restarts it in full when the
///   app is back, so nothing closes behind a notice nobody could have seen. The
///   idle time itself keeps counting by the clock: a phone that froze the app
///   delays the timer, and the timer finding the time already passed shows the
///   notice at once. Leaving the app is not leaving a session — one on screen
///   when the app went stays on screen as far as this is concerned.
@Riverpod(keepAlive: true)
class SessionKeepAlive extends _$SessionKeepAlive {
  /// How long the notice stays before the session closes.
  static const grace = Duration(seconds: 10);

  final _entries = <String, _KeptSession>{};
  late final ValueListenable<int> _setting;
  late final AppLifecycleListener _lifecycle;
  var _appShown = true;

  /// How long a session off screen stays open; null for as long as it takes.
  static Duration? get timeout {
    final seconds = Stores.setting.remoteSessionIdleTimeout.fetch();
    return seconds <= 0 ? null : Duration(seconds: seconds);
  }

  @override
  Map<String, SessionExpiry> build() {
    _setting = Stores.setting.remoteSessionIdleTimeout.listenable()
      ..addListener(_onTimeoutChanged);
    _lifecycle = AppLifecycleListener(
      onShow: _onAppShown,
      onHide: _onAppHidden,
    );
    ref.onDispose(() {
      _setting.removeListener(_onTimeoutChanged);
      _lifecycle.dispose();
      for (final entry in _entries.values) {
        entry.cancelTimers();
      }
      _entries.clear();
    });
    return const {};
  }

  /// Starts tracking session [id]. Registering an id again replaces it.
  void register(
    String id, {
    required String name,
    required String host,
    required FutureOr<void> Function() onClose,
    bool visible = true,
  }) {
    _entries.remove(id)?.cancelTimers();
    _drop(id);
    final entry = _KeptSession(name: name, host: host, onClose: onClose);
    _entries[id] = entry;
    if (!visible) setVisible(id, false);
  }

  /// Stops tracking [id] — its owner closed it, or is showing it for good.
  void unregister(String id) {
    final entry = _entries.remove(id);
    if (entry == null) return;
    entry.cancelTimers();
    _drop(id);
  }

  /// Whether session [id] is on screen. Coming back withdraws the notice.
  void setVisible(String id, bool visible) {
    final entry = _entries[id];
    if (entry == null) return;
    if (visible) {
      if (entry.hiddenAt == null) return;
      entry
        ..hiddenAt = null
        ..cancelTimers();
      _drop(id);
      return;
    }
    if (entry.hiddenAt != null) return;
    entry.hiddenAt = clock.now();
    _schedule(id, entry);
  }

  /// The notice's "Keep alive": a full [timeout] again from now.
  void keepAlive(String id) {
    final entry = _entries[id];
    if (entry == null || entry.hiddenAt == null) return;
    entry
      ..cancelTimers()
      ..hiddenAt = clock.now();
    _drop(id);
    _schedule(id, entry);
  }

  /// Whether [id] is tracked. For tests and for an owner checking its own
  /// bookkeeping.
  @visibleForTesting
  bool isRegistered(String id) => _entries.containsKey(id);

  void _schedule(String id, _KeptSession entry) {
    entry.idle?.cancel();
    entry.idle = null;
    // A notice already up has a countdown of its own.
    if (state.containsKey(id)) return;
    final hiddenAt = entry.hiddenAt;
    final timeout = SessionKeepAlive.timeout;
    if (hiddenAt == null || timeout == null) return;
    final left = hiddenAt.add(timeout).difference(clock.now());
    if (left <= Duration.zero) {
      _expire(id, entry);
      return;
    }
    entry.idle = Timer(left, () => _expire(id, entry));
  }

  void _expire(String id, _KeptSession entry) {
    entry.idle = null;
    if (!identical(_entries[id], entry) || !ref.mounted) return;
    state = Map.unmodifiable({
      ...state,
      id: SessionExpiry(
        id: id,
        name: entry.name,
        host: entry.host,
        deadline: _appShown ? clock.now().add(grace) : null,
      ),
    });
    if (_appShown) _startClosing(id, entry);
  }

  void _startClosing(String id, _KeptSession entry) {
    entry.closing?.cancel();
    entry.closing = Timer(grace, () => unawaited(_close(id, entry)));
  }

  Future<void> _close(String id, _KeptSession entry) async {
    if (!identical(_entries[id], entry)) return;
    _entries.remove(id);
    entry.cancelTimers();
    _drop(id);
    try {
      await entry.onClose();
    } catch (e, s) {
      Loggers.app.warning('Closing an idle session', e, s);
    }
  }

  /// Takes [id]'s notice down, if it is up.
  void _drop(String id) {
    if (!ref.mounted || !state.containsKey(id)) return;
    state = Map.unmodifiable({...state}..remove(id));
  }

  /// Applies a new timeout to every session already waiting, measured from
  /// when each left the screen. A notice the new timeout would not have shown
  /// yet is withdrawn; one it would have shown already stays.
  void _onTimeoutChanged() {
    final timeout = SessionKeepAlive.timeout;
    final now = clock.now();
    for (final MapEntry(key: id, value: entry) in _entries.entries.toList()) {
      final hiddenAt = entry.hiddenAt;
      if (hiddenAt == null) continue;
      if (state.containsKey(id) &&
          (timeout == null || hiddenAt.add(timeout).isAfter(now))) {
        entry.cancelTimers();
        _drop(id);
      }
      _schedule(id, entry);
    }
  }

  void _onAppHidden() {
    _appShown = false;
    if (!ref.mounted || state.isEmpty) return;
    for (final id in state.keys) {
      final entry = _entries[id];
      entry?.closing?.cancel();
      entry?.closing = null;
    }
    state = Map.unmodifiable({
      for (final MapEntry(key: id, value: expiry) in state.entries)
        id: SessionExpiry(id: id, name: expiry.name, host: expiry.host),
    });
  }

  void _onAppShown() {
    _appShown = true;
    if (!ref.mounted || state.isEmpty) return;
    final deadline = clock.now().add(grace);
    for (final id in state.keys) {
      final entry = _entries[id];
      if (entry != null) _startClosing(id, entry);
    }
    state = Map.unmodifiable({
      for (final MapEntry(key: id, value: expiry) in state.entries)
        id: SessionExpiry(
          id: id,
          name: expiry.name,
          host: expiry.host,
          deadline: deadline,
        ),
    });
  }
}

final class _KeptSession {
  _KeptSession({required this.name, required this.host, required this.onClose});

  final String name;
  final String host;
  final FutureOr<void> Function() onClose;

  /// When it left the screen; null while it is on it.
  DateTime? hiddenAt;

  /// Until the notice.
  Timer? idle;

  /// Until the close, while the notice is up.
  Timer? closing;

  void cancelTimers() {
    idle?.cancel();
    idle = null;
    closing?.cancel();
    closing = null;
  }
}
