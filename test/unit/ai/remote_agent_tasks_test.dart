/// `RemoteAgentTasks` against a loopback agent: which servers are listed, how
/// pages are read and kept, and what a server that stops offering Agent mode
/// leaves behind (nothing).
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/data/model/server/monitor/monitor_access.dart';
import 'package:server_box/data/model/server/monitor/monitor_agent.dart';
import 'package:server_box/data/model/server/monitor/monitor_capabilities.dart';
import 'package:server_box/data/model/server/monitor/monitor_http_credential.dart';
import 'package:server_box/data/model/server/server.dart';
import 'package:server_box/data/model/server/server_private_info.dart';
import 'package:server_box/data/model/server/ssh_credential.dart';
import 'package:server_box/data/provider/ai/agent_scope.dart';
import 'package:server_box/data/provider/ai/remote_agent.dart';
import 'package:server_box/data/provider/server/all.dart';
import 'package:server_box/data/provider/server/single.dart';
import 'package:server_box/data/res/status.dart';

import '../../helpers/fake_agent_health.dart';
import '../../helpers/rust_lib_helper.dart';
import '../../helpers/test_db.dart';

/// An agent with [count] tasks, newest first, served [RemoteAgentTasks.pageSize]
/// at a time behind a `before` cursor (a task id).
class _Agent {
  _Agent._(this._server);

  final HttpServer _server;
  var count = 0;

  /// Answers the next list read with a 500.
  var failNext = false;

  /// Holds list reads until completed, to catch two in flight.
  Completer<void>? hold;

  final reads = <Map<String, String>>[];

  /// Event streams the agent holds open now.
  var openEvents = 0;

  String get addr => 'http://127.0.0.1:${_server.port}';

  static Future<_Agent> start() async {
    final agent = _Agent._(await HttpServer.bind(InternetAddress.loopbackIPv4, 0));
    agent._server.listen(agent._serve);
    return agent;
  }

  static String id(int i) => 't${i.toString().padLeft(3, '0')}';

  Map<String, Object?> flow(int i) => {
    'id': id(i),
    'title': 'task $i',
    'status': 'done',
    // Newest first: a higher index is older.
    'updatedAt': DateTime.utc(2026, 1, 1).subtract(Duration(minutes: i)).toIso8601String(),
  };

  Future<void> _serve(HttpRequest req) async {
    if (await answerAgentHealth(req)) return;
    await req.drain<void>();
    final res = req.response..headers.contentType = ContentType.json;
    switch (req.uri.path) {
      case '/api/v1/login':
        res.write(jsonEncode({'token': 't'}));
      case '/api/v1/agent/flows':
        reads.add(req.uri.queryParameters);
        await hold?.future;
        if (failNext) {
          failNext = false;
          res
            ..statusCode = 500
            ..write(jsonEncode({'error': 'boom'}));
          break;
        }
        final limit = int.parse(req.uri.queryParameters['limit'] ?? '50');
        final before = req.uri.queryParameters['before'];
        final start = before == null ? 0 : int.parse(before.substring(1)) + 1;
        final end = (start + limit).clamp(0, count);
        res.write(jsonEncode({
          'flows': [for (var i = start; i < end; i++) flow(i)],
          'configured': true,
          'defaultMode': 'auto',
          'bypassAllowed': true,
          if (end < count) 'next': id(end - 1),
        }));
      case '/api/v1/agent/events':
        // Held open, as the agent does; nothing to say.
        // Only a ping, as an idle agent sends: nothing the stream yields. The
        // socket is detached because `HttpResponse.done` never learns that
        // the client went away; a read on the socket does.
        res.headers
          ..contentType = ContentType('text', 'event-stream')
          ..chunkedTransferEncoding = false;
        final socket = await res.detachSocket();
        socket.write(': ping\n\n');
        openEvents++;
        await socket.drain<void>().catchError((_) {});
        socket.destroy();
        openEvents--;
        return;
      default:
        res.statusCode = 404;
    }
    await res.close();
  }

  Future<void> close() => _server.close(force: true);
}

/// The servers listed, and which of them offer Agent mode, for the overrides.
final _servers = <String, Spi>{};
final _offering = <String>{};

class _Servers extends ServersNotifier {
  @override
  ServersState build() => ServersState(servers: {..._servers}, serverOrder: [..._servers.keys]);
}

class _Server extends ServerNotifier {
  @override
  ServerState build(String id) => ServerState(
    spi: _servers[id]!,
    status: InitStatus.status,
    conn: ServerConn.finished,
    agentCapabilities: MonitorCapabilities(
      access: MonitorAccess.granted,
      features: {if (_offering.contains(id)) MonitorFeature.agentMode},
      version: '0.4.0',
    ),
  );
}

class _RealHttp extends HttpOverrides {}

