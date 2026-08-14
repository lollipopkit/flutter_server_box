import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:fl_lib/fl_lib.dart';
import 'package:server_box/core/utils/android_rootfs.dart';
import 'package:server_box/core/utils/local_shell.dart';
import 'package:server_box/data/model/server/server_exec.dart';
import 'package:server_box/data/res/store.dart';

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
  const LocalExec({this.inRootfs = false});

  /// Whether commands run inside the Linux userland rather than on the host.
  ///
  /// What the Agent gets on Android, and the reason [AndroidRootfs] is worth
  /// its size on a platform that already has a shell: the host one runs as the
  /// app, beside its stores and its keys, while the guest sees a filesystem
  /// that contains none of them.
  final bool inRootfs;

  /// What names this machine where a server id is expected.
  ///
  /// Reserved rather than generated: server ids come from `ShortId`, whose
  /// alphabet has no `#`, so nothing the user configures can collide with it.
  /// One spelling, shared with the terminal's [LocalSource].
  static const deviceId = '#local';

  /// Whether this platform will run one.
  ///
  /// The same answer as a terminal's, and for one of the same two reasons: iOS
  /// cannot start a process at all, and a sandboxed macOS build is the App
  /// Store one. Sandboxed *exec* does work — measured — but a build that
  /// cannot show a local terminal should not quietly run local commands for a
  /// model either.
  static bool get isSupported => LocalShellBackend.isSupported;

  /// Whether the Agent may be told this machine exists at all.
  ///
  /// Three gates on Android and two elsewhere: the platform, the setting the
  /// user turned on, and — on Android — a Linux userland to run in, because
  /// that is the only local target offered there. Asked in one place so the
  /// instructions and the tool cannot disagree: a model told about a machine
  /// its tools then refuse spends a turn proposing commands for it.
  static bool get isOffered {
    if (!isSupported) return false;
    if (!Stores.setting.agentLocalExec.fetch()) return false;
    if (isAndroid && !AndroidRootfs.isReady) return false;
    return true;
  }

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
    // One executable either way; only what it is told to run differs, which
    // is what the ternary below says. The one that used to stand here chose
    // between `shell` and `shell`.
    final guest = inRootfs
        ? AndroidRootfs.enter(command: entry ?? script)
        : null;
    if (inRootfs && guest == null) {
      throw StateError('There is no Linux userland on this device to run in.');
    }
    final process = await Process.start(
      guest?.executable ?? shell,
      guest?.arguments ?? (entry == null ? [flag, script] : [flag, entry]),
      // The guest's own PATH and home, or Android's name for a directory that
      // does not exist inside it and a shell that finds none of its own tools.
      environment: guest == null
          ? env
          : {...AndroidRootfs.environment, ...?env},
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
    final sigkill = Timer(const Duration(seconds: 3), () {
      try {
        process.kill(ProcessSignal.sigkill);
      } catch (_) {
        // Already gone, which is the point.
      }
    });
    // Cancelled when the process goes on its own, which is the ordinary case.
    // Left running, the timer held this closure — and the `Process` with it —
    // for three seconds past every cancelled command.
    process.exitCode.whenComplete(sigkill.cancel).ignore();
  }
}
