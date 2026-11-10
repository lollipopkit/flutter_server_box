/// `MonitorHttpClient` and the app ↔ agent protocol (`sbm_parser::protocol`):
/// it names its protocol on every request, asks `/health` before signing in,
/// and tells "update the agent" and "update the app" apart from a failed link.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/core/monitor/http.dart';
import 'package:server_box/data/model/app/error.dart';
import 'package:server_box/data/model/server/monitor/monitor_http_credential.dart';
import 'package:server_box/src/rust/api/protocol.dart';

import '../../helpers/rust_lib_helper.dart';

void main() {
  setUpAll(initRustLibForTest);

  late HttpServer server;
  late MonitorHttpClient client;
  late List<String?> named;
  late List<String> paths;

  /// An agent whose `/health` is [health] (`null`: a 404, as before it had
  /// one) and which answers everything else with [status].
  Future<void> agent(Map<String, Object?>? health, {int status = 200, int healthStatus = 200}) async {
    named = [];
    paths = [];
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((req) async {
      await req.drain<void>();
      named.add(req.headers.value(MonitorProtocol.header));
      paths.add(req.uri.path);
      final (code, body) = switch (req.uri.path) {
        '/api/v1/health' when health == null => (404, {'error': 'not found'}),
        '/api/v1/health' => (healthStatus, health),
        '/api/v1/login' when status == 200 => (200, {'token': 't'}),
        '/api/v1/capabilities' when status == 200 => (200, <String, Object?>{}),
        _ => (status, {'error': 'client_too_old'}),
      };
      req.response
        ..statusCode = code
        ..headers.contentType = ContentType.json
        ..write(jsonEncode(body));
      await req.response.close();
    });
    client = MonitorHttpClient(
      MonitorHttpCredential(
        addr: 'http://127.0.0.1:${server.port}',
        pwd: 'pw',
      ),
    );
  }

  tearDown(() async {
    client.dispose();
    await server.close(force: true);
  });

  Matcher failsAs(MonitorHttpErrType type) => throwsA(
    isA<MonitorHttpErr>()
        .having((e) => e.type, 'type', type)
        .having((e) => e.solution, 'solution', isNotNull),
  );

  test('every request names the protocol', () async {
    await agent({'protocol': monitorProtocol(), 'min_client_protocol': 1});
    await client.capabilities();
    expect(named, isNotEmpty);
    expect(named, everyElement('${monitorProtocol()}'));
  });

  test('an agent from before /health, or before the protocol, says to update it', () async {
    await agent(null);
    await expectLater(client.capabilities(), failsAs(MonitorHttpErrType.agentTooOld));
    expect(paths, ['/api/v1/health']);
  });

  test('an agent at the first protocol says to update it', () async {
    await agent({'protocol': 1, 'min_client_protocol': 1});
    await expectLater(
      client.capabilities(),
      throwsA(isA<MonitorHttpErr>().having((e) => e.message, 'message', l10n.monitorAgentTooOld)),
    );
  });

  // A proxy in front of a current agent that is restarting.
  test('a /health that failed is that failure, not an agent too old', () async {
    await agent({'error': 'bad gateway'}, healthStatus: 502);
    await expectLater(
      client.capabilities(),
      throwsA(isA<MonitorHttpErr>().having((e) => e.type, 'type', isNot(MonitorHttpErrType.agentTooOld))),
    );
    expect(paths, ['/api/v1/health']);
  });

  test('a client for updating still reaches an agent too old for the app', () async {
    await agent({'protocol': 1, 'min_client_protocol': 1});
    final updater = MonitorHttpClient.toUpdate(client.monitor);
    addTearDown(updater.dispose);
    await updater.capabilities();
    expect(paths, ['/api/v1/login', '/api/v1/capabilities']);
  });

  test('/health is asked once', () async {
    await agent({'protocol': monitorProtocol(), 'min_client_protocol': 1});
    await client.capabilities();
    await client.capabilities();
    expect(paths, ['/api/v1/health', '/api/v1/login', '/api/v1/capabilities', '/api/v1/capabilities']);
  });

  test('an agent that no longer answers this app says to update the app', () async {
    await agent({'protocol': monitorProtocol() + 2, 'min_client_protocol': monitorProtocol() + 1});
    await expectLater(client.capabilities(), failsAs(MonitorHttpErrType.clientTooOld));
  });

  test('an agent older than this app reads says to update the agent', () async {
    await agent({'protocol': 0, 'min_client_protocol': 0});
    await expectLater(client.capabilities(), failsAs(MonitorHttpErrType.agentTooOld));
  });

  test('a 426 from an agent replaced since is the same as being told by /health', () async {
    await agent({'protocol': monitorProtocol()}, status: 426);
    await expectLater(client.capabilities(), failsAs(MonitorHttpErrType.clientTooOld));
  });
}
