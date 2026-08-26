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
/// repo's own intermediate.
///
/// Exactly two things about it are backed by a released build, both asserted
/// against the fixtures in `hive_release_migration_test.dart`: such a server
/// arrives with `id == ''`, and its `ssh` fields arrive nested under one key.
/// Those are what the seed cannot drift away from without that test failing.
///
/// Nothing else here is: the `kv` key is an arbitrary legacy reference, chosen
/// to read like one rather than because any fixture verifies that shape. What
/// is under test is that the *reference* is rewritten, whatever it was.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ServerStore servers;

  /// An arbitrary legacy reference: the `kv` key the server is stored under,
  /// and the value every record below uses to name it. Its shape is not
  /// asserted anywhere and nothing depends on it.
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

  /// The empty `id` and the nested `ssh` are the release-backed part; the key
  /// it is stored under is not.
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

  test(
    'an agent conversation follows it, in the column and in the JSON',
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
    },
  );

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

  test('a late port forward still resolves a generated server id', () async {
    seedLegacyServer();
    final id = await migrate();

    seed('port_forward', 'pf-late', {
      'id': 'pf-late',
      'serverId': legacyRef,
      'name': 'late-forward',
      'type': 'local',
      'localPort': 15432,
    });
    await const KvToTablesMigration().apply();

    expect(PortForwardStore.forTest().fetchForServer(id).single.id, 'pf-late');
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
    final raw =
        SqliteDb.instance.select(
              "SELECT value FROM kv WHERE store = 'setting' AND key = ?;",
              ['serverOrder'],
            ).single['value']
            as String;
    expect(json.decode(raw), [id]);
  });

  test('known hosts remap servers and retain ad-hoc connection ids', () async {
    seedLegacyServer();
    seed('setting', 'sshKnownHostFingerprints', {
      '$legacyRef::ssh-ed25519': 'SHA256:SERVER',
      'session-123::ssh-rsa': 'SHA256:ADHOC',
      'malformed': 'SHA256:IGNORED',
    });

    final id = await migrate();
    final raw =
        SqliteDb.instance.select(
              "SELECT value FROM kv WHERE store = 'setting' AND key = ?;",
              ['sshKnownHostFingerprints'],
            ).single['value']
            as String;

    expect(json.decode(raw), {
      '$id::ssh-ed25519': 'SHA256:SERVER',
      'session-123::ssh-rsa': 'SHA256:ADHOC',
    });
  });

  test('duplicate embedded server ids are assigned distinct rows', () async {
    seed('server', 'legacy-a', {
      'id': 'duplicate-id',
      'name': 'alpha',
      'ssh': {'ip': '10.0.0.1', 'port': 22, 'user': 'root'},
    });
    seed('server', 'legacy-b', {
      'id': 'duplicate-id',
      'name': 'beta',
      'ssh': {'ip': '10.0.0.2', 'port': 22, 'user': 'root'},
    });
    seed('port_forward', 'pf-b', {
      'id': 'pf-b',
      'serverId': 'legacy-b',
      'name': 'beta-forward',
      'type': 'local',
      'localPort': 2200,
    });

    await const KvToTablesMigration().apply();
    servers.dropCache();
    final migrated = servers.fetch();

    expect(migrated, hasLength(2));
    expect(migrated.map((server) => server.id).toSet(), hasLength(2));
    expect(
      migrated.where((server) => server.id == 'duplicate-id').single.name,
      'alpha',
    );
    final beta = migrated.where((server) => server.name == 'beta').single;
    expect(beta.id, isNot('duplicate-id'));
    expect(
      PortForwardStore.forTest().fetchForServer(beta.id).single.id,
      'pf-b',
      reason: 'the exact legacy kv key still resolves to its reassigned row',
    );
  });

  test('a malformed server does not block unrelated records', () async {
    seed('server', 'broken', {
      'id': <String>['not', 'a', 'string'],
      'name': 'broken',
      'ssh': {'ip': '10.0.0.9'},
    });
    seed('server', 'healthy', {
      'id': 'healthy-id',
      'name': 'healthy',
      'ssh': {'ip': '10.0.0.1', 'port': 22, 'user': 'root'},
    });

    await const KvToTablesMigration().apply();
    servers.dropCache();

    expect(servers.fetch().map((server) => server.id), ['healthy-id']);
    expect(
      SqliteDb.instance
          .select("SELECT count(*) AS n FROM kv WHERE store = 'server';")
          .single['n'],
      0,
      reason: 'the migration completes and consumes the legacy store',
    );
  });

  test('a malformed private key does not block valid keys', () async {
    seed('key', 'broken', {
      'id': <String>['not', 'a', 'string'],
      'private_key': 'BROKEN',
    });
    seed('key', 'healthy', {'id': 'healthy', 'private_key': 'PRIVATE'});

    await const KvToTablesMigration().apply();

    final keys = SqliteDb.instance.select(
      'SELECT name, key FROM private_key ORDER BY name;',
    );
    expect(keys, hasLength(1));
    expect(keys.single['name'], 'healthy');
    expect(keys.single['key'], 'PRIVATE');
  });

  test('malformed child rows do not block valid children', () async {
    seedLegacyServer();
    seed('snippet', 'broken-snippet', {
      'name': 'broken',
      'script': <String>['not', 'a', 'string'],
    });
    seed('snippet', 'healthy-snippet', {
      'name': 'healthy',
      'script': 'echo healthy',
    });
    seed('port_forward', 'broken-forward', {
      'id': <String>['not', 'a', 'string'],
      'serverId': legacyRef,
    });
    seed('port_forward', 'healthy-forward', {
      'id': 'healthy-forward',
      'serverId': legacyRef,
      'localPort': 2200,
    });
    seed('conn_stat', 'broken-stat', {
      'serverId': <String>['not', 'a', 'string'],
      'timestamp': '2026-01-01T00:00:00.000',
    });
    seed('conn_stat', 'healthy-stat', {
      'serverId': legacyRef,
      'timestamp': '2026-01-01T00:00:00.000',
      'result': 'success',
    });
    seed('agent_conversation', 'conversation::broken', {
      'id': <String>['not', 'a', 'string'],
      'server_id': legacyRef,
    });
    seed('agent_conversation', 'conversation::healthy', {
      'id': 'healthy-conversation',
      'server_id': legacyRef,
      'updated_at': '2026-01-01T00:00:00.000',
      'items': <Object>[],
    });

    final id = await migrate();

    expect(SnippetStore.forTest().fetch().single.name, 'healthy');
    expect(
      PortForwardStore.forTest().fetchForServer(id).single.id,
      'healthy-forward',
    );
    expect(
      SqliteDb.instance
          .select('SELECT count(*) AS n FROM conn_stat;')
          .single['n'],
      1,
    );
    expect(
      AgentConversationStore.forTest().fetchForServer(id).single.id,
      'healthy-conversation',
    );
  });
}
