import 'package:fl_lib/fl_lib.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/data/store/migrations/m006_bmc_columns.dart';

/// The columns the step adds to `server`. The account itself is a table, not a
/// column: see `BmcCredential`.
const _added = ['bmc_addr', 'bmc_cert_sha256', 'bmc_cred_id'];

void main() {
  setUp(SqliteDb.openInMemory);
  tearDown(SqliteDb.close);

  /// The v6 shape: everything up to the monitor plaintext opt-in, and no BMC.
  void createV6Server() {
    SqliteDb.instance.execute(
      'CREATE TABLE server ('
      'id TEXT PRIMARY KEY, name TEXT, ssh_ip TEXT, monitor_allow_insecure INTEGER'
      ');',
    );
  }

  List<String> serverColumns() => SqliteDb.instance
      .select('PRAGMA table_info(server);')
      .map((column) => column['name'] as String)
      .toList();

  test('adds the account table and the columns naming one device', () async {
    createV6Server();
    SqliteDb.instance.execute(
      "INSERT INTO server VALUES ('srv-1', 'prod', '10.0.0.1', NULL);",
    );

    await const BmcColumnsMigration().apply();

    final row = SqliteDb.instance.select('SELECT * FROM server;').single;
    expect(row['name'], 'prod');
    expect(row['ssh_ip'], '10.0.0.1');
    // A server that had no BMC before still has none after. The columns exist;
    // nothing was invented to fill them.
    for (final column in _added) {
      expect(row[column], isNull, reason: column);
    }

    expect(
      SqliteDb.instance.select(
        "SELECT name FROM sqlite_master WHERE type='table' AND name='bmc_credential';",
      ),
      hasLength(1),
    );
  });

  test('the account reference carries its foreign key', () async {
    createV6Server();
    await const BmcColumnsMigration().apply();

    // Added by `ALTER TABLE`, which is the one place the schema could end up
    // differing from what Drift creates on a fresh install — and the
    // difference would be silent: `ON DELETE SET NULL` not firing, so deleting
    // an account leaves every server that used it pointing at a row that is
    // gone.
    final fks = SqliteDb.instance.select('PRAGMA foreign_key_list(server);');
    final toCredential = fks.where((fk) => fk['table'] == 'bmc_credential');
    expect(toCredential, hasLength(1));
    expect(toCredential.single['from'], 'bmc_cred_id');
    expect(toCredential.single['to'], 'id');
    expect(toCredential.single['on_delete'], 'SET NULL');
  });

  test('deleting an account keeps the servers that used it', () async {
    createV6Server();
    await const BmcColumnsMigration().apply();

    // The previous test reads the declaration; this one runs it. A REFERENCES
    // clause on ADD COLUMN is accepted whether or not the pragma that enforces
    // it is on, so the declaration being right is not the same fact as the
    // action firing.
    SqliteDb.instance.execute('PRAGMA foreign_keys = ON;');
    SqliteDb.instance.execute(
      'INSERT INTO bmc_credential (id, name, user, pwd) '
      "VALUES ('cred-1', 'rack-a', 'admin', 'pw');",
    );
    SqliteDb.instance.execute(
      'INSERT INTO server (id, name, bmc_addr, bmc_cred_id) '
      "VALUES ('srv-1', 'prod', 'https://10.0.0.9', 'cred-1');",
    );

    SqliteDb.instance.execute("DELETE FROM bmc_credential WHERE id = 'cred-1';");

    final row = SqliteDb.instance.select('SELECT * FROM server;').single;
    expect(row['id'], 'srv-1', reason: 'the server outlives the account');
    expect(row['bmc_addr'], 'https://10.0.0.9', reason: 'and keeps its address');
    expect(row['bmc_cred_id'], isNull);
  });

  test('the lookup by account is indexed', () async {
    createV6Server();
    await const BmcColumnsMigration().apply();

    // `db.dart` lists this index too, but that list runs from Drift's
    // `onCreate` and so only ever reaches a database being created. Without it
    // here, an upgrading install differs from a fresh one and "how many
    // servers use this account" is a full scan on every rebuild of the editor.
    final indexes = SqliteDb.instance
        .select('PRAGMA index_list(server);')
        .map((row) => row['name'] as String);
    expect(indexes, contains('idx_server_bmc_cred'));
  });

  test('runs again after being interrupted partway', () async {
    createV6Server();
    // What a process stopping mid-step leaves: the table and the first column
    // committed, the version not yet recorded, so the whole migration runs
    // again. Without the guards the retry fails on `duplicate column name`,
    // and the step can never finish.
    SqliteDb.instance.execute(
      'CREATE TABLE bmc_credential (id TEXT NOT NULL PRIMARY KEY, '
      'name TEXT NOT NULL UNIQUE, user TEXT NOT NULL, pwd TEXT, '
      'updated_at INTEGER NOT NULL DEFAULT 0, rev INTEGER NOT NULL DEFAULT 0'
      ') WITHOUT ROWID;',
    );
    SqliteDb.instance.execute('ALTER TABLE server ADD COLUMN bmc_addr TEXT;');

    await const BmcColumnsMigration().apply();

    final columns = serverColumns();
    for (final column in _added) {
      expect(
        columns.where((c) => c == column),
        hasLength(1),
        reason: '$column should exist exactly once',
      );
    }
  });

  test('is idempotent', () async {
    createV6Server();
    await const BmcColumnsMigration().apply();
    await const BmcColumnsMigration().apply();

    expect(serverColumns().where((c) => c.startsWith('bmc_')), hasLength(3));
  });
}
