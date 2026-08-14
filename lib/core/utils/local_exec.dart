import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:server_box/core/utils/local_shell.dart';
import 'package:server_box/data/model/server/server_exec.dart';

/// [ServerExec] on the machine the app is running on.
///
/// Pipes, not a pseudo-terminal. `ServerExec` is "run this and tell me what it
/// said", and a pty would answer with the command echoed back, the output, and
/// escape sequences drawing a prompt — three things to strip before anything
/// could be parsed. [LocalShellBackend] is the other shape, for when the point
/// *is* a terminal.
///
/// That also keeps `stdout` and `stderr` apart, which a pty merges, so a caller
/// reading only one of them gets what it asked for — `runWithSudo` watching for
/// a rejected password is one.
class LocalExec implements ServerExec {
  const LocalExec();

  /// Whether this platform will run one.
  ///
  /// The same answer as a terminal's, and for one of the same two reasons: iOS
  /// cannot start a process at all, and a sandboxed macOS build is the App
  /// Store one. Sandboxed *exec* does work — measured — but a build that
  /// cannot show a local terminal should not quietly run local commands for a
  /// model either.
  static bool get isSupported => LocalShellBackend.isSupported;

  @override
  Future<ExecResult> run(
    String script, {
    String? entry,
    Map<String, String>? env,
    String? stdin,
    OnExecOutput? onStdout,
    OnExecOutput? onStderr,
    Future<void>? cancel,
  }) async {
    final shell = LocalShellBackend.shellPath;
    final flag = Platform.isWindows ? '/C' : '-c';

    // The same two shapes [SshExec] gives it: with no [entry] the script is the
    // command, which leaves stdin free to be stdin — where a sudo password
    // belongs. With one, the entry is the command and the script is what it
    // reads.
    final process = await Process.start(
      entry == null ? shell : shell,
      entry == null ? [flag, script] : [flag, entry],
      environment: env,
      // Added to, not replaced: a command here runs on the user's own machine
      // and is written expecting the PATH they have.
      includeParentEnvironment: true,
    );

    var cancelled = false;
    unawaited(
      cancel?.then((_) {
        cancelled = true;
        _kill(process);
      }),
    );

    final out = StringBuffer();
    final err = StringBuffer();
    const decoder = Utf8Decoder(allowMalformed: true);
    final outDone = decoder.bind(process.stdout).forEach((chunk) {
      out.write(chunk);
      onStdout?.call(chunk);
    });
    final errDone = decoder.bind(process.stderr).forEach((chunk) {
      err.write(chunk);
      onStderr?.call(chunk);
    });

    if (stdin != null) process.stdin.write(stdin);
    if (entry != null) process.stdin.write('$script\n');
    // Closed either way: a command that reads stdin would otherwise wait for
    // input nobody is going to send.
    try {
      await process.stdin.close();
    } catch (_) {
      // The process exited before reading anything, which is not this call's
      // failure — the exit code below is the answer.
    }

    final exitCode = await process.exitCode;
    await Future.wait([outDone, errDone]);

    return ExecResult(
      // A cancelled command has no exit code worth reporting: it was killed,
      // and the signal's number is not what the caller asked about.
      exitCode: cancelled ? null : exitCode,
      stdout: out.toString(),
      stderr: err.toString(),
    );
  }

  /// Ends the process.
  ///
  /// Only the process, unlike the terminal's pty. `Process.start` does not make
  /// the child a session leader, so its pid is not a group id — signalling
  /// `-pid` would reach whatever group the *app* is in. A shell running one
  /// command execs it rather than forking, so this reaches the real work in
  /// the ordinary case; a script that backgrounds something outlives this, and
  /// there is no safe way from here to find it.
  void _kill(Process process) {
    if (!process.kill()) return;
    // For a script that trapped the first one. Nothing is reading it any more.
    Timer(const Duration(seconds: 3), () {
      try {
        process.kill(ProcessSignal.sigkill);
      } catch (_) {
        // Already gone, which is the point.
      }
    });
  }
}
