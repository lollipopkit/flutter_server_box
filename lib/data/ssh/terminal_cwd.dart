import 'package:fl_lib/fl_lib.dart';
import 'package:server_box/core/utils/ssh_exec.dart';
import 'package:server_box/data/ssh/terminal_session.dart';
import 'package:server_box/data/ssh/tmux/tmux_control_shell_session.dart';
import 'package:server_box/src/rust/api/shell_cwd.dart';

/// Where a terminal's shell is, for something that wants to follow it — the
/// file panel beside a terminal.
abstract final class TerminalCwd {
  /// How long the question may take before the answer is "don't know".
  static const _timeout = Duration(seconds: 5);

  /// What the shell last said through OSC 7, or else what `/proc` says about
  /// it, asked on an exec channel of the terminal's own connection — see
  /// `sbm_parser::shell_cwd`. Nothing is typed into the terminal either way.
  ///
  /// Null when neither answers: a shell on this device or behind the monitor
  /// agent, which has no exec channel beside it; a server without `/proc`; or
  /// several shells on one connection that cannot be told apart.
  static Future<String?> of(TerminalSession session) async {
    if (session.cwd.value case final reported?) return reported;
    // tmux's client is what sshd started, and its directory is not the
    // pane's: `/proc` has no answer for a terminal under it.
    if (session.foreground is TmuxControlShellSession) return null;
    final client = session.client;
    if (client == null || client.isClosed) return null;
    try {
      final result = await SshExec(
        client,
      ).run(shellCwdScript(), entry: 'sh', cancel: Future.delayed(_timeout));
      final terminal = session.terminal;
      return shellCwdPick(
        raw: result.stdout,
        cols: terminal.viewWidth,
        rows: terminal.viewHeight,
      );
    } catch (e, s) {
      Loggers.app.warning('Asking where the shell is', e, s);
      return null;
    }
  }
}
