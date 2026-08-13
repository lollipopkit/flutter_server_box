import 'dart:convert';
import 'dart:typed_data';

import 'package:dartssh2/dartssh2.dart';
import 'package:server_box/data/model/server/server_exec.dart';
import 'package:server_box/data/model/server/system.dart';

/// [ServerExec] over an SSH connection.
///
/// One command, one channel — which is what SSH multiplexing is for, and why
/// running a command has never needed the interactive shell the terminal page
/// holds open.
class SshExec implements ServerExec {
  const SshExec(this.client, {this.system});

  final SSHClient client;

  /// What the far end runs, which decides the interpreter a script with no
  /// [ServerExec.run] `entry` is fed to. Null before the first status fetch
  /// has said, which reads as POSIX.
  final SystemType? system;

  @override
  Future<ExecResult> run(
    String script, {
    String? entry,
    Map<String, String>? env,
    String? stdin,
    OnExecOutput? onStdout,
    OnExecOutput? onStderr,
  }) async {
    final session = await client.execute(
      // Fed on stdin rather than passed as an argument: a script with
      // newlines, quotes or a heredoc in it survives that way, and shell
      // quoting is not something every caller should have to get right.
      entry ?? defaultScriptEntry(system),
      environment: env,
    );

    final out = StringBuffer();
    final err = StringBuffer();
    final decoder = const Utf8Decoder(allowMalformed: true);

    final outDone = decoder.bind(session.stdout).forEach((chunk) {
      out.write(chunk);
      onStdout?.call(chunk);
    });
    final errDone = decoder.bind(session.stderr).forEach((chunk) {
      err.write(chunk);
      onStderr?.call(chunk);
    });

    if (stdin != null) {
      session.stdin.add(Uint8List.fromList(utf8.encode(stdin)));
    }
    session.stdin.add(Uint8List.fromList(utf8.encode('$script\n')));
    await session.stdin.close();

    await session.done;
    await Future.wait([outDone, errDone]);

    return ExecResult(
      exitCode: session.exitCode,
      stdout: out.toString(),
      stderr: err.toString(),
    );
  }
}
