import 'dart:async';

import 'package:fl_tty/fl_tty.dart';
import 'package:server_box/src/rust/api/script.dart' as script_ffi;

export 'package:fl_tty/fl_tty.dart' show CommandByteExec, CommandExec, ExecResult, ExecSession, OnExecOutput;

/// What [ServerExecSudo.runWithSudo] answers: the command's own result, and
/// whether sudo refused the password it was given (or was given none).
///
/// Beside the exit code rather than in it: a command's own exit status can be
/// any number, and the output is still worth reading either way.
final class SudoExecResult extends ExecResult {
  SudoExecResult(ExecResult result, {required this.rejected})
    : super(
        exitCode: result.exitCode,
        stdout: result.stdout,
        stderr: result.stderr,
        outputIncomplete: result.outputIncomplete,
        streamError: result.streamError,
        streamErrorStackTrace: result.streamErrorStackTrace,
        mayStillRun: result.mayStillRun,
      );

  final bool rejected;

  @override
  bool get succeeded => !rejected && super.succeeded;
}

extension SudoRejection on ExecResult {
  /// Sudo refused the password: only ever true of [SudoExecResult].
  bool get sudoRejected => switch (this) {
    final SudoExecResult r => r.rejected,
    _ => false,
  };
}

/// A command that exited non-zero where it had to succeed. [toString] is what
/// it printed, which is what the user is shown.
final class CommandFailed implements Exception {
  const CommandFailed(this.what, this.result);

  /// What was being run, in a few words: `install`, `read`.
  final String what;
  final ExecResult result;

  @override
  String toString() {
    final said = result.combined.trim();
    return said.isEmpty ? '$what exited with ${result.exitCode}' : said;
  }
}

extension ServerExecSudo on CommandExec {
  /// Runs [script] with [password] on its stdin, saying whether sudo rejected
  /// the password ([SudoExecResult.rejected]).
  ///
  /// The password goes here rather than into the command `sudo -S` is part of,
  /// which is what `sudo -S` reading stdin is for. Written into the command it
  /// would end up wherever that command is recorded — the agent's audit log,
  /// the machine's process list, a debug log — and none of those are places a
  /// password should be recoverable from.
  ///
  /// Null when the caller has no password to offer, which is the case where
  /// the far side is expected to allow the command without one.
  Future<SudoExecResult> runWithSudo(
    String script, {
    String? password,
    String? entry,
    OnExecOutput? onStdout,
    OnExecOutput? onStderr,
  }) async {
    final result = await run(
      script,
      entry: entry,
      // A newline of its own: `sudo -S` reads one line and stops, and a
      // password the user did not end with Enter would otherwise hang it.
      stdin: password == null ? null : '$password\n',
      onStdout: onStdout,
      onStderr: onStderr,
    );
    // `sudo` says so on stderr and then exits non-zero like everything else,
    // so without reading what it said a wrong password is indistinguishable
    // from the command itself failing. Read off the whole stream: a phrase
    // can arrive split across two chunks.
    return SudoExecResult(
      result,
      rejected: script_ffi.sudoPasswordRejected(stderr: result.stderr),
    );
  }
}
