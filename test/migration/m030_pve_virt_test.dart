/// The step that moves PVE out of `server` into `server_pve`.
///
/// A rebuild of `server`, like m017 and m028, so the same things can go wrong
/// the same silent way — the children cascading off the dropped table, the
/// pragma left off, the indexes not coming back — and each has a test here.
///
/// Where the v30 database comes from: no SQLite fixture written by a release
/// exists yet (`test/fixtures/` holds Hive boxes only), and building one
/// needs the release's own code. Two sources stand in:
///
/// - `hive_release_migration_test.dart` runs the whole chain, this step
///   included, over boxes v1.0.1466/1480/1491 wrote themselves. Their server
///   with `pveIgnoreCert: true` and their three-tab bar are the
///   release-written case, and the PVE row is asserted there.
/// - The cases below — both values of `pve_ignore_cert`, an empty address,
///   the children, a full bar, a bar that already has the tab — are not in any
///   fixture, so this file builds the v30 `server` from today's DDL with the
///   three columns put back (`serverDdlBeforePveTable`), and drops the table
///   v30 did not have.
library;

import 'package:fl_lib/fl_lib.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/data/model/server/pve_config.dart';
import 'package:server_box/data/store/migrations/all.dart';
import 'package:server_box/data/store/migrations/m030_pve_virt.dart';
import 'package:server_box/data/store/pve.dart';
import 'package:server_box/data/store/schema.dart';
import 'package:server_box/data/store/setting.dart';
import 'package:server_box/data/store/tables.dart';
import 'package:sqlite3/sqlite3.dart';

import '../helpers/server_ddl.dart';
import '../helpers/test_db.dart';

List<List<Object?>> _xinfo(String table) => SqliteDb.instance
    .select('PRAGMA table_xinfo($table);')
    .map((r) => [r['name'], r['type'], r['notnull'], r['dflt_value'], r['pk']])
    .toList();

List<List<Object?>> _foreignKeys(String table) => SqliteDb.instance
    .select('PRAGMA foreign_key_list($table);')
    .map((r) => [r['table'], r['from'], r['to'], r['on_delete']])
    .toList();

int _count(String table) =>
    SqliteDb.instance.select('SELECT count(*) AS n FROM $table;').single['n']
        as int;

/// A database as v30 left it: `server` with the PVE columns, no `server_pve`.
Future<void> _createV30() async {
  final db = SqliteDb.instance;
  db.execute('PRAGMA foreign_keys = ON;');
  await createTables(db);
  replaceServerTable(serverDdlBeforePveTable(freshServerDdl()));
  db.execute('DROP TABLE server_pve;');
}

void _seedServer(
  String id, {
  String? pveAddr,
  bool ignoreCert = false,
  String? pvePwd,
  String? keyId,
}) {
  if (keyId != null) {
    SqliteDb.instance.execute(
      'INSERT OR IGNORE INTO private_key (id, name, key) VALUES (?, ?, ?);',
      [keyId, keyId, 'k'],
    );
  }
  SqliteDb.instance.execute(
    'INSERT INTO server (updated_at, rev, id, name, ssh_ip, ssh_port, '
    'ssh_user, ssh_key_id, monitor_addr, preferred_transport, geo_lat, '
    'geo_lon, pve_addr, pve_ignore_cert, pve_pwd) '
    "VALUES (1700000000, 3, ?, ?, '10.0.0.1', 22, 'root', ?, 'https://h:3770', "
    "'monitorHttp', 1.5, 2.5, ?, ?, ?);",
    [id, id, keyId, pveAddr, if (ignoreCert) 1 else 0, pvePwd],
  );
}

void _seedChildren(String id) {
  final db = SqliteDb.instance;
  db.execute("INSERT INTO server_tag VALUES (?, 'prod');", [id]);
  db.execute("INSERT INTO server_env VALUES (?, 'TERM', 'xterm');", [id]);
  db.execute("INSERT INTO server_disabled_cmd VALUES (?, 'sensors');", [id]);
  db.execute("INSERT INTO server_custom_cmd VALUES (?, 'up', 'uptime');", [
    id,
  ]);
  db.execute(
    "INSERT INTO container_host VALUES (?, 'docker', 'unix:///d.sock');",
    [id],
  );
}

Map<String, Object?>? _pveRow(String id) {
  final rows = SqliteDb.instance.select(
    'SELECT * FROM server_pve WHERE server_id = ?;',
    [id],
  );
  return rows.isEmpty ? null : Map.of(rows.single);
}

