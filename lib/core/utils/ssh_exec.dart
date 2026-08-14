import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dartssh2/dartssh2.dart';
import 'package:server_box/data/model/server/server_exec.dart';

/// [ServerExec] over an SSH connection.
///
/// One command, one channel — which is what SSH multiplexing is for, and why
/// running a command has never needed the interactive shell the terminal page
/// holds open.
///
/// Cancelling here really stops the command: the channel carries a signal, and
/// what is left of the output is what had already arrived.
class SshExec implements ServerExec {
  const SshExec(this.client);

  final SSHClient client;

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
    // With no [entry] the script *is* the command, which leaves the channel's
    // stdin free to be stdin — where a sudo password belongs. With one, the
    // entry is the command and the script is what it reads.
    final session = await client.execute(entry ?? script, environment: env);

    // Registered rather than awaited: this races the command, and a signal
    // that never comes must not hold the result up. `session.done` completes
    // once the channel closes either way, so there is nothing else to unwind.
    unawaited(
      cancel?.then((_) {
        try {
          session.kill(SSHSignal.KILL);
        } catch (_) {
          // Already gone. Closing below is still what releases the channel.
        }
        session.close();
      }),
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
    if (entry != null) {
      session.stdin.add(Uint8List.fromList(utf8.encode('$script\n')));
    }
    // Closed either way: a command that reads stdin would otherwise wait for
    // input nobody is going to send.
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
