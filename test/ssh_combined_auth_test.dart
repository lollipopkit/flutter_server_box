import 'dart:io';

import 'package:dartssh2/dartssh2.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/core/utils/server.dart';
import 'package:server_box/data/model/server/server_private_info.dart';

import 'helpers/spi_fixture.dart';

void main() {
  group('SSH client authentication configuration', () {
    test('enables public key and password authentication together', () async {
      final client = await _createClient(
        spiFixture(
          name: 'combined-auth',
          ip: '127.0.0.1',
          user: 'tester',
          pwd: 'account-password',
          keyId: 'test-key',
        ),
        privateKey: _testPrivateKey,
      );

      expect(client.identities, isNotEmpty);
      expect(client.onPasswordRequest, isNotNull);
      expect(await client.onPasswordRequest!(), 'account-password');
    });

    test('keeps key-only authentication password-free', () async {
      final client = await _createClient(
        spiFixture(
          name: 'key-only',
          ip: '127.0.0.1',
          user: 'tester',
          pwd: '',
          keyId: 'test-key',
        ),
        privateKey: _testPrivateKey,
      );

      expect(client.identities, isNotEmpty);
      expect(client.onPasswordRequest, isNull);
    });

    test('keeps password-only authentication unchanged', () async {
      final client = await _createClient(
        spiFixture(
          name: 'password-only',
          ip: '127.0.0.1',
          user: 'tester',
          pwd: 'account-password',
        ),
      );

      expect(client.identities, isNull);
      expect(client.onPasswordRequest, isNotNull);
      expect(await client.onPasswordRequest!(), 'account-password');
    });
  });
}

Future<SSHClient> _createClient(Spi spi, {String? privateKey}) async {
  final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
  final peerFuture = server.first;
  final client = await genClient(
    spi.copyWith(ssh: spi.ssh!.copyWith(port: server.port)),
    privateKey: privateKey,
    knownHostFingerprints: const {},
  );
  final peer = await peerFuture;

  client.authenticated.ignore();
  client.done.ignore();
  addTearDown(() async {
    client.close();
    peer.destroy();
    await server.close();
  });
  return client;
}

final String _testPrivateKey = File(
  'packages/dartssh2/test/fixtures/ssh-ed25519/id_ed25519',
).readAsStringSync();
