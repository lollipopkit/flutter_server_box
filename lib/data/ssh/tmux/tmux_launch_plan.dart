import 'package:server_box/data/ssh/tmux/tmux_command_builder.dart';
import 'package:server_box/data/ssh/tmux/tmux_restore_state.dart';
import 'package:server_box/data/ssh/tmux/tmux_session.dart';
import 'package:server_box/data/ssh/tmux/tmux_session_info.dart';

final class TmuxLaunchPlan {
  final String? command;
  final String? sessionName;
  final int? windowIndex;

  const TmuxLaunchPlan._({
    required this.command,
    required this.sessionName,
    required this.windowIndex,
  });

  const TmuxLaunchPlan.none()
    : this._(command: null, sessionName: null, windowIndex: null);

  const TmuxLaunchPlan.tmux({
    required String command,
    required String sessionName,
    int? windowIndex,
  }) : this._(
         command: command,
         sessionName: sessionName,
         windowIndex: windowIndex,
       );

  bool get shouldLaunchTmux => command != null && sessionName != null;
}

TmuxLaunchPlan buildRestoredTmuxLaunchPlan(
  TmuxRestoreState restoreState,
  List<TmuxSessionInfo> sessions, {
  String tmuxBin = 'tmux',
  String? lang,
}) {
  if (!restoreState.hasSession) return const TmuxLaunchPlan.none();

  final sessionName = restoreState.sessionName!;
  final exists = sessions.any((session) => session.name == sessionName);
  if (!exists) return const TmuxLaunchPlan.none();

  final command = restoreState.windowIndex != null
      ? TmuxCommandBuilder.attachSessionWindow(
          sessionName,
          restoreState.windowIndex!,
          tmuxBin: tmuxBin,
          lang: lang,
        )
      : TmuxCommandBuilder.attachSession(
          sessionName,
          tmuxBin: tmuxBin,
          lang: lang,
        );

  return TmuxLaunchPlan.tmux(
    command: command,
    sessionName: sessionName,
    windowIndex: restoreState.windowIndex,
  );
}

TmuxLaunchPlan buildChosenTmuxLaunchPlan(
  TmuxAttachChoice choice, {
  String tmuxBin = 'tmux',
  String? lang,
}) {
  return switch (choice) {
    TmuxAttachExisting(
      sessionName: final sessionName,
      windowIndex: final windowIndex,
    ) =>
      TmuxLaunchPlan.tmux(
        command: windowIndex != null
            ? TmuxCommandBuilder.attachSessionWindow(
                sessionName,
                windowIndex,
                tmuxBin: tmuxBin,
                lang: lang,
              )
            : TmuxCommandBuilder.attachSession(
                sessionName,
                tmuxBin: tmuxBin,
                lang: lang,
              ),
        sessionName: sessionName,
        windowIndex: windowIndex,
      ),
    TmuxAttachNew(sessionName: final sessionName) => TmuxLaunchPlan.tmux(
      command: TmuxCommandBuilder.newSessionOrAttach(
        sessionName,
        tmuxBin: tmuxBin,
        lang: lang,
      ),
      sessionName: sessionName,
    ),
    _ => const TmuxLaunchPlan.none(),
  };
}
