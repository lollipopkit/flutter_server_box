import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:fl_lib/fl_lib.dart';
import 'package:server_box/core/utils/android_rootfs.dart';
import 'package:server_box/core/utils/ish_exec.dart';
import 'package:server_box/core/utils/local_shell.dart';
import 'package:server_box/core/utils/process_tree.dart';
import 'package:server_box/core/utils/rootfs.dart';
import 'package:server_box/data/model/server/server_exec.dart';
import 'package:server_box/data/res/store.dart';

/// [ServerExec] on the machine the app is running on.
///
/// Two mechanisms behind one name, which is the split the terminal already has
/// (`LocalShellBackend` and `IshShellBackend`): everywhere but iOS the app
/// starts a process, and iOS has none to start, so its commands run inside the
/// interpreter's guest. What the Agent's tools ask is the same either way —
/// whether this machine is a container, and where a path it names actually is.
abstract class LocalExec implements ServerExec {
  const LocalExec();

  /// What names this machine where a server id is expected.
  ///
  /// Reserved rather than generated: server ids come from `ShortId`, whose
  /// alphabet has no `#`, so nothing the user configures can collide with it.
  /// One spelling, shared with the terminal's [LocalSource].
  static const deviceId = '#local';

  /// The one this device runs commands with, or null where none can.
  ///
  /// Asked in one place so that "which platform is this" is answered once. A
  /// caller that got an instance has a machine; what kind it is, it asks the
  /// instance.
  static LocalExec? forThisDevice() {
    if (isIOS) return IshExec.isSupported ? const IshExec() : null;
    if (!ProcessExec.isSupported) return null;
    return ProcessExec(inRootfs: isAndroid);
  }

  /// Whether this platform will run one.
  ///
  /// The reasons differ by platform and are on each implementation: a
  /// sandboxed macOS build is the App Store one and hosts no pty, and iOS
  /// depends on whether the engine was linked into this build at all.
  static bool get isSupported => forThisDevice() != null;

  /// Whether the Agent may be told this machine exists at all.
  ///
  /// Three gates where the local target is a container and two elsewhere: the
  /// platform, the setting the user turned on, and a userland to run in.
  /// Asked in one place so the instructions and the tool cannot disagree: a
  /// model told about a machine its tools then refuse spends a turn proposing
  /// commands for it.
  static bool get isOffered {
    final exec = forThisDevice();
    if (exec == null) return false;
    if (!Stores.setting.agentLocalExec.fetch()) return false;
    if (exec.inRootfs && !Rootfs.isReady) return false;
    return true;
  }

  /// Whether commands run inside the Linux userland rather than on the host.
  ///
  /// What the Agent gets on both platforms that have one, and the reason a
  /// userland is worth its size even on Android, which already had a shell:
  /// the host one runs as the app, beside its stores and its keys, while the
  /// guest sees a filesystem that contains none of them.
  bool get inRootfs;

  /// Where a path the model wrote actually is, or null when it is nowhere this
  /// machine will expose.
  ///
  /// The Agent's file tools are `dart:io` and never enter a guest, so on a
  /// container this is the boundary itself rather than a convenience. On the
  /// host the two are the same string.
  Future<String?> hostPathOf(String path, {bool forWrite = false});
}

/// [LocalExec] as a process on the host, which is every platform but iOS.
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
class ProcessExec extends LocalExec {
  const ProcessExec({this.inRootfs = false});

  @override
  final bool inRootfs;

  /// Whether this platform will start one.
  ///
  /// The same answer as a terminal's, and for one of the same two reasons: iOS
  /// cannot start a process at all, and a sandboxed macOS build is the App
  /// Store one. Sandboxed *exec* does work — measured — but a build that
  /// cannot show a local terminal should not quietly run local commands for a
  /// model either.
  static bool get isSupported => LocalShellBackend.isSupported;

  @override
  Future<String?> hostPathOf(String path, {bool forWrite = false}) {
    // On the host they are the same string; there is no guest to be outside of.
    if (!inRootfs) return Future.value(path);
    return AndroidRootfs.hostPathOf(path, forWrite: forWrite);
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
        ? await AndroidRootfs.enter(command: entry ?? script)
        : null;
    if (inRootfs && guest == null) {
      throw StateError('There is no Linux userland on this device to run in.');
    }
    try {
      final executable = guest?.executable ?? shell;
      final arguments =
          guest?.arguments ?? (entry == null ? [flag, script] : [flag, entry]);
      final setsid = cancel == null ? null : _setsidPath;
      final process = await Process.start(
        setsid ?? executable,
        setsid == null ? arguments : [executable, ...arguments],
        // The guest's own PATH and home, or Android's name for a directory that
        // does not exist inside it and a shell that finds none of its own tools.
        environment: guest == null
            ? env
            : {...AndroidRootfs.environment, ...?env},
        // Added to, not replaced: a command here runs on the user's own machine
        // and is written expecting the PATH they have.
        includeParentEnvironment: true,
      );
      final processGroupId = setsid == null ? null : process.pid;

      var cancelled = false;
      unawaited(
        cancel?.then((_) {
          cancelled = true;
          ProcessTree.terminate(process, processGroupId);
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
    } finally {
      guest?.release();
    }
  }
}

final String? _setsidPath = () {
  if (!Platform.isLinux) return null;
  for (final path in const ['/usr/bin/setsid', '/bin/setsid']) {
    if (File(path).existsSync()) return path;
  }
  return null;
}();
