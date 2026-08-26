import 'package:flutter/painting.dart' show Alignment;
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:server_box/data/model/app/float_shell.dart';
import 'package:server_box/data/res/store.dart';
import 'package:server_box/data/ssh/terminal_session.dart';

part 'terminal_shell.g.dart';

/// A terminal that has been taken out of its tab and put in a window over the
/// app.
///
/// Out of, not copied from. Two `TerminalView`s on one [TerminalSession] both
/// resize it as they lay out, each undoing the other's size a frame later and
/// sending the far side a `SIGWINCH` for every one — so while this is set, the
/// tab that owns the session draws a placeholder instead of its terminal. The
/// session itself never moves: it is the thing both views are of, and it
/// belongs to neither.
class FloatingTerminal {
  const FloatingTerminal({
    required this.session,
    required this.title,
    required this.collapsed,
  });

  final TerminalSession session;

  /// What the window's title bar says — the tab's name, which is the server or
  /// the shell it is on.
  final String title;

  final bool collapsed;

  FloatingTerminal copyWith({bool? collapsed}) => FloatingTerminal(
    session: session,
    title: title,
    collapsed: collapsed ?? this.collapsed,
  );
}

/// Which terminal is floating, if any.
///
/// Unlike the Agent's, this cannot be restored on the next launch: an Agent
/// conversation is stored and a shell is a connection, so there is nothing for
/// a relaunch to put back in the window. What does persist is how the window
/// was left — its size, where it was dragged, and whether it was collapsed —
/// which is what [FloatShellGeometry] keeps.
@Riverpod(keepAlive: true)
class TerminalShell extends _$TerminalShell {
  @override
  FloatingTerminal? build() => null;

  /// Pops [session] out of its tab, the way it was last left: a user who
  /// collapsed the window meant to keep it out of the way.
  void float(TerminalSession session, {required String title}) {
    state = FloatingTerminal(
      session: session,
      title: title,
      collapsed:
          terminalShellGeometry.storedMode == FloatShellMode.collapsed,
    );
  }

  void expand() => _setCollapsed(false);

  void collapse() => _setCollapsed(true);

  /// Puts the terminal back in its tab.
  void hide() => state = null;

  /// The same, for a caller that knows only which session it is giving up —
  /// the terminal page on its way out, which must not close a window that is
  /// showing some other terminal by then.
  ///
  /// The one call that can arrive after everything is gone. The page schedules
  /// it for the end of the frame that unmounts it, and the frame that unmounts
  /// a page is sometimes the one taking the whole tree down with it — a tab
  /// switched off in the settings, a test's teardown. Reading [state] then
  /// throws `UnmountedRefException`, from a callback nobody is in a position
  /// to catch.
  void hideIf(TerminalSession session) {
    if (!ref.mounted) return;
    if (identical(state?.session, session)) state = null;
  }

  bool isFloating(TerminalSession session) =>
      identical(state?.session, session);

  void _setCollapsed(bool collapsed) {
    final current = state;
    if (current == null || current.collapsed == collapsed) return;
    state = current.copyWith(collapsed: collapsed);
    terminalShellGeometry.saveMode(
      collapsed ? FloatShellMode.collapsed : FloatShellMode.expanded,
    );
  }
}

/// How much of the floating terminal is on screen.
///
/// Derived rather than stored beside the session: "no terminal is floating"
/// and "the window is hidden" are the same fact, and holding both is how they
/// come to disagree.
extension FloatingTerminalMode on FloatingTerminal? {
  FloatShellMode get mode {
    final self = this;
    if (self == null) return FloatShellMode.hidden;
    return self.collapsed ? FloatShellMode.collapsed : FloatShellMode.expanded;
  }
}

/// Where the floating terminal was left. A getter for the reason
/// `agentShellGeometry` is one: the store is not registered at import time.
FloatShellGeometry get terminalShellGeometry => FloatShellGeometry(
  Stores.setting.terminalShell,
  // The Agent's corner is the bottom right. Both windows can be up at once, so
  // this one starts in the opposite corner of the same edge rather than on top
  // of it.
  defaultCorner: Alignment.topRight,
);
