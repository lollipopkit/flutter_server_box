part of 'tab.dart';

/// Synchronized input: what is typed in one terminal of the workspace on
/// screen goes to every other terminal in it.
///
/// Mirrors keystrokes rather than commands, as tmux's `synchronize-panes`
/// does — so an editor, a pager, a half-typed line all stay in step, and
/// nothing is run that was not typed.
final class _Mirror {
  _Mirror(this.host);

  final _WorkspaceTabState host;

  /// The sessions mirrored now: what each listener forwards to, read when
  /// typed, so a session joining or leaving does not re-hook the rest.
  var _sessions = const <TerminalSession>[];

  /// The listener this mirror added to each session, the only one it takes
  /// back.
  final _hooked = <TerminalSession, void Function(String)>{};

  /// The terminal tabs' session notifiers, listened to because a session
  /// arrives after its tab: once its page has connected.
  final _watched = <ValueNotifier<TerminalSession?>>{};

  Workspace? _ws;

  void update(Workspace ws) {
    _ws = ws;
    final now = <ValueNotifier<TerminalSession?>>{
      for (final t in ws.tabs)
        if (t.view == WorkspaceView.term)
          if (host._runtimes[t.id] case final rt?) rt.session,
    };
    for (final n in _watched.difference(now)) {
      n.removeListener(_apply);
    }
    for (final n in now.difference(_watched)) {
      n.addListener(_apply);
    }
    _watched
      ..clear()
      ..addAll(now);
    _apply();
  }

  void _apply() {
    final ws = _ws;
    _sessions = [
      if (ws != null && ws.sync)
        for (final n in _watched) ?n.value,
    ];
    for (final s in [..._hooked.keys]) {
      if (!_sessions.contains(s)) s.removeTypedListener(_hooked.remove(s)!);
    }
    for (final s in _sessions) {
      _hooked.putIfAbsent(s, () {
        void forward(String data) {
          for (final other in _sessions) {
            if (!identical(other, s)) other.sendTyped(data);
          }
        }

        s.addTypedListener(forward);
        return forward;
      });
    }
  }

  void dispose() {
    for (final n in _watched) {
      n.removeListener(_apply);
    }
    for (final e in _hooked.entries) {
      e.key.removeTypedListener(e.value);
    }
    _hooked.clear();
  }
}
