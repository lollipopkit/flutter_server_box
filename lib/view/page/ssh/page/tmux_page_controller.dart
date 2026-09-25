import 'dart:async';

import 'package:server_box/data/ssh/tmux/tmux_control_client.dart';
import 'package:server_box/data/ssh/tmux/tmux_control_models.dart';

/// Lifecycle phases for the tmux part of an SSH page.
enum TmuxPageLifecyclePhase {
  detached,
  attaching,
  attached,
  detaching,
  disposed,
}

/// Owns the tmux client and the page-facing tmux lifecycle state.
///
/// This is deliberately not a general SSH page controller. It only manages the
/// tmux client, snapshot subscription, and the small amount of state the page
/// needs for restoration and redraw. SSH connection, foreground shell binding,
/// and terminal rendering remain in the page.
final class TmuxPageController {
  TmuxPageController({
    required void Function(TmuxControlSnapshot snapshot) onSnapshot,
    required void Function(TmuxPageLifecyclePhase phase) onPhaseChanged,
  }) : _onSnapshot = onSnapshot,
       _onPhaseChanged = onPhaseChanged;

  final void Function(TmuxControlSnapshot snapshot) _onSnapshot;
  final void Function(TmuxPageLifecyclePhase phase) _onPhaseChanged;

  TmuxControlClient? _client;
  StreamSubscription<TmuxControlSnapshot>? _snapshotSubscription;
  TmuxPageLifecyclePhase _phase = TmuxPageLifecyclePhase.detached;

  String? _currentSessionName;
  int? _currentWindowIndex;
  String? _restorableSessionName;
  int? _restorableWindowIndex;

  TmuxPageLifecyclePhase get phase => _phase;
  TmuxControlClient? get client => _client;
  String? get currentSessionName => _currentSessionName;
  int? get currentWindowIndex => _currentWindowIndex;
  String? get restorableSessionName => _restorableSessionName;
  int? get restorableWindowIndex => _restorableWindowIndex;

  bool get isAttached => _phase == TmuxPageLifecyclePhase.attached;

  /// Claims ownership of a newly created control client.
  void attach(TmuxControlClient client) {
    detach();
    _phase = TmuxPageLifecyclePhase.attaching;
    _notifyPhaseChanged();
    _client = client;
    _snapshotSubscription = client.snapshots.listen(_handleSnapshot);
    _phase = TmuxPageLifecyclePhase.attached;
    _notifyPhaseChanged();
  }

  /// Drops the client without clearing the page-facing restore state.
  void detach() {
    if (_phase == TmuxPageLifecyclePhase.disposed) return;
    if (_client == null) return;
    _phase = TmuxPageLifecyclePhase.detaching;
    _notifyPhaseChanged();
    unawaited(_snapshotSubscription?.cancel());
    _snapshotSubscription = null;
    _client = null;
    _phase = TmuxPageLifecyclePhase.detached;
    _notifyPhaseChanged();
  }

  /// Clears both the live client and the page-facing restore state.
  void clear() {
    detach();
    if (_phase == TmuxPageLifecyclePhase.disposed) return;
    _currentSessionName = null;
    _currentWindowIndex = null;
    _restorableSessionName = null;
    _restorableWindowIndex = null;
    _phase = TmuxPageLifecyclePhase.detached;
    _notifyPhaseChanged();
  }

  /// Saves the latest snapshot state for page restoration.
  void saveState({required String sessionName, int? windowIndex}) {
    _currentSessionName = sessionName;
    _currentWindowIndex = windowIndex;
    _restorableSessionName = sessionName;
    _restorableWindowIndex = windowIndex;
  }

  Future<void> dispose() async {
    if (_phase == TmuxPageLifecyclePhase.disposed) return;
    // The page is unmounting. Do not notify phase changes here: the callback
    // may call setState, which Flutter rejects while the element is defunct.
    _phase = TmuxPageLifecyclePhase.disposed;
    await _snapshotSubscription?.cancel();
    _snapshotSubscription = null;
    await _client?.dispose();
    _client = null;
  }

  void _handleSnapshot(TmuxControlSnapshot snapshot) {
    if (_phase == TmuxPageLifecyclePhase.disposed) return;
    _currentSessionName = snapshot.session.name;
    _currentWindowIndex = snapshot.activeWindow?.index;
    _restorableSessionName = snapshot.session.name;
    _restorableWindowIndex = snapshot.activeWindow?.index;
    _onSnapshot(snapshot);
  }

  void _notifyPhaseChanged() {
    _onPhaseChanged(_phase);
  }
}
