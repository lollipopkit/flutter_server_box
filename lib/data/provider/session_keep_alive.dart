import 'dart:async';

import 'package:clock/clock.dart';
import 'package:fl_lib/fl_lib.dart';
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
    this.paused,
  });

  final String id;

  /// What the session shows — a guest, a remote desktop profile.
  final String name;

  /// The server it goes through.
  final String host;

  /// When it closes. Null while the app itself is off screen, when [paused]
  /// says what was left.
  final DateTime? deadline;

  /// What was left of the countdown when the app went off screen.
  final Duration? paused;

  @override
  bool operator ==(Object other) =>
      other is SessionExpiry &&
      other.id == id &&
      other.name == name &&
      other.host == host &&
      other.deadline == deadline &&
      other.paused == paused;

  @override
  int get hashCode => Object.hash(id, name, host, deadline, paused);

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
/// - The app off screen holds the countdown, and carries on with what was left
///   when the app is back — never less than [graceOnReturn], so there is time
///   to read the notice and keep the session. Going away and back does not buy
///   a fresh countdown each time.
/// - A notice left off screen for another whole [timeout] is not waited on:
///   the session is closed then, and [SessionsClosedAway] says so once the app
///   is back. An app left in the background does not keep an idle session
///   open for good.
/// - The idle time itself keeps counting by the clock: a phone that froze the
///   app delays the timer, and the timer finding the time already passed shows
///   the notice at once. Leaving the app is not leaving a session — one on
///   screen when the app went stays on screen as far as this is concerned.
@Riverpod(keepAlive: true)
class SessionKeepAlive extends _$SessionKeepAlive {
  /// How long the notice stays before the session closes.
  static const grace = Duration(seconds: 10);

  /// The least a notice is given when the app comes back: long enough to find
  /// the button.
  static const graceOnReturn = Duration(seconds: 5);

  /// Closed off screen, waiting to be reported once the app is back.
  final _closedAway = <SessionExpiry>[];

  final _entries = <String, _KeptSession>{};
  var _appShown = true;

  /// How long a session off screen stays open; null for as long as it takes.
  static Duration? get timeout {
    final seconds = Stores.setting.remoteSessionIdleTimeout.fetch();
    return seconds <= 0 ? null : Duration(seconds: seconds);
  }

  @override
  Map<String, SessionExpiry> build() {
    // Locals, not fields: `build` runs again on the same notifier when the
    // provider is rebuilt, and each run sets up and tears down its own.
    final setting = Stores.setting.remoteSessionIdleTimeout.listenable()
      ..addListener(_onTimeoutChanged);
    final lifecycle = AppLifecycleListener(
      onShow: _onAppShown,
      onHide: _onAppHidden,
    );
    ref.onDispose(() {
      setting.removeListener(_onTimeoutChanged);
      lifecycle.dispose();
      for (final entry in _entries.values) {
        entry.cancelTimers();
      }
      _entries.clear();
    });
    return const {};
  }

  /// Starts tracking session [id]. Registering an id again replaces it.
  ///
  /// [owner] identifies who registered it, for an [unregister] that must
  /// not take a later owner's registration of the same id with it.
  void register(
    String id, {
    required String name,
    required String host,
    required FutureOr<void> Function() onClose,
    bool visible = true,
    Object? owner,
  }) {
    _entries.remove(id)?.cancelTimers();
    _drop(id);
    final entry = _KeptSession(
      name: name,
      host: host,
      onClose: onClose,
      owner: owner,
    );
    _entries[id] = entry;
    if (!visible) setVisible(id, false);
  }

