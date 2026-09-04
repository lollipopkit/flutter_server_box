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
/// Configuration (skipped when unset), from the environment or the workspace
/// `.env`. The value is anything the system `ssh` accepts, `~/.ssh/config`
/// aliases included — the connection parameters are read back from `ssh -G`,
/// so this file never has to name a host, a user or a key:
/// - `SBM_E2E_SSH_HOST_WINDOWS`: a Windows remote running OpenSSH server
/// - `SBM_E2E_SSH_KEY_PASSPHRASE`: only if the key `ssh -G` names is encrypted.
///   dartssh2 authenticates from a key file; its `SSHAgentHandler` is agent
///   *forwarding*, so an agent-held key is not reachable from here the way it
///   is from the system `ssh`.
@Timeout(Duration(minutes: 5))
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dartssh2/dartssh2.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/data/model/app/scripts/shell_func.dart';
import 'package:server_box/data/model/server/system.dart';

import 'rust_lib_helper.dart';

/// Long enough that a slow-but-working install is never called a hang, short
/// enough that a hang is not the whole test budget.
const _installTimeout = Duration(seconds: 45);

/// How many times to install. The failure is intermittent — a single green run
/// says nothing.
const _rounds = 5;

String? _env(String key) {
  final fromEnv = Platform.environment[key];
  if (fromEnv != null && fromEnv.isNotEmpty) return fromEnv;

  // Workspace-root `.env`, the same file the Rust suite reads. Parsed rather
  // than sourced: only this one key matters and nothing here should inherit
  // the rest of that file.
  final dotenv = File('.env');
  if (!dotenv.existsSync()) return null;
  for (final line in dotenv.readAsLinesSync()) {
    final trimmed = line.trim();
    if (!trimmed.startsWith('$key=')) continue;
    final value = trimmed.substring(key.length + 1).trim().replaceAll(
      RegExp(r'''^["']|["']$'''),
      '',
    );
    if (value.isNotEmpty) return value;
  }
  return null;
}

/// What the system `ssh` would use for [host], so an alias in `~/.ssh/config`
/// works here as it does there. dartssh2 does not read that file.
class _SshTarget {
  _SshTarget({
    required this.hostname,
    required this.port,
    required this.user,
    required this.identityFiles,
  });

  final String hostname;
  final int port;
  final String user;
  final List<String> identityFiles;

  static Future<_SshTarget?> resolve(String host) async {
    final result = await Process.run('ssh', ['-G', host]);
    if (result.exitCode != 0) return null;

    String? hostname, user;
    var port = 22;
    final identities = <String>[];
    for (final line in const LineSplitter().convert(result.stdout as String)) {
      final space = line.indexOf(' ');
      if (space < 0) continue;
      final key = line.substring(0, space);
      final value = line.substring(space + 1).trim();
      switch (key) {
        case 'hostname':
          hostname = value;
        case 'user':
          user = value;
        case 'port':
          port = int.tryParse(value) ?? 22;
        case 'identityfile':
          identities.add(
            value.startsWith('~')
                ? value.replaceFirst('~', Platform.environment['HOME'] ?? '~')
                : value,
          );
      }
    }
    if (hostname == null || user == null) return null;
    return _SshTarget(
      hostname: hostname,
      port: port,
      user: user,
      identityFiles: identities,
    );
  }

