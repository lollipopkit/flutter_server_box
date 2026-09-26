/// Opt-in end-to-end check of the one thing the app does to a Windows server
/// before it can read anything from it: send the status script over SSH.
///
/// It was written to answer whether a hang seen in the Rust suite
/// (`crates/sbm_parser/tests/ssh_e2e.rs`) was that suite's system `ssh` or the
/// install itself. It was the install: over dartssh2, the client the app
/// actually uses, sending the real script hung in 4 of 5 attempts. The install
/// command waited for an EOF that Windows OpenSSH does not reliably deliver, so
/// anyone adding a Windows server had those odds of the app sitting there
/// forever. `sbm_parser::script::install_command` no longer waits for one.
///
/// Which makes this the regression test for it, and the reason it repeats: the
/// failure was never every time.
///
/// Configuration, from the environment or the workspace `.env`. Skipped when
/// the host is unset, and when no key `ssh -G` names can be opened — which is
/// what an unconfigured machine looks like, and the runner prints the reason
/// each identity gave.
///
/// The host value is anything the system `ssh` accepts, `~/.ssh/config` aliases
/// included — the connection parameters are read back from `ssh -G`, so this
/// file never has to name a host, a user or a key:
/// - `SBM_E2E_SSH_HOST_WINDOWS`: a Windows remote running OpenSSH server
/// - `SBM_E2E_SSH_KEY_PASSPHRASE`: only if the key `ssh -G` names is encrypted.
///   dartssh2 authenticates from a key file; its `SSHAgentHandler` is agent
///   *forwarding*, so an agent-held key is not reachable from here the way it
///   is from the system `ssh`.
@Timeout(Duration(minutes: 5))
library;

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dartssh2/dartssh2.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/data/model/app/scripts/shell_func.dart';
import 'package:server_box/data/model/server/system.dart';

import '../helpers/rust_lib_helper.dart';
import '../helpers/ssh_e2e.dart';

/// Long enough that a slow-but-working install is never called a hang, short
/// enough that a hang is not the whole test budget.
const _installTimeout = Duration(seconds: 45);

/// How many times to install. The failure is intermittent — a single green run
/// says nothing.
const _rounds = 5;

