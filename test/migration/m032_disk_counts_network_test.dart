import 'package:fl_lib/fl_lib.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/data/model/server/custom.dart';
import 'package:server_box/data/model/server/server_private_info.dart';
import 'package:server_box/data/model/server/ssh_credential.dart';
import 'package:server_box/data/store/migrations/all.dart';
import 'package:server_box/data/store/migrations/m032_disk_counts_network.dart';
import 'package:server_box/data/store/schema.dart';
import 'package:server_box/data/store/server.dart';
import 'package:server_box/data/store/tables.dart';

/// By name, not in order: `ADD COLUMN` appends, and a fresh table declares the
/// column in the middle.
Map<String, (String, bool, Object?)> _serverColumns() => {
  for (final row in SqliteDb.instance.select('PRAGMA table_info(server);'))
    row['name'] as String: (
      row['type'] as String,
      (row['notnull'] as int) == 1,
      row['dflt_value'],
    ),
};

void main() {
  setUp(() => SqliteDb.openInMemory());

  tearDown(() async {
    await closeTables();
    await SqliteDb.close();
  });

  test('is the last registered schema step', () {
    expect(const DiskCountsNetworkMigration().from, 32);
    expect(
      kSchemaMigrations.whereType<DiskCountsNetworkMigration>(),
      hasLength(1),
    );
    expect(kSchemaMigrations.last.from, SchemaVersion.current - 1);
  });

  test('adds the same column a fresh database has', () async {
    await createTables(SqliteDb.instance);
    final fresh = _serverColumns();

    await closeTables();
    await SqliteDb.close();
    SqliteDb.openInMemory();
    await createTables(SqliteDb.instance);
    // What a v32 database looks like: the table without the column.
    SqliteDb.instance.execute(
      'ALTER TABLE server DROP COLUMN disk_counts_network;',
    );
    await const DiskCountsNetworkMigration().apply();

    expect(_serverColumns(), fresh);
  });

  test('is safe to run again', () async {
    await createTables(SqliteDb.instance);
    final before = _serverColumns();
    await const DiskCountsNetworkMigration().apply();
    expect(_serverColumns(), before);
  });

  /// A server written before the column keeps no `custom` it did not have:
  /// the column's default is the empty record's value.
  test('a server written before the column is unchanged', () async {
    await createTables(SqliteDb.instance);
    SqliteDb.instance.execute(
      'ALTER TABLE server DROP COLUMN disk_counts_network;',
    );
    SqliteDb.instance.execute(
      'INSERT INTO server (id, name, ssh_ip, ssh_port, ssh_user) '
      "VALUES ('s1', 'old', '10.0.0.1', 22, 'root');",
    );

    await const DiskCountsNetworkMigration().apply();

    final spi = ServerStore().fetchOneRaw('s1');
    expect(spi, isNotNull);
    expect(spi!.custom, isNull);
  });

  test('the switch survives the round trip', () async {
    await createTables(SqliteDb.instance);
    final store = ServerStore();
    const spi = Spi(
      name: 'nas-client',
      id: 's2',
      ssh: SshCredential(ip: '10.0.0.2', port: 22, user: 'root'),
      custom: ServerCustom(tempIsCelsius: true, diskCountsNetwork: true),
    );
    store.put(spi);

    final read = store.fetchOneRaw('s2')!;
    expect(read.custom?.diskCountsNetwork, isTrue);
  });
}
