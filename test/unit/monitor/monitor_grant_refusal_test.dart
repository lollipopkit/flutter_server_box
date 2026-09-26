/// `MonitorHttpClient` against an agent whose `full_access` is off: both of
/// its refusals — `/exec`, and the ticket for a stream or a terminal — arrive
/// as [MonitorHttpErrType.notGranted], the one type a caller can tell apart
/// from a link that failed.
///
/// Found against a real agent: before this, both were `unknown` carrying a
/// DioException's text, and the Virtualization tab reported the host as
/// unreachable. The status codes and bodies are the agent's
/// (`monitor/src/api/exec.rs`, `issue_ws_ticket` in `api/server.rs`).
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/data/model/app/error.dart';
import 'package:server_box/data/model/server/monitor_http_credential.dart';
import 'package:server_box/data/provider/server/monitor_http.dart';

void main() {
  late HttpServer server;
  late MonitorHttpClient client;

  setUp(() async {
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((req) async {
      await req.drain<void>();
      final (status, body) = switch (req.uri.path) {
        '/api/v1/login' => (200, {'token': 'test-token'}),
        '/api/v1/exec' => (403, {'error': 'full access not available'}),
        '/api/v1/ws-ticket' => (403, {'error': 'full access not available'}),
        _ => (404, {'error': 'not found'}),
      };
      req.response
        ..statusCode = status
        ..headers.contentType = ContentType.json
        ..write(jsonEncode(body));
      await req.response.close();
    });
    client = MonitorHttpClient(
      MonitorHttpCredential(
        addr: 'http://127.0.0.1:${server.port}',
        user: 'admin',
        pwd: 'pw',
      ),
    );
  });

  tearDown(() async {
    client.dispose();
    await server.close(force: true);
  });

  Matcher notGranted(String said) => throwsA(
    isA<MonitorHttpErr>()
        .having((e) => e.type, 'type', MonitorHttpErrType.notGranted)
        .having((e) => e.message, 'message', contains(said))
        .having((e) => e.solution, 'solution', isNotNull),
  );

  test('a refused command is notGranted', () async {
    await expectLater(client.exec('true'), notGranted('full access is off'));
  });

  test('a refused stream ticket is notGranted, with the agent\'s words', () async {
    await expectLater(
      client.openStream(),
      notGranted('full access not available'),
    );
  });

  test('so is a refused terminal ticket', () async {
    await expectLater(
      client.openTerminal(),
      notGranted('full access not available'),
    );
  });
}
