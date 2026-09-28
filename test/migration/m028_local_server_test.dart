/// The step that lets a server be this device.
///
/// A rebuild of `server`, like m017, so the same things can go wrong the same
/// silent way: the children cascading off the dropped table, the pragma left
/// off, the indexes not coming back. Each has a test here.
library;

import 'package:fl_lib/fl_lib.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/data/model/server/server_private_info.dart';
import 'package:server_box/data/model/server/ssh_credential.dart';
import 'package:server_box/data/store/migrations/m028_local_server.dart';
import 'package:server_box/data/store/server.dart';
import 'package:server_box/data/store/tables.dart';
import 'package:sqlite3/sqlite3.dart';

import '../helpers/server_ddl.dart';
import '../helpers/test_db.dart';

void main() {
  setUp(SqliteDb.openInMemory);
  tearDown(closeTestDb);

  String serverDdl() =>
      SqliteDb.instance
              .select("SELECT sql FROM sqlite_master WHERE name = 'server';")
              .single['sql']
          as String;

  /// The v28 shape: the v29 table less `is_local`, with the CHECK it relaxes
  /// put back. v29 is today's table with the PVE columns m030 later moved out.
  ///
  /// Derived from today's DDL by removing exactly those two things, each
  /// asserted to have been found — so a change to the table that moves either
  /// fails here rather than producing a v28 that never existed.
  Future<void> createV28Schema() async {
    final db = SqliteDb.instance;
    await createTables(db);
    final fresh = serverDdlBeforePveTable(serverDdl());
    const localColumn =
        '"is_local" INTEGER NOT NULL DEFAULT 0 CHECK ("is_local" IN (0, 1)), ';
    const check =
        'CHECK (ssh_ip IS NOT NULL OR monitor_addr IS NOT NULL OR is_local = 1)';
    expect(fresh, contains(localColumn));
    expect(fresh, contains(check));
    final v28 = fresh
        .replaceFirst(localColumn, '')
        .replaceFirst(
          check,
          'CHECK (ssh_ip IS NOT NULL OR monitor_addr IS NOT NULL)',
        );

    db.execute('PRAGMA foreign_keys = OFF;');
    db.execute('PRAGMA legacy_alter_table = ON;');
    db.execute('DROP TABLE server;');
    db.execute(v28);
    db.execute('PRAGMA legacy_alter_table = OFF;');
    db.execute('PRAGMA foreign_keys = ON;');
  }

  void seedServerWithChildren(String id) {
    final db = SqliteDb.instance;
    db.execute(
      'INSERT INTO server (updated_at, rev, id, name, ssh_ip, ssh_port, '
      'ssh_user, ssh_enabled, monitor_addr, monitor_enabled, '
      'preferred_transport, geo_lat, geo_lon) '
      "VALUES (1700000000, 3, '$id', 'router', '10.0.0.1', 22, 'root', 0, "
      "'https://h:3770', 1, 'monitorHttp', 1.5, 2.5);",
    );
    db.execute("INSERT INTO server_tag VALUES ('$id', 'prod');");
    db.execute("INSERT INTO server_env VALUES ('$id', 'TERM', 'xterm');");
    db.execute("INSERT INTO server_disabled_cmd VALUES ('$id', 'sensors');");
    db.execute("INSERT INTO server_custom_cmd VALUES ('$id', 'up', 'uptime');");
  }

  int count(String table) =>
      SqliteDb.instance.select('SELECT count(*) AS n FROM $table;').single['n']
          as int;

  test('adds the column and keeps every field of every server', () async {
    await createV28Schema();
    seedServerWithChildren('s-1');

    await const LocalServerMigration().apply();

    final row = SqliteDb.instance.select('SELECT * FROM server;').single;
    expect(row['is_local'], 0);
    expect(row['ssh_ip'], '10.0.0.1');
    expect(row['ssh_enabled'], 0);
    expect(row['monitor_addr'], 'https://h:3770');
    expect(row['preferred_transport'], 'monitorHttp');
    expect(row['geo_lat'], 1.5);
    // What sync reads. A rebuild that reset either would make every server
    // look freshly edited to a peer.
    expect(row['updated_at'], 1700000000);
    expect(row['rev'], 3);
  });

  test('ends in the shape a fresh install had at v29', () async {
    await createTables(SqliteDb.instance);
    replaceServerTable(serverDdlBeforePveTable(serverDdl()));
    final fresh = SqliteDb.instance
        .select('PRAGMA table_xinfo(server);')
        .map((r) => [r['name'], r['type'], r['notnull'], r['dflt_value']])
        .toList();
    await SqliteDb.close();
    SqliteDb.openInMemory();

    await createV28Schema();
    await const LocalServerMigration().apply();

    final migrated = SqliteDb.instance
        .select('PRAGMA table_xinfo(server);')
        .map((r) => [r['name'], r['type'], r['notnull'], r['dflt_value']])
        .toList();
    expect(migrated, fresh);
  });

  test('the children survive the table being dropped', () async {
    await createV28Schema();
    seedServerWithChildren('s-1');

    await const LocalServerMigration().apply();

    expect(count('server_tag'), 1);
    expect(count('server_env'), 1);
    expect(count('server_disabled_cmd'), 1);
    expect(count('server_custom_cmd'), 1);
  });

  test('the cascade still works afterwards', () async {
    await createV28Schema();
    seedServerWithChildren('s-1');

    await const LocalServerMigration().apply();
    SqliteDb.instance.execute("DELETE FROM server WHERE id = 's-1';");

    expect(count('server_tag'), 0);
    expect(count('server_env'), 0);
    expect(count('server_disabled_cmd'), 0);
    expect(count('server_custom_cmd'), 0);
  });

  test('a row with no address is accepted only when it is local', () async {
    await createV28Schema();
    await const LocalServerMigration().apply();
    final db = SqliteDb.instance;

    expect(
      () => db.execute("INSERT INTO server (id, name) VALUES ('none', 'n');"),
      throwsA(isA<SqliteException>()),
    );
    expect(
      () => db.execute(
        "INSERT INTO server (id, name, is_local) VALUES ('me', 'm', 1);",
      ),
      returnsNormally,
    );
  });

  test('the port range check survives the rebuild', () async {
    await createV28Schema();
    await const LocalServerMigration().apply();

    expect(
      () => SqliteDb.instance.execute(
        'INSERT INTO server (id, name, ssh_ip, ssh_port, ssh_user) '
        "VALUES ('bad', 'b', '10.0.0.1', 70000, 'root');",
      ),
      throwsA(isA<SqliteException>()),
    );
  });

  test('the indexes come back', () async {
    await createV28Schema();
    await const LocalServerMigration().apply();

    final names = SqliteDb.instance
        .select("SELECT name FROM sqlite_master WHERE type = 'index';")
        .map((row) => row['name'])
        .toSet();
    expect(names, containsAll(['idx_server_key', 'idx_server_bmc_cred']));
  });

  test('running it twice is harmless', () async {
    await createV28Schema();
    seedServerWithChildren('s-1');

    await const LocalServerMigration().apply();
    await const LocalServerMigration().apply();

    expect(count('server'), 1);
    expect(count('server_tag'), 1);
  });

  test('a local server round-trips through the store', () async {
    await createV28Schema();
    await const LocalServerMigration().apply();

    final store = ServerStore();
    store.put(
      Spi(
        name: 'me',
        id: 'l-1',
        local: true,
        // Parked, not dialled — and kept.
        ssh: const SshCredential(ip: '10.0.0.1'),
      ),
    );

    final read = store.fetch().single;
    expect(read.local, isTrue);
    expect(read.ssh?.ip, '10.0.0.1');
    expect(read.sshOn, isNull);
    expect(read.transport, ServerTransport.local);
  });
}
