import 'package:fl_lib/fl_lib.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/data/model/server/pve_config.dart';
import 'package:server_box/data/model/server/server_private_info.dart';
import 'package:server_box/data/model/server/ssh_credential.dart';
import 'package:server_box/data/store/pve.dart';
import 'package:server_box/data/store/server.dart';
import 'package:server_box/data/store/stores.dart';

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
    if (!getIt.isRegistered<PveStore>()) {
      getIt.registerSingleton<PveStore>(PveStore());
    }
    if (!getIt.isRegistered<ServerStore>()) {
      getIt.registerSingleton<ServerStore>(ServerStore(pve: Stores.pve));
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

  test('an unreadable restore entry is skipped, not read as a removal', () {
    Stores.pve.put(_server.id, _token);

    for (final bad in <Object>[
      {'auth': 'token'},
      'not an object',
      42,
    ]) {
      expect(Stores.pve.restoreOne(_server.id, bad), isFalse, reason: '$bad');
      expect(Stores.pve.fetch(_server.id), _token, reason: '$bad');
    }

    // What does say "none".
    expect(Stores.pve.restoreOne(_server.id, const {}), isTrue);
    expect(Stores.pve.fetch(_server.id), isNull);
  });

  test('a restore does not stamp the server', () async {
    final before = serverStamp();
    await Future<void>.delayed(const Duration(milliseconds: 2));

    expect(Stores.pve.restoreOne(_server.id, _token.toJson()), isTrue);
    expect(Stores.pve.fetch(_server.id), _token);
    expect(serverStamp(), before, reason: 'set by the server merge alone');

    await Future<void>.delayed(const Duration(milliseconds: 2));
    expect(Stores.pve.restoreOne(_server.id, null), isTrue);
    expect(Stores.pve.fetch(_server.id), isNull);
    expect(serverStamp(), before);
  });

  test('a cascade or a rename through the server store is announced', () async {
    var events = 0;
    final sub = Stores.pve.watch().listen((_) => events++);
    addTearDown(sub.cancel);

    Stores.pve.put(_server.id, _token);
    await Future<void>.delayed(Duration.zero);
    events = 0;

    Stores.server.rename(_server, _server.copyWith(id: 'pve-2'));
    await Future<void>.delayed(Duration.zero);
    expect(events, 1, reason: 'the row moved to another id');

    Stores.server.deleteById('pve-2');
    await Future<void>.delayed(Duration.zero);
    expect(events, 2, reason: 'the row cascaded away');
    expect(Stores.pve.fetchAll(), isEmpty);
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

      test('no `pve` object is none, whatever `custom` holds', () {
        expect(PveConfig.fromServerRecord(_server.toJson()), isNull);
        // The fields an older build kept inside `custom` are not read.
        expect(
          PveConfig.fromServerRecord({
            ..._server.toJson(),
            'custom': {'pveAddr': 'https://10.0.0.9:8006', 'pvePwd': 'p'},
          }),
          isNull,
        );
      });
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
