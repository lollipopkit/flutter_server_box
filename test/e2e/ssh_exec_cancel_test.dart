/// Opt-in end-to-end test of stopping a command on a real SSH server, over
/// the client the app uses (dartssh2) and [SshExec] — what the Agent's stop
/// button pulls (#1684).
///
/// Skipped unless `SBM_E2E_SSH_HOST` is set, in the environment or the
/// workspace-root `.env`: an SSH destination `ssh -G` resolves, on a Linux
/// host with `setsid` (util-linux) and `bash`. It only runs `sleep` there, and
/// kills what it started.
///
/// - `SBM_E2E_SSH_SUDO_PASSWORD` (optional): the account's sudo password, for
///   a command left running as root. Read from the environment only; never
///   printed.
library;

import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

import 'package:dartssh2/dartssh2.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/core/utils/ssh_exec.dart';
import 'package:server_box/data/model/server/server_exec.dart';

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
  final sudoPassword = e2eEnv('SBM_E2E_SSH_SUDO_PASSWORD');

  late SSHClient client;
  setUpAll(() async {
    await initRustLibForTest();
    client = await connectSshE2e(target, prepared.identities);
  });

  // Durations nothing else on the host sleeps for, so `pgrep` finds only
  // this run's processes.
  final base = 600 + Random().nextInt(100000);
  final used = <int>[];
  int sleepFor() {
    final s = base + used.length;
    used.add(s);
    return s;
  }

  Future<bool> running(int s) async {
    final r = await execSshE2e(client, 'pgrep -fx "sleep $s"', null);
    return r.exitCode == 0;
  }

  tearDownAll(() async {
    for (final s in used) {
      await execSshE2e(client, 'pkill -fx "sleep $s"', null);
    }
    if (sudoPassword != null) {
      for (final s in used) {
        await execSshE2e(
          client,
          "sudo -S -p '' pkill -fx 'sleep $s'",
          Uint8List.fromList('$sudoPassword\n'.codeUnits),
        );
      }
    }
    client.close();
  });

  /// Runs [command], stops it a second in, once [s] is running.
  Future<({ExecResult result, Duration took})> stop(
    String command,
    int s, {
    String? stdin,
    SshExec? exec,
  }) async {
    final cancel = Completer<void>();
    final run = (exec ?? SshExec(client)).run(
      command,
      stdin: stdin,
      cancel: cancel.future,
    );
    await Future<void>.delayed(const Duration(seconds: 1));
    expect(await running(s), isTrue, reason: 'the command started');
    final watch = Stopwatch()..start();
    cancel.complete();
    final result = await run;
    return (result: result, took: watch.elapsed);
  }

  test('runs as before through the login shell', () async {
    final r = await SshExec(client).run(
      "printf '%s|' \"a'b\" 'c\\\\d'; echo \$SHELL",
      cancel: Completer<void>().future,
    );
    expect(r.stdout, startsWith("a'b|c\\d|"));
    expect(r.stderr, isNot(contains('sbm-sid')));
  });

  test('a stop kills the command and returns at once', () async {
    final s = sleepFor();
    final r = await stop('sleep $s', s);
    expect(r.took, lessThan(SshExec.signalGrace));
    expect(r.result.mayStillRun, isFalse);
    expect(await running(s), isFalse, reason: 'SIGKILL reached it');
  });

  test(
    'a stop kills a child in a process group of its own',
    () async {
      // Job control puts the child in a group of its own: SIGKILL to the
      // command's group misses it, and sshd keeps the channel open while it
      // holds stdout — the stuck build of #1684. Still in the session.
      final s = sleepFor();
      final r = await stop("bash -c 'set -m; sleep $s & wait'", s);
      expect(r.result.mayStillRun, isFalse);
      expect(await running(s), isFalse, reason: 'killed by its session');
      expect(r.took, lessThan(SshExec.drainTimeout + SshExec.signalGrace));
    },
    timeout: const Timeout(Duration(seconds: 60)),
  );

  test(
    'a stop kills a child that let go of the output',
    () async {
      // Out of the signal's reach and holding nothing open, so the channel
      // closes at once: only the session id still finds it.
      final s = sleepFor();
      final r = await stop(
        "bash -c 'set -m; sleep $s </dev/null >/dev/null 2>&1 & wait'",
        s,
      );
      expect(r.result.mayStillRun, isFalse);
      expect(await running(s), isFalse, reason: 'killed by its session');
    },
    timeout: const Timeout(Duration(seconds: 60)),
  );

  test(
    'a stop says so when a process has left the session',
    () async {
      // `setsid -w` waits for a child in a session of its own: out of every
      // reach, so all a stop can do is not wait for it, and say so.
      final s = sleepFor();
      final r = await stop('echo started; setsid -w sleep $s', s);
      expect(r.took, lessThan(const Duration(seconds: 20)));
      expect(r.result.stdout, contains('started'));
      expect(r.result.mayStillRun, isTrue);
      expect(await running(s), isTrue);
    },
    timeout: const Timeout(Duration(seconds: 60)),
  );

  test(
    'a stop kills what runs as root through sudo',
    () async {
      final s = sleepFor();
      final r = await stop(
        "sudo -S -p '' sleep $s",
        s,
        stdin: '$sudoPassword\n',
        exec: SshExec(client, sudoPassword: () async => sudoPassword),
      );
      expect(r.result.mayStillRun, isFalse);
      expect(await running(s), isFalse);
    },
    timeout: const Timeout(Duration(seconds: 60)),
    skip: sudoPassword == null ? 'SBM_E2E_SSH_SUDO_PASSWORD not set' : null,
  );
}
