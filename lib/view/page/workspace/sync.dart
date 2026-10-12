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

  /// The sessions given a mirror, to take it back from.
  var _hooked = <TerminalSession>[];

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
    final sessions = <TerminalSession>[
      if (ws != null && ws.sync)
        for (final n in _watched) ?n.value,
    ];
    for (final s in _hooked) {
      if (!sessions.contains(s)) s.onTyped = null;
    }
    for (final s in sessions) {
      s.onTyped = (data) {
        for (final other in sessions) {
          if (!identical(other, s)) other.sendTyped(data);
        }
      };
    }
    _hooked = sessions;
  }

  void dispose() {
    for (final n in _watched) {
      n.removeListener(_apply);
    }
    for (final s in _hooked) {
      s.onTyped = null;
    }
  }
}
