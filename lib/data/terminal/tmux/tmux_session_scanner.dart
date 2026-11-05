import 'dart:async';

import 'package:fl_lib/fl_lib.dart';
import 'package:server_box/data/terminal/persistent_shell.dart';
import 'package:server_box/data/terminal/tmux/tmux_command_builder.dart';
import 'package:server_box/data/terminal/tmux/tmux_session_info.dart';
import 'package:server_box/data/terminal/tmux/tmux_window_info.dart';
import 'package:server_box/src/rust/api/tmux.dart' as ffi;

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
    return ffi.tmuxParseFind(
      output: result.output,
      succeeded: result.exitCode == 0,
    );
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

  /// The tmux sessions on the remote server, or null when listing them failed.
  ///
  /// Empty where tmux is absent or no server is running: neither has sessions.
  Future<List<TmuxSessionInfo>?> tryListSessions() async {
    try {
      if (!await _ensureTmuxResolved()) return const [];
      final result = await _shell.run(
        TmuxCommandBuilder.listSessionsCmd(tmuxBin: _tmuxBin!),
        timeout: const Duration(seconds: 5),
      );
      final exitCode = result.exitCode;
      final listing = exitCode == null
          ? null
          : ffi.tmuxReadSessions(output: result.output, exitCode: exitCode);
      if (listing == null) {
        Loggers.app.warning(
          'tmux list-sessions exited $exitCode',
          result.output.split('\n').take(3).join('\n'),
        );
        return null;
      }
      if (listing.unreadable > 0 && listing.sessions.isEmpty) {
        Loggers.app.warning(
          'tmux list-sessions returned ${listing.unreadable} unparseable line(s)',
          result.output.split('\n').take(3).join('\n'),
        );
        return null;
      }
      return listing.sessions
          .map(TmuxSessionInfo.fromFfi)
          .toList(growable: false);
    } catch (e, st) {
      Loggers.app.warning('Failed to list tmux sessions', e, st);
      return null;
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
      return ffi
          .tmuxParseWindows(output: result.output)
          .map(TmuxWindowInfo.fromFfi)
          .toList();
    } catch (e, st) {
      Loggers.app.warning('Failed to list tmux windows', e, st);
      return null;
    }
  }
}
