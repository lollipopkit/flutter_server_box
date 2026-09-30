import 'dart:async';

import 'package:fl_lib/fl_lib.dart';
import 'package:server_box/data/ssh/persistent_shell.dart';
import 'package:server_box/data/ssh/tmux/tmux_command_builder.dart';
import 'package:server_box/data/ssh/tmux/tmux_session_info.dart';
import 'package:server_box/data/ssh/tmux/tmux_window_info.dart';

/// Discovers tmux before the foreground control-mode client is attached.
final class TmuxSessionScanner {
  final PersistentShell _shell;
  String? _tmuxBin;
  String? get tmuxBin => _tmuxBin;

  TmuxSessionScanner(this._shell);

  Future<String?> _findTmuxBin() async {
    final result = await _shell.run(
      TmuxCommandBuilder.findTmux,
      timeout: const Duration(seconds: 5),
    );
    if (result.exitCode != 0) return null;

    final tmuxBin = result.output.trim();
    if (tmuxBin.isEmpty) return null;
    return tmuxBin;
  }

  Future<bool> _ensureTmuxResolved() async {
    if (_tmuxBin != null) return true;
    return isTmuxAvailable();
  }

  /// Locates tmux and caches its executable path when available.
  Future<bool> isTmuxAvailable() async {
    try {
      final tmuxBin = await _findTmuxBin();
      if (tmuxBin == null) return false;
      _tmuxBin = tmuxBin;
      return true;
    } catch (_) {
      return false;
    }
  }

  /// List all tmux sessions on the remote server.
  Future<List<TmuxSessionInfo>> listSessions() async {
    try {
      if (!await _ensureTmuxResolved()) return [];
      final result = await _shell.run(
        TmuxCommandBuilder.listSessionsCmd(tmuxBin: _tmuxBin!),
        timeout: const Duration(seconds: 5),
      );
      if (result.exitCode != 0) return [];
      final lines = result.output
          .split('\n')
          .where((line) => line.trim().isNotEmpty)
          .toList(growable: false);
      final sessions = lines
          .map(TmuxSessionInfo.tryParse)
          .whereType<TmuxSessionInfo>()
          .toList(growable: false);
      if (lines.isNotEmpty && sessions.isEmpty) {
        // A successful command whose every line fails to parse is not "no
        // sessions"; it is a broken discovery contract, and returning silently
        // would hide that from both the user and the logs.
        Loggers.app.warning(
          'tmux list-sessions returned ${lines.length} unparseable line(s)',
          lines.take(3).join('\n'),
        );
      }
      return sessions;
    } catch (e, st) {
      Loggers.app.warning('Failed to list tmux sessions', e, st);
      return [];
    }
  }

  /// List windows, returning null when discovery or the command fails.
  ///
  /// This is only for validating a restored window before the foreground CC
  /// client is attached; live window and pane state belongs to that client.
  Future<List<TmuxWindowInfo>?> tryListWindows(String sessionTarget) async {
    try {
      if (!await _ensureTmuxResolved()) return null;
      final result = await _shell.run(
        TmuxCommandBuilder.listWindows(sessionTarget, tmuxBin: _tmuxBin!),
        timeout: const Duration(seconds: 5),
      );
      if (result.exitCode != 0) return null;
      return result.output
          .split('\n')
          .where((line) => line.trim().isNotEmpty)
          .map(TmuxWindowInfo.tryParse)
          .whereType<TmuxWindowInfo>()
          .toList();
    } catch (e, st) {
      Loggers.app.warning('Failed to list tmux windows', e, st);
      return null;
    }
  }
}
