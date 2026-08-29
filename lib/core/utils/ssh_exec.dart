import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dartssh2/dartssh2.dart';
import 'package:server_box/data/model/server/server_exec.dart';

typedef SshExecCollectedOutput = ({
  String stdout,
  String stderr,
  bool outputIncomplete,
});

/// Collects both SSH output streams until the command and streams have ended.
///
/// The completion futures are registered before [commandDone] is awaited. A
/// fast command can close stdout and stderr before its SSH exit status arrives;
/// registering `asFuture` afterwards misses that already-delivered done event
/// and falsely turns an ordinary command into a drain timeout.
Future<SshExecCollectedOutput> collectSshExecOutput({
  required Stream<List<int>> stdout,
  required Stream<List<int>> stderr,
  required Future<void> commandDone,
  required Duration drainTimeout,
  OnExecOutput? onStdout,
  OnExecOutput? onStderr,
}) async {
  final out = StringBuffer();
  final err = StringBuffer();
  final decoder = const Utf8Decoder(allowMalformed: true);

  // Subscriptions rather than `forEach`, so that giving up on the drain can
  // actually let go of the streams instead of leaving them writing into
  // buffers nobody will read.
  final outSub = decoder.bind(stdout).listen((chunk) {
    out.write(chunk);
    onStdout?.call(chunk);
  });
  final errSub = decoder.bind(stderr).listen((chunk) {
    err.write(chunk);
    onStderr?.call(chunk);
  });

  // These must be obtained while the subscriptions are still live. Calling
  // asFuture after a done event has already been delivered creates futures
  // that can no longer complete.
  final outDone = outSub.asFuture<void>();
  final errDone = errSub.asFuture<void>();

  await commandDone;

  var incomplete = false;
  await Future.wait([outDone, errDone]).timeout(
    drainTimeout,
    onTimeout: () async {
      incomplete = true;
      await outSub.cancel();
      await errSub.cancel();
      return const <void>[];
    },
  );

  return (
    stdout: out.toString(),
    stderr: err.toString(),
    outputIncomplete: incomplete,
  );
}

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

  /// How long to keep reading once the command itself has finished.
  ///
  /// `session.done` completes when the process exits, which is not when the
  /// channel goes quiet: anything it left running still holds stdout open.
  /// Without a bound here a finished command reads as a hung one, and the only
  /// thing that ends it is whatever timeout the caller happens to have — five
  /// minutes, for the Agent.
  static const drainTimeout = Duration(seconds: 5);

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

    final output = collectSshExecOutput(
      stdout: session.stdout,
      stderr: session.stderr,
      commandDone: session.done,
      drainTimeout: drainTimeout,
      onStdout: onStdout,
      onStderr: onStderr,
    );

    try {
      if (stdin != null) {
        session.stdin.add(Uint8List.fromList(utf8.encode(stdin)));
      }
      if (entry != null) {
        session.stdin.add(Uint8List.fromList(utf8.encode('$script\n')));
      }
      // Closed either way: a command that reads stdin would otherwise wait for
      // input nobody is going to send.
      await session.stdin.close();

      final collected = await output;
      return ExecResult(
        exitCode: session.exitCode,
        stdout: collected.stdout,
        stderr: collected.stderr,
        outputIncomplete: collected.outputIncomplete,
      );
    } finally {
      session.close();
    }
  }
}
