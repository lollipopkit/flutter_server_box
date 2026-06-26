import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:server_box/data/ssh/persistent_shell.dart';
import 'package:server_box/data/ssh/tmux/tmux_command_builder.dart';
import 'package:server_box/data/ssh/tmux/tmux_session_info.dart';
import 'package:server_box/data/ssh/tmux/tmux_session_scanner.dart';
import 'package:server_box/data/ssh/tmux/tmux_window_info.dart';

/// Represents the user's choice when connecting to tmux.
sealed class TmuxAttachChoice {
  const TmuxAttachChoice();
}

/// Attach to an existing tmux session, optionally at a specific window.
final class TmuxAttachExisting extends TmuxAttachChoice {
  final String sessionName;
  final int? windowIndex;
  const TmuxAttachExisting({required this.sessionName, this.windowIndex});
}

/// Create a new tmux session with the given name.
final class TmuxAttachNew extends TmuxAttachChoice {
  final String sessionName;
  const TmuxAttachNew({required this.sessionName});
}

/// Skip tmux entirely (use raw shell).
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
  final ValueNotifier<TmuxAttachChoice?> choiceNotifier = ValueNotifier(null);
  final String? _lang;

  TmuxSession(PersistentShell shell, {String? lang})
    : _shell = shell,
      _lang = lang,
      _scanner = TmuxSessionScanner(shell, lang: lang);

  TmuxSessionScanner get scanner => _scanner;

  String? _lastSessionName;
  String? get lastSessionName => _lastSessionName;

  /// Check if tmux is available on the remote server.
  Future<bool> get isAvailable => _scanner.isTmuxAvailable();

  /// Discover available sessions.
  Future<List<TmuxSessionInfo>> get sessions => _scanner.listSessions();

  /// List windows in a session.
  Future<List<TmuxWindowInfo>> listWindows(String sessionName) =>
      _scanner.listWindows(sessionName);

  /// Set the user's choice and remember the session name for reconnection.
  void setChoice(TmuxAttachChoice choice) {
    choiceNotifier.value = choice;
    if (choice is TmuxAttachExisting) {
      _lastSessionName = choice.sessionName;
    } else if (choice is TmuxAttachNew) {
      _lastSessionName = choice.sessionName;
    }
  }

  /// Generate the shell command to execute for tmux attachment.
  ///
  /// Returns the command string to prepend to the terminal session.
  /// For existing sessions: `tmux attach-session -t <name>`
  /// For new sessions: `tmux new-session -s <name>`
  /// For skip: returns null (no tmux command).
  String? buildAttachCommand(
    TmuxAttachChoice choice, {
    String tmuxBin = 'tmux',
  }) {
    return switch (choice) {
      TmuxAttachExisting(sessionName: final name, windowIndex: final win) =>
        win != null
            ? TmuxCommandBuilder.attachSessionWindow(
                name,
                win,
                tmuxBin: tmuxBin,
                lang: _lang,
              )
            : TmuxCommandBuilder.attachSession(
                name,
                tmuxBin: tmuxBin,
                lang: _lang,
              ),
      TmuxAttachNew(sessionName: final name) => TmuxCommandBuilder.newSession(
        name,
        tmuxBin: tmuxBin,
        lang: _lang,
      ),
      TmuxAttachSkip() => null,
    };
  }

  /// Build the command for auto-reconnection.
  ///
  /// If a previous session was active, try to reattach.
  /// Otherwise, fall back to creating a new session.
  String buildReconnectCommand() {
    if (_lastSessionName != null) {
      return TmuxCommandBuilder.newSessionOrAttach(
        _lastSessionName!,
        lang: _lang,
      );
    }
    return 'tmux new-session';
  }

  /// Generate the initial auto-tmux command.
  ///
  /// Uses `tmux new-session -A` which attaches to an existing session
  /// with the given name or creates a new one.
  String buildAutoCommand({String? sessionName}) {
    final name = sessionName ?? 'server_box';
    return TmuxCommandBuilder.newSessionOrAttach(name, lang: _lang);
  }

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
