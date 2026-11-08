import 'dart:convert';
import 'dart:io';

import 'package:fl_lib/fl_lib.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/data/model/app/bak/backup.dart';
import 'package:server_box/data/model/app/bak/backup2.dart';
import 'package:server_box/data/model/app/menu/server_func.dart';
import 'package:server_box/data/model/container/type.dart';
import 'package:server_box/data/model/server/private_key_info.dart';
import 'package:server_box/data/model/server/pve_config.dart';
import 'package:server_box/data/model/server/server_private_info.dart';
import 'package:server_box/data/model/server/ssh_credential.dart';
import 'package:server_box/data/store/stores.dart';

/// Who a restored record *is*, and what a restore is allowed to overwrite.
///
/// Both halves of the same question. A backup names records by id and, for
/// records old enough to predate ids, by name — and a server's name is not
/// unique, unlike a private key's or a snippet's.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('sbm-restore-identity-');
    Paths.doc = tempDir.path;
  });

  tearDownAll(() async => tempDir.delete(recursive: true));

  setUp(() async {
    SqliteDb.openInMemory();
    await Stores.init();
  });

  tearDown(() async {
    await getIt.reset();
    await SqliteDb.close();
  });

  Map<String, dynamic> encoded(Spi spi) =>
      json.decode(
            json.encode(
              spi.toJson(),
              toEncodable: (value) => (value as dynamic).toJson(),
            ),
          )
          as Map<String, dynamic>;

  int revOf(String id) =>
      SqliteDb.instance
              .select('SELECT rev FROM server WHERE id = ?;', [id])
              .single['rev']
          as int;

  group('a name is not an identity', () {
    test('two servers sharing a name keep their own ids', () async {
      const a = Spi(id: 'srv-a', name: 'web', ssh: SshCredential(ip: '10.0.0.1'));
      const b = Spi(id: 'srv-b', name: 'web', ssh: SshCredential(ip: '10.0.0.2'));
      Stores.server.put(a);
      Stores.server.put(b);

      // The same two records coming back. Matching them by name sent both at
      // whichever one the lookup answered with — which the graph then reported
      // as a malformed backup, so every restore on such a device failed.
      final backup = BackupV2(
        version: BackupV2.formatVer,
        date: DateTime.now().millisecondsSinceEpoch,
        spis: {a.id: encoded(a), b.id: encoded(b)},
        snippets: const {},
        keys: const {},
        container: const {},
        history: const {},
        settings: const {},
      );

      await backup.merge(force: true);
      Stores.server.dropCache();

      expect(Stores.server.fetchOneRaw('srv-a')?.ssh?.ip, '10.0.0.1');
      expect(Stores.server.fetchOneRaw('srv-b')?.ssh?.ip, '10.0.0.2');
    });

    BackupV2 holding(List<Spi> servers) => BackupV2(
      version: BackupV2.formatVer,
      date: DateTime.now().millisecondsSinceEpoch,
      spis: {for (final s in servers) s.id: encoded(s)},
      snippets: const {},
      keys: const {},
      container: const {},
      history: const {},
      settings: const {},
    );

    test('two of the same name, one of them here: both are restored, as themselves', () async {
      const a = Spi(id: 'srv-a', name: 'web', ssh: SshCredential(ip: '10.0.0.1'));
      const b = Spi(id: 'srv-b', name: 'web', ssh: SshCredential(ip: '10.0.0.2'));
      Stores.server.put(b);

      // `a` matched by name onto `b`, which the backup also holds: both
      // restored to one id, refused as a malformed backup.
      await holding([a, b]).merge(force: true);
      Stores.server.dropCache();
      expect(Stores.server.fetchOneRaw('srv-a')?.ssh?.ip, '10.0.0.1');
      expect(Stores.server.fetchOneRaw('srv-b')?.ssh?.ip, '10.0.0.2');
    });

    test("in a sync, another device's server of the same name is another server", () async {
      const here = Spi(id: 'srv-here', name: 'web', ssh: SshCredential(ip: '10.0.0.1'));
      const there = Spi(id: 'srv-there', name: 'web', ssh: SshCredential(ip: '10.0.0.2'));
      Stores.server.put(here);

      await holding([there]).merge();
      Stores.server.dropCache();
      expect(Stores.server.fetchOneRaw('srv-here')?.ssh?.ip, '10.0.0.1');
      expect(Stores.server.fetchOneRaw('srv-there')?.ssh?.ip, '10.0.0.2');
    });

    test('an ambiguous name resolves to nothing rather than to one of them', () {
      Stores.server.put(
        const Spi(id: 'srv-a', name: 'web', ssh: SshCredential(ip: '10.0.0.1')),
      );
      Stores.server.put(
        const Spi(id: 'srv-b', name: 'web', ssh: SshCredential(ip: '10.0.0.2')),
      );

      const incoming = Spi(
        id: 'web',
        name: 'web',
        ssh: SshCredential(ip: '10.0.0.9'),
      );
      expect(Stores.server.reconcile(incoming).id, 'web');
    });

    test('a legacy record does not adopt one of two same-named servers', () async {
      const a = Spi(id: 'srv-a', name: 'web', ssh: SshCredential(ip: '10.0.0.1'));
      const b = Spi(id: 'srv-b', name: 'web', ssh: SshCredential(ip: '10.0.0.2'));
      Stores.server.put(a);
      Stores.server.put(b);

      // Keyed by name, the way a record written before ids was. Resolving it
      // through a name->id map answers with whichever of the two came last,
      // and that one is then overwritten.
      final backup = BackupV2(
        version: BackupV2.formatVer,
        date: DateTime.now().millisecondsSinceEpoch,
        spis: const {
          'web': {
            'id': '',
            'name': 'web',
            'ssh': {'ip': '10.0.0.9', 'port': 22, 'user': 'root'},
          },
        },
        snippets: const {},
        keys: const {},
        container: const {},
        history: const {},
        settings: const {},
      );

      await backup.merge(force: true);
      Stores.server.dropCache();

      expect(Stores.server.fetchOneRaw('srv-a')?.ssh?.ip, '10.0.0.1');
      expect(Stores.server.fetchOneRaw('srv-b')?.ssh?.ip, '10.0.0.2');
      expect(Stores.server.fetch().length, 3, reason: 'it arrives as its own');
    });

    test('one local server of that name still adopts a legacy record', () {
      Stores.server.put(
        const Spi(id: 'srv-a', name: 'web', ssh: SshCredential(ip: '10.0.0.1')),
      );

      const incoming = Spi(
        id: 'web',
        name: 'web',
        ssh: SshCredential(ip: '10.0.0.9'),
      );
      expect(Stores.server.reconcile(incoming).id, 'srv-a');
    });
  });

  group('a v1 restore', () {
    test('points a server at the key id its key landed under', () async {
      // What every install upgraded from Hive looks like: the key is here
      // under a generated id, while the backup still calls it by its name.
      const local = PrivateKeyInfo(id: 'k-local', name: 'mykey', key: 'PEM');
      Stores.key.put(local);

      const backupKey = PrivateKeyInfo(id: 'mykey', name: 'mykey', key: 'PEM');
      const spi = Spi(
        id: 'srv-1',
        name: 'web',
        ssh: SshCredential(ip: '10.0.0.1', keyId: 'mykey'),
      );

      final backup = BackupV1(
        version: 1,
        date: '',
        spis: const [spi],
        snippets: const [],
        keys: const [backupKey],
        container: const {},
        history: const {},
        settings: const {},
        lastModTime: DateTime.now().millisecondsSinceEpoch,
      );

      // Unresolved, the server names a key row that was never inserted, the
      // foreign key refuses it, and the whole restore rolls back.
      await backup.merge(force: true);
      Stores.server.dropCache();
      Stores.key.dropCache();

      final restored = Stores.server.fetchOneRaw('srv-1');
      expect(restored, isNotNull, reason: 'the restore failed outright');
      expect(restored!.ssh?.keyId, Stores.key.fetchByName('mykey')?.id);
      expect(Stores.key.fetchOneRaw(restored.ssh!.keyId!), isNotNull);
    });

    test('leaves every restored server without PVE', () async {
      const spi = Spi(id: 'srv-1', name: 'pve', ssh: SshCredential(ip: '10.0.0.1'));
      Stores.server.put(spi);
      Stores.pve.put(spi.id, const PveConfig(addr: 'https://h:8006'));
      final record = json.decode(json.encode(spi.toJson())) as Map;
      // What that build kept inside `custom`; not read any more.
      record['custom'] = {'pveAddr': 'https://10.0.0.9:8006', 'pvePwd': 'p'};

      final backup = BackupV1.fromJson(
        json.decode(
          json.encode({
            'version': 1,
            'date': '',
            'spis': [record],
            'snippets': [],
            'keys': [],
            'container': {},
            'history': {},
            'settings': null,
            'lastModTime': DateTime.now().millisecondsSinceEpoch,
          }),
        ) as Map<String, dynamic>,
      );
      await backup.merge(force: true);

      expect(Stores.server.fetchOneRaw(spi.id)?.name, 'pve');
      expect(Stores.pve.fetchAll(), isEmpty);
    });
  });

  group('a setting the device does not hold', () {
    test('arrives even when neither side carries a timestamp', () async {
      // Nothing local to protect, so there is nothing for the backup to be
      // older than — but `0 <= 0` read as a tie and dropped the entry, which
      // is every entry of every envelope written without timestamps.
      final backup = BackupV2(
        version: BackupV2.formatVer,
        date: 1,
        spis: const {},
        snippets: const {},
        keys: const {},
        container: const {},
        history: const {},
        settings: const {'timeOut': 11},
      );

      await backup.merge();

      expect(Stores.setting.get<int>('timeOut'), 11);
    });
  });

  group('a restored setting in an older shape', () {
    test('a button row written as indexes reads as the entries it named', () async {
      // A restore does not run the schema migrator, so `EnumNamesMigration`
      // does not see this row — and does not have to. Every read goes through
      // the property's `fromObj`, which takes either shape; the same tolerance
      // a device still on an older build relies on when it syncs one over.
      final backup = BackupV2(
        version: BackupV2.formatVer,
        date: DateTime.now().millisecondsSinceEpoch,
        spis: const {},
        snippets: const {},
        keys: const {},
        container: const {},
        history: const {},
        settings: const {
          'serverBtns': [0, 2],
        },
      );

      await backup.merge(force: true);

      expect(Stores.setting.serverFuncBtns.fetch(), [
        ServerFuncBtn.terminal.name,
        ServerFuncBtn.container.name,
      ]);
    });
  });

  group('a pull that changes nothing', () {
    test('does not stamp every server as edited here', () async {
      const spi = Spi(
        id: 'srv-1',
        name: 'web',
        ssh: SshCredential(ip: '10.0.0.1'),
      );
      Stores.server.put(spi);
      Stores.container.put(spi.id, ContainerType.docker, 'tcp://host:2375');
      final before = revOf(spi.id);

      // The same state coming back. It used to delete and reinsert the
      // container rows either way and stamp the server for it, so this device
      // then held the newest copy of everything and its next push overwrote
      // the peer's real edits.
      expect(
        Stores.container.restoreOne(spi.id, const {
          'host_docker': 'tcp://host:2375',
        }),
        isFalse,
      );
      expect(revOf(spi.id), before);
    });

    test('a restore that changes something keeps the timestamp it came with', () async {
      const spi = Spi(
        id: 'srv-1',
        name: 'web',
        ssh: SshCredential(ip: '10.0.0.1'),
      );
      Stores.server.put(spi);
      final before = revOf(spi.id);
      await Future<void>.delayed(const Duration(milliseconds: 2));

      // The server merge sets the incoming record's timestamp; the container
      // rows restored under it must not replace that with now.
      expect(
        Stores.container.restoreOne(spi.id, const {
          'host_docker': 'tcp://other:2375',
        }),
        isTrue,
      );
      expect(Stores.container.fetch(spi.id, ContainerType.docker), 'tcp://other:2375');
      expect(revOf(spi.id), before);
    });

    test('leaves a container host this device configured later', () async {
      const spi = Spi(
        id: 'srv-1',
        name: 'web',
        ssh: SshCredential(ip: '10.0.0.1'),
      );
      Stores.server.put(spi);
      Stores.container.put(spi.id, ContainerType.docker, 'tcp://local:2375');

      // A backup taken before that, which `merge` correctly declines to apply
      // to the server — and which used to delete the host anyway.
      final backup = BackupV2(
        version: BackupV2.formatVer,
        date: 1,
        spis: {spi.id: encoded(spi)},
        snippets: const {},
        keys: const {},
        container: const {},
        history: const {},
        settings: const {},
      );

      await backup.merge();
      expect(
        Stores.container.fetch(spi.id, ContainerType.docker),
        'tcp://local:2375',
      );
    });
  });
}
