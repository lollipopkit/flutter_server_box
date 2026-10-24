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
      final key = const HostCertAuthority(publicKey: _ed25519, hosts: '*').key;
      expect(key, isNotNull);
      final bare = _ed25519.split(' ').take(2).join(' ');
      expect(HostCertAuthority(publicKey: '  $bare\n', hosts: '*').key, key);
    });

    test('anything else is not a key', () {
      for (final line in [
        '',
        'ssh-ed25519',
        'ssh-ed25519 not-base64!',
        // The type outside the blob disagrees with the one inside it.
        'ssh-rsa ${_ed25519.split(' ')[1]}',
        'ssh-dss ${_ed25519.split(' ')[1]}',
        // Cut short when pasted: the type is whole, the key is not.
        'ssh-ed25519 ${_ed25519.split(' ')[1].substring(0, 24)}',
      ]) {
        expect(HostCertAuthority(publicKey: line, hosts: '*').key, isNull,
            reason: line);
      }
    });
  });

  group('what is pasted', () {
    test('a whole known_hosts line brings its hosts', () {
      final ca = HostCertAuthority.parse(
        '@cert-authority *.example.com,!db.example.com $_ed25519',
        hosts: '*',
      );
      expect(ca.hosts, '*.example.com,!db.example.com');
      expect(ca.key, isNotNull);
      expect(ca.type, 'ssh-ed25519');
      expect(ca.comment, 'ca@example.com');
    });

    test('a key line alone takes the hosts given', () {
      final ca = HostCertAuthority.parse('  $_ed25519 ', hosts: ' 10.0.0.* ');
      expect(ca.publicKey, _ed25519);
      expect(ca.hosts, '10.0.0.*');
    });

    test('the same key for the same hosts is the same, whatever the comment',
        () {
      const a = HostCertAuthority(publicKey: _ed25519, hosts: '*');
      final b = HostCertAuthority(
        publicKey: _ed25519.replaceAll('ca@example.com', 'other'),
        hosts: '*',
      );
      expect(a.sameAs(b), isTrue);
      expect(a.sameAs(const HostCertAuthority(publicKey: _ed25519, hosts: '10.*')),
          isFalse);
    });
  });

  group('which hosts it vouches for', () {
    bool matches(String hosts, String host, [int port = 22]) =>
        HostCertAuthority(publicKey: _ed25519, hosts: hosts).matches(host, port);

    test('no hosts is none, as a `@cert-authority` line without them is', () {
      expect(matches('', 'anything'), isFalse);
      expect(matches(' , ', 'anything'), isFalse);
      expect(
        const HostCertAuthority(publicKey: _ed25519, hosts: ' ').hasHosts,
        isFalse,
      );
    });

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
    const broken = HostCertAuthority(publicKey: 'ssh-ed25519 nope', hosts: '*');

    test('the keys of the authorities that vouch for the host', () {
      final trust = HostCertAuthority.trustFor(
        [fleet, broken],
        host: 'web.example.com',
        port: 22,
      );
      expect(trust!.authorities, [fleet.key]);
      expect(trust.principals, ['web.example.com']);
    });

    test('and the host as configured, when another was dialled', () {
      final trust = HostCertAuthority.trustFor(
        [fleet],
        host: 'web.example.com',
        port: 22,
        alsoKnownAs: ['WEB.example.com', '10.0.0.5'],
      );
      expect(trust!.principals, ['web.example.com', '10.0.0.5']);
    });

    test('the host lower-cased, as OpenSSH checks principals', () {
      final trust = HostCertAuthority.trustFor(
        [fleet],
        host: 'Web.Example.com',
        port: 22,
      );
      expect(trust!.principals, ['web.example.com']);
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
    /// what it was configured with is all that is looked at. With [viaAlter],
    /// the configured address refuses and `alterUrl` is what is dialled.
    Future<SSHClient> connect({
      List<HostCertAuthority>? authorities,
      bool viaAlter = false,
      Map<String, String> pins = const {},
    }) async {
      final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      final peer = server.first;
      final spi = spiFixture(
        name: 'web',
        id: 'web',
        ip: '127.0.0.1',
        user: 'u',
        pwd: 'p',
      );
      final ssh = viaAlter
          ? spi.ssh!.copyWith(
              port: await _closedPort(),
              alterUrl: 'u@localhost:${server.port}',
            )
          : spi.ssh!.copyWith(port: server.port);
      final client = await genClient(
        spi.copyWith(ssh: ssh),
        knownHostFingerprints: pins,
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
      const ca = HostCertAuthority(publicKey: _ed25519, hosts: '*');
      final client = await connect(authorities: [ca]);
      expect(client.hostCertificateTrust!.authorities, [ca.key]);
      expect(client.hostCertificateTrust!.principals, ['127.0.0.1']);
    });

    test('with an authority, certificates are proposed before any key',
        () async {
      final client =
          await connect(
        authorities: [const HostCertAuthority(publicKey: _ed25519, hosts: '*')],
      );
      final offered = client.algorithms.hostkey;
      final firstKey = offered.indexWhere((t) => !t.isCertificate);
      // At least one certificate ahead, or the checks below say nothing.
      expect(firstKey, greaterThan(0));
      expect(offered.take(firstKey).every((t) => t.isCertificate), isTrue);
      expect(offered.skip(firstKey).any((t) => t.isCertificate), isFalse);
    });

    test('a key pinned for the host is proposed first', () async {
      final client = await connect(pins: {'web::rsa-sha2-512': 'SHA256:x'});
      expect(client.algorithms.hostkey.take(2).map((t) => t.name), [
        'rsa-sha2-512-cert-v01@openssh.com',
        'rsa-sha2-512',
      ]);
    });

    test('through alterUrl, scoped to and checked against the host dialled',
        () async {
      final client = await connect(
        viaAlter: true,
        authorities: [
          // Vouches for the configured address only: not for the one dialled.
          const HostCertAuthority(publicKey: _ed25519, hosts: '127.0.0.1'),
          HostCertAuthority(publicKey: _ed25519.replaceAll('ca@', 'b@'),
              hosts: 'localhost,[localhost]:*'),
        ],
      );
      // The machine is named either way; the authorities are the dialled
      // host's alone.
      expect(client.hostCertificateTrust!.principals, ['localhost', '127.0.0.1']);
      expect(client.hostCertificateTrust!.authorities, hasLength(1));
    });

    test('none when no authority vouches for it', () async {
      final client = await connect(
        authorities: [const HostCertAuthority(publicKey: _ed25519, hosts: '10.*')],
      );
      expect(client.hostCertificateTrust, isNull);
    });

    test('read from the settings when not handed over', () async {
      Stores.setting.sshHostCertAuthorities.put(
        [const HostCertAuthority(publicKey: _ed25519, hosts: '*')],
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
        HostCertAuthority(publicKey: _ed25519, hosts: '*'),
      ];
      Stores.setting.sshHostCertAuthorities.put(list);
      expect(Stores.setting.sshHostCertAuthorities.get(), list);
    });

    test('a malformed row is dropped, not the list', () {
      Stores.setting.sshHostCertAuthorities.put(
        const [HostCertAuthority(publicKey: _ed25519, hosts: '*')],
      );
      // As a sync might write it: a row without a key beside a good one.
      final raw = Stores.setting.sshHostCertAuthorities.store
          .get(Stores.setting.sshHostCertAuthorities.key) as List;
      Stores.setting.sshHostCertAuthorities.store.set(
        Stores.setting.sshHostCertAuthorities.key,
        [{'hosts': '*'}, ...raw],
      );
      expect(Stores.setting.sshHostCertAuthorities.get(),
          [const HostCertAuthority(publicKey: _ed25519, hosts: '*')]);
    });

    test('a row with no hosts vouches for none, not for all', () {
      final ca = HostCertAuthority.fromJson(
        jsonDecode('{"publicKey": "$_ed25519"}') as Map<String, dynamic>,
      );
      expect(ca.hasHosts, isFalse);
      expect(ca.matches('anything', 22), isFalse);
    });
  });
}

/// A port nothing listens on: bound, then let go.
Future<int> _closedPort() async {
  final socket = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
  final port = socket.port;
  await socket.close();
  return port;
}
