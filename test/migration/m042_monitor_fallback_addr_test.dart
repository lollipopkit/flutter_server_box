import 'dart:io';

import 'package:fl_lib/fl_lib.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/data/model/server/monitor/monitor_http_credential.dart';
import 'package:server_box/data/model/server/server_private_info.dart';
import 'package:server_box/data/store/migrations/all.dart';
import 'package:server_box/data/store/migrations/m042_monitor_fallback_addr.dart';
import 'package:server_box/data/store/migrations/m043_bmc_target.dart';
import 'package:server_box/data/store/schema.dart';
import 'package:server_box/data/store/server.dart';
import 'package:server_box/data/store/tables.dart';

import '../helpers/server_ddl.dart';

/// Each `server` column by name.
Map<String, (String, bool, Object?)> _serverColumns() => {
  for (final row in SqliteDb.instance.select('PRAGMA table_info(server);'))
    row['name'] as String: (
      row['type'] as String,
      (row['notnull'] as int) == 1,
      row['dflt_value'],
    ),
};

/// `server` as v42 created it: the DDL that release's Drift wrote, kept in
/// `test/fixtures/schema/` and never regenerated.
Future<void> createV42Server() async {
  await createTables(SqliteDb.instance);
  replaceServerTable(
    File('test/fixtures/schema/server_v42.sql').readAsStringSync(),
  );
}

void main() {
  setUp(() => SqliteDb.openInMemory());

  tearDown(() async {
    await closeTables();
    await SqliteDb.close();
  });

  test('is registered at its own step', () {
    expect(const MonitorFallbackAddrMigration().from, 42);
    expect(
      kSchemaMigrations.whereType<MonitorFallbackAddrMigration>(),
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
    await createV42Server();
    await const MonitorFallbackAddrMigration().apply();
    // The steps since that touch `server`.
    await const BmcTargetMigration().apply();

    expect(_serverColumns(), fresh);
  });

  test('is safe to run again', () async {
    await createTables(SqliteDb.instance);
    final before = _serverColumns();
    await const MonitorFallbackAddrMigration().apply();
    expect(_serverColumns(), before);
  });

  test('a server written before the column has no fallback', () async {
    await createV42Server();
    SqliteDb.instance.execute(
      'INSERT INTO server (id, name, monitor_addr) '
      "VALUES ('s1', 'old', 'https://10.0.0.1:3770');",
    );

    await const MonitorFallbackAddrMigration().apply();

    final monitor = ServerStore().fetchOneRaw('s1')!.monitorHttp!;
    expect(monitor.addr, 'https://10.0.0.1:3770');
    expect(monitor.fallbackAddr, isNull);
  });

  test('the fallback survives the round trip', () async {
    await createTables(SqliteDb.instance);
    final store = ServerStore();
    const spi = Spi(
      name: 'agent',
      id: 's2',
      monitorHttp: MonitorHttpCredential(
        addr: 'https://192.168.1.2:3770',
        fallbackAddr: 'https://100.64.0.2:3770',
      ),
    );
    store.put(spi);

    expect(
      store.fetchOneRaw('s2')!.monitorHttp?.fallbackAddr,
      'https://100.64.0.2:3770',
    );
    expect(
      MonitorHttpCredential.fromJson(spi.monitorHttp!.toJson()).fallbackAddr,
      'https://100.64.0.2:3770',
    );
  });
}
