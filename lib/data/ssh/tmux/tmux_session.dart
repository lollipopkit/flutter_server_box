import 'dart:async';

import 'package:server_box/data/ssh/persistent_shell.dart';
import 'package:server_box/data/ssh/tmux/tmux_session_info.dart';
import 'package:server_box/data/ssh/tmux/tmux_session_scanner.dart';
import 'package:server_box/data/ssh/tmux/tmux_window_info.dart';

/// A user's tmux selection for a new terminal connection.
sealed class TmuxAttachChoice {
  const TmuxAttachChoice();
}

/// Attach to an existing tmux session, optionally at a specific window.
final class TmuxAttachExisting extends TmuxAttachChoice {
  final String sessionName;
  final int? windowIndex;
  const TmuxAttachExisting({required this.sessionName, this.windowIndex});
}

/// Creates a tmux session named [sessionName].
final class TmuxAttachNew extends TmuxAttachChoice {
  final String sessionName;
  const TmuxAttachNew({required this.sessionName});
}

/// Opens the raw shell without tmux.
final class TmuxAttachSkip extends TmuxAttachChoice {
  const TmuxAttachSkip();
}

/// Manages tmux session lifecycle for an SSH connection.
///
/// Uses `tmux -CC` protocol for session discovery on a background channel,
/// and generates the appropriate attach command for the main terminal.
final class TmuxSession {
  final PersistentShell _shell;
  final TmuxSessionScanner _scanner;

  TmuxSession(PersistentShell shell, {String? lang})
    : _shell = shell,
      _scanner = TmuxSessionScanner(shell, lang: lang);

  TmuxSessionScanner get scanner => _scanner;

  /// Whether tmux is available on the remote server.
  Future<bool> get isAvailable => _scanner.isTmuxAvailable();

  /// Discover available sessions.
  Future<List<TmuxSessionInfo>> get sessions => _scanner.listSessions();

  /// List windows in a session.
  Future<List<TmuxWindowInfo>> listWindows(String sessionName) =>
      _scanner.listWindows(sessionName);

  /// List windows while preserving command failure as null.
  Future<List<TmuxWindowInfo>?> tryListWindows(String sessionName) =>
      _scanner.tryListWindows(sessionName);

  Future<bool> killWindow(String sessionName, int windowIndex) =>
      _scanner.killWindow(sessionName, windowIndex);

  Future<bool> newWindow(String sessionName) => _scanner.newWindow(sessionName);

  /// Kill a tmux session.
  Future<bool> killSession(String name) => _scanner.killSession(name);

  /// Close the underlying PersistentShell SSH channel.
  Future<void> dispose() async {
    try {
      await _shell.close();
    } catch (_) {}
  }

  /// Run an arbitrary command on the remote server.
  Future<bool> runCommand(String command) => _scanner.runCommand(command);

  /// Run a command and capture its output.
  Future<String?> runCommandAndCapture(String command) =>
      _scanner.runCommandAndCapture(command);
}
