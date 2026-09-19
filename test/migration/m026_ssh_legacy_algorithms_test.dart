import 'package:fl_lib/fl_lib.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/data/model/server/server_private_info.dart';
import 'package:server_box/data/model/server/ssh_credential.dart';
import 'package:server_box/data/store/migrations/all.dart';
import 'package:server_box/data/store/migrations/m026_ssh_legacy_algorithms.dart';
import 'package:server_box/data/store/schema.dart';
import 'package:server_box/data/store/server.dart';
import 'package:server_box/data/store/tables.dart';

/// By name, not in order: `ADD COLUMN` appends, and a fresh table declares the
/// column in the middle. Nothing reads this table by position — the store names
/// every column it writes — so the order is not what has to match.
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

  test('is registered at its own step', () {
    // The chain's last step is asserted where that step lives; what matters
    // here is that this one is in the list at the version it claims, since a
    // step missing from `kSchemaMigrations` is a launch that throws on a real
    // install and nothing in this file's other tests would notice.
    expect(const SshLegacyAlgorithmsMigration().from, 26);
    expect(
      kSchemaMigrations.whereType<SshLegacyAlgorithmsMigration>(),
      hasLength(1),
    );
    expect(SchemaVersion.current, greaterThan(26));
    expect(kSchemaMigrations.last.from, SchemaVersion.current - 1);
  });

  test('adds the same column a fresh database has', () async {
    await createTables(SqliteDb.instance);
    final fresh = _serverColumns();

    await closeTables();
    await SqliteDb.close();
    SqliteDb.openInMemory();
    await createTables(SqliteDb.instance);
    // What a v26 database looks like: the table without the switch.
    SqliteDb.instance.execute(
      'ALTER TABLE server DROP COLUMN ssh_allow_legacy_algorithms;',
    );
    await const SshLegacyAlgorithmsMigration().apply();

    expect(_serverColumns(), fresh);
  });

  test('is safe to run again', () async {
    await createTables(SqliteDb.instance);
    final before = _serverColumns();
    await const SshLegacyAlgorithmsMigration().apply();
    expect(_serverColumns(), before);
  });

  /// The default is the whole safety of it: a server written before the column
  /// was one of the many that never needed a retired algorithm, and has to go
  /// on proposing exactly what it did.
  test('a server written before the column is not opted in', () async {
    await createTables(SqliteDb.instance);
    SqliteDb.instance.execute(
      'ALTER TABLE server DROP COLUMN ssh_allow_legacy_algorithms;',
    );
    SqliteDb.instance.execute(
      'INSERT INTO server (id, name, ssh_ip, ssh_port, ssh_user, monitor_addr) '
      "VALUES ('s1', 'old', '10.0.0.1', 22, 'root', 'https://agent:3770');",
    );

    await const SshLegacyAlgorithmsMigration().apply();

    final spi = ServerStore().fetchOneRaw('s1');
    expect(spi, isNotNull);
    expect(spi!.ssh?.allowLegacyAlgorithms, isFalse);
  });

  test('the switch survives the round trip', () async {
    await createTables(SqliteDb.instance);
    final store = ServerStore();
    const spi = Spi(
      name: 'router',
      id: 's2',
      ssh: SshCredential(
        ip: '10.0.0.2',
        port: 22,
        user: 'root',
        allowLegacyAlgorithms: true,
      ),
    );
    store.put(spi);

    final read = store.fetchOneRaw('s2')!;
    expect(read.ssh?.allowLegacyAlgorithms, isTrue);
  });
}
