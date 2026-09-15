/// The step that lets one server carry SSH and a monitor agent at once.
///
/// Worth more care than most: SQLite cannot drop a table constraint, so this
/// rebuilds `server` — and `server` is the parent of six child tables with
/// `ON DELETE CASCADE`. Get the foreign-key pragma wrong and dropping the old
/// table takes every tag, jump, env and custom command with it, silently, on
/// the one launch that runs the step.
library;

import 'package:fl_lib/fl_lib.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/data/model/server/monitor_http_credential.dart';
import 'package:server_box/data/model/server/server_private_info.dart';
import 'package:server_box/data/model/server/ssh_credential.dart';
import 'package:server_box/data/store/migrations/all.dart';
import 'package:server_box/data/store/migrations/m017_both_transports.dart';
import 'package:server_box/data/store/server.dart';
import 'package:server_box/data/store/tables.dart';
import 'package:sqlite3/sqlite3.dart';

void main() {
  setUp(SqliteDb.openInMemory);
  tearDown(SqliteDb.close);

  /// The v17 shape: the current one, less the column this step adds and with
  /// the exclusivity check it relaxes put back.
  ///
  /// Rebuilt by hand rather than derived, because that is the difference —
  /// `createTables` produces the *new* constraint, and a test that started
  /// from it would never exercise the thing this step exists to change.
  Future<void> createV17Schema() async {
    final db = SqliteDb.instance;
    await createTables(db);
    db.execute('PRAGMA foreign_keys = OFF;');
    db.execute('PRAGMA legacy_alter_table = ON;');
    db.execute('ALTER TABLE server RENAME TO server_new;');
    db.execute('''
      CREATE TABLE server (
        updated_at INTEGER NOT NULL DEFAULT 0,
        rev INTEGER NOT NULL DEFAULT 0,
        id TEXT NOT NULL,
        name TEXT NOT NULL,
        auto_connect INTEGER NOT NULL DEFAULT 1,
        system_type TEXT,
        ssh_ip TEXT,
        ssh_port INTEGER,
        ssh_user TEXT,
        ssh_pwd TEXT,
        ssh_key_id TEXT REFERENCES private_key(id) ON DELETE SET NULL,
        ssh_key_path TEXT,
        ssh_alter_url TEXT,
        ssh_proxy_command TEXT,
        ssh_file_transport TEXT,
        monitor_addr TEXT,
        monitor_user TEXT,
        monitor_pwd TEXT,
        monitor_ignore_cert INTEGER,
        monitor_allow_insecure INTEGER,
        wol_mac TEXT,
        wol_ip TEXT,
        wol_pwd TEXT,
        bmc_addr TEXT,
        bmc_cert_sha256 TEXT,
        bmc_cred_id TEXT REFERENCES bmc_credential(id) ON DELETE SET NULL,
        pve_addr TEXT,
        pve_ignore_cert INTEGER NOT NULL DEFAULT 0,
        pve_pwd TEXT,
        prefer_temp_dev TEXT,
        temp_is_celsius INTEGER NOT NULL DEFAULT 1,
        logo_url TEXT,
        net_dev TEXT,
        script_dir TEXT,
        PRIMARY KEY (id),
        CHECK ((ssh_ip IS NOT NULL) <> (monitor_addr IS NOT NULL)),
        CHECK (ssh_port IS NULL OR ssh_port BETWEEN 1 AND 65535)
      ) WITHOUT ROWID;
    ''');
    db.execute('DROP TABLE server_new;');
    db.execute('PRAGMA legacy_alter_table = OFF;');
    db.execute('PRAGMA foreign_keys = ON;');
  }

  void seedServerWithChildren(String id) {
    final db = SqliteDb.instance;
    db.execute(
      'INSERT INTO server (updated_at, rev, id, name, ssh_ip, ssh_port, '
      'ssh_user, ssh_file_transport) '
      "VALUES (1700000000, 3, '$id', 'router', '10.0.0.1', 22, 'root', 'scp');",
    );
    db.execute("INSERT INTO server_tag VALUES ('$id', 'prod');");
    db.execute("INSERT INTO server_env VALUES ('$id', 'TERM', 'xterm');");
    db.execute("INSERT INTO server_disabled_cmd VALUES ('$id', 'sensors');");
    db.execute("INSERT INTO server_custom_cmd VALUES ('$id', 'up', 'uptime');");
  }

  int count(String table) =>
      SqliteDb.instance.select('SELECT count(*) AS n FROM $table;').single['n']
          as int;

  List<String> columns() => SqliteDb.instance
      .select('PRAGMA table_info(server);')
      .map((column) => column['name'] as String)
      .toList();

  /// This step, and then every step registered after it.
  ///
  /// Only the store round-trip below wants this. That test writes through
  /// today's [ServerStore], which names today's columns — so stopping at the
  /// step under test fails on whichever column a later step added, and reports
  /// it as the round trip being broken rather than as the test having stopped
  /// too early. Every other test here asserts what *this* step produces and
  /// must not run anything past it.
  Future<void> applyThisAndEverythingAfter() async {
    const step = BothTransportsMigration();
    final rest =
        kSchemaMigrations.where((m) => m.from >= step.from).toList()
          ..sort((a, b) => a.from.compareTo(b.from));
    for (final m in rest) {
      await m.apply();
    }
  }

  test('adds the column and keeps every server', () async {
    await createV17Schema();
    seedServerWithChildren('s-1');

    await const BothTransportsMigration().apply();

    expect(columns(), contains('preferred_transport'));
    final row = SqliteDb.instance.select('SELECT * FROM server;').single;
    expect(row['id'], 's-1');
    expect(row['ssh_ip'], '10.0.0.1');
    expect(row['ssh_file_transport'], 'scp');
    // The columns sync reads. A rebuild that reset either would make every
    // server look freshly edited to a peer.
    expect(row['updated_at'], 1700000000);
    expect(row['rev'], 3);
    // Null: no existing row can have both, so none of them has anything to
    // prefer.
    expect(row['preferred_transport'], isNull);
  });

  test('the children survive the table being dropped', () async {
    // The reason this step is not a one-liner. `server` is dropped and
    // recreated, and six tables cascade off it — with `foreign_keys` left on,
    // the drop would take all of their rows and nothing would say so.
    await createV17Schema();
    seedServerWithChildren('s-1');

    await const BothTransportsMigration().apply();

    expect(count('server_tag'), 1);
    expect(count('server_env'), 1);
    expect(count('server_disabled_cmd'), 1);
    expect(count('server_custom_cmd'), 1);
  });

  test('the cascade still works afterwards', () async {
    // The other half: the pragma has to be *restored*. Left off, every cascade
    // in the app is disarmed for the life of the connection, and deleting a
    // server would leave its children behind as orphans.
    await createV17Schema();
    seedServerWithChildren('s-1');

    await const BothTransportsMigration().apply();
    SqliteDb.instance.execute("DELETE FROM server WHERE id = 's-1';");

    expect(count('server_tag'), 0);
    expect(count('server_env'), 0);
    expect(count('server_disabled_cmd'), 0);
    expect(count('server_custom_cmd'), 0);
  });

  test('a server may then carry both, which it could not before', () async {
    await createV17Schema();

    expect(
      () => SqliteDb.instance.execute(
        'INSERT INTO server (id, name, ssh_ip, ssh_port, ssh_user, '
        'monitor_addr) '
        "VALUES ('both', 'b', '10.0.0.1', 22, 'root', 'https://h:3770');",
      ),
      throwsA(isA<SqliteException>()),
    );

    await const BothTransportsMigration().apply();

    expect(
      () => SqliteDb.instance.execute(
        'INSERT INTO server (id, name, ssh_ip, ssh_port, ssh_user, '
        'monitor_addr) '
        "VALUES ('both', 'b', '10.0.0.1', 22, 'root', 'https://h:3770');",
      ),
      returnsNormally,
    );
  });

  test('and still may not carry neither', () async {
    await createV17Schema();
    await const BothTransportsMigration().apply();

    expect(
      () => SqliteDb.instance.execute(
        "INSERT INTO server (id, name) VALUES ('empty', 'e');",
      ),
      throwsA(isA<SqliteException>()),
    );
  });

  test('the port range check survives the rebuild', () async {
    // The rebuild rewrites *both* constraints, so the one that was not the
    // point of the exercise has to come out the other side intact.
    await createV17Schema();
    await const BothTransportsMigration().apply();

    expect(
      () => SqliteDb.instance.execute(
        'INSERT INTO server (id, name, ssh_ip, ssh_port, ssh_user) '
        "VALUES ('bad', 'b', '10.0.0.1', 70000, 'root');",
      ),
      throwsA(isA<SqliteException>()),
    );
  });

  test('a round trip through the store keeps both credentials', () async {
    await createV17Schema();
    await applyThisAndEverythingAfter();

    final store = ServerStore();
    store.put(
      Spi(
        name: 'both',
        id: 'b-1',
        ssh: const SshCredential(ip: '10.0.0.1'),
        monitorHttp: const MonitorHttpCredential(addr: 'https://h:3770'),
        preferredTransport: ServerTransport.monitorHttp,
      ),
    );

    final read = store.fetch().single;
    expect(read.ssh?.ip, '10.0.0.1');
    expect(read.monitor?.addr, 'https://h:3770');
    expect(read.transport, ServerTransport.monitorHttp);
    expect(read.fallbackTransport, ServerTransport.ssh);
  });

  test('the indexes on server come back', () async {
    // `DROP TABLE` takes them with it, and Drift only creates indexes on
    // `onCreate` — which an upgrading install never reaches. Both of these
    // also serve an `ON DELETE SET NULL`, so without them deleting a key or a
    // BMC account scans `server` once per row deleted, for good.
    await createV17Schema();

    await const BothTransportsMigration().apply();

    final names = SqliteDb.instance
        .select("SELECT name FROM sqlite_master WHERE type = 'index';")
        .map((row) => row['name'])
        .toSet();
    expect(names, contains('idx_server_key'));
    expect(names, contains('idx_server_bmc_cred'));
  });

  test('runs again without complaining', () async {
    // The version is recorded only once every statement has run, so a process
    // stopped partway means the whole step runs again.
    await createV17Schema();
    seedServerWithChildren('s-1');

    await const BothTransportsMigration().apply();
    await const BothTransportsMigration().apply();

    expect(columns().where((c) => c == 'preferred_transport'), hasLength(1));
    expect(count('server'), 1);
    expect(count('server_tag'), 1);
  });
}
