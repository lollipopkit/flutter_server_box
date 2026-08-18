import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:fl_lib/fl_lib.dart';
import 'package:meta/meta.dart';
import 'package:server_box/core/utils/file_tail.dart';
import 'package:server_box/core/utils/ios_rootfs.dart';
import 'package:server_box/core/utils/local_exec.dart';
import 'package:server_box/data/model/server/server_exec.dart';

/// [LocalExec] inside the Linux guest on iOS.
///
/// The same shape Android's local target has — the container is the only local
/// machine, and the file tools resolve inside it — reached the only way this
/// platform allows. There is no host shell to be the other answer: an App Store
/// app cannot start a process, which is why it carries an interpreter at all.
///
/// A session in the guest is a process with a pseudo-terminal, and a pty is the
/// wrong shape for `ServerExec`: it merges the two streams, echoes what is
/// written to it, and makes every program that asks believe it is talking to a
/// terminal, so `ls` prints columns and `ps` truncates to a width nobody chose.
/// So the command's own streams are sent to two files instead, and read from
/// the host — which costs nothing here, because `realfs` mounts the guest's
/// filesystem as an ordinary directory tree that both sides can see. What is
/// left on the terminal is what a redirect could not catch: the shell's
/// complaint if the redirect itself failed, and anything written to `/dev/tty`.
class IshExec extends LocalExec {
  const IshExec();

  /// Whether this build can run one at all — see [IosRootfs.isAvailable],
  /// which is false whenever the engine was stripped from the build.
  static bool get isSupported => IosRootfs.isAvailable;

  /// Always. The guest is the only local machine iOS has.
  @override
  bool get inRootfs => true;

  @override
  Future<String?> hostPathOf(String path, {bool forWrite = false}) =>
      IosRootfs.hostPathOf(path, forWrite: forWrite);

  /// How often the session and its two output files are looked at.
  ///
  /// The same reasoning as the terminal's: reading with a timeout blocks this
  /// isolate, so the wait belongs here rather than in the engine.
  static const _interval = Duration(milliseconds: 16);

  /// End of transmission — what a console in canonical mode takes for the end
  /// of input, since there is no descriptor here to close instead.
  static const _eof = '\u0004';

  /// How long a command the engine will take, in bytes.
  ///
  /// `sbm_ish_open` packs `/bin/sh`, `-c` and the command into one 4096-byte
  /// block (`ios/Runner/ish/sbm_ish.c`) and answers `-E2BIG` rather than
  /// truncating — which reaches a caller as "the guest refused a session (-7)",
  /// a sentence that says nothing about length. The guest's own `ARGV_MAX` is
  /// 32 pages, so 4 KB is this app's limit and not Linux's.
  ///
  /// Left where it is rather than raised: that block is a local of the thread
  /// that becomes the guest process, and a script long enough to reach it is
  /// better off in a file, which has no limit worth naming. The status script
  /// is 4919 bytes and would never have fit.
  @visibleForTesting
  static const argvLimit = 4000;

  /// Whether [command] has to be run from a file rather than handed to the
  /// engine. Counted in bytes, which is what the C side counts.
  @visibleForTesting
  static bool needsFile(String command) =>
      utf8.encode(command).length > argvLimit;

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
    if (entry != null) {
      // The shape that feeds a script to a command on its stdin, which is how
      // the status script is installed over SSH. Nothing asks it of a local
      // machine, and answering it here would mean pushing a whole script
      // through a console's line discipline.
      throw StateError(
        'The Linux guest runs a script, not a command that reads one. Run the '
        'script itself.',
      );
    }

    final root = IosRootfs.root;
    if (root == null || !IosRootfs.isReadySync) {
      throw StateError('There is no Linux userland on this device to run in.');
    }

    final booted = IosRootfs.boot();
    if (booted < 0 && booted != IosRootfs.alreadyBooted) {
      throw StateError('The Linux guest did not start ($booted)');
    }

    // Named rather than reused, so two commands at once cannot read each
    // other's output. `ShortId`'s alphabet is filename-safe.
    final name = '.sbm-exec-${ShortId.generate()}';
    final directory = Directory(root.joinPath('tmp'));
    await directory.create(recursive: true);
    final outFile = File('${directory.path}/$name.out');
    final errFile = File('${directory.path}/$name.err');
    final ours = <File>[outFile, errFile];

