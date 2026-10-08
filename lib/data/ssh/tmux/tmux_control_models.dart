import 'package:server_box/data/ssh/tmux/tmux_ids.dart';
import 'package:server_box/data/ssh/tmux/tmux_pane_mode_snapshot.dart';

/// A tmux session as shown by the native window bar and session switcher.
final class TmuxControlSessionSummary {
  final TmuxSessionId id;
  final String name;
  final int windows;
  final bool attached;

  const TmuxControlSessionSummary({
    required this.id,
    required this.name,
    required this.windows,
    required this.attached,
  });

  @override
  String toString() => '$id:$name';
}

/// A tmux window. The ID is stable; the index is display-only state.
final class TmuxControlWindow {
  final TmuxWindowId id;
  final int index;
  final String name;
  final bool active;
  final List<TmuxControlPane> panes;

  const TmuxControlWindow({
    required this.id,
    required this.index,
    required this.name,
    required this.active,
    this.panes = const <TmuxControlPane>[],
  });

  @override
  String toString() => '$id:$index:$name';
}

/// One pane in a tmux window.
///
/// The app deliberately renders only the active pane rather than a split layout.
/// This model keeps the other panes addressable so they remain visible and
/// switchable instead of silently disappearing behind that decision.
final class TmuxControlPane {
  final TmuxPaneId id;
  final int index;
  final String title;
  final String currentCommand;
  final bool active;
  final int cursorX;
  final int cursorY;
  final int height;

  const TmuxControlPane({
    required this.id,
    required this.index,
    required this.title,
    required this.currentCommand,
    required this.active,
    this.cursorX = 0,
    this.cursorY = 0,
    this.height = 24,
  });

  String get displayName {
    final trimmedTitle = title.trim();
    if (trimmedTitle.isNotEmpty) return trimmedTitle;
    final command = currentCommand.trim();
    return command.isEmpty ? id.value : command;
  }

  @override
  String toString() => '$id:$index:$displayName';
}

/// The state a terminal page needs while it is attached through `tmux -CC`.
final class TmuxControlSnapshot {
  final List<TmuxControlSessionSummary> sessions;
  final TmuxControlSessionSummary session;
  final List<TmuxControlWindow> windows;
  final TmuxWindowId activeWindowId;
  final TmuxPaneId activePaneId;
  final TmuxPaneModeSnapshot mode;

  /// Every pane of the session, by window: what a pane's status belongs to,
  /// and how a pane that has closed is told apart from one not shown.
  final Map<TmuxPaneId, TmuxWindowId> paneWindows;

  const TmuxControlSnapshot({
    required this.sessions,
    required this.session,
    required this.windows,
    required this.activeWindowId,
    required this.activePaneId,
    this.mode = const TmuxPaneModeSnapshot(),
    this.paneWindows = const {},
  });

  TmuxControlWindow? get activeWindow {
    for (final window in windows) {
      if (window.id == activeWindowId) return window;
    }
    return null;
  }
}

final class TmuxControlPaneOutput {
  final TmuxPaneId paneId;
  final List<int> data;

  const TmuxControlPaneOutput(this.paneId, this.data);
}

final class TmuxControlCommandException implements Exception {
  final String command;
  final String output;

  const TmuxControlCommandException(this.command, this.output);

  @override
  String toString() => 'tmux command failed: $command: $output';
}
