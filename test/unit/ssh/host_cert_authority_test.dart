/// Trusted host certificate authorities (#1783): which hosts a CA vouches for,
/// in `known_hosts` pattern syntax, and what dartssh2 is told for one.
library;

import 'dart:convert';
import 'dart:io';

import 'package:dartssh2/dartssh2.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/core/utils/server.dart';
import 'package:server_box/data/model/server/host_cert_authority.dart';
import 'package:server_box/data/res/store.dart';
import 'package:server_box/data/store/setting.dart';

import '../../helpers/spi_fixture.dart';
import '../../helpers/test_db.dart';

/// A real key line, from `ssh-keygen` (the fork's fixture).
const _ed25519 =
    'ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPKE1+CXgaJMCIcTuFpYsKdP'
    'TXBAm8Uyi5w1k1ugCRgX ca@example.com';

void main() {
  group('the key', () {
    test('an OpenSSH public key line is read, comment or not', () {
      final key = const HostCertAuthority(publicKey: _ed25519).key;
      expect(key, isNotNull);
      final bare = _ed25519.split(' ').take(2).join(' ');
      expect(HostCertAuthority(publicKey: '  $bare\n').key, key);
    });

    test('anything else is not a key', () {
      for (final line in [
        '',
        'ssh-ed25519',
        'ssh-ed25519 not-base64!',
        // The type outside the blob disagrees with the one inside it.
        'ssh-rsa ${_ed25519.split(' ')[1]}',
        'ssh-dss ${_ed25519.split(' ')[1]}',
      ]) {
        expect(HostCertAuthority(publicKey: line).key, isNull, reason: line);
      }
    });
  });

  group('which hosts it vouches for', () {
    bool matches(String hosts, String host, [int port = 22]) =>
        HostCertAuthority(publicKey: _ed25519, hosts: hosts).matches(host, port);

    test('`*` is every host, on any port', () {
      expect(matches('*', 'anything'), isTrue);
      expect(matches('*', '10.0.0.1', 2222), isTrue);
    });

    test('wildcards, case not considered', () {
      expect(matches('*.example.com', 'WEB.Example.com'), isTrue);
      expect(matches('*.example.com', 'example.org'), isFalse);
      expect(matches('web-?.example.com', 'web-1.example.com'), isTrue);
      expect(matches('web-?.example.com', 'web-10.example.com'), isFalse);
      expect(matches('10.0.0.*', '10.0.0.7'), isTrue);
    });

    test('a list, where `!` excludes whatever else matched', () {
      const hosts = '*.example.com, !db.example.com, 10.0.0.1';
      expect(matches(hosts, 'web.example.com'), isTrue);
      expect(matches(hosts, '10.0.0.1'), isTrue);
      expect(matches(hosts, 'db.example.com'), isFalse);
      expect(matches('!db.example.com', 'web.example.com'), isFalse);
    });

    test('another port is matched as [host]:port, as OpenSSH matches it', () {
      expect(matches('*.example.com', 'web.example.com', 2222), isFalse);
      expect(matches('[*.example.com]:2222', 'web.example.com', 2222), isTrue);
      expect(matches('[*.example.com]:2222', 'web.example.com'), isFalse);
    });
  });

  group('what dartssh2 is told', () {
    const fleet = HostCertAuthority(publicKey: _ed25519, hosts: '*.example.com');
    const broken = HostCertAuthority(publicKey: 'ssh-ed25519 nope');

    test('the keys of the authorities that vouch for the host', () {
      final trust = HostCertAuthority.trustFor(
        [fleet, broken],
        host: 'web.example.com',
        port: 22,
      );
      expect(trust!.authorities, [fleet.key]);
      expect(trust.principals, ['web.example.com']);
    });

    test('and the name it was reached by too, once', () {
      final trust = HostCertAuthority.trustFor(
        [fleet],
        host: 'web.example.com',
        port: 22,
        alsoKnownAs: ['web.example.com', 'web.vpn'],
      );
      expect(trust!.principals, ['web.example.com', 'web.vpn']);
    });

    test('nothing when none does, leaving the host to the first-use prompt',
        () {
      expect(
        HostCertAuthority.trustFor([fleet, broken], host: 'db.example.org', port: 22),
        isNull,
      );
    });
  });

  group('what a connection is given', () {
    setUp(() async {
      await openTestDb();
      getIt.registerSingleton<SettingStore>(SettingStore('setting_test'));
    });

    tearDown(() async {
      await getIt.reset();
      await closeTestDb();
    });

    /// The client [genClient] builds, against a socket that never answers:
    /// what it was configured with is all that is looked at.
    Future<SSHClient> connect({List<HostCertAuthority>? authorities}) async {
      final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      final peer = server.first;
      final spi = spiFixture(name: 'web', ip: '127.0.0.1', user: 'u', pwd: 'p');
      final client = await genClient(
        spi.copyWith(ssh: spi.ssh!.copyWith(port: server.port)),
        knownHostFingerprints: const {},
        hostCertAuthorities: authorities,
      );
      final socket = await peer;
      client.authenticated.ignore();
      client.done.ignore();
      addTearDown(() async {
        client.close();
        socket.destroy();
        await server.close();
      });
      return client;
    }

    test('an authority vouching for the host, with the host as principal',
        () async {
      const ca = HostCertAuthority(publicKey: _ed25519);
      final client = await connect(authorities: [ca]);
      expect(client.hostCertificateTrust!.authorities, [ca.key]);
      expect(client.hostCertificateTrust!.principals, ['127.0.0.1']);
    });

    test('none when no authority vouches for it', () async {
      final client = await connect(
        authorities: [const HostCertAuthority(publicKey: _ed25519, hosts: '10.*')],
      );
      expect(client.hostCertificateTrust, isNull);
    });

    test('read from the settings when not handed over', () async {
      Stores.setting.sshHostCertAuthorities.put(
        [const HostCertAuthority(publicKey: _ed25519)],
      );
      final client = await connect();
      expect(client.hostCertificateTrust, isNotNull);
    });
  });

  group('stored', () {
    setUp(() async {
      await openTestDb();
      getIt.registerSingleton<SettingStore>(SettingStore('setting_test'));
    });

    tearDown(() async {
      await getIt.reset();
      await closeTestDb();
    });

    test('the list survives a write and a read, in order', () {
      const list = [
        HostCertAuthority(publicKey: _ed25519, hosts: '*.example.com'),
        HostCertAuthority(publicKey: _ed25519),
      ];
      Stores.setting.sshHostCertAuthorities.put(list);
      expect(Stores.setting.sshHostCertAuthorities.get(), list);
    });

    test('a row with no hosts reads as every host', () {
      expect(
        HostCertAuthority.fromJson(
          jsonDecode('{"publicKey": "$_ed25519"}') as Map<String, dynamic>,
        ).hosts,
        '*',
      );
    });
  });
}
