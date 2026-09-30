import 'dart:async';

import 'package:server_box/data/ssh/persistent_shell.dart';
import 'package:server_box/data/ssh/tmux/tmux_ids.dart';
import 'package:server_box/data/ssh/tmux/tmux_session_info.dart';
import 'package:server_box/data/ssh/tmux/tmux_session_scanner.dart';
import 'package:server_box/data/ssh/tmux/tmux_window_info.dart';

/// A user's tmux selection for a new terminal connection.
sealed class TmuxAttachChoice {
  const TmuxAttachChoice();
}

/// Attach to an existing tmux session, optionally at a specific window.
///
/// [sessionId] is preferred when discovery or a live client provided it;
/// [sessionName] remains the display and legacy-restoration identity.
final class TmuxAttachExisting extends TmuxAttachChoice {
  final String sessionName;
  final TmuxSessionId? sessionId;
  final int? windowIndex;
  const TmuxAttachExisting({
    required this.sessionName,
    this.sessionId,
    this.windowIndex,
  });

  String get target => sessionId?.value ?? sessionName;
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

/// Manages tmux session discovery while a terminal is being opened.
///
/// This is a short-lived `sh` used before the foreground `tmux -CC` client is
/// attached; live state and switching are handled by [TmuxControlClient].
final class TmuxSession {
  final PersistentShell _shell;
  final TmuxSessionScanner _scanner;

  TmuxSession(PersistentShell shell)
    : _shell = shell,
      _scanner = TmuxSessionScanner(shell);

  TmuxSessionScanner get scanner => _scanner;

  /// Whether tmux is available on the remote server.
  Future<bool> get isAvailable => _scanner.isTmuxAvailable();

  /// Discover available sessions.
  Future<List<TmuxSessionInfo>> get sessions => _scanner.listSessions();

  /// List windows while preserving command failure as null.
  Future<List<TmuxWindowInfo>?> tryListWindows(String sessionTarget) =>
      _scanner.tryListWindows(sessionTarget);

  /// Close the underlying PersistentShell SSH channel.
  Future<void> dispose() async {
    try {
      await _shell.close();
    } catch (_) {}
  }
}
