import 'package:server_box/src/rust/api/tmux.dart' as ffi;

/// The tmux commands the terminal sends before its control-mode client takes
/// over, from `sbm_parser::tmux`. This only carries them.
abstract final class TmuxCommandBuilder {
  /// Attach to an existing session. Prefer a stable `$id` target: `:` in a
  /// name would be read as a session/window divider.
  static String attachSession(String sessionTarget, {String tmuxBin = 'tmux'}) =>
      ffi.tmuxAttachSessionCommand(bin: tmuxBin, session: sessionTarget);

  /// Attach to one window of a session.
  static String attachSessionWindow(
    String sessionTarget,
    int windowIndex, {
    String tmuxBin = 'tmux',
  }) => ffi.tmuxAttachWindowCommand(
    bin: tmuxBin,
    session: sessionTarget,
    window: windowIndex,
  );

  /// Attach to [sessionName], creating it when it does not exist.
  static String newSessionOrAttach(
    String sessionName, {
    String tmuxBin = 'tmux',
  }) => ffi.tmuxNewSessionOrAttachCommand(bin: tmuxBin, name: sessionName);

  static String listSessionsCmd({String tmuxBin = 'tmux'}) =>
      ffi.tmuxListSessionsCommand(bin: tmuxBin);

  /// Discovery uses this only to validate a restored window before attach.
  /// Once attached, `TmuxControlClient` owns window and pane state.
  static String listWindows(String sessionTarget, {String tmuxBin = 'tmux'}) =>
      ffi.tmuxListWindowsCommand(bin: tmuxBin, session: sessionTarget);

  /// Locates tmux, including installations added to `PATH` by `.bashrc`.
  static String get findTmux => ffi.tmuxFindCommand();
}
