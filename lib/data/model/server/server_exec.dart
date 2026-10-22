import 'dart:async';

import 'package:fl_tty/fl_tty.dart';
import 'package:server_box/src/rust/api/script.dart' as script_ffi;

export 'package:fl_tty/fl_tty.dart' show CommandByteExec, CommandExec, ExecResult, ExecSession, OnExecOutput;

/// The exit code [ServerExecSudo.runWithSudo] reports when sudo would not
/// take the password it was given, or was not given one at all.
///
/// A number rather than an exception because it travels with the rest of the
/// result: the command's own output is still worth reading, and a caller that
/// does not care about sudo can treat it as any other non-zero exit.
const kSudoPasswordRejected = 2;

extension ServerExecSudo on CommandExec {
  /// Runs [script] with [password] on its stdin, reporting a rejected sudo
  /// password as [kSudoPasswordRejected].
  ///
  /// The password goes here rather than into the command `sudo -S` is part of,
  /// which is what `sudo -S` reading stdin is for. Written into the command it
  /// would end up wherever that command is recorded — the agent's audit log,
  /// the machine's process list, a debug log — and none of those are places a
  /// password should be recoverable from.
  ///
  /// Null when the caller has no password to offer, which is the case where
  /// the far side is expected to allow the command without one.
  Future<ExecResult> runWithSudo(
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
    if (!script_ffi.sudoPasswordRejected(stderr: result.stderr)) return result;
    return ExecResult(
      exitCode: kSudoPasswordRejected,
      stdout: result.stdout,
      stderr: result.stderr,
    );
  }
}