void main() {
  late SettingStore setting;

  setUp(() {
    SqliteDb.openInMemory();
    setting = SettingStore.instance;
  });

  tearDown(closeTestDb);

  Object? storedTabs() => setting.get<Object>(PveVirtMigration.homeTabsKey);

  test('is registered at its own step', () {
    expect(const PveVirtMigration().from, 30);
    expect(kSchemaMigrations.whereType<PveVirtMigration>(), hasLength(1));
    expect(SchemaVersion.current, greaterThan(30));
  });

  test('ends in the shape a fresh install has', () async {
    await createTables(SqliteDb.instance);
    final freshServer = _xinfo('server');
    final freshPve = _xinfo('server_pve');
    final freshPveKeys = _foreignKeys('server_pve');
    await closeTables();
    await SqliteDb.close();
    SqliteDb.openInMemory();

    await _createV30();
    await const PveVirtMigration().apply();

    expect(_xinfo('server'), freshServer);
    expect(_xinfo('server_pve'), freshPve);
    expect(_foreignKeys('server_pve'), freshPveKeys);
  });

  group('the copy', () {
    test('a server that ignored the certificate has no pin', () async {
      await _createV30();
      _seedServer(
        'ignored',
        pveAddr: 'https://127.0.0.1:8006',
        ignoreCert: true,
        pvePwd: 'p',
        keyId: 'key',
      );

      await const PveVirtMigration().apply();

      expect(_pveRow('ignored'), {
        'server_id': 'ignored',
        'addr': 'https://127.0.0.1:8006',
        'auth': 'password',
        'pwd': 'p',
        'token_id': null,
        'token_secret': null,
        'cert_sha256': null,
      });
    });

    test('a server that validated it keeps validating, still no pin', () async {
      await _createV30();
      _seedServer('ca', pveAddr: 'https://pve.example.com:8006');

      await const PveVirtMigration().apply();

      final row = _pveRow('ca')!;
      expect(row['auth'], 'password');
      expect(row['pwd'], isNull);
      expect(row['cert_sha256'], isNull);
    });

    test('no address, or an empty one, is no PVE', () async {
      await _createV30();
      _seedServer('none');
      _seedServer('empty', pveAddr: '  ', pvePwd: 'p');

      await const PveVirtMigration().apply();

      expect(_count('server_pve'), 0);
    });

    test('the PVE password only where SSH uses a key', () async {
      // What every earlier build sent: `pve_pwd` with a key, the SSH password
      // otherwise. The editor hid the field for a password login but still
      // saved what it held, so a copy there is a password nothing sends.
      await _createV30();
      _seedServer(
        'key',
        pveAddr: 'https://h:8006',
        pvePwd: 'pve-pw',
        keyId: 'k-1',
      );
      _seedServer('pwd', pveAddr: 'https://h:8006', pvePwd: 'stale');

      await const PveVirtMigration().apply();

      expect(_pveRow('key')!['pwd'], 'pve-pw');
      expect(_pveRow('pwd')!['pwd'], isNull);
    });

    test('an empty password is no password', () async {
      await _createV30();
      _seedServer('blank', pveAddr: 'https://h:8006', pvePwd: '', keyId: 'k');

      await const PveVirtMigration().apply();

      expect(_pveRow('blank')!['pwd'], isNull);
    });

    test('reads back through the store', () async {
      await _createV30();
      _seedServer('pve', pveAddr: 'https://h:8006', ignoreCert: true);
      await const PveVirtMigration().apply();

      expect(
        PveStore().fetch('pve'),
        const PveConfig(addr: 'https://h:8006', auth: PveAuth.password),
      );
    });
  });

  group('the rebuild', () {
    test('keeps every other field of every server', () async {
      await _createV30();
      _seedServer('s-1', pveAddr: 'https://h:8006');

      await const PveVirtMigration().apply();

      final row = SqliteDb.instance.select('SELECT * FROM server;').single;
      expect(row['ssh_ip'], '10.0.0.1');
      expect(row['monitor_addr'], 'https://h:3770');
      expect(row['preferred_transport'], 'monitorHttp');
      expect(row['geo_lat'], 1.5);
      // What sync reads. A rebuild that reset either would make every server
      // look freshly edited to a peer.
      expect(row['updated_at'], 1700000000);
      expect(row['rev'], 3);
      expect(row.keys, isNot(contains('pve_addr')));
    });

    test('the children survive the table being dropped', () async {
      await _createV30();
      _seedServer('s-1', pveAddr: 'https://h:8006');
      _seedChildren('s-1');

      await const PveVirtMigration().apply();

      expect(_count('server_tag'), 1);
      expect(_count('server_env'), 1);
      expect(_count('server_disabled_cmd'), 1);
      expect(_count('server_custom_cmd'), 1);
      expect(_count('container_host'), 1);
      expect(_count('server_pve'), 1);
    });

    test('the cascade still works afterwards, the new child included', () async {
      await _createV30();
      _seedServer('s-1', pveAddr: 'https://h:8006');
      _seedChildren('s-1');

      await const PveVirtMigration().apply();
      SqliteDb.instance.execute("DELETE FROM server WHERE id = 's-1';");

      for (final table in const [
        'server_tag',
        'server_env',
        'server_disabled_cmd',
        'server_custom_cmd',
        'container_host',
        'server_pve',
      ]) {
        expect(_count(table), 0, reason: table);
      }
    });

    test('the constraints survive it', () async {
      await _createV30();
      _seedServer('s-1', pveAddr: 'https://h:8006');
      await const PveVirtMigration().apply();
      final db = SqliteDb.instance;

      expect(
        () => db.execute("INSERT INTO server (id, name) VALUES ('n', 'n');"),
        throwsA(isA<SqliteException>()),
      );
      expect(
        () => db.execute(
          "UPDATE server_pve SET auth = 'ticket' WHERE server_id = 's-1';",
        ),
        throwsA(isA<SqliteException>()),
        reason: 'auth is a PveAuth name',
      );
      expect(
        () => db.execute(
          'INSERT INTO server_pve (server_id, addr, auth) '
          "VALUES ('ghost', 'https://h', 'token');",
        ),
        throwsA(isA<SqliteException>()),
        reason: 'a row for a server that does not exist',
      );
    });

    test('the indexes come back', () async {
      await _createV30();
      await const PveVirtMigration().apply();

      final names = SqliteDb.instance
          .select("SELECT name FROM sqlite_master WHERE type = 'index';")
          .map((row) => row['name'])
          .toSet();
      expect(names, containsAll(['idx_server_key', 'idx_server_bmc_cred']));
    });

    test('running it twice is harmless', () async {
      await _createV30();
      _seedServer('s-1', pveAddr: 'https://h:8006');
      _seedChildren('s-1');

      await const PveVirtMigration().apply();
      await const PveVirtMigration().apply();

      expect(_count('server'), 1);
      expect(_count('server_tag'), 1);
      expect(_count('server_pve'), 1);
    });
  });

  group('the home bar', () {
    test('gets the tab appended when a server has PVE', () async {
      await _createV30();
      _seedServer('plain');
      _seedServer('pve', pveAddr: 'https://h:8006');
      setting.set(PveVirtMigration.homeTabsKey, ['ssh', 'server', 'file']);

      await const PveVirtMigration().apply();

      // Appended, and nothing the user arranged moves.
      expect(storedTabs(), ['ssh', 'server', 'file', 'virt']);
    });

    test('is untouched when no server has PVE', () async {
      await _createV30();
      _seedServer('plain');
      setting.set(PveVirtMigration.homeTabsKey, ['server', 'ssh']);

      await const PveVirtMigration().apply();

      expect(storedTabs(), ['server', 'ssh']);
    });

    test('is untouched when it already has the tab', () async {
      await _createV30();
      _seedServer('pve', pveAddr: 'https://h:8006');
      setting.set(PveVirtMigration.homeTabsKey, ['virt', 'server']);

      await const PveVirtMigration().apply();

      expect(storedTabs(), ['virt', 'server']);
    });

    test('is untouched when full, so the tab is under "more"', () async {
      await _createV30();
      _seedServer('pve', pveAddr: 'https://h:8006');
      const full = ['server', 'ssh', 'file', 'agent'];
      expect(full, hasLength(PveVirtMigration.barRoom));
      setting.set(PveVirtMigration.homeTabsKey, full);

      await const PveVirtMigration().apply();

      expect(storedTabs(), full);
    });

    test('is not written when it was never arranged', () async {
      // Such a bar is `AppTab.defaultOrder`, read at launch. A snapshot of it
      // written here would stop this install following the default.
      await _createV30();
      _seedServer('pve', pveAddr: 'https://h:8006');

      await const PveVirtMigration().apply();

      expect(storedTabs(), isNull);
    });

    test('the write is not a user edit', () async {
      await _createV30();
      _seedServer('pve', pveAddr: 'https://h:8006');
      setting.set(PveVirtMigration.homeTabsKey, [
        'server',
      ], updateLastUpdateTsOnSet: false);

      await const PveVirtMigration().apply();
      // The per-key stamp is written through a microtask queue.
      await Future<void>.delayed(Duration.zero);

      expect(storedTabs(), ['server', 'virt']);
      expect(setting.lastUpdateTs?[PveVirtMigration.homeTabsKey], isNull);
    });
  });

  test('the whole chain from v30 goes through it', () async {
    await _createV30();
    _seedServer('pve', pveAddr: 'https://h:8006', ignoreCert: true);
    setting.schemaVersion.put(30);

    await SchemaVersion.migrate(kSchemaMigrations);

    expect(SchemaVersion.stored, SchemaVersion.current);
    expect(_pveRow('pve')?['addr'], 'https://h:8006');
  });
}
