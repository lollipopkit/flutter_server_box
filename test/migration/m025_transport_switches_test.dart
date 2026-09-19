import 'package:fl_lib/fl_lib.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/data/model/server/monitor_http_credential.dart';
import 'package:server_box/data/model/server/server_private_info.dart';
import 'package:server_box/data/model/server/ssh_credential.dart';
import 'package:server_box/data/store/migrations/all.dart';
import 'package:server_box/data/store/migrations/m025_transport_switches.dart';
import 'package:server_box/data/store/schema.dart';
import 'package:server_box/data/store/server.dart';
import 'package:server_box/data/store/tables.dart';

/// By name, not in order: `ADD COLUMN` appends, and a fresh table declares
/// these two in the middle. Nothing reads this table by position — the store
/// names every column it writes — so the order is not what has to match.
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

  test('is the registered final step', () {
    expect(const TransportSwitchesMigration().from, 25);
    expect(SchemaVersion.current, 26);
    expect(kSchemaMigrations.last, isA<TransportSwitchesMigration>());
    expect(kSchemaMigrations.last.from, SchemaVersion.current - 1);
  });

  test('adds the same columns a fresh database has', () async {
    await createTables(SqliteDb.instance);
    final fresh = _serverColumns();

    await closeTables();
    await SqliteDb.close();
    SqliteDb.openInMemory();
    await createTables(SqliteDb.instance);
    // What a v25 database looks like: the table without the two switches.
    SqliteDb.instance.execute('ALTER TABLE server DROP COLUMN ssh_enabled;');
    SqliteDb.instance.execute(
      'ALTER TABLE server DROP COLUMN monitor_enabled;',
    );
    await const TransportSwitchesMigration().apply();

    expect(_serverColumns(), fresh);
  });

  test('is safe to run again', () async {
    await createTables(SqliteDb.instance);
    final before = _serverColumns();
    await const TransportSwitchesMigration().apply();
    expect(_serverColumns(), before);
  });

  /// The migration's whole purpose: a server that predates the switches is one
  /// that dialled everything it had configured, and it has to go on doing that.
  test('a server written before the switches keeps both ways in', () async {
    await createTables(SqliteDb.instance);
    SqliteDb.instance.execute('ALTER TABLE server DROP COLUMN ssh_enabled;');
    SqliteDb.instance.execute(
      'ALTER TABLE server DROP COLUMN monitor_enabled;',
    );
    SqliteDb.instance.execute(
      'INSERT INTO server (id, name, ssh_ip, ssh_port, ssh_user, monitor_addr) '
      "VALUES ('s1', 'old', '10.0.0.1', 22, 'root', 'https://agent:3770');",
    );

    await const TransportSwitchesMigration().apply();

    final spi = ServerStore().fetchOneRaw('s1');
    expect(spi, isNotNull);
    expect(spi!.sshEnabled, isTrue);
    expect(spi.monitorEnabled, isTrue);
    expect(spi.sshOn, isNotNull);
    expect(spi.monitorOn, isNotNull);
  });

  test('a switched-off method survives the round trip', () async {
    await createTables(SqliteDb.instance);
    final store = ServerStore();
    const spi = Spi(
      name: 'both',
      id: 's2',
      ssh: SshCredential(ip: '10.0.0.2', port: 22, user: 'root'),
      monitorHttp: MonitorHttpCredential(addr: 'https://agent:3770'),
      monitorEnabled: false,
    );
    store.put(spi);

    final read = store.fetchOneRaw('s2')!;
    // The configuration is still there — that is what "off" means — and
    // nothing reaching the machine is allowed to see it.
    expect(read.monitorHttp?.addr, 'https://agent:3770');
    expect(read.monitorEnabled, isFalse);
    expect(read.monitorOn, isNull);
    expect(read.sshOn, isNotNull);
  });
}