  /// The first identity that loads, and why each of the others did not.
  ///
  /// Decrypts with `SBM_E2E_SSH_KEY_PASSPHRASE` when one is set. Nothing
  /// prompts: a test that blocks on a passphrase is the hang this file exists
  /// to measure.
  ///
  /// **[reasons] is the point of the return type.** This used to swallow every
  /// exception and answer an empty list, so a blank passphrase, a wrong one, a
  /// key format the fork does not read and a path that is not there all failed
  /// identically — and the failure the runner printed was a guess written into
  /// the `reason:` of an `expect`. Every one of those has a different fix, and
  /// the loader is the only place that knows which it was.
  ({List<SSHKeyPair> pairs, List<String> reasons}) loadIdentities() {
    final passphrase = _env('SBM_E2E_SSH_KEY_PASSPHRASE');
    final reasons = <String>[];
    for (final path in identityFiles) {
      // The basename, never the path: `ssh -G` resolves `~`, and a home
      // directory is a username. This text ends up in CI logs.
      final name = path.split(Platform.pathSeparator).last;
      final file = File(path);
      if (!file.existsSync()) {
        reasons.add('$name: not on this machine');
        continue;
      }
      final pem = file.readAsStringSync();
      final encrypted = SSHKeyPair.isEncryptedPem(pem);
      if (encrypted && passphrase == null) {
        // The case that cost an afternoon: `.env` carried the key with an
        // empty value, which `_env` reads as unset — correctly — and the
        // failure then blamed the identity file.
        reasons.add(
          '$name: encrypted, and SBM_E2E_SSH_KEY_PASSPHRASE is empty or unset',
        );
        continue;
      }
      try {
        final pairs = SSHKeyPair.fromPem(pem, encrypted ? passphrase : null);
        if (pairs.isNotEmpty) return (pairs: pairs, reasons: reasons);
        reasons.add('$name: parsed, but carried no key pair');
      } catch (e) {
        // The message, not the object: a wrong passphrase and a format this
        // fork cannot read both arrive here and read differently.
        reasons.add('$name: $e');
      }
    }
    return (pairs: const [], reasons: reasons);
  }
}

Future<SSHClient> _connect(_SshTarget target, List<SSHKeyPair> identities) async {
  final socket = await SSHSocket.connect(
    target.hostname,
    target.port,
    timeout: const Duration(seconds: 10),
  );
  final client = SSHClient(
    socket,
    username: target.user,
    identities: identities,
    // The app pins host keys; this test is about the data path, and asking it
    // to also carry a known-hosts store would only give it a second way to fail
    disableHostkeyVerification: true,
  );
  await client.authenticated;
  return client;
}

/// Run [command], write [input] to its stdin, close it, and collect what came
/// back. The shape the app uses in `ServerNotifier`: `stdin.add` then
/// `stdin.close`, with nothing read until the command is done.
Future<({int? exitCode, String stdout, String stderr})> _exec(
  SSHClient client,
  String command,
  Uint8List? input,
) async {
  final session = await client.execute(command);
  final stdout = <int>[];
  final stderr = <int>[];
  final collected = Future.wait([
    session.stdout.forEach(stdout.addAll),
    session.stderr.forEach(stderr.addAll),
  ]);
  if (input != null) {
    session.stdin.add(input);
    await session.stdin.close();
  }
  await session.done;
  await collected;
  return (
    exitCode: session.exitCode,
    stdout: utf8.decode(stdout, allowMalformed: true),
    stderr: utf8.decode(stderr, allowMalformed: true),
  );
}

void main() {
  final host = _env('SBM_E2E_SSH_HOST_WINDOWS');
  if (host == null) {
    test('windows install e2e', () {
      // ignore: avoid_print
      print(
        'skipping: SBM_E2E_SSH_HOST_WINDOWS not set (environment or .env)',
      );
    }, skip: 'SBM_E2E_SSH_HOST_WINDOWS not set');
    return;
  }

  // Nullable rather than `late`: when the setup fails there is nothing to tear
  // down, and a LateInitializationError there hides the reason it failed
  SSHClient? client;
  var remoteDir = '';
  late String installCmd;

  setUpAll(() async {
    await initRustLibForTest();

    final target = await _SshTarget.resolve(host);
    expect(target, isNotNull, reason: 'ssh -G could not resolve the host');
    final loaded = target!.loadIdentities();
    final identities = loaded.pairs;
    expect(
      identities,
      isNotEmpty,
      reason: loaded.reasons.isEmpty
          ? 'ssh -G named no identity files for this host'
          : 'no identity ssh -G named could be loaded:\n'
                '  ${loaded.reasons.join('\n  ')}',
    );

    final connected = await _connect(target, identities);
    client = connected;

    // %TEMP% belongs to the account that authenticated, which is not
    // necessarily the one running these tests
    final temp = await _exec(
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
    await _exec(
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
        final result = await _exec(
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
    final result = await _exec(client!, installCmd, bytes).timeout(
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
