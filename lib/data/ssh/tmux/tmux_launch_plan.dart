import 'package:server_box/data/ssh/tmux/tmux_command_builder.dart';
import 'package:server_box/data/ssh/tmux/tmux_ids.dart';
import 'package:server_box/data/ssh/tmux/tmux_restore_state.dart';
import 'package:server_box/data/ssh/tmux/tmux_session.dart';
import 'package:server_box/data/ssh/tmux/tmux_session_info.dart';
import 'package:server_box/data/ssh/tmux/tmux_window_info.dart';

final class TmuxLaunchPlan {
  final String? command;
  final String? sessionName;
  final TmuxSessionId? sessionId;
  final int? windowIndex;

  const TmuxLaunchPlan._({
    required this.command,
    required this.sessionName,
    this.sessionId,
    required this.windowIndex,
  });

  const TmuxLaunchPlan.none()
    : this._(command: null, sessionName: null, windowIndex: null);

  const TmuxLaunchPlan.tmux({
    required String command,
    required String sessionName,
    TmuxSessionId? sessionId,
    int? windowIndex,
  }) : this._(
         command: command,
         sessionName: sessionName,
         sessionId: sessionId,
         windowIndex: windowIndex,
       );

  bool get shouldLaunchTmux => command != null && sessionName != null;
}

int? validateRestoredWindowIndex(
  int? restoredWindowIndex,
  List<TmuxWindowInfo> windows,
) {
  if (restoredWindowIndex == null) return null;
  return windows.any((window) => window.index == restoredWindowIndex)
      ? restoredWindowIndex
      : null;
}

TmuxLaunchPlan buildRestoredTmuxLaunchPlan(
  TmuxRestoreState restoreState,
  List<TmuxSessionInfo> sessions, {
  required List<TmuxWindowInfo> windows,
  String tmuxBin = 'tmux',
}) {
  if (!restoreState.hasSession) return const TmuxLaunchPlan.none();

  TmuxSessionInfo? session;
  for (final candidate in sessions) {
    if (candidate.name == restoreState.sessionName) {
      session = candidate;
      break;
    }
  }
  if (session == null) return const TmuxLaunchPlan.none();

  final windowIndex = validateRestoredWindowIndex(
    restoreState.windowIndex,
    windows,
  );
  final target = session.id.value;
  final command = windowIndex != null
      ? TmuxCommandBuilder.attachSessionWindow(
          target,
          windowIndex,
          tmuxBin: tmuxBin,
        )
      : TmuxCommandBuilder.attachSession(target, tmuxBin: tmuxBin);

  return TmuxLaunchPlan.tmux(
    command: command,
    sessionName: session.name,
    sessionId: session.id,
    windowIndex: windowIndex,
  );
}

/// Chooses the session automatic attach should use.
///
/// The default name is preferred because it is the one the user configured.
/// Otherwise an already-attached session is preferred, since it is the one
/// most likely to represent ongoing work; the first discovered session is the
/// final fallback so auto attach never silently creates a duplicate session
/// when an existing one is available.
TmuxSessionInfo? selectAutoTmuxSession(
  List<TmuxSessionInfo> sessions, {
  required String defaultSessionName,
}) {
  if (sessions.isEmpty) return null;

  for (final session in sessions) {
    if (session.name == defaultSessionName) return session;
  }
  for (final session in sessions) {
    if (session.attached) return session;
  }
  return sessions.first;
}

/// Builds the automatic attach plan used when the session selector is off.
///
/// An existing session is preferred over creating a duplicate; see
/// [selectAutoTmuxSession] for the selection order.
TmuxLaunchPlan buildAutoTmuxLaunchPlan(
  List<TmuxSessionInfo> sessions, {
  required String defaultSessionName,
  String tmuxBin = 'tmux',
}) {
  final session = selectAutoTmuxSession(
    sessions,
    defaultSessionName: defaultSessionName,
  );
  if (session == null) {
    return buildChosenTmuxLaunchPlan(
      TmuxAttachNew(sessionName: defaultSessionName),
      tmuxBin: tmuxBin,
    );
  }

  return buildChosenTmuxLaunchPlan(
    TmuxAttachExisting(sessionName: session.name, sessionId: session.id),
    tmuxBin: tmuxBin,
  );
}

TmuxLaunchPlan buildChosenTmuxLaunchPlan(
  TmuxAttachChoice choice, {
  String tmuxBin = 'tmux',
}) {
  return switch (choice) {
    TmuxAttachExisting(
      :final sessionName,
      :final sessionId,
      :final windowIndex,
    ) =>
      TmuxLaunchPlan.tmux(
        command: windowIndex != null
            ? TmuxCommandBuilder.attachSessionWindow(
                sessionId?.value ?? sessionName,
                windowIndex,
                tmuxBin: tmuxBin,
              )
            : TmuxCommandBuilder.attachSession(
                sessionId?.value ?? sessionName,
                tmuxBin: tmuxBin,
              ),
        sessionName: sessionName,
        sessionId: sessionId,
        windowIndex: windowIndex,
      ),
    TmuxAttachNew(sessionName: final sessionName) => TmuxLaunchPlan.tmux(
      command: TmuxCommandBuilder.newSessionOrAttach(
        sessionName,
        tmuxBin: tmuxBin,
      ),
      sessionName: sessionName,
    ),
    _ => const TmuxLaunchPlan.none(),
  };
}
