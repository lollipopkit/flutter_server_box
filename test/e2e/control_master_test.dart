import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/core/ssh/client.dart';
import 'package:server_box/data/model/server/server_private_info.dart';
import 'package:server_box/data/model/server/ssh_credential.dart';

import '../helpers/rust_lib_helper.dart';

/// A server reached through a jump whose OpenSSH master carries it.
///
/// Opt-in, against real hosts: a jump at `SBM_E2E_MUX_JUMP` (`host:port`)
/// with an OpenSSH master running for `SBM_E2E_MUX_USER` at
/// `SBM_E2E_MUX_CONTROL_PATH` (a `ControlPath`, `%C` included), started with
/// `ssh -o ControlMaster=yes -o ControlPath=… -fN`; a target at
/// `SBM_E2E_MUX_TARGET` that only the jump can reach, whose `hostname` is that
/// name, authorising a key in the agent at `SBM_E2E_MUX_AGENT`.
///
/// The jump is given no credentials: only its master can carry the target.
void main() {
  final env = Platform.environment;
  final jumpAt = env['SBM_E2E_MUX_JUMP'];
  final user = env['SBM_E2E_MUX_USER'];
  final controlPath = env['SBM_E2E_MUX_CONTROL_PATH'];
  final targetHost = env['SBM_E2E_MUX_TARGET'];
  final agent = env['SBM_E2E_MUX_AGENT'];
  final missing = [jumpAt, user, controlPath, targetHost, agent].contains(null);

  group('through an OpenSSH master', skip: missing ? 'no e2e hosts' : null, () {
    setUpAll(initRustLibForTest);

    Spi jump(String path) {
      final at = Uri.parse('ssh://$jumpAt');
      return Spi(
        name: 'jump',
        id: 'jump',
        ssh: SshCredential(
          ip: at.host,
          port: at.port,
          user: user!,
          controlPath: path,
        ),
      );
    }

    Future<String> hostnameVia(Spi j) async {
      final client = await genClient(
        Spi(
          name: 'target',
          id: 'target',
          ssh: SshCredential(
            ip: targetHost!,
            user: user!,
            identityAgent: agent,
            jumpIds: const ['jump'],
          ),
        ),
        jumpSpisById: {'jump': j},
        knownHostFingerprints: const {},
        onHostKeyPrompt: (_) async => true,
        onHostKeyAccepted: (_, _) {},
      );
      try {
        return utf8.decode(await client.run('hostname')).trim();
      } finally {
        client.close();
      }
    }

    test('the master opens the stream; the jump needs no session', () async {
      expect(await hostnameVia(jump(controlPath!)), targetHost);
    });

    test('streams side by side', () async {
      final j = jump(controlPath!);
      expect(
        await Future.wait([hostnameVia(j), hostnameVia(j)]),
        [targetHost, targetHost],
      );
    });

    test('no master there: the jump is connected to as usual', () async {
      // Which, with no credentials for it, cannot succeed.
      await expectLater(
        hostnameVia(jump('$controlPath-none')),
        throwsA(anything),
      );
    });
  });
}
