import 'dart:convert';

import 'package:fl_lib/fl_lib.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/data/model/server/port_forward.dart';
import 'package:server_box/data/model/server/remote_desktop.dart';
import 'package:server_box/data/model/server/server_private_info.dart';
import 'package:server_box/data/model/server/snippet.dart';
import 'package:server_box/data/model/server/ssh_credential.dart';
import 'package:server_box/data/store/agent_conversation.dart';
import 'package:server_box/data/store/port_forward.dart';
import 'package:server_box/data/store/remote_desktop.dart';
import 'package:server_box/data/store/server.dart';
import 'package:server_box/data/store/snippet.dart';

import 'helpers/test_db.dart';

void main() {
  late ServerStore servers;
  late PortForwardStore forwards;
  late RemoteDesktopStore remoteDesktops;
  late SnippetStore snippets;
  late AgentConversationStore conversations;

  const original = Spi(
    id: 'server-old',
    name: 'production',
    ssh: SshCredential(ip: '10.0.0.1'),
  );
  const jumpOwner = Spi(
    id: 'jump-owner',
    name: 'through-production',
    ssh: SshCredential(ip: '10.0.0.2', jumpIds: ['server-old']),
  );
  const forward = PortForwardConfig(
    id: 'forward-1',
    serverId: 'server-old',
    name: 'postgres',
    type: PortForwardType.local,
    localPort: 15432,
  );
  const remoteDesktop = RemoteDesktopProfile(
    id: 'desktop-1',
    serverId: 'server-old',
    name: 'Windows',
    protocol: RemoteDesktopProtocol.rdp,
    port: 3389,
  );
  const snippet = Snippet(
    id: 'snippet-1',
    name: 'deploy',
    script: 'deploy',
    autoRunOn: ['server-old'],
  );

  setUp(() async {
    await openTestDb();
    forwards = PortForwardStore();
    remoteDesktops = RemoteDesktopStore();
    snippets = SnippetStore();
    conversations = AgentConversationStore();
    servers = ServerStore(
      portForwards: forwards,
      remoteDesktops: remoteDesktops,
      snippets: snippets,
      conversations: conversations,
    );
    servers.put(original);
    servers.put(jumpOwner);
    forwards.put(forward);
    remoteDesktops.put(remoteDesktop);
    snippets.put(snippet);
    servers.trustHost(original.id, 'ssh-ed25519', 'SHA256:old');
    SqliteDb.instance.execute('INSERT INTO container_host VALUES (?, ?, ?);', [
      original.id,
      'docker',
      'tcp://docker:2375',
    ]);
    SqliteDb.instance.execute('INSERT INTO container_runtime VALUES (?, ?);', [
      original.id,
      'podman',
    ]);
    SqliteDb.instance.execute(
      'INSERT INTO server_dist (server_id, dist, updated_at) VALUES (?, ?, ?);',
      [original.id, 'ubuntu', 1],
    );
    SqliteDb.instance.execute(
      'INSERT INTO benchmark_run '
      '(id, server_id, started_at, status, options, run_dir) '
      'VALUES (?, ?, ?, ?, ?, ?);',
      ['bench-1', original.id, 1, 'running', '{}', '/tmp/yabs-1'],
    );
    SqliteDb.instance.execute(
      'INSERT INTO conn_stat '
      '(id, server_id, server_name, timestamp, result, duration_ms) '
      'VALUES (?, ?, ?, ?, ?, ?);',
      ['stat-1', original.id, original.name, 1, 'success', 5],
    );
    final conversation = <String, Object?>{
      'id': 'conversation-1',
      'server_id': original.id,
      'title': 'hello',
      'created_at': '2026-01-01T00:00:00.000',
      'updated_at': '2026-01-01T00:00:00.000',
      'protocol': 'responses',
      'provider_base_url': 'https://example.com',
      'model': 'test',
      'items': <Object?>[],
    };
    SqliteDb.instance.execute(
      'INSERT INTO agent_conversation VALUES (?, ?, ?, ?);',
      ['conversation-1', original.id, 1, json.encode(conversation)],
    );
    SqliteDb.instance.execute(
      'INSERT INTO agent_active_conversation VALUES (?, ?);',
      [original.id, 'conversation-1'],
    );
  });

  tearDown(SqliteDb.close);

  test('renaming moves every dependent row in one committed state', () async {
    // Prime the caches that a raw foreign-key update used to leave stale.
    expect(forwards.fetch().single.serverId, original.id);
    expect(remoteDesktops.fetch().single.serverId, original.id);
    expect(snippets.fetch().single.autoRunOn, [original.id]);
    final forwardChanged = forwards.watch().first;
    final remoteDesktopChanged = remoteDesktops.watch().first;
    final snippetChanged = snippets.watch().first;
    final conversationChanged = conversations.watch().first;

    final oldForwardRev =
        SqliteDb.instance.select('SELECT rev FROM port_forward WHERE id = ?;', [
              forward.id,
            ]).single['rev']
            as int;
    final oldSnippetRev =
        SqliteDb.instance.select('SELECT rev FROM snippet WHERE id = ?;', [
              snippet.id,
            ]).single['rev']
            as int;
    final oldRemoteDesktopRev =
        SqliteDb.instance.select(
              'SELECT rev FROM remote_desktop_profile WHERE id = ?;',
              [remoteDesktop.id],
            ).single['rev']
            as int;
    final oldOwnerRev =
        SqliteDb.instance.select('SELECT rev FROM server WHERE id = ?;', [
              jumpOwner.id,
            ]).single['rev']
            as int;

    final replacement = original.copyWith(id: 'server-new');
    servers.rename(original, replacement);
    await Future.wait([
      forwardChanged,
      remoteDesktopChanged,
      snippetChanged,
      conversationChanged,
    ]).timeout(const Duration(seconds: 1));

    expect(servers.fetchOneRaw(original.id), isNull);
    expect(servers.fetchOneRaw(replacement.id), replacement);
    expect(servers.knownHosts(replacement.id), {'ssh-ed25519': 'SHA256:old'});
    expect(forwards.fetch().single.serverId, replacement.id);
    expect(remoteDesktops.fetch().single.serverId, replacement.id);
    expect(snippets.fetch().single.autoRunOn, [replacement.id]);
    expect(
      SqliteDb.instance
          .select('SELECT server_id FROM container_host;')
          .single['server_id'],
      replacement.id,
    );
    expect(
      SqliteDb.instance
          .select('SELECT server_id FROM container_runtime;')
          .single['server_id'],
      replacement.id,
    );
    expect(
      SqliteDb.instance
          .select('SELECT server_id FROM conn_stat;')
          .single['server_id'],
      replacement.id,
    );
    // Left out of the carried tables, these were cascaded away by the delete
    // that ends a rename: the recorded distribution, and the whole benchmark
    // history including a row naming a directory with a live run in it.
    expect(
      SqliteDb.instance
          .select('SELECT server_id FROM server_dist;')
          .single['server_id'],
      replacement.id,
    );
    expect(
      SqliteDb.instance
          .select('SELECT server_id, run_dir FROM benchmark_run;')
          .single['server_id'],
      replacement.id,
    );
    expect(servers.fetchOneRaw(jumpOwner.id)?.ssh?.jumpIds, [replacement.id]);

    final conversationRow = SqliteDb.instance
        .select('SELECT server_id, data FROM agent_conversation;')
        .single;
    expect(conversationRow['server_id'], replacement.id);
    expect(
      (json.decode(conversationRow['data'] as String) as Map)['server_id'],
      replacement.id,
    );
    expect(
      SqliteDb.instance
          .select('SELECT server_id FROM agent_active_conversation;')
          .single['server_id'],
      replacement.id,
    );

    expect(
      SqliteDb.instance.select('SELECT rev FROM port_forward WHERE id = ?;', [
        forward.id,
      ]).single['rev'],
      greaterThan(oldForwardRev),
    );
    expect(
      SqliteDb.instance.select('SELECT rev FROM snippet WHERE id = ?;', [
        snippet.id,
      ]).single['rev'],
      greaterThan(oldSnippetRev),
    );
    expect(
      SqliteDb.instance.select(
        'SELECT rev FROM remote_desktop_profile WHERE id = ?;',
        [remoteDesktop.id],
      ).single['rev'],
      greaterThan(oldRemoteDesktopRev),
    );
    expect(
      SqliteDb.instance.select('SELECT rev FROM server WHERE id = ?;', [
        jumpOwner.id,
      ]).single['rev'],
      greaterThan(oldOwnerRev),
    );
    expect(
      SqliteDb.instance.select(
        "SELECT count(*) AS n FROM tombstone WHERE tbl = 'server' AND row_id = ?;",
        [original.id],
      ).single['n'],
      1,
    );
  });

  test('a failed replacement rolls the original graph back', () {
    SqliteDb.instance.execute(
      "UPDATE agent_conversation SET data = 'not-json' WHERE id = ?;",
      ['conversation-1'],
    );

    expect(
      () => servers.rename(original, original.copyWith(id: 'server-new')),
      throwsA(isA<FormatException>()),
    );

    servers.dropCache();
    expect(servers.fetchOneRaw(original.id), original);
    expect(forwards.fetchForServer(original.id), [forward]);
    expect(remoteDesktops.fetchForServer(original.id), [remoteDesktop]);
    expect(snippets.fetch().single.autoRunOn, [original.id]);
    expect(servers.knownHosts(original.id), isNotEmpty);
    expect(
      SqliteDb.instance.select(
        'SELECT count(*) AS n FROM server WHERE id = ?;',
        ['server-new'],
      ).single['n'],
      0,
    );
  });

  test(
    'direct deletion invalidates child caches and stamps removed links',
    () async {
      expect(forwards.fetch(), [forward]);
      expect(remoteDesktops.fetch(), [remoteDesktop]);
      expect(snippets.fetch().single.autoRunOn, [original.id]);
      final forwardChanged = forwards.watch().first;
      final remoteDesktopChanged = remoteDesktops.watch().first;
      final snippetChanged = snippets.watch().first;
      final oldSnippetRev =
          SqliteDb.instance.select('SELECT rev FROM snippet WHERE id = ?;', [
                snippet.id,
              ]).single['rev']
              as int;

      servers.deleteById(original.id);
      await Future.wait([
        forwardChanged,
        remoteDesktopChanged,
        snippetChanged,
      ]).timeout(const Duration(seconds: 1));

      expect(forwards.fetch(), isEmpty);
      expect(remoteDesktops.fetch(), isEmpty);
      expect(
        SqliteDb.instance.select(
          'SELECT count(*) AS n FROM tombstone '
          "WHERE tbl = 'remote_desktop_profile' AND row_id = ?;",
          [remoteDesktop.id],
        ).single['n'],
        1,
      );
      expect(snippets.fetch().single.autoRunOn, anyOf(isNull, isEmpty));
      expect(
        SqliteDb.instance.select('SELECT rev FROM snippet WHERE id = ?;', [
          snippet.id,
        ]).single['rev'],
        greaterThan(oldSnippetRev),
      );
      expect(
        servers.fetchOneRaw(jumpOwner.id)?.ssh?.jumpIds,
        anyOf(isNull, isEmpty),
      );
    },
  );

  test('known-host change rolls back when the server stamp fails', () {
    servers.forgetHost(original.id, 'ssh-ed25519');
    SqliteDb.instance.execute(
      'CREATE TRIGGER reject_server_stamp '
      'BEFORE UPDATE OF updated_at ON server '
      "BEGIN SELECT RAISE(ABORT, 'stamp failed'); END;",
    );

    expect(
      () => servers.trustHost(original.id, 'ssh-rsa', 'SHA256:new'),
      throwsA(anything),
    );
    expect(servers.knownHosts(original.id), isEmpty);
  });
}
