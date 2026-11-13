import 'dart:io';

import 'package:fl_lib/fl_lib.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/data/model/server/server_private_info.dart';
import 'package:server_box/data/model/server/ssh_credential.dart';
import 'package:server_box/data/store/migrations/all.dart';
import 'package:server_box/data/store/migrations/m040_ssh_forward_agent.dart';
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

/// `server` as v40 created it: the DDL that release's Drift wrote, kept in
/// `test/fixtures/schema/` and never regenerated.
Future<void> createV40Server() async {
  await createTables(SqliteDb.instance);
  replaceServerTable(
    File('test/fixtures/schema/server_v40.sql').readAsStringSync(),
  );
}

void main() {
  setUp(() => SqliteDb.openInMemory());

  tearDown(() async {
    await closeTables();
    await SqliteDb.close();
  });

  test('is registered at its own step', () {
    expect(const SshForwardAgentMigration().from, 40);
    expect(
      kSchemaMigrations.whereType<SshForwardAgentMigration>(),
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
    await createV40Server();
    await const SshForwardAgentMigration().apply();

    expect(_serverColumns(), fresh);
  });

  test('is safe to run again', () async {
    await createTables(SqliteDb.instance);
    final before = _serverColumns();
    await const SshForwardAgentMigration().apply();
    expect(_serverColumns(), before);
  });

  test('a server written before the column does not forward', () async {
    await createV40Server();
    SqliteDb.instance.execute(
      'INSERT INTO server (id, name, ssh_ip, ssh_port, ssh_user, '
      'ssh_identity_agent) '
      "VALUES ('s1', 'old', '10.0.0.1', 22, 'root', 'SSH_AUTH_SOCK');",
    );

    await const SshForwardAgentMigration().apply();

    final ssh = ServerStore().fetchOneRaw('s1')!.ssh!;
    expect(ssh.identityAgent, SshCredential.authSock);
    expect(ssh.forwardAgent, isFalse);
  });

  test('the switch survives the round trip', () async {
    await createTables(SqliteDb.instance);
    final store = ServerStore();
    const spi = Spi(
      name: 'box',
      id: 's2',
      ssh: SshCredential(
        ip: '10.0.0.2',
        identityAgent: SshCredential.authSock,
        forwardAgent: true,
      ),
    );
    store.put(spi);

    expect(store.fetchOneRaw('s2')!.ssh?.forwardAgent, isTrue);
    expect(SshCredential.fromJson(spi.ssh!.toJson()).forwardAgent, isTrue);
  });
}
