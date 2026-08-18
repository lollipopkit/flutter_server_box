import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:fl_lib/fl_lib.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:server_box/data/model/container/type.dart';
import 'package:server_box/data/model/server/connection_stat.dart';
import 'package:server_box/data/model/server/private_key_info.dart';
import 'package:server_box/data/model/server/server_private_info.dart';
import 'package:server_box/data/model/server/snippet.dart';
import 'package:server_box/data/model/server/ssh_credential.dart';
import 'package:server_box/data/res/store.dart';
import 'package:server_box/data/store/schema.dart';
import 'package:server_box/hive/hive_registrar.g.dart';
import 'package:server_box/hive/spi_legacy_adapter.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// What an existing install's data looks like after the move off Hive.
///
/// This is the one pass over a user's real records, and it is not repeatable —
/// once the marker is written the boxes are never read again. So it is worth
/// checking against boxes written the way the app wrote them, through
/// `HiveStore`, rather than against a hand-built map.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('sbm-hive-import-');
    // `HiveStore.boxDir` resolves to this on an unsandboxed desktop build, and
    // it is `late final`, so this stands in for `Paths.init` — which would need
    // path_provider and would write into the real documents directory.
    Paths.doc = tempDir.path;

    // One seeded generator reused, not a new one per byte — `Random(1)` inside
    // the closure would have produced the same value 32 times.
    final rng = Random(1);
    FlutterSecureStorage.setMockInitialValues({
      'hivePwd': base64UrlEncode(
        Uint8List.fromList(List<int>.generate(32, (_) => rng.nextInt(256))),
      ),
    });
    SharedPreferences.setMockInitialValues({});
    await PrefStore.shared.init();

    Hive.init(tempDir.path);
    Hive.registerAdapters();
    Hive.registerAdapter(SpiLegacyAdapter());
  });

  tearDownAll(() async {
    await Hive.close();
    await tempDir.delete(recursive: true);
  });

  setUp(() async {
    SqliteDb.openInMemory();
  });

  tearDown(() async {
    await getIt.reset();
    await SqliteDb.close();
    await Hive.close();
    // By file rather than `Hive.deleteFromDisk`, which only knows about boxes
    // the current instance still has open — `seedHive` closes them all.
    for (final f in tempDir.listSync()) {
      if (f is File) f.deleteSync();
    }
    Hive.init(tempDir.path);
  });

  /// Fills the boxes the way a running app would have left them.
  Future<void> seedHive() async {
    Future<HiveStore> open(String name) async {
      final store = HiveStore(name);
      await store.init();
      return store;
    }

    final server = await open('server');
    await server.box.put(
      'srv-1',
      const Spi(
        id: 'srv-1',
        name: 'prod',
        ssh: SshCredential(ip: '10.0.0.1', user: 'root', port: 2222),
        tags: ['a'],
      ),
    );

    final snippet = await open('snippet');
    await snippet.box.put('uptime', const Snippet(name: 'uptime', script: 'w'));

    final key = await open('key');
    await key.box.put(
      'k1',
      const PrivateKeyInfo(id: 'k1', key: 'PRIVATE'),
    );

    final setting = await open('setting');
    await setting.box.put('timeOut', 9);
    await setting.box.put('recordHistory', false);
    await setting.box.put('homeTabs', ['server', 'ssh']);

    final history = await open('history');
    await history.box.put('sftpPath', ['/etc', '/var']);
    await history.box.put('sshTabs', '[]');

    final docker = await open('docker');
    await docker.box.put('containerHostdocker', 'unix:///var/run/docker.sock');

    final stats = await open('connection_stats');
    await stats.box.put(
      'srv-1_1000',
      ConnectionStat(
        serverId: 'srv-1',
        serverName: 'prod',
        timestamp: DateTime.now(),
        result: ConnectionResult.success,
        durationMs: 12,
      ),
    );

    final agent = await open('agent_conversation');
    await agent.box.put('active::srv-1', 'conv-1');

    await Hive.close();
  }

  test('every box lands in the store that replaced it', () async {
    await seedHive();
    await Stores.init();

    final spi = Stores.server.fetchOneRaw('srv-1');
    expect(spi?.name, 'prod');
    expect(spi?.ssh?.ip, '10.0.0.1');
    expect(spi?.ssh?.port, 2222);
    expect(spi?.tags, ['a']);

    expect(Stores.snippet.fetchOneRaw('uptime')?.script, 'w');
    expect(Stores.key.fetchOneRaw('k1')?.key, 'PRIVATE');

    expect(Stores.setting.timeout.get(), 9);
    expect(Stores.setting.recordHistory.get(), false);
    expect(Stores.setting.homeTabs.get().map((e) => e.name), ['server', 'ssh']);

    expect(Stores.history.sftpGoPath.all, ['/etc', '/var']);
    expect(
      Stores.container.fetch('', ContainerType.docker),
      'unix:///var/run/docker.sock',
    );
    expect(
      Stores.connectionStats.getConnectionHistory('srv-1').single.serverName,
      'prod',
    );
    expect(Stores.agentConversation.activeConversationId('srv-1'), 'conv-1');
  });

  test('the records are readable as JSON, not as adapter bytes', () async {
    await seedHive();
    await Stores.init();

    // The point of the exercise: nothing decodes through a TypeAdapter any
    // more, so what is in the row has to stand on its own.
    final raw = SqliteDb.instance.select(
      'SELECT value FROM kv WHERE store = ? AND key = ?;',
      ['server', 'srv-1'],
    ).single['value'] as String;
    final decoded = json.decode(raw) as Map<String, dynamic>;
    expect(decoded['name'], 'prod');
    expect((decoded['ssh'] as Map)['ip'], '10.0.0.1');
  });

  test('it records the current schema version', () async {
    await seedHive();
    await Stores.init();
    expect(SchemaVersion.stored, SchemaVersion.current);
  });

  test('a second launch does not import again', () async {
    await seedHive();
    await Stores.init();

    // Stand in for a user edit made after the upgrade. If the import ran a
    // second time it would put the old value back.
    Stores.setting.timeout.put(42);
    await getIt.reset();

    await Stores.init();
    expect(Stores.setting.timeout.get(), 42);
  });

  test('the plaintext index box is deleted, the encrypted boxes are kept',
      () async {
    await seedHive();
    // The one box the app opened without a cipher.
    final index = File(tempDir.path.joinPath('conn_stats_index.hive'));
    await index.writeAsString('idx_srv-1');

    await Stores.init();

    expect(index.existsSync(), isFalse, reason: 'it was never encrypted');
    expect(
      File(tempDir.path.joinPath('server_enc.hive')).existsSync(),
      isTrue,
      reason: 'kept so a bad import can be rolled back to',
    );
  });

  test('connection stats land in their table, not in kv', () async {
    await seedHive();
    await Stores.init();

    // The box held one row per attempt plus a second, unencrypted box of key
    // lists. Both are one table now, so nothing of it should be left in `kv`.
    final kv = SqliteDb.instance.select(
      "SELECT count(*) AS n FROM kv WHERE store LIKE 'conn%';",
    ).single['n'];
    expect(kv, 0);

    final rows = SqliteDb.instance.select(
      'SELECT server_id FROM conn_stat;',
    );
    expect(rows.single['server_id'], 'srv-1');
  });

  test('a fresh install imports nothing and is already current', () async {
    // No boxes on disk at all.
    await Stores.init();

    expect(SchemaVersion.stored, SchemaVersion.current);
    expect(Stores.server.fetch(), isEmpty);
  });

  test('importing does not present itself as a local edit', () async {
    await seedHive();
    await Stores.init();

    // `Stores.lastModTime` drives which side of a sync wins. Stamping each row
    // as it landed would make a device that has just finished reading its own
    // disk claim the newer copy of everything.
    expect(Stores.lastModTime, 0);
  });
}
