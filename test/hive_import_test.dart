import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:fl_lib/fl_lib.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:server_box/data/model/server/connection_stat.dart';
import 'package:server_box/data/model/server/server_private_info.dart';
import 'package:server_box/data/model/server/ssh_credential.dart';
import 'package:server_box/data/res/store.dart';
import 'package:server_box/data/store/schema.dart';
import 'package:server_box/hive/hive_registrar.g.dart';
import 'package:server_box/hive/legacy_adapters.dart';
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
    registerHiveLegacyAdapters();
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
    // Production only reads Hive. This writer seeds the current layout the
    // release used without restoring an adapter for the live Spi model.
    Hive.registerAdapter(_SpiWriter(), override: true);
    await server.box.put(
      'srv-1',
      const Spi(
        id: 'srv-1',
        name: 'prod',
        ssh: SshCredential(ip: '10.0.0.1', user: 'root', port: 2222),
        tags: ['a'],
      ),
    );
    Hive.registerAdapter(SpiNestedLegacyAdapter(), override: true);

    // Through the released layouts, not through today's models: `Snippet` and
    // `PrivateKeyInfo` have each gained a field since, so writing one here
    // would produce bytes no install has and prove nothing about the ones that
    // do. The frozen types are read-only, hence the seed-only writers below.
    Hive.registerAdapter(_V1SnippetWriter(), override: true);
    Hive.registerAdapter(_V1PrivateKeyWriter(), override: true);

    final snippet = await open('snippet');
    await snippet.box.put(
      'uptime',
      const LegacySnippetV1(
        name: 'uptime',
        script: 'w',
        tags: null,
        note: null,
        autoRunOn: null,
      ),
    );

    final key = await open('key');
    await key.box.put(
      'k1',
      const LegacyPrivateKeyV1(id: 'k1', key: 'PRIVATE'),
    );

    // Back to the read-only decoders the app registers.
    Hive.registerAdapter(LegacySnippetAdapter(), override: true);
    Hive.registerAdapter(LegacyPrivateKeyAdapter(), override: true);

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

  /// One row of `kv`, decoded.
  ///
  /// The import's whole output is that table — taking a record apart into
  /// columns is `KvToTablesMigration`'s job, and `hive_release_migration_test`
  /// is what covers the two steps end to end. Reading through the stores here
  /// would test the migration instead of the import.
  Map<String, dynamic>? kvRow(String store, String key) {
    final rows = SqliteDb.instance.select(
      'SELECT value FROM kv WHERE store = ? AND key = ?;',
      [store, key],
    );
    if (rows.isEmpty) return null;
    return json.decode(rows.single['value'] as String) as Map<String, dynamic>;
  }

  test('every box lands in the store that replaced it', () async {
    await seedHive();
    await Stores.init();

    final spi = kvRow('server', 'srv-1')!;
    expect(spi['name'], 'prod');
    expect((spi['ssh'] as Map)['ip'], '10.0.0.1');
    expect((spi['ssh'] as Map)['port'], 2222);
    expect(spi['tags'], ['a']);

    expect(kvRow('snippet', 'uptime')!['script'], 'w');
    // `private_key`, which is what the released model's `toJson` called it.
    expect(kvRow('key', 'k1')!['private_key'], 'PRIVATE');

    expect(Stores.setting.timeout.get(), 9);
    expect(Stores.setting.recordHistory.get(), false);
    expect(Stores.setting.homeTabs.get().map((e) => e.name), ['server', 'ssh']);

    expect(Stores.history.sftpGoPath.all, ['/etc', '/var']);

    final docker = SqliteDb.instance.select(
      "SELECT key FROM kv WHERE store = 'docker';",
    );
    expect(docker.map((r) => r['key']), contains('containerHostdocker'));

    expect(
      SqliteDb.instance
          .select("SELECT count(*) AS n FROM kv WHERE store = 'conn_stat';")
          .single['n'],
      1,
    );
    expect(
      SqliteDb.instance
          .select(
            "SELECT value FROM kv WHERE store = 'agent_conversation' "
            "AND key = 'active::srv-1';",
          )
          .single['value'],
      '"conv-1"',
    );
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

  test('it records the layout it wrote, not the current one', () async {
    await seedHive();
    await Stores.init();
    // The import produces the shape that was current when Hive was dropped.
    // Claiming `current` would tell the migrator there is nothing left to do
    // and strand every record in that shape.
    expect(SchemaVersion.stored, SchemaVersion.hiveImportProduces);
    expect(SchemaVersion.stored, lessThan(SchemaVersion.current));
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

  test('a connection stat arrives as the JSON that release wrote', () async {
    await seedHive();
    await Stores.init();

    // The second, unencrypted box of key lists is not carried across at all:
    // it held nothing the records do not already say.
    expect(
      SqliteDb.instance
          .select(
            "SELECT count(*) AS n FROM kv WHERE store = 'conn_stats_index';",
          )
          .single['n'],
      0,
    );

    final stat = kvRow('conn_stat', 'srv-1_1000')!;
    expect(stat['serverId'], 'srv-1');
    expect(stat['serverName'], 'prod');
    // The `@JsonValue`, not the enum's name. Telling the two apart is the
    // migration's job and it has a table for it.
    expect(stat['result'], 'success');
  });

  test('a fresh install imports nothing and is already current', () async {
    // No boxes on disk at all.
    await Stores.init();

    expect(SchemaVersion.stored, SchemaVersion.current);
    // `setting` is not empty — the marker and the schema version live there —
    // but no box contributed a record.
    expect(
      SqliteDb.instance
          .select("SELECT count(*) AS n FROM kv WHERE store <> 'setting';")
          .single['n'],
      0,
    );
  });

  test('a box that could not be read is retried, the rest are not recopied',
      () async {
    await seedHive();

    // A box that will not open. In the field this is the keychain being
    // briefly unavailable at launch on a locked iOS device, which hits the
    // encrypted boxes and not the plaintext ones. Here the box file is a
    // directory, which `Hive.openBox` cannot read either — corrupting the
    // bytes instead does not work, because Hive recovers such a box as an
    // empty one rather than failing to open it.
    final encPath = tempDir.path.joinPath('snippet_enc.hive');
    final intact = File(encPath).readAsBytesSync();
    File(encPath).deleteSync();
    Directory(encPath).createSync();
    addTearDown(() {
      final dir = Directory(encPath);
      if (dir.existsSync()) dir.deleteSync(recursive: true);
    });
    // `runIfNeeded` looks for either name, so the box still counts as present.
    final plain = File(tempDir.path.joinPath('snippet.hive'))..createSync();

    await Stores.init();

    expect(kvRow('server', 'srv-1')?['name'], 'prod',
        reason: 'a box that opened is across');
    expect(kvRow('snippet', 'uptime'), isNull,
        reason: 'the box that did not open has nothing across');

    // Stands in for a user edit between the two launches. The app is usable
    // with the import unfinished, so copying every box again would put the old
    // value back.
    Stores.setting.timeout.put(42);
    await getIt.reset();

    // The box is readable again.
    Directory(encPath).deleteSync(recursive: true);
    plain.deleteSync();
    File(encPath).writeAsBytesSync(intact);
    await Stores.init();

    expect(kvRow('snippet', 'uptime')?['script'], 'w',
        reason: 'the unread box is retried');
    expect(Stores.setting.timeout.get(), 42,
        reason: 'a box already copied is not copied a second time');
  });

  test('a record the destination rejects does not hold its box open', () async {
    await seedHive();
    // A value with no `toJson` and no JSON form. Seeded here rather than in
    // `seedHive`, which the other tests share.
    final stats = HiveStore('connection_stats');
    await stats.init();
    await stats.box.put('bad-row', DateTime(2020));
    await Hive.close();

    await Stores.init();

    expect(kvRow('conn_stat', 'srv-1_1000'), isNotNull,
        reason: 'the readable record still lands');

    // Deliberate, and the opposite of an unopenable box: what makes a record
    // fail here — an unregistered typeId, a truncated value, a shape the
    // destination will not take — gives the same answer on every later launch.
    // Holding the box open for it would leave the marker unwritten for good,
    // so the import would re-run every launch and `conn_stats_index` would
    // stay on disk in plaintext, which is the thing deleting it exists to
    // avoid.
    expect(
      Stores.setting.get<bool>('${StoreDefaults.prefixKey}hiveImported'),
      true,
      reason: 'the box is done; the rejected record is not retried',
    );
  });

  test('a v1.0.1466 server record arrives nested under ssh', () async {
    await seedHive();

    // What 1466 actually had on disk. Its `Spi` was typeId 3 with the SSH
    // fields flat on the record; the current one is typeId 15 with them under
    // `ssh`, and `seedHive` writes that current shape — so nothing else here
    // exercises the path every App Store install upgrading from 1466 takes.
    //
    // Registered over `SpiLegacyAdapter` only to seed, because that one is
    // read-only by design. `_V2SpiWriter.write` is a copy of the 1466
    // generated `SpiAdapter.write`, which is the layout under test.
    Hive.registerAdapter(_V2SpiWriter(), override: true);
    final server = HiveStore('server');
    await server.init();
    await server.box.put(
      'srv-v2',
      const LegacySpiV2(
        name: 'legacy',
        ssh: SshCredential(
          ip: '10.0.0.9',
          port: 2200,
          user: 'admin',
          pwd: 'secret',
          keyId: 'k1',
          alterUrl: 'alt.example',
          jumpId: 'srv-1',
          jumpIds: ['srv-1'],
          proxyCommand: 'nc %h %p',
        ),
        monitorHttp: null,
        tags: ['legacy'],
        autoConnect: false,
        custom: null,
        wolCfg: null,
        envs: {'TERM': 'xterm'},
        id: 'srv-v2',
        customSystemType: null,
        disabledCmdTypes: ['sensors'],
      ),
    );
    await Hive.close();
    // Back to the read-only decoder the app registers.
    Hive.registerAdapter(SpiLegacyAdapter(), override: true);

    await Stores.init();

    final nested = kvRow('server', 'srv-v2');
    expect(nested, isNotNull, reason: 'a typeId 3 record is still readable');
    final spi = Spi.fromJson(nested!);
    expect(spi.name, 'legacy');
    expect(spi.id, 'srv-v2');
    expect(spi.tags, ['legacy']);
    expect(spi.autoConnect, false);
    expect(spi.envs, {'TERM': 'xterm'});
    expect(spi.disabledCmdTypes, ['sensors']);

    // The nesting itself: flat fields 1..17 become one credential.
    expect(spi.ssh?.ip, '10.0.0.9');
    expect(spi.ssh?.port, 2200);
    expect(spi.ssh?.user, 'admin');
    expect(spi.ssh?.pwd, 'secret');
    expect(spi.ssh?.keyId, 'k1');
    expect(spi.ssh?.alterUrl, 'alt.example');
    expect(spi.ssh?.jumpId, 'srv-1');
    expect(spi.ssh?.jumpIds, ['srv-1']);
    expect(spi.ssh?.proxyCommand, 'nc %h %p');
    // 1466 had no monitor support, so field 18 was never written.
    expect(spi.monitorHttp, isNull);

    // Landed as JSON in the current shape, not as v2 bytes.
    final raw = SqliteDb.instance.select(
      'SELECT value FROM kv WHERE store = ? AND key = ?;',
      ['server', 'srv-v2'],
    ).single['value'] as String;
    final decoded = json.decode(raw) as Map<String, dynamic>;
    expect((decoded['ssh'] as Map)['ip'], '10.0.0.9');
    expect(decoded.containsKey('ip'), isFalse, reason: 'no flat field is left');
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

class _SpiWriter extends TypeAdapter<Spi> {
  @override
  final typeId = 15;

  @override
  Spi read(BinaryReader reader) =>
      throw UnsupportedError('Test adapter only writes released Spi records');

  @override
  void write(BinaryWriter writer, Spi obj) {
    writer
      ..writeByte(11)
      ..writeByte(0)
      ..write(obj.name)
      ..writeByte(6)
      ..write(obj.tags)
      ..writeByte(8)
      ..write(obj.autoConnect)
      ..writeByte(10)
      ..write(obj.custom)
      ..writeByte(11)
      ..write(obj.wolCfg)
      ..writeByte(12)
      ..write(obj.envs)
      ..writeByte(13)
      ..write(obj.id)
      ..writeByte(14)
      ..write(obj.customSystemType)
      ..writeByte(15)
      ..write(obj.disabledCmdTypes)
      ..writeByte(18)
      ..write(obj.monitorHttp)
      ..writeByte(19)
      ..write(obj.ssh);
  }
}

/// Writes the typeId 3 layout that v1.0.1466 wrote, so the import is fed the
/// bytes a real upgrading install has rather than the current shape.
///
/// The body is the generated `SpiAdapter.write` from that tag, with the flat
/// SSH fields taken off [LegacySpiV2.ssh]. There is no field 18 because 1466
/// had none — the count stays 18, as it was written then.
class _V2SpiWriter extends TypeAdapter<LegacySpiV2> {
  @override
  final typeId = 3;

  @override
  LegacySpiV2 read(BinaryReader reader) =>
      throw UnsupportedError('seed-only writer');

  @override
  void write(BinaryWriter writer, LegacySpiV2 obj) {
    final ssh = obj.ssh;
    writer
      ..writeByte(18)
      ..writeByte(0)
      ..write(obj.name)
      ..writeByte(1)
      ..write(ssh?.ip ?? '')
      ..writeByte(2)
      ..write(ssh?.port ?? 22)
      ..writeByte(3)
      ..write(ssh?.user ?? 'root')
      ..writeByte(4)
      ..write(ssh?.pwd)
      ..writeByte(5)
      ..write(ssh?.keyId)
      ..writeByte(6)
      ..write(obj.tags)
      ..writeByte(7)
      ..write(ssh?.alterUrl)
      ..writeByte(8)
      ..write(obj.autoConnect)
      ..writeByte(9)
      ..write(ssh?.jumpId)
      ..writeByte(10)
      ..write(obj.custom)
      ..writeByte(11)
      ..write(obj.wolCfg)
      ..writeByte(12)
      ..write(obj.envs)
      ..writeByte(13)
      ..write(obj.id)
      ..writeByte(14)
      ..write(obj.customSystemType)
      ..writeByte(15)
      ..write(obj.disabledCmdTypes)
      ..writeByte(16)
      ..write(ssh?.proxyCommand)
      ..writeByte(17)
      ..write(ssh?.jumpIds);
  }
}

/// Writes the typeId 2 layout every released build wrote: no id, because a
/// snippet was keyed by its name.
class _V1SnippetWriter extends TypeAdapter<LegacySnippetV1> {
  @override
  final typeId = 2;

  @override
  LegacySnippetV1 read(BinaryReader reader) =>
      throw UnsupportedError('seed-only writer');

  @override
  void write(BinaryWriter writer, LegacySnippetV1 obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.name)
      ..writeByte(1)
      ..write(obj.script)
      ..writeByte(2)
      ..write(obj.tags)
      ..writeByte(3)
      ..write(obj.note)
      ..writeByte(4)
      ..write(obj.autoRunOn);
  }
}

/// Writes the typeId 1 layout every released build wrote: an id that was also
/// the name, and the key.
class _V1PrivateKeyWriter extends TypeAdapter<LegacyPrivateKeyV1> {
  @override
  final typeId = 1;

  @override
  LegacyPrivateKeyV1 read(BinaryReader reader) =>
      throw UnsupportedError('seed-only writer');

  @override
  void write(BinaryWriter writer, LegacyPrivateKeyV1 obj) {
    writer
      ..writeByte(2)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.key);
  }
}