/// Async so that whether this machine *can* run the test is settled before the
/// tests are declared, which is the only place `skip:` can be decided.
///
/// The alternative — a precondition read off the environment at the top — is
/// what this file had, and it was wrong in both directions: it demanded
/// `SBM_E2E_SSH_KEY_PASSPHRASE` even for an unencrypted key, which is the
/// normal shape of a dedicated test key, and skipped the regression test for a
/// hang that shipped to users. The question is never which variables are set,
/// it is whether an identity loads — [SshE2eTarget.loadIdentities] answers that
/// per key and says why for each, so its reasons are the message rather than a
/// guess written above it.
///
/// Which message depends on where the answer came from. Nothing configured to
/// load is an opt-out and skips; a key that was tried and would not open is a
/// broken setup and fails, on the same reasoning as an unresolvable host.
Future<void> main() async {
  final host = e2eEnv('SBM_E2E_SSH_HOST_WINDOWS');
  if (host == null) {
    test(
      'windows install e2e',
      () {},
      skip: 'SBM_E2E_SSH_HOST_WINDOWS not set (environment or .env)',
    );
    return;
  }

  // A host that is named and cannot be resolved is a typo, not an opt-out:
  // somebody asked for this test and it is not going to run. That is a
  // failure.
  final resolved = await SshE2eTarget.resolve(host);
  final target = resolved.target;
  if (target == null) {
    test('windows install e2e', () {
      fail(resolved.problem ?? 'ssh -G could not resolve $host');
    });
    return;
  }

  final loaded = target.loadIdentities();
  final identities = loaded.pairs;
  if (identities.isEmpty) {
    // Same rule as the host: a key that was tried and would not open is a
    // broken setup, not an opt-out. Skipping it means a rotated passphrase
    // leaves the suite green with this regression no longer run, which is what
    // the rewrite above set out to stop.
    if (loaded.failures.isNotEmpty) {
      test('windows install e2e', () {
        fail(
          'every identity ssh -G named for $host failed to load: '
          '${loaded.failures.join('; ')}',
        );
      });
      return;
    }
    test(
      'windows install e2e',
      () {},
      skip: loaded.reasons.isEmpty
          ? 'ssh -G named no identity files for $host'
          : 'no identity ssh -G named is available here: '
                '${loaded.reasons.join('; ')}',
    );
    return;
  }

  // Nullable rather than `late`: when the setup fails there is nothing to tear
  // down, and a LateInitializationError there hides the reason it failed
  SSHClient? client;
  var remoteDir = '';
  late String installCmd;

  setUpAll(() async {
    await initRustLibForTest();

    final connected = await connectSshE2e(target, identities);
    client = connected;

    // %TEMP% belongs to the account that authenticated, which is not
    // necessarily the one running these tests
    final temp = await execSshE2e(
      connected,
      r'powershell -NoProfile -Command "Write-Output $env:TEMP"',
      null,
    );
    expect(temp.exitCode, 0, reason: 'could not read %TEMP%: ${temp.stderr}');
    remoteDir = '${temp.stdout.trim()}\\server_box_dart_e2e';

    installCmd = ShellFuncManager.getInstallShellCmd(
      'dart-e2e',
      systemType: SystemType.windows,
      customDir: remoteDir,
    );
  });

  tearDownAll(() async {
    final connected = client;
    if (connected == null) return;
    await execSshE2e(
      connected,
      'powershell -NoProfile -Command "Remove-Item -Recurse -Force '
      r'-ErrorAction SilentlyContinue ' "'$remoteDir'\"",
      null,
    );
    connected.close();
  });

  test('the app installs the windows status script, every time', () async {
    final script = ShellFuncManager.allScript(systemType: SystemType.windows);
    final bytes = Uint8List.fromList(
      utf8.encode(
        ShellFuncManager.installPayload(script, systemType: SystemType.windows),
      ),
    );
    // ignore: avoid_print
    print('script is ${bytes.length} bytes; installing $_rounds times');

    final slow = <String>[];
    for (var round = 1; round <= _rounds; round++) {
      final started = DateTime.now();
      try {
        final result = await execSshE2e(
          client!,
          installCmd,
          bytes,
        ).timeout(_installTimeout);
        final took = DateTime.now().difference(started);
        // ignore: avoid_print
        print('round $round: exit ${result.exitCode} in ${took.inMilliseconds}ms');
        expect(result.exitCode, 0, reason: 'round $round: ${result.stderr}');
      } on TimeoutException {
        slow.add('round $round');
      }
    }

    expect(
      slow,
      isEmpty,
      reason:
          'the install hung in ${slow.length}/$_rounds rounds — the same '
          'failure the Rust suite sees, so it is the remote and not the ssh '
          'client, and adding a Windows server in the app can hang too',
    );
  });

  test('a stdin payload several times the script also gets through', () async {
    // 32 KiB, seven times the script. Not larger, and this is the ceiling
    // rather than a round number: over dartssh2 this same install is 3/3 at 4,
    // 16 and 32 KiB (~190ms each), 2/3 at 64 KiB and 0/3 at 128 and 256 KiB,
    // while the system `ssh` carries 256 KiB every time. So there is a second
    // limit above this one that belongs to the client, not to the install
    // command — nothing here can grow the script past a few KiB, but a test
    // that asserted past the wall would only be flaky about someone else's bug.
    final body = List.filled(512, 'x' * 63).join('\n');
    final bytes = Uint8List.fromList(
      utf8.encode(
        ShellFuncManager.installPayload(body, systemType: SystemType.windows),
      ),
    );

    final started = DateTime.now();
    final result = await execSshE2e(client!, installCmd, bytes).timeout(
      _installTimeout,
      onTimeout: () => throw TimeoutException(
        'the install hung on 32 KiB',
        _installTimeout,
      ),
    );
    // ignore: avoid_print
    print(
      '32 KiB: exit ${result.exitCode} in '
      '${DateTime.now().difference(started).inMilliseconds}ms',
    );
    expect(result.exitCode, 0, reason: result.stderr);
  });
}
