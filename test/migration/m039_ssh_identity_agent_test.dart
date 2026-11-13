import 'package:fl_lib/fl_lib.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/data/model/server/server_private_info.dart';
import 'package:server_box/data/model/server/ssh_credential.dart';
import 'package:server_box/data/store/migrations/all.dart';
import 'package:server_box/data/store/migrations/m039_ssh_identity_agent.dart';
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

/// `server` as v39 created it: today's table less the column, derived and
/// asserted by [serverDdlBeforeIdentityAgent].
Future<void> createV39Server() async {
  await createTables(SqliteDb.instance);
  replaceServerTable(serverDdlBeforeIdentityAgent(freshServerDdl()));
}

void main() {
  setUp(() => SqliteDb.openInMemory());

  tearDown(() async {
    await closeTables();
    await SqliteDb.close();
  });

  test('is registered at its own step', () {
    expect(const SshIdentityAgentMigration().from, 39);
    expect(
      kSchemaMigrations.whereType<SshIdentityAgentMigration>(),
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
    await createV39Server();
    await const SshIdentityAgentMigration().apply();

    expect(_serverColumns(), fresh);
  });

  test('is safe to run again', () async {
    await createTables(SqliteDb.instance);
    final before = _serverColumns();
    await const SshIdentityAgentMigration().apply();
    expect(_serverColumns(), before);
  });

  test('a server written before the column offers no agent', () async {
    await createV39Server();
    SqliteDb.instance.execute(
      'INSERT INTO server (id, name, ssh_ip, ssh_port, ssh_user) '
      "VALUES ('s1', 'old', '10.0.0.1', 22, 'root');",
    );

    await const SshIdentityAgentMigration().apply();

    expect(ServerStore().fetchOneRaw('s1')!.ssh?.identityAgent, isNull);
  });

  test('the agent survives the round trip', () async {
    await createTables(SqliteDb.instance);
    final store = ServerStore();
    const spi = Spi(
      name: 'box',
      id: 's2',
      ssh: SshCredential(
        ip: '10.0.0.2',
        identityAgent: '~/.1password/agent.sock',
      ),
    );
    store.put(spi);

    expect(
      store.fetchOneRaw('s2')!.ssh?.identityAgent,
      '~/.1password/agent.sock',
    );
    expect(
      SshCredential.fromJson(spi.ssh!.toJson()).identityAgent,
      '~/.1password/agent.sock',
    );
  });
}
