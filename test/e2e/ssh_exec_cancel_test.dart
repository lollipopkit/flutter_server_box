/// Opt-in end-to-end test of stopping a command on a real SSH server, over
/// the client the app uses (dartssh2) and [SshExec] — what the Agent's stop
/// button pulls (#1684).
///
/// Skipped unless `SBM_E2E_SSH_HOST` is set, in the environment or the
/// workspace-root `.env`: an SSH destination `ssh -G` resolves, on a Linux
/// host with `setsid` (util-linux). It only runs `sleep` there, and kills what
/// it started.
library;

import 'dart:async';
import 'dart:math';

import 'package:dartssh2/dartssh2.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/core/utils/ssh_exec.dart';

import '../helpers/rust_lib_helper.dart';
import '../helpers/ssh_e2e.dart';

Future<void> main() async {
  final host = e2eEnv('SBM_E2E_SSH_HOST');
  if (host == null) {
    test('ssh exec cancel e2e', () {}, skip: 'SBM_E2E_SSH_HOST not set');
    return;
  }
  final prepared = await prepareSshE2e(host);
  final target = prepared.target;
  if (target == null) {
    test(
      'ssh exec cancel e2e',
      () => fail(prepared.failure ?? ''),
      skip: prepared.skip,
    );
    return;
  }

  late SSHClient client;
  setUpAll(() async {
    await initRustLibForTest();
    client = await connectSshE2e(target, prepared.identities);
  });
  tearDownAll(() => client.close());

  // A duration nothing else on the host sleeps for, so `pgrep` finds only
  // this run's process.
  final seconds = 600 + Random().nextInt(100000);

  Future<bool> running(int s) async {
    final r = await execSshE2e(client, 'pgrep -fx "sleep $s"', null);
    return r.exitCode == 0;
  }

  tearDownAll(() async {
    for (final s in [seconds, seconds + 1]) {
      await execSshE2e(client, 'pkill -fx "sleep $s"', null);
    }
  });

  test('a stop kills the command and returns at once', () async {
    final cancel = Completer<void>();
    final watch = Stopwatch()..start();
    final run = SshExec(client).run('sleep $seconds', cancel: cancel.future);
    await Future<void>.delayed(const Duration(seconds: 1));
    expect(await running(seconds), isTrue, reason: 'the command started');

    cancel.complete();
    final result = await run;
    expect(watch.elapsed, lessThan(SshExec.drainTimeout));
    expect(result.outputIncomplete, isFalse);
    expect(await running(seconds), isFalse, reason: 'SIGKILL reached it');
  });

  test(
    'a stop returns even when a process outside the group holds stdout',
    () async {
      // `setsid -w` waits for a child in a session of its own: SIGKILL to the
      // command's process group misses it, and sshd keeps the channel open
      // for as long as it holds stdout — the stuck build of #1684.
      final s = seconds + 1;
      final cancel = Completer<void>();
      final run = SshExec(
        client,
      ).run('echo started; setsid -w sleep $s', cancel: cancel.future);
      await Future<void>.delayed(const Duration(seconds: 1));
      expect(await running(s), isTrue, reason: 'the command started');

      final watch = Stopwatch()..start();
      cancel.complete();
      final result = await run;
      expect(
        watch.elapsed,
        lessThan(SshExec.drainTimeout + const Duration(seconds: 2)),
      );
      expect(result.stdout, contains('started'));
      expect(result.outputIncomplete, isTrue);
    },
    timeout: const Timeout(Duration(seconds: 60)),
  );
}
