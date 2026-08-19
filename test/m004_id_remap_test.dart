import 'dart:convert';

import 'package:fl_lib/fl_lib.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/data/model/container/type.dart';
import 'package:server_box/data/store/agent_conversation.dart';
import 'package:server_box/data/store/container.dart';
import 'package:server_box/data/store/migrations/m004_kv_to_tables.dart';
import 'package:server_box/data/store/port_forward.dart';
import 'package:server_box/data/store/server.dart';
import 'package:server_box/data/store/snippet.dart';

import 'helpers/test_db.dart';

/// A server stored before 1155 has an **empty** `id`, so an empty primary key
/// is what `KvToTablesMigration` would have to write — and it generates one
/// instead. Everything that named the old key has to follow it in the same
/// pass; nothing runs afterwards that could.
///
/// The input here is hand-written because m004's input is not a release
/// artifact: it consumes what `HiveImport` leaves in `kv`, which is this
/// repo's own intermediate. The one thing that *is* a fact about a released
/// build — that such a server arrives with `id == ''` — is checked against the
/// 1466 fixture in `hive_release_migration_test.dart`, so this seed cannot
/// drift away from what a real upgrade produces without that test failing.
///
/// The key below is the `user@ip:port` form such an install used. Any string
/// would do: what is under test is that the *reference* is rewritten, not what
/// it looked like.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ServerStore servers;

  /// The old key, and what the app wrote into every record that referenced it.
  const legacyRef = 'root@10.0.0.1:22';

  setUp(() async {
    await openTestDb();
    servers = ServerStore.forTest();
  });

  tearDown(SqliteDb.close);

  void seed(String store, String key, Object value) {
    SqliteDb.instance.execute(
      'INSERT INTO kv (store, key, value, updated_at) VALUES (?, ?, ?, 0);',
      [store, key, json.encode(value)],
    );
  }

  /// Written the way 1466 wrote it: no id of its own, keyed by the connection.
  void seedLegacyServer() => seed('server', legacyRef, {
    'id': '',
    'name': 'legacy',
    'ssh': {'ip': '10.0.0.1', 'port': 22, 'user': 'root'},
  });

  Future<String> migrate() async {
    await const KvToTablesMigration().apply();
    servers.dropCache();
    return servers.fetch().single.id;
  }

  test('the server is given a real id', () async {
    seedLegacyServer();

    final id = await migrate();

    expect(id, isNotEmpty);
    expect(id, isNot(legacyRef), reason: 'an id is not a connection string');
  });

  test('an agent conversation follows it, in the column and in the JSON',
      () async {
    // The store rebuilds a conversation from `data` and compares the
    // `serverId` it finds there against the server it was asked about. A
    // payload still naming the old key left the conversation reachable by no
    // path at all: not `fetchActive`, not `setActive`, not delete.
    seedLegacyServer();
    seed('agent_conversation', 'conversation::conv-1', {
      'id': 'conv-1',
      'server_id': legacyRef,
      'title': 'disk is filling up',
      'created_at': '2026-01-01T00:00:00.000',
      'updated_at': '2026-01-02T00:00:00.000',
      'protocol': 'responses',
      'provider_base_url': 'https://api.openai.com',
      'model': 'gpt-test',
      'items': <Object>[],
    });
    seed('agent_conversation', 'active::$legacyRef', 'conv-1');

    final id = await migrate();
    final store = AgentConversationStore.forTest();

    expect(store.activeConversationId(id), 'conv-1');
    expect(store.fetchForServer(id).single.serverId, id);
    // The one that reads the column and the payload together.
    expect(store.fetchActive(id)?.id, 'conv-1');
    expect(store.fetchForServer(legacyRef), isEmpty);
  });

  test('a snippet auto-run target follows it', () async {
    seedLegacyServer();
    seed('snippet', 'deploy', {
      'name': 'deploy',
      'script': 'systemctl restart app',
      'autoRunOn': [legacyRef],
    });

    final id = await migrate();

    expect(SnippetStore.forTest().fetch().single.autoRunOn, [id]);
  });

  test('a port forward follows it', () async {
    seedLegacyServer();
    seed('port_forward', 'pf-1', {
      'id': 'pf-1',
      'serverId': legacyRef,
      'name': 'postgres',
      'type': 'local',
      'localPort': 15432,
    });

    final id = await migrate();

    expect(PortForwardStore.forTest().fetchForServer(id).single.id, 'pf-1');
  });

  test('a container host follows it', () async {
    seedLegacyServer();
    seed('docker', 'containerHostdocker$legacyRef', 'tcp://10.0.0.1:2375');

    final id = await migrate();

    expect(
      ContainerStore.forTest().fetch(id, ContainerType.docker),
      'tcp://10.0.0.1:2375',
    );
  });

  test('the server order follows it', () async {
    seedLegacyServer();
    seed('setting', 'serverOrder', [legacyRef]);

    final id = await migrate();

    // Read out of `kv` rather than through `Stores.setting`, which would need
    // the whole GetIt registration for one string.
    final raw = SqliteDb.instance
        .select("SELECT value FROM kv WHERE store = 'setting' AND key = ?;", [
          'serverOrder',
        ])
        .single['value'] as String;
    expect(json.decode(raw), [id]);
  });
}