    final command = wrapScript(
      script,
      out: '/tmp/$name.out',
      err: '/tmp/$name.err',
      env: env,
      readsStdin: stdin != null,
    );

    // Past what the engine takes as an argument, so the script goes where its
    // output already does. Nothing about the run changes: the shell that reads
    // the file is the one the redirect and the environment were written for,
    // and it is still the session's process, so its exit code is the answer.
    var opened = command;
    if (needsFile(command)) {
      final file = File('${directory.path}/$name.sh');
      await file.writeAsString(command);
      ours.add(file);
      opened = "sh '/tmp/$name.sh'";
    }

    final id = IosRootfs.open(command: opened);
    if (id < 0) {
      await _remove(ours);
      throw StateError('The Linux guest refused a session ($id)');
    }

    final out = FileTail(outFile, onStdout);
    final err = FileTail(errFile, onStderr);
    var cancelled = false;
    var finished = false;

    // Registered rather than awaited: this races the command, and a signal
    // that never comes must not hold the result up. Closing the session hangs
    // its process group up, and the loop below sees the session end.
    unawaited(
      cancel?.then((_) {
        if (finished) return;
        cancelled = true;
        IosRootfs.close(id);
      }),
    );

    if (stdin != null) {
      // Written straight at the console's line discipline, which holds a
      // bounded buffer and waits when it is full. Short by construction —
      // `runWithSudo`'s password is what this exists for — and a caller with a
      // whole script to send is refused above rather than left to wedge here.
      IosRootfs.write(id, stdin);
      IosRootfs.write(id, _eof);
    }

    int? exitCode;
    try {
      while (true) {
        // Zero, so this returns whatever is there and no more; null means the
        // session has ended and its console is drained.
        final console = IosRootfs.read(id, timeout: Duration.zero);
        if (console == null) break;
        // Reported as stderr because that is where a reader is already looking
        // for a command that went wrong, and because that is what this is.
        if (console.isNotEmpty) {
          err.adopt(console);
          onStderr?.call(console);
        }
        await out.poll();
        await err.poll();
        await Future<void>.delayed(_interval);
      }
      // Before closing: a closed session has no exit code left to report.
      exitCode = IosRootfs.exitCode(id);
      await out.poll();
      await err.poll();
      out.finish();
      err.finish();
    } finally {
      finished = true;
      IosRootfs.close(id);
      await _remove(ours);
    }

    return ExecResult(
      // A cancelled command has no exit code worth reporting: it was hung up,
      // and what its shell made of that is not what the caller asked about.
      exitCode: cancelled ? null : exitCode,
      stdout: out.text,
      stderr: err.text,
    );
  }

  /// The script, with its own streams sent somewhere the host can read them.
  ///
  /// `exec` rather than wrapping the script in braces: the redirect applies to
  /// everything after it without the script having to be syntactically
  /// nestable, so a script that opens with a comment or a here-document is left
  /// exactly as it was written. If the redirect itself fails the shell says so
  /// on the terminal and stops, which is why what the terminal says is kept.
  ///
  /// Exposed because the rest of this class needs a device and an engine that
  /// is not in this repository, and the shell it writes is checkable here.
  @visibleForTesting
  static String wrapScript(
    String script, {
    required String out,
    required String err,
    required Map<String, String>? env,
    required bool readsStdin,
  }) {
    final buffer = StringBuffer()
      // `/dev/null` where there is nothing to type, the way a process with a
      // closed stdin behaves: a command that reads input should see the end of
      // it rather than wait for a console nobody is typing at.
      ..writeln("exec >'$out' 2>'$err'${readsStdin ? '' : ' </dev/null'}");
    if (env != null) {
      for (final entry in env.entries) {
        buffer.writeln("export ${entry.key}='${_quoted(entry.value)}'");
      }
    }
    return (buffer..write(script)).toString();
  }

  /// A value for the inside of single quotes, where the only thing that can end
  /// them is a quote of its own.
  static String _quoted(String value) => value.replaceAll("'", r"'\''");

  static Future<void> _remove(List<File> files) async {
    for (final file in files) {
      try {
        if (await file.exists()) await file.delete();
      } catch (_) {
        // A command that made it unwritable, or a guest that is gone. Either
        // way it is a file in the guest's own /tmp.
      }
    }
  }
}
