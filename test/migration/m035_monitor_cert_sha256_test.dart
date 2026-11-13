/// The step that replaces `server.monitor_ignore_cert` with
/// `monitor_cert_sha256`.
///
/// A rebuild of `server`, like m017, m028 and m030, so the same things can go
/// wrong the same silent way — the children cascading off the dropped table,
/// the pragma left off, the indexes not coming back — and each has a test.
///
/// Where the v35 database comes from: no release has written one — the
/// newest, v1.0.1856, is at v33, so an install reaches v35 only through m033
/// and m034 on its way here — and no SQLite fixture written by a release
/// exists (`test/fixtures/` holds Hive boxes only). The v35 `server` is
/// therefore today's DDL with `monitor_ignore_cert` put back where it stood
/// (`serverDdlBeforeMonitorCertPin`). Release-written data reaches this step
/// through `hive_release_migration_test.dart`, which runs the whole chain,
/// this step included, over boxes v1.0.1466/1480/1491 wrote.
library;

import 'package:fl_lib/fl_lib.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/data/model/server/monitor/monitor_http_credential.dart';
import 'package:server_box/data/store/migrations/all.dart';
import 'package:server_box/data/store/migrations/m035_monitor_cert_sha256.dart';
import 'package:server_box/data/store/migrations/m039_ssh_identity_agent.dart';
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

/// A database as v35 left it.
Future<void> _createV35() async {
  final db = SqliteDb.instance;
  db.execute('PRAGMA foreign_keys = ON;');
  await createTables(db);
  createServerCustomCmdTable();
  replaceServerTable(serverDdlBeforeMonitorCertPin(freshServerDdl()));
}

void _seedServer(String id, {int? ignoreCert}) {
  SqliteDb.instance.execute(
    'INSERT INTO server (updated_at, rev, id, name, ssh_ip, ssh_port, '
    'ssh_user, monitor_addr, monitor_user, monitor_pwd, monitor_ignore_cert, '
    'monitor_allow_insecure, preferred_transport, geo_lat, geo_lon, '
    'disk_counts_network) '
    "VALUES (1700000000, 3, ?, ?, '10.0.0.1', 22, 'root', 'https://h:3770', "
    "'admin', 'pw', ?, 1, 'monitorHttp', 1.5, 2.5, 1);",
    [id, id, ignoreCert],
  );
}

void _seedChildren(String id) {
  final db = SqliteDb.instance;
  db.execute("INSERT INTO server_tag VALUES (?, 'prod');", [id]);
  db.execute("INSERT INTO server_env VALUES (?, 'TERM', 'xterm');", [id]);
  db.execute("INSERT INTO server_custom_cmd VALUES (?, 'up', 'uptime');", [
    id,
  ]);
  db.execute(
    "INSERT INTO server_pve (server_id, addr, auth) VALUES (?, 'https://p', 'token');",
    [id],
  );
}

void main() {
  setUp(SqliteDb.openInMemory);
  tearDown(closeTestDb);

  test('is registered at its own step', () {
    expect(const MonitorCertSha256Migration().from, 35);
    expect(
      kSchemaMigrations.whereType<MonitorCertSha256Migration>(),
      hasLength(1),
    );
    expect(SchemaVersion.current, greaterThan(35));
  });

  test('ends in the shape a fresh install has', () async {
    await createTables(SqliteDb.instance);
    final fresh = _xinfo('server');
    await closeTables();
    await SqliteDb.close();
    SqliteDb.openInMemory();

    await _createV35();
    await const MonitorCertSha256Migration().apply();
    await const SshIdentityAgentMigration().apply();

    expect(_xinfo('server'), fresh);
  });

  group('the copy', () {
    test('neither value of the switch becomes a pin', () async {
      await _createV35();
      _seedServer('ignored', ignoreCert: 1);
      _seedServer('validated', ignoreCert: 0);
      _seedServer('unset');

      await const MonitorCertSha256Migration().apply();

      final pins = SqliteDb.instance
          .select('SELECT id, monitor_cert_sha256 FROM server ORDER BY id;')
          .map((r) => [r['id'], r['monitor_cert_sha256']])
          .toList();
      expect(pins, [
        ['ignored', null],
        ['unset', null],
        ['validated', null],
      ]);
    });

    test('keeps every other field', () async {
      await _createV35();
      _seedServer('s-1', ignoreCert: 1);

      await const MonitorCertSha256Migration().apply();

      final row = SqliteDb.instance.select('SELECT * FROM server;').single;
      expect(row['monitor_addr'], 'https://h:3770');
      expect(row['monitor_user'], 'admin');
      expect(row['monitor_pwd'], 'pw');
      expect(row['monitor_allow_insecure'], 1);
      expect(row['preferred_transport'], 'monitorHttp');
      expect(row['geo_lat'], 1.5);
      expect(row['disk_counts_network'], 1);
      // What sync reads. A rebuild that reset either would make every server
      // look freshly edited to a peer.
      expect(row['updated_at'], 1700000000);
      expect(row['rev'], 3);
      expect(row.keys, isNot(contains('monitor_ignore_cert')));
    });

    test('reads back through the store with no pin', () async {
      await _createV35();
      _seedServer('s-1', ignoreCert: 1);
      await const MonitorCertSha256Migration().apply();

      expect(
        ServerStore.instance.fetchOneRaw('s-1')!.monitorHttp,
        const MonitorHttpCredential(
          addr: 'https://h:3770',
          pwd: 'pw',
          legacyUser: 'admin',
          allowInsecure: true,
        ),
      );
    });
  });

  group('the rebuild', () {
    test('the children survive the table being dropped', () async {
      await _createV35();
      _seedServer('s-1');
      _seedChildren('s-1');

      await const MonitorCertSha256Migration().apply();

      for (final table in const [
        'server_tag',
        'server_env',
        'server_custom_cmd',
        'server_pve',
      ]) {
        expect(_count(table), 1, reason: table);
      }
    });

    test('the cascade still works afterwards', () async {
      await _createV35();
      _seedServer('s-1');
      _seedChildren('s-1');

      await const MonitorCertSha256Migration().apply();
      SqliteDb.instance.execute("DELETE FROM server WHERE id = 's-1';");

      for (final table in const [
        'server_tag',
        'server_env',
        'server_custom_cmd',
        'server_pve',
      ]) {
        expect(_count(table), 0, reason: table);
      }
    });

    test('the constraints survive it', () async {
      await _createV35();
      await const MonitorCertSha256Migration().apply();

      expect(
        () => SqliteDb.instance.execute(
          "INSERT INTO server (id, name) VALUES ('n', 'n');",
        ),
        throwsA(isA<SqliteException>()),
        reason: 'neither SSH nor an agent nor this device',
      );
    });

    test('the indexes come back', () async {
      await _createV35();
      await const MonitorCertSha256Migration().apply();

      final names = SqliteDb.instance
          .select("SELECT name FROM sqlite_master WHERE type = 'index';")
          .map((row) => row['name'])
          .toSet();
      expect(names, containsAll(['idx_server_key', 'idx_server_bmc_cred']));
    });

    test('running it twice is harmless', () async {
      await _createV35();
      _seedServer('s-1', ignoreCert: 1);
      _seedChildren('s-1');

      await const MonitorCertSha256Migration().apply();
      await const MonitorCertSha256Migration().apply();

      expect(_count('server'), 1);
      expect(_count('server_tag'), 1);
    });
  });
}
