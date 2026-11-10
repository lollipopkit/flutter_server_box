import 'dart:io';

import 'package:fl_lib/fl_lib.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/data/store/migrations/all.dart';
import 'package:server_box/data/store/migrations/m033_sync_record.dart';
import 'package:server_box/data/store/schema.dart';
import 'package:server_box/data/store/stores.dart';
import 'package:server_box/data/store/sync_recorder.dart';

List<Map<String, Object?>> _table() => [
  for (final row in SqliteDb.instance.select('PRAGMA table_info(sync_record);'))
    {'name': row['name'], 'type': row['type'], 'notnull': row['notnull'], 'pk': row['pk']},
];

Map<(String, String), String> _records() => {
  for (final row in SqliteDb.instance.select('SELECT c, id, hlc FROM sync_record;'))
    (row['c'] as String, row['id'] as String): row['hlc'] as String,
};

/// A v33 database: today's tables without `sync_record`.
Future<void> _v33() async {
  SqliteDb.openInMemory();
  await Stores.init();
  SyncRecorder.resetForTest();
  SqliteDb.instance.execute('DROP TABLE sync_record;');
}

void main() {
  setUpAll(() async {
    final dir = await Directory.systemTemp.createTemp('sbm-m033-');
    Paths.doc = dir.path;
    addTearDown(() => dir.delete(recursive: true));
  });

  tearDown(() async {
    await Future<void>.delayed(Duration.zero);
    await getIt.reset();
    await SqliteDb.close();
  });

  test('is the last registered schema step', () {
    expect(const SyncRecordMigration().from, 33);
    expect(kSchemaMigrations.whereType<SyncRecordMigration>(), hasLength(1));
    expect(kSchemaMigrations.last.from, SchemaVersion.current - 1);
  });

  test('makes the table a fresh database has', () async {
    SqliteDb.openInMemory();
    await Stores.init();
    final fresh = _table();
    await getIt.reset();
    await SqliteDb.close();

    await _v33();
    await const SyncRecordMigration().apply();
    expect(_table(), fresh);
  });

  /// What a v33 install wrote: a server, a deleted snippet, a setting with its
  /// stamp in `lastUpdateTs`, and a history key, which stays unsynced.
  test("seeds what the snapshot sync stamped, as no device's", () async {
    await _v33();
    final db = SqliteDb.instance;
    db.execute(
      'INSERT INTO server (id, name, ssh_ip, ssh_port, ssh_user, updated_at) '
      "VALUES ('s1', 'web', '10.0.0.1', 22, 'root', 1762000000000);",
    );
    db.execute(
      "INSERT INTO tombstone (tbl, row_id, deleted_at) VALUES ('snippet', 'gone', 1762000000500);",
    );
    db.execute(
      "INSERT INTO kv (store, key, value, updated_at) VALUES ('setting', 'timeOut', '17', 1762000001000);",
    );
    db.execute(
      "INSERT INTO kv (store, key, value, updated_at) VALUES ('setting', ?, ?, 0);",
      [Stores.setting.lastUpdateTsKey, '{"timeOut":1762000001000}'],
    );
    db.execute(
      "INSERT INTO kv (store, key, value, updated_at) VALUES ('history', 'sftpPath', '[\"/srv\"]', 1762000002000);",
    );

    await const SyncRecordMigration().apply();

    final legacy = SyncRecorder.legacy;
    String stamp(int ms) => syncStampOf(ms: BigInt.from(ms), device: legacy);
    expect(_records(), {
      ('server', 's1'): stamp(1762000000000),
      ('snippet', 'gone'): stamp(1762000000500),
      ('kv:setting', 'timeOut'): stamp(1762000001000),
    });
    expect(SyncRecorder.pending(''), isEmpty);
  });

  test('is safe to run again, and keeps a newer stamp', () async {
    await _v33();
    SqliteDb.instance.execute(
      'INSERT INTO server (id, name, ssh_ip, ssh_port, ssh_user, updated_at) '
      "VALUES ('s1', 'web', '10.0.0.1', 22, 'root', 1762000000000);",
    );
    await const SyncRecordMigration().apply();
    SyncRecorder.record('server', 's1');
    final edited = _records()[('server', 's1')];
    await const SyncRecordMigration().apply();
    expect(_records()[('server', 's1')], edited);
  });
}
