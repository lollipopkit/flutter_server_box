import 'package:fl_lib/fl_lib.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/data/store/migrations/m006_bmc_columns.dart';

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

  test('adds the four BMC columns without changing existing rows', () async {
    createV6Server();
    SqliteDb.instance.execute(
      "INSERT INTO server VALUES ('srv-1', 'prod', '10.0.0.1', NULL);",
    );

    await const BmcColumnsMigration().apply();

    final row = SqliteDb.instance.select('SELECT * FROM server;').single;
    expect(row['name'], 'prod');
    expect(row['ssh_ip'], '10.0.0.1');
    // A server that had no BMC before the migration still has none after it.
    // The columns exist; nothing was invented to fill them.
    expect(row['bmc_addr'], isNull);
    expect(row['bmc_user'], isNull);
    expect(row['bmc_pwd'], isNull);
    expect(row['bmc_cert_sha256'], isNull);
  });

  test('runs again after being interrupted between the ALTERs', () async {
    createV6Server();
    // What a process stopping mid-step leaves: the first two columns committed,
    // the version not yet recorded, so the whole migration runs again. Without
    // the per-column check the retry fails on `duplicate column name`, and the
    // step can never finish.
    SqliteDb.instance.execute('ALTER TABLE server ADD COLUMN bmc_addr TEXT;');
    SqliteDb.instance.execute('ALTER TABLE server ADD COLUMN bmc_user TEXT;');

    await const BmcColumnsMigration().apply();

    final columns = SqliteDb.instance
        .select('PRAGMA table_info(server);')
        .map((column) => column['name'] as String)
        .toList();
    for (final expected in const [
      'bmc_addr',
      'bmc_user',
      'bmc_pwd',
      'bmc_cert_sha256',
    ]) {
      expect(
        columns.where((c) => c == expected),
        hasLength(1),
        reason: '$expected should exist exactly once',
      );
    }
  });

  test('is idempotent', () async {
    createV6Server();
    await const BmcColumnsMigration().apply();
    await const BmcColumnsMigration().apply();

    final columns = SqliteDb.instance
        .select('PRAGMA table_info(server);')
        .map((column) => column['name'] as String)
        .where((name) => name.startsWith('bmc_'));
    expect(columns, hasLength(4));
  });
}
