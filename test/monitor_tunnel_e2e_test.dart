import 'dart:io';
import 'dart:typed_data';

import 'package:dartssh2/dartssh2.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/core/utils/server.dart';
import 'package:server_box/data/model/server/monitor_http_credential.dart';
import 'package:server_box/data/model/server/server_private_info.dart';
import 'package:server_box/data/model/server/ssh_credential.dart';

/// End-to-end over a live `monitor` agent: login, ticket, WebSocket, and a
/// real SSH session negotiated through it.
///
/// `monitor_tunnel_test.dart` covers the same client against a stub agent, so
/// this exists for the one thing a stub can't prove — that the real agent's
/// relay, the real sshd on the far side, and dartssh2 on this side actually
/// agree. Opt-in, following `sbm_parser`'s `ssh_e2e` convention:
///
/// ```sh
/// SBM_E2E_MONITOR_URL=http://127.0.0.1:3771 \
/// SBM_E2E_MONITOR_USER=admin \
/// SBM_E2E_MONITOR_PASSWORD=... \
/// SBM_E2E_SSH_USER=me \
/// SBM_E2E_SSH_KEY=/path/to/id_ed25519 \
/// flutter test test/monitor_tunnel_e2e_test.dart
/// ```
///
/// Credentials come from the environment, never from the repo. Silently
/// skipped when unset.
void main() {
  final env = Platform.environment;
  final url = env['SBM_E2E_MONITOR_URL'];
  final monitorUser = env['SBM_E2E_MONITOR_USER'];
  final monitorPwd = env['SBM_E2E_MONITOR_PASSWORD'];
  final sshUser = env['SBM_E2E_SSH_USER'];
  final keyPath = env['SBM_E2E_SSH_KEY'];

  final configured =
      url != null &&
      monitorUser != null &&
      monitorPwd != null &&
      sshUser != null &&
      keyPath != null;

  if (!configured) {
    test('monitor tunnel e2e (skipped: SBM_E2E_MONITOR_* unset)', () {}, skip: true);
    return;
  }

  late String privateKey;
  late Spi spi;

  setUpAll(() {
    privateKey = File(keyPath).readAsStringSync();
    spi = Spi(
      name: 'e2e',
      id: 'e2e',
      // No address of its own: the agent decides what to connect to.
      // `keyId` must be set for `genClient` to take its key-auth branch at
      // all — the `privateKey` argument only preloads the key that id names,
      // for the isolate case where the store isn't reachable.
      ssh: SshCredential(
        ip: '',
        user: sshUser,
        keyId: 'e2e-key',
        viaMonitor: true,
      ),
      monitorHttp: MonitorHttpCredential(
        addr: url,
        user: monitorUser,
        pwd: monitorPwd,
      ),
    );
  });

  /// Connects through the agent. Host key callbacks are supplied so the test
  /// never reaches the app's stores or its confirmation dialog — but the
  /// verification itself still runs, which is the point: the agent in the
  /// middle must not be able to satisfy it.
  Future<(SSHClient, String?)> connect() async {
    String? seenFingerprint;
    final client = await genClient(
      spi,
      privateKey: privateKey,
      knownHostFingerprints: const {},
      onHostKeyPrompt: (info) async {
        seenFingerprint = info.fingerprintBase64;
        return true;
      },
      onHostKeyAccepted: (_, _) {},
      timeout: const Duration(seconds: 20),
    );
    await client.authenticated;
    return (client, seenFingerprint);
  }

  test('runs a command over the agent-relayed SSH session', () async {
    final (client, fingerprint) = await connect();
    addTearDown(client.close);

    expect(
      fingerprint,
      isNotNull,
      reason: 'the app must still verify the host key itself over the tunnel',
    );

    final output = await client.run('echo tunnel-e2e-marker && id -un');
    final text = String.fromCharCodes(output);
    expect(text, contains('tunnel-e2e-marker'));
    expect(
      text,
      contains(sshUser),
      reason: 'the session must be the requested SSH account, not the agent\'s',
    );
  }, timeout: const Timeout(Duration(seconds: 60)));

  test('opens an interactive shell on a PTY', () async {
    final (client, _) = await connect();
    addTearDown(client.close);

    // What the app's terminal actually opens. Unlike `run`, this keeps the
    // channel open in both directions for the life of the session, so a relay
    // that only survives request/response traffic fails here and nowhere else.
    final session = await client.shell(
      pty: const SSHPtyConfig(width: 80, height: 24),
    );
    addTearDown(session.close);

    final seen = StringBuffer();
    final sub = session.stdout.listen(
      (chunk) => seen.write(String.fromCharCodes(chunk)),
    );
    addTearDown(sub.cancel);

    session.write(Uint8List.fromList('echo pty-e2e-marker\n'.codeUnits));
    await Future.doWhile(() async {
      if (seen.toString().contains('pty-e2e-marker')) return false;
      await Future.delayed(const Duration(milliseconds: 100));
      return true;
    }).timeout(
      const Duration(seconds: 20),
      onTimeout: () => fail('no shell output over the tunnel; saw "$seen"'),
    );

    // A resize is a channel request rather than data, so it proves the relay
    // carries the out-of-band traffic an interactive session depends on
    session.resizeTerminal(100, 30);
    session.write(Uint8List.fromList('echo pty-resized\n'.codeUnits));
    await Future.doWhile(() async {
      if (seen.toString().contains('pty-resized')) return false;
      await Future.delayed(const Duration(milliseconds: 100));
      return true;
    }).timeout(
      const Duration(seconds: 20),
      onTimeout: () => fail('shell stopped responding after a resize'),
    );
  }, timeout: const Timeout(Duration(seconds: 60)));

  test('carries bulk data without corrupting it', () async {
    final (client, _) = await connect();
    addTearDown(client.close);

    // Comfortably past the relay's 32 KiB read chunk and its 8-frame queue,
    // so both directions have to stall and resume
    const lines = 20000;
    final output = await client.run('seq 1 $lines');
    final text = String.fromCharCodes(output);
    final parsed = text
        .split('\n')
        .where((l) => l.trim().isNotEmpty)
        .map(int.parse)
        .toList();

    expect(parsed.length, lines, reason: 'no line may be dropped');
    expect(parsed.first, 1);
    expect(parsed.last, lines, reason: 'and none reordered');
  }, timeout: const Timeout(Duration(seconds: 120)));

  test('runs an SFTP session over the tunnel', () async {
    final (client, _) = await connect();
    addTearDown(client.close);

    // SFTP is a separate subsystem and by far the heaviest user of the relay,
    // so a framing or backpressure bug shows up here before anywhere else
    final sftp = await client.sftp();
    final remote = '/tmp/sbm-sftp-e2e-${DateTime.now().microsecondsSinceEpoch}';
    final payload = List<int>.generate(512 * 1024, (i) => i % 251);

    final handle = await sftp.open(
      remote,
      mode: SftpFileOpenMode.create |
          SftpFileOpenMode.write |
          SftpFileOpenMode.truncate,
    );
    await handle.writeBytes(Uint8List.fromList(payload));
    await handle.close();
    addTearDown(() async {
      try {
        await sftp.remove(remote);
      } catch (_) {
        // Best effort; the file is in /tmp either way
      }
    });

    final readBack = await (await sftp.open(remote)).readBytes();
    expect(readBack.length, payload.length, reason: 'no byte may be lost');
    expect(
      readBack,
      orderedEquals(payload),
      reason: 'and none may be reordered or altered',
    );
  }, timeout: const Timeout(Duration(seconds: 120)));

  test('forwards a local port through the tunnelled session', () async {
    final (client, _) = await connect();
    addTearDown(client.close);

    // Forwarded to the far host's own sshd: it is the one service known to be
    // listening there, since this session just came through it. The agent's
    // HTTP port would only work when the agent and sshd share a host, which
    // is exactly the case this feature exists to avoid.
    final forward = await client.forwardLocal('127.0.0.1', 22);
    addTearDown(forward.close);

    // A forward carrying real traffic gets the peer's version string without
    // sending anything first, so the read direction is proven on its own
    final response = StringBuffer();
    await for (final chunk in forward.stream) {
      response.write(String.fromCharCodes(chunk));
      if (response.toString().contains('\n')) break;
    }
    expect(response.toString(), startsWith('SSH-2.0-'));
  }, timeout: const Timeout(Duration(seconds: 60)));
}