  /// Stops tracking [id] — its owner closed it, or is showing it for good.
  /// With [owner], only a registration made with that owner.
  void unregister(String id, {Object? owner}) {
    final entry = _entries[id];
    if (entry == null) return;
    if (owner != null && !identical(entry.owner, owner)) return;
    _entries.remove(id);
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
        paused: _appShown ? null : grace,
      ),
    });
    if (_appShown) {
      _startClosing(id, entry, grace);
    } else {
      _startAway(id, entry);
    }
  }

  void _startClosing(String id, _KeptSession entry, Duration after) {
    entry.closing?.cancel();
    entry.closing = Timer(after, () => unawaited(_close(id, entry)));
  }

  /// A notice nobody can see: closed anyway after another whole [timeout],
  /// counted from [since] — when the wait began, kept across a change of
  /// [timeout] so the new one applies to the time already waited.
  void _startAway(String id, _KeptSession entry, {DateTime? since}) {
    entry.cancelAway();
    final timeout = SessionKeepAlive.timeout;
    if (timeout == null) return;
    final began = since ?? clock.now();
    entry.awaySince = began;
    final left = began.add(timeout).difference(clock.now());
    if (left <= Duration.zero) {
      _closeAway(id, entry);
      return;
    }
    entry.away = Timer(left, () => _closeAway(id, entry));
  }

  /// Whether [entry]'s away wait has run out by the clock — which a suspended
  /// app's timer may not have noticed yet.
  static bool _awayOverdue(_KeptSession entry) {
    final since = entry.awaySince;
    final timeout = SessionKeepAlive.timeout;
    if (since == null || timeout == null) return false;
    return !since.add(timeout).isAfter(clock.now());
  }

  void _closeAway(String id, _KeptSession entry) {
    final expiry = state[id];
    if (expiry != null && identical(_entries[id], entry)) {
      _closedAway.add(expiry);
    }
    unawaited(_close(id, entry));
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
      // A notice that stays while the app is away waits the new timeout,
      // from when that wait began.
      if (state.containsKey(id) && entry.awaySince != null) {
        _startAway(id, entry, since: entry.awaySince);
        continue;
      }
      _schedule(id, entry);
    }
  }

  void _onAppHidden() {
    _appShown = false;
    if (!ref.mounted || state.isEmpty) return;
    final now = clock.now();
    final next = <String, SessionExpiry>{};
    for (final MapEntry(key: id, value: expiry) in state.entries) {
      final entry = _entries[id];
      entry?.closing?.cancel();
      entry?.closing = null;
      if (entry != null) _startAway(id, entry);
      final deadline = expiry.deadline;
      final left = deadline == null
          ? expiry.paused ?? grace
          : deadline.difference(now);
      next[id] = SessionExpiry(
        id: id,
        name: expiry.name,
        host: expiry.host,
        paused: left.isNegative ? Duration.zero : left,
      );
    }
    state = Map.unmodifiable(next);
  }

  void _onAppShown() {
    _appShown = true;
    if (!ref.mounted) return;
    // The app may be shown before an overdue away timer fires — a suspended
    // app's timers do not run — and resuming such a notice would grant a
    // fresh grace after however long the app was away.
    for (final id in state.keys.toList()) {
      final entry = _entries[id];
      if (entry != null && _awayOverdue(entry)) _closeAway(id, entry);
    }
    if (_closedAway.isNotEmpty) {
      ref.read(sessionsClosedAwayProvider.notifier).add(_closedAway);
      _closedAway.clear();
    }
    if (state.isEmpty) return;
    final now = clock.now();
    final next = <String, SessionExpiry>{};
    for (final MapEntry(key: id, value: expiry) in state.entries) {
      final paused = expiry.paused ?? grace;
      final left = paused < graceOnReturn ? graceOnReturn : paused;
      final entry = _entries[id];
      if (entry != null) {
        entry.cancelAway();
        _startClosing(id, entry, left);
      }
      next[id] = SessionExpiry(
        id: id,
        name: expiry.name,
        host: expiry.host,
        deadline: now.add(left),
      );
    }
    state = Map.unmodifiable(next);
  }
}

final class _KeptSession {
  _KeptSession({
    required this.name,
    required this.host,
    required this.onClose,
    this.owner,
  });

  final Object? owner;
  final String name;
  final String host;
  final FutureOr<void> Function() onClose;

  /// When it left the screen; null while it is on it.
  DateTime? hiddenAt;

  /// Until the notice.
  Timer? idle;

  /// Until the close, while the notice is up.
  Timer? closing;

  /// Until the close, while the notice is up and the app off screen.
  Timer? away;

  /// When the [away] wait began; null while there is none.
  DateTime? awaySince;

  void cancelAway() {
    away?.cancel();
    away = null;
    awaySince = null;
  }

  void cancelTimers() {
    idle?.cancel();
    idle = null;
    closing?.cancel();
    closing = null;
    cancelAway();
  }
}

/// Sessions [SessionKeepAlive] closed while the app was off screen, reported
/// once it is back — they went without their notice ever being seen.
@Riverpod(keepAlive: true)
class SessionsClosedAway extends _$SessionsClosedAway {
  @override
  List<SessionExpiry> build() => const [];

  void add(Iterable<SessionExpiry> closed) =>
      state = List.unmodifiable([...state, ...closed]);

  /// Reported: nothing left to say.
  void clear() => state = const [];
}
