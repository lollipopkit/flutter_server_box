/// Pure utility for building tmux commands.
///
/// Extracted from TmuxSession for testability without flutter dependencies.
abstract final class TmuxCommandBuilder {
  /// Escape a shell argument for use in tmux commands.
  static String escapeArg(String arg) {
    return "'${arg.replaceAll("'", "'\\''")}'";
  }

  static String tmuxPrefix({String tmuxBin = 'tmux', String? lang}) {
    if (lang == null || lang.trim().isEmpty) {
      return tmuxBin;
    }
    final escapedLang = escapeArg(lang);
    return 'env LANG=$escapedLang LC_CTYPE=$escapedLang LC_ALL=$escapedLang $tmuxBin';
  }

  /// Build the attach command for an existing session.
  static String attachSession(
    String sessionName, {
    String tmuxBin = 'tmux',
    String? lang,
  }) {
    return '${tmuxPrefix(tmuxBin: tmuxBin, lang: lang)} attach-session -t ${escapeArg(sessionName)}';
  }

  /// Build the attach command targeting a specific window.
  static String attachSessionWindow(
    String sessionName,
    int windowIndex, {
    String tmuxBin = 'tmux',
    String? lang,
  }) {
    return '${tmuxPrefix(tmuxBin: tmuxBin, lang: lang)} attach-session -t ${escapeArg('$sessionName:$windowIndex')}';
  }

  /// Build the new-session command.
  static String newSession(
    String sessionName, {
    String tmuxBin = 'tmux',
    String? lang,
  }) {
    return '${tmuxPrefix(tmuxBin: tmuxBin, lang: lang)} new-session -s ${escapeArg(sessionName)}';
  }

  /// Build the new-session -A command (attach or create).
  static String newSessionOrAttach(
    String sessionName, {
    String tmuxBin = 'tmux',
    String? lang,
  }) {
    return '${tmuxPrefix(tmuxBin: tmuxBin, lang: lang)} new-session -A -s ${escapeArg(sessionName)}';
  }

  /// Build the kill-session command.
  static String killSession(
    String sessionName, {
    String tmuxBin = 'tmux',
    String? lang,
  }) {
    return '${tmuxPrefix(tmuxBin: tmuxBin, lang: lang)} kill-session -t ${escapeArg(sessionName)}';
  }

  /// Build the list-sessions command with format string.
  static String listSessionsCmd({String tmuxBin = 'tmux', String? lang}) =>
      '${tmuxPrefix(tmuxBin: tmuxBin, lang: lang)} list-sessions -F '
      '"#{session_name}|#{session_windows}|#{session_attached}'
      '|#{session_created_string}|#{session_last_attached_string}'
      '|#{session_activity_string}"';

  /// Build the list-windows command for a session.
  static String listWindows(
    String sessionName, {
    String tmuxBin = 'tmux',
    String? lang,
  }) =>
      '${tmuxPrefix(tmuxBin: tmuxBin, lang: lang)} list-windows -t ${escapeArg(sessionName)} -F '
      '"#{window_index}|#{window_name}|#{window_active}|#{window_panes}|#{window_activity_string}"';

  /// Build the list-clients command with identity and disambiguation fields.
  static String listClients({String tmuxBin = 'tmux', String? lang}) =>
      '${tmuxPrefix(tmuxBin: tmuxBin, lang: lang)} list-clients -F '
      '"#{client_tty}|#{client_session}|#{window_index}|#{client_activity}"';

  /// Build the switch-client command for a specific client tty.
  static String switchClient(
    String clientTty,
    String target, {
    String tmuxBin = 'tmux',
    String? lang,
  }) =>
      '${tmuxPrefix(tmuxBin: tmuxBin, lang: lang)} switch-client -c ${escapeArg(clientTty)} -t ${escapeArg(target)}';

  /// Build the kill-window command.
  static String killWindow(
    String sessionName,
    int windowIndex, {
    String tmuxBin = 'tmux',
    String? lang,
  }) =>
      '${tmuxPrefix(tmuxBin: tmuxBin, lang: lang)} kill-window -t ${escapeArg('$sessionName:$windowIndex')}';

  /// Build the select-window command.
  static String selectWindow(
    String sessionName,
    int windowIndex, {
    String tmuxBin = 'tmux',
    String? lang,
  }) =>
      '${tmuxPrefix(tmuxBin: tmuxBin, lang: lang)} select-window -t ${escapeArg('$sessionName:$windowIndex')}';

  /// Build the new-window command.
  static String newWindow(
    String sessionName, {
    String tmuxBin = 'tmux',
    String? lang,
  }) =>
      '${tmuxPrefix(tmuxBin: tmuxBin, lang: lang)} new-window -t ${escapeArg(sessionName)}';

  /// Find tmux binary path.
  /// Uses `bash -i -c` to start an interactive shell that sources ~/.bashrc,
  /// ensuring PATH includes homebrew/linuxbrew etc.
  static String get findTmux =>
      "bash -i -c 'command -v tmux' 2>/dev/null || "
      'command -v tmux 2>/dev/null || which tmux 2>/dev/null';
}
