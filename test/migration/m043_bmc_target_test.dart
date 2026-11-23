import 'dart:io';

import 'package:fl_lib/fl_lib.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/data/store/bmc_target.dart';
import 'package:server_box/data/store/migrations/all.dart';
import 'package:server_box/data/store/migrations/m043_bmc_target.dart';
import 'package:server_box/data/store/schema.dart';
import 'package:server_box/data/store/server.dart';
import 'package:server_box/data/store/tables.dart';
import 'package:sqlite3/sqlite3.dart';

import '../helpers/server_ddl.dart';
import '../helpers/test_db.dart';

List<List<Object?>> _xinfo(String table) => SqliteDb.instance
    .select('PRAGMA table_xinfo($table);')
    .map((r) => [r['name'], r['type'], r['notnull'], r['dflt_value'], r['pk']])
    .toList();

int _count(String table) =>
    SqliteDb.instance.select('SELECT count(*) AS n FROM $table;').single['n']
        as int;

/// `server` as v43 created it: the DDL that release wrote, kept in
/// `test/fixtures/schema/server_v43.sql` and never regenerated.
Future<void> _createV43() async {
  final db = SqliteDb.instance;
  db.execute('PRAGMA foreign_keys = ON;');
  await createTables(db);
  db.execute('DROP TABLE IF EXISTS bmc_target_tag;');
  db.execute('DROP TABLE IF EXISTS bmc_target;');
  replaceServerTable(
    File('test/fixtures/schema/server_v43.sql').readAsStringSync(),
  );
}