void main() {
  late ProviderContainer container;
  late _Agent agent;

  setUpAll(() async {
    await initRustLibForTest();
    container = ProviderContainer(
      overrides: [
        serversProvider.overrideWith(_Servers.new),
        serverProvider.overrideWith2((_) => _Server()),
      ],
    );
    // Set once per isolate.
    AgentScope.container = container;
  });

  setUp(() async {
    HttpOverrides.global = _RealHttp();
    await openTestDb();
    agent = await _Agent.start();
    _servers.clear();
    _offering.clear();
  });

  tearDown(() async {
    RemoteAgentTasks.reset();
    await agent.close();
    await closeTestDb();
  });

  /// Lists [ids] (each on [agent] unless it is in [ssh]) and makes the
  /// container read them again.
  void serve(List<String> ids, {Set<String> offering = const {}, Set<String> ssh = const {}}) {
    _servers
      ..clear()
      ..addAll({
        for (final id in ids)
          id: Spi(
            id: id,
            name: 'srv-$id',
            ssh: ssh.contains(id) ? const SshCredential(ip: '10.0.0.1') : null,
            monitorHttp: ssh.contains(id) ? null : MonitorHttpCredential(addr: agent.addr, pwd: 'pw'),
          ),
      });
    _offering
      ..clear()
      ..addAll(offering);
    container.invalidate(serversProvider);
    for (final id in ids) {
      container.invalidate(serverProvider(id));
    }
  }

  List<String> ids(String server) => [for (final f in RemoteAgentTasks.tasks.value[server] ?? const []) f.id];

  test('lists the servers whose agent offers Agent mode, in order', () {
    serve(['a', 'b', 'c', 'd'], offering: {'a', 'c', 'd'}, ssh: {'d'});

    expect([for (final s in RemoteAgentTasks.servers()) s.id], ['a', 'c']);
    expect(RemoteAgentTasks.servers().first.name, 'srv-a');
  });

  test('the first page fills the list, its modes and the cursor', () async {
    agent.count = RemoteAgentTasks.pageSize + 10;
    serve(['a'], offering: {'a'});

    await RemoteAgentTasks.refresh();

    expect(ids('a'), hasLength(RemoteAgentTasks.pageSize));
    expect(ids('a').first, _Agent.id(0));
    expect(RemoteAgentTasks.modes.value['a'], (defaultMode: AgentPermissionMode.auto, bypassAllowed: true));
    expect(RemoteAgentTasks.more.value['a'], _Agent.id(RemoteAgentTasks.pageSize - 1));
    expect(RemoteAgentTasks.loading.value, isEmpty);
  });

  test('the next page is added once, and a second ask while it reads is not made', () async {
    agent.count = RemoteAgentTasks.pageSize + 10;
    serve(['a'], offering: {'a'});
    await RemoteAgentTasks.refresh();

    agent.hold = Completer<void>();
    final first = RemoteAgentTasks.loadMore('a');
    await pumpEventQueue();
    expect(RemoteAgentTasks.loadingMore('a'), isTrue);
    await RemoteAgentTasks.loadMore('a');
    agent.hold!.complete();
    await first;

    expect(agent.reads.where((q) => q.containsKey('before')), hasLength(1));
    expect(ids('a'), hasLength(RemoteAgentTasks.pageSize + 10));
    expect(ids('a').toSet(), hasLength(RemoteAgentTasks.pageSize + 10), reason: 'no task twice');
    expect(RemoteAgentTasks.more.value, isNot(contains('a')), reason: 'the list is whole');
  });

  test('a refresh keeps what was read past the first page, and the list whole', () async {
    agent.count = RemoteAgentTasks.pageSize + 10;
    serve(['a'], offering: {'a'});
    await RemoteAgentTasks.refresh();
    await RemoteAgentTasks.loadMore('a');

    await RemoteAgentTasks.refresh();

    expect(ids('a'), hasLength(RemoteAgentTasks.pageSize + 10));
    expect(RemoteAgentTasks.more.value, isNot(contains('a')));
  });

  test('a failed read says why, and the next one that works clears it', () async {
    agent.count = 3;
    serve(['a'], offering: {'a'});

    agent.failNext = true;
    await RemoteAgentTasks.refresh();
    expect(RemoteAgentTasks.errors.value, contains('a'));

    await RemoteAgentTasks.refresh();
    expect(RemoteAgentTasks.errors.value, isNot(contains('a')));
    expect(ids('a'), hasLength(3));
  });

  test('a server that stops offering Agent mode leaves nothing behind', () async {
    agent.count = 3;
    serve(['a'], offering: {'a'});
    RemoteAgentTasks.follow();
    addTearDown(RemoteAgentTasks.unfollow);
    await RemoteAgentTasks.refresh();
    RemoteAgentTasks.select((serverId: 'a', flowId: _Agent.id(0)));
    RemoteAgentTasks.errors.value = {'a': 'earlier'};
    expect(ids('a'), hasLength(3));

    serve(['a']);
    await pumpEventQueue();

    expect(RemoteAgentTasks.tasks.value, isNot(contains('a')));
    expect(RemoteAgentTasks.modes.value, isNot(contains('a')));
    expect(RemoteAgentTasks.errors.value, isNot(contains('a')));
    expect(RemoteAgentTasks.selected.value, isNull);
  });

  test('a server dropped lets go of its event stream, idle as it is', () async {
    agent.count = 1;
    serve(['a'], offering: {'a'});
    RemoteAgentTasks.follow();
    addTearDown(RemoteAgentTasks.unfollow);
    for (var i = 0; i < 50 && agent.openEvents == 0; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
    expect(agent.openEvents, 1);

    serve(['a']);
    for (var i = 0; i < 50 && agent.openEvents > 0; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
    expect(agent.openEvents, 0, reason: 'the request ended with the stream');
  });

  test('reset leaves nothing to the next test', () async {
    serve(['a'], offering: {'a'});
    RemoteAgentTasks.follow();
    RemoteAgentTasks.newOn.value = 'a';

    RemoteAgentTasks.reset();

    expect(RemoteAgentTasks.newOn.value, isNull);
    // A follow after the reset starts from nothing: its first follower
    // subscribes again rather than counting on a closed subscription.
    agent.count = 1;
    RemoteAgentTasks.follow();
    addTearDown(RemoteAgentTasks.unfollow);
    await RemoteAgentTasks.refresh();
    expect(ids('a'), hasLength(1));
  });
}
