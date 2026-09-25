import 'package:fl_lib/fl_lib.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/data/model/server/pve_config.dart';
import 'package:server_box/data/model/server/server_private_info.dart';
import 'package:server_box/data/model/server/ssh_credential.dart';
import 'package:server_box/data/res/store.dart';
import 'package:server_box/data/store/pve.dart';
import 'package:server_box/data/store/server.dart';

import '../../helpers/test_db.dart';

const _server = Spi(
  id: 'pve-1',
  name: 'pve',
  ssh: SshCredential(ip: '10.0.0.5', user: 'root', port: 22),
);

const _token = PveConfig(
  addr: 'https://localhost:8006',
  auth: PveAuth.token,
  tokenId: 'root@pam!serverbox',
  tokenSecret: 'aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee',
  certSha256:
      '9c1185a5c5e9fc54612808977ee8f548b2258d31ddadef8e3b1e1b06a1a1e2b7',
);

/// `server_pve`: a child of `server`, stamped through it and cascading with it.
void main() {
  setUp(() async {
    await openTestDb();
    if (!getIt.isRegistered<ServerStore>()) {
      getIt.registerSingleton<ServerStore>(ServerStore());
    }
    if (!getIt.isRegistered<PveStore>()) {
      getIt.registerSingleton<PveStore>(PveStore());
    }
    Stores.server.dropCache();
    Stores.server.put(_server);
  });

  tearDown(closeTestDb);

  int serverStamp() => Stores.server.timestamps[_server.id]!;

  test('a configuration survives the table', () {
    Stores.pve.put(_server.id, _token);
    expect(Stores.pve.fetch(_server.id), _token);
    expect(Stores.pve.fetchAll(), {_server.id: _token});

    const pwd = PveConfig(addr: 'https://h:8006', pwd: 'p');
    Stores.pve.put(_server.id, pwd);
    expect(Stores.pve.fetch(_server.id), pwd);
  });

  test('the auth method is stored by name', () {
    Stores.pve.put(_server.id, _token);
    final row = SqliteDb.instance
        .select('SELECT auth FROM server_pve;')
        .single;
    expect(row['auth'], 'token');
  });

  test('a change stamps the server, and writing the same thing does not', () async {
    final before = serverStamp();
    await Future<void>.delayed(const Duration(milliseconds: 2));

    Stores.pve.put(_server.id, _token);
    final afterPut = serverStamp();
    expect(afterPut, greaterThan(before));

    await Future<void>.delayed(const Duration(milliseconds: 2));
    Stores.pve.put(_server.id, _token);
    expect(serverStamp(), afterPut, reason: 'nothing changed');

    await Future<void>.delayed(const Duration(milliseconds: 2));
    Stores.pve.remove(_server.id);
    expect(serverStamp(), greaterThan(afterPut));
    expect(Stores.pve.fetch(_server.id), isNull);
  });

  test('deleting the server takes the row with it', () {
    Stores.pve.put(_server.id, _token);

    Stores.server.deleteById(_server.id);

    expect(Stores.pve.fetchAll(), isEmpty);
  });

  test('renaming the server id carries the row across', () {
    Stores.pve.put(_server.id, _token);

    Stores.server.rename(_server, _server.copyWith(id: 'pve-2'));

    expect(Stores.pve.fetch('pve-1'), isNull);
    expect(Stores.pve.fetch('pve-2'), _token);
  });

  test('a restore entry for a server not here is skipped', () {
    expect(Stores.pve.restoreOne('ghost', _token.toJson()), isFalse);
    expect(Stores.pve.fetchAll(), isEmpty);
  });

  test('an unreadable restore entry loses PVE, not the restore', () {
    Stores.pve.put(_server.id, _token);

    expect(Stores.pve.restoreOne(_server.id, {'auth': 'token'}), isTrue);

    expect(Stores.pve.fetch(_server.id), isNull);
  });

  group('PveConfig', () {
    test('toString names neither secret', () {
      const both = PveConfig(
        addr: 'https://h:8006',
        pwd: 'hunter2',
        tokenId: 'root@pam!sb',
        tokenSecret: 'the-secret',
      );
      expect('$both', isNot(contains('hunter2')));
      expect('$both', isNot(contains('the-secret')));
      expect('$both', contains('root@pam!sb'));
    });

    test('an unknown auth name reads as a password login', () {
      final cfg = PveConfig.fromJson({'addr': 'https://h', 'auth': 'ticket'});
      expect(cfg.auth, PveAuth.password);
    });

    test('the token id pattern is what PVE accepts', () {
      const ok = [
        'root@pam!serverbox',
        'monitor@pve!app-1',
        'svc.user@ldap_corp!t.2',
      ];
      const bad = [
        'root@pam',
        'root!token',
        '@pam!token',
        'root@pam!',
        'root@pam!1token',
        'root@pam!tok en',
        'root@pam!a=b',
      ];
      for (final id in ok) {
        expect(PveConfig.tokenIdPattern.hasMatch(id), isTrue, reason: id);
      }
      for (final id in bad) {
        expect(PveConfig.tokenIdPattern.hasMatch(id), isFalse, reason: id);
      }
    });

    group('a server record from an import or a share', () {
      test('carries it as `pve` beside its own fields', () {
        final record = {
          ..._server.toJson(),
          'pve': _token.toJson(),
        };
        expect(PveConfig.fromServerRecord(record), _token);
      });

      test('from an older build, inside `custom`', () {
        final record = {
          ..._server.toJson(),
          'custom': {
            'pveAddr': 'https://10.0.0.9:8006',
            'pveIgnoreCert': true,
            'pvePwd': 'p',
          },
        };
        // No PVE password: this server's SSH logs in with a password, and
        // that is what a PVE login sends.
        expect(
          PveConfig.fromServerRecord(record),
          const PveConfig(addr: 'https://10.0.0.9:8006'),
        );
        final keyed = {
          ...record,
          'ssh': const SshCredential(ip: '10.0.0.5', keyId: 'k'),
        };
        expect(
          PveConfig.fromServerRecord(keyed),
          const PveConfig(addr: 'https://10.0.0.9:8006', pwd: 'p'),
        );
      });

      test('an empty or missing address is none', () {
        expect(PveConfig.fromServerRecord(_server.toJson()), isNull);
        expect(
          PveConfig.fromServerRecord({
            'custom': {'pveAddr': ' ', 'pvePwd': 'p'},
          }),
          isNull,
        );
      });
    });
  });

  group('legacy fields', () {
    Map<String, Object?> record({String? keyId, bool flat = false}) {
      const custom = {'pveAddr': 'https://h:8006', 'pvePwd': 'pve-pw'};
      if (flat) {
        return {'ip': '10.0.0.1', 'pubKeyId': ?keyId, 'custom': custom};
      }
      return {
        'ssh': {'ip': '10.0.0.1', 'pubKeyId': ?keyId},
        'custom': custom,
      };
    }

    test('the PVE password is read only where SSH uses a key', () {
      expect(PveConfig.fromLegacyRecord(record(keyId: 'k'))?.pwd, 'pve-pw');
      expect(
        PveConfig.fromLegacyRecord(record(keyId: 'k', flat: true))?.pwd,
        'pve-pw',
        reason: 'the pre-v3 flat layout',
      );
      expect(PveConfig.fromLegacyRecord(record())?.pwd, isNull);
      expect(PveConfig.fromLegacyRecord(record())?.addr, 'https://h:8006');
    });

    test('written the way an older build reads them', () {
      expect(_token.toLegacyCustom(), {
        'pveAddr': 'https://localhost:8006',
        'pveIgnoreCert': true,
      });
      expect(
        const PveConfig(addr: 'https://h:8006', pwd: 'p').toLegacyCustom(),
        {'pveAddr': 'https://h:8006', 'pveIgnoreCert': false, 'pvePwd': 'p'},
      );
    });

    test('merged onto what is here, never replacing it', () {
      const legacy = PveConfig(addr: 'https://localhost:8006');
      expect(PveConfig.mergeLegacy(_token, legacy), _token);
      expect(PveConfig.mergeLegacy(null, legacy), legacy);

      final moved = PveConfig.mergeLegacy(
        _token,
        const PveConfig(addr: 'https://10.0.0.9:8006'),
      );
      expect(moved.addr, 'https://10.0.0.9:8006');
      expect(moved.auth, PveAuth.token);
      expect(moved.certSha256, isNull, reason: 'a pin names one address');

      const pwd = PveConfig(addr: 'https://h:8006', pwd: 'old');
      expect(
        PveConfig.mergeLegacy(
          pwd,
          const PveConfig(addr: 'https://h:8006', pwd: 'new'),
        ).pwd,
        'new',
      );
    });
  });

  test('a change is announced, and writing the same is not one', () async {
    var events = 0;
    final sub = Stores.pve.watch().listen((_) => events++);
    addTearDown(sub.cancel);

    Stores.pve.put(_server.id, _token);
    await Future<void>.delayed(Duration.zero);
    expect(events, 1);

    Stores.pve.put(_server.id, _token);
    await Future<void>.delayed(Duration.zero);
    expect(events, 1);

    Stores.pve.remove(_server.id);
    await Future<void>.delayed(Duration.zero);
    expect(events, 2);
  });
}