void main() {
  setUp(SqliteDb.openInMemory);
  tearDown(closeTestDb);

  test('is registered at its own step', () {
    expect(const BmcTargetMigration().from, 43);
    expect(
      kSchemaMigrations.whereType<BmcTargetMigration>(),
      hasLength(1),
    );
    expect(kSchemaMigrations.last.from, SchemaVersion.current - 1);
  });

  test('ends in the shape a fresh install has', () async {
    await createTables(SqliteDb.instance);
    final freshServer = _xinfo('server');
    final freshTarget = _xinfo('bmc_target');
    final freshTags = _xinfo('bmc_target_tag');
    await closeTables();
    await SqliteDb.close();
    SqliteDb.openInMemory();

    await _createV43();
    await const BmcTargetMigration().apply();

    expect(_xinfo('server'), freshServer);
    expect(_xinfo('bmc_target'), freshTarget);
    expect(_xinfo('bmc_target_tag'), freshTags);
  });

  test('moves configured server BMCs and their tags into bmc_target', () async {
    await _createV43();
    final db = SqliteDb.instance;
    db.execute(
      'INSERT INTO bmc_credential (id, name, user, pwd) '
      "VALUES ('cred-1', 'rack-a', 'root', 'secret');",
    );
    db.execute(
      'INSERT INTO server (updated_at, rev, id, name, ssh_ip, ssh_port, '
      'ssh_user, bmc_addr, bmc_cert_sha256, bmc_cred_id) '
      "VALUES (1700000100, 4, 's1', 'web-01', '10.0.0.1', 22, 'root', "
      "'https://10.0.0.11', 'aa:bb', 'cred-1');",
    );
    db.execute(
      'INSERT INTO server (updated_at, rev, id, name, ssh_ip, ssh_port, '
      'ssh_user, bmc_addr) '
      "VALUES (1700000200, 1, 's2', 'plain', '10.0.0.2', 22, 'root', NULL);",
    );
    db.execute(
      'INSERT INTO server (updated_at, rev, id, name, ssh_ip, ssh_port, '
      'ssh_user, bmc_addr) '
      "VALUES (1700000300, 1, 's3', 'blank', '10.0.0.3', 22, 'root', '   ');",
    );
    db.execute("INSERT INTO server_tag VALUES ('s1', 'prod');");
    db.execute("INSERT INTO server_tag VALUES ('s1', 'rack-1');");
    db.execute("INSERT INTO server_tag VALUES ('s2', 'prod');");

    await const BmcTargetMigration().apply();

    final targets = BmcTargetStore().fetch();
    expect(targets, hasLength(1));
    final bmc = targets.single;
    expect(bmc.id, 'bmc_s1');
    expect(bmc.name, 'web-01');
    expect(bmc.addr, 'https://10.0.0.11');
    expect(bmc.credId, 'cred-1');
    expect(bmc.certSha256, 'aa:bb');
    expect(bmc.serverId, 's1');
    expect(bmc.tags, unorderedEquals(['prod', 'rack-1']));

    final serverCols = db
        .select('PRAGMA table_info(server);')
        .map((r) => r['name'])
        .toSet();
    expect(serverCols, isNot(contains('bmc_addr')));
    expect(serverCols, isNot(contains('bmc_cert_sha256')));
    expect(serverCols, isNot(contains('bmc_cred_id')));
    expect(ServerStore().fetchOneRaw('s1')?.name, 'web-01');
    expect(ServerStore().fetchOneRaw('s2')?.name, 'plain');
  });

  test('nulls a dangling bmc_cred_id instead of breaking foreign keys', () async {
    await _createV43();
    final db = SqliteDb.instance;
    db.execute('PRAGMA foreign_keys = OFF;');
    db.execute(
      'INSERT INTO server (id, name, ssh_ip, ssh_port, ssh_user, bmc_addr, bmc_cred_id) '
      "VALUES ('s1', 'orphan-cred', '10.0.0.1', 22, 'root', 'https://10.0.0.99', 'missing-cred');",
    );
    db.execute('PRAGMA foreign_keys = ON;');

    await const BmcTargetMigration().apply();

    final bmc = BmcTargetStore().fetchOne('bmc_s1');
    expect(bmc, isNotNull);
    expect(bmc!.credId, isNull);
    expect(db.select('PRAGMA foreign_key_check;'), isEmpty);
  });

  test('keeps server children intact and unlinks bmc_target when server is deleted', () async {
    await _createV43();
    final db = SqliteDb.instance;
    db.execute(
      'INSERT INTO server (id, name, ssh_ip, ssh_port, ssh_user, bmc_addr) '
      "VALUES ('s1', 'node-1', '10.0.0.1', 22, 'root', 'https://10.0.0.51');",
    );
    db.execute("INSERT INTO server_tag VALUES ('s1', 'edge');");
    db.execute("INSERT INTO server_env VALUES ('s1', 'TERM', 'xterm');");
    db.execute(
      "INSERT INTO server_pve (server_id, addr, auth) VALUES ('s1', 'https://p', 'token');",
    );

    await const BmcTargetMigration().apply();

    expect(_count('server_tag'), 1);
    expect(_count('server_env'), 1);
    expect(_count('server_pve'), 1);
    expect(_count('bmc_target'), 1);

    // Deleting the host cascades its direct children, while leaving the BMC
    // target alive as a standalone card (`server_id` set to NULL).
    db.execute("DELETE FROM server WHERE id = 's1';");
    expect(_count('server_tag'), 0);
    expect(_count('server_env'), 0);
    expect(_count('server_pve'), 0);
    final bmc = BmcTargetStore().fetchOne('bmc_s1');
    expect(bmc, isNotNull);
    expect(bmc!.serverId, isNull);
  });

  test('restores indexes, enforces server constraints, and is idempotent', () async {
    await _createV43();
    final db = SqliteDb.instance;
    db.execute(
      'INSERT INTO server (id, name, ssh_ip, ssh_port, ssh_user, bmc_addr) '
      "VALUES ('s1', 'node-1', '10.0.0.1', 22, 'root', 'https://10.0.0.51');",
    );

    await const BmcTargetMigration().apply();
    await const BmcTargetMigration().apply();

    final indexes = db
        .select("SELECT name FROM sqlite_master WHERE type = 'index';")
        .map((r) => r['name'])
        .toSet();
    expect(
      indexes,
      containsAll([
        'idx_server_key',
        'idx_bmc_target_cred',
        'idx_bmc_target_server',
        'idx_bmc_target_tag_tag',
      ]),
    );
    expect(indexes, isNot(contains('idx_server_bmc_cred')));

    expect(_count('server'), 1);
    expect(_count('bmc_target'), 1);
    expect(
      () => db.execute("INSERT INTO server (id, name) VALUES ('bad', 'bad');"),
      throwsA(isA<SqliteException>()),
    );
  });

  test('seeds sync_record for migrated bmc_target rows', () async {
    await _createV43();
    final db = SqliteDb.instance;
    db.execute(
      'INSERT INTO server (updated_at, rev, id, name, ssh_ip, ssh_port, ssh_user, bmc_addr) '
      "VALUES (1700000500, 2, 's1', 'node-1', '10.0.0.1', 22, 'root', 'https://10.0.0.51');",
    );

    await const BmcTargetMigration().apply();

    final rows = db.select(
      "SELECT id, hlc FROM sync_record WHERE c = 'bmc_target';",
    );
    expect(rows, hasLength(1));
    expect(rows.single['id'], 'bmc_s1');
    expect(rows.single['hlc'] as String, isNotEmpty);
  });
}
