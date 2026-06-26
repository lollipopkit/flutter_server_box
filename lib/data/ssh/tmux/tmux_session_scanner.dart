import 'dart:async';

import 'package:fl_lib/fl_lib.dart';
import 'package:server_box/data/ssh/persistent_shell.dart';
import 'package:server_box/data/ssh/tmux/tmux_command_builder.dart';
import 'package:server_box/data/ssh/tmux/tmux_session_info.dart';
import 'package:server_box/data/ssh/tmux/tmux_window_info.dart';

/// Scans for available tmux sessions on the remote server and manages
/// tmux -CC connections.
final class TmuxSessionScanner {
  final PersistentShell _shell;
  final String? _lang;
  String? _tmuxBin;
  String? get tmuxBin => _tmuxBin;

  TmuxSessionScanner(this._shell, {String? lang}) : _lang = lang;

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

  /// Find tmux binary and check availability. Stores the path for later use.
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
        TmuxCommandBuilder.listSessionsCmd(tmuxBin: _tmuxBin!, lang: _lang),
        timeout: const Duration(seconds: 5),
      );
      if (result.exitCode != 0) return [];
      return result.output
          .split('\n')
          .where((line) => line.trim().isNotEmpty)
          .map(TmuxSessionInfo.tryParse)
          .whereType<TmuxSessionInfo>()
          .toList();
    } catch (e, st) {
      Loggers.app.warning('Failed to list tmux sessions', e, st);
      return [];
    }
  }

  /// List windows in a tmux session.
  Future<List<TmuxWindowInfo>> listWindows(String sessionName) async {
    try {
      if (!await _ensureTmuxResolved()) return [];
      final result = await _shell.run(
        TmuxCommandBuilder.listWindows(
          sessionName,
          tmuxBin: _tmuxBin!,
          lang: _lang,
        ),
        timeout: const Duration(seconds: 5),
      );
      if (result.exitCode != 0) return [];
      return result.output
          .split('\n')
          .where((line) => line.trim().isNotEmpty)
          .map(TmuxWindowInfo.tryParse)
          .whereType<TmuxWindowInfo>()
          .toList();
    } catch (e, st) {
      Loggers.app.warning('Failed to list tmux windows', e, st);
      return [];
    }
  }

  /// Run a command and capture its output.
  Future<String?> runCommandAndCapture(String command) async {
    try {
      final result = await _shell.run(
        command,
        timeout: const Duration(seconds: 5),
      );
      if (result.exitCode == 0) return result.output;
      return null;
    } catch (e, st) {
      Loggers.app.warning('Failed to run command: $command', e, st);
      return null;
    }
  }

  /// Run an arbitrary command on the remote server.
  Future<bool> runCommand(String command) async {
    try {
      final result = await _shell.run(
        command,
        timeout: const Duration(seconds: 5),
      );
      return result.exitCode == 0;
    } catch (e, st) {
      Loggers.app.warning('Failed to run command: $command', e, st);
      return false;
    }
  }

  /// Kill a tmux session by name.
  Future<bool> killSession(String sessionName) async {
    try {
      final result = await _shell.run(
        TmuxCommandBuilder.killSession(
          sessionName,
          tmuxBin: _tmuxBin ?? 'tmux',
          lang: _lang,
        ),
        timeout: const Duration(seconds: 5),
      );
      return result.exitCode == 0;
    } catch (e, st) {
      Loggers.app.warning('Failed to kill tmux session', e, st);
      return false;
    }
  }
}
