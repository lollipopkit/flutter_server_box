/// `MonitorHttpCredential.fallbackAddr`: the same agent at a second address,
/// dialled when the first cannot be connected to.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/core/monitor/http.dart';
import 'package:server_box/data/model/app/error.dart';
import 'package:server_box/data/model/server/monitor/monitor_http_credential.dart';
import 'package:server_box/src/rust/api/protocol.dart';

import '../../helpers/rust_lib_helper.dart';

void main() {
  setUpAll(initRustLibForTest);

  final servers = <HttpServer>[];
  final clients = <MonitorHttpClient>[];

  tearDown(() async {
    for (final c in clients) {
      c.dispose();
    }
    clients.clear();
    for (final s in servers) {
      await s.close(force: true);
    }
    servers.clear();
  });

  /// An agent on loopback, recording the paths it was asked.
  Future<(String, List<String>)> agent({int capabilities = 200}) async {
    final paths = <String>[];
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    servers.add(server);
    server.listen((req) async {
      await req.drain<void>();
      paths.add(req.uri.path);
      final (code, body) = switch (req.uri.path) {
        '/api/v1/health' => (200, {'protocol': monitorProtocol(), 'min_client_protocol': 1}),
        '/api/v1/login' => (200, {'token': 't'}),
        _ => (capabilities, <String, Object?>{}),
      };
      req.response
        ..statusCode = code
        ..headers.contentType = ContentType.json
        ..write(jsonEncode(body));
      await req.response.close();
    });
    return ('http://127.0.0.1:${server.port}', paths);
  }

  /// An address nothing listens on: a port bound and given back.
  Future<String> closed() async {
    final s = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    final port = s.port;
    await s.close();
    return 'http://127.0.0.1:$port';
  }

  MonitorHttpClient client(String addr, {String? fallback}) {
    final c = MonitorHttpClient(
      MonitorHttpCredential(addr: addr, fallbackAddr: fallback, pwd: 'pw'),
    );
    clients.add(c);
    return c;
  }

  test('an address that cannot be connected to moves to the fallback', () async {
    final (addr, paths) = await agent();
    final c = client(await closed(), fallback: addr);
    await c.capabilities();
    await c.capabilities();
    expect(paths, ['/api/v1/health', '/api/v1/login', '/api/v1/capabilities', '/api/v1/capabilities']);
    expect(c.agentUri.toString(), addr);
  });

  test('a reachable address is not left for the fallback', () async {
    final (addr, paths) = await agent();
    final (fallback, fallbackPaths) = await agent();
    await client(addr, fallback: fallback).capabilities();
    expect(paths, isNotEmpty);
    expect(fallbackPaths, isEmpty);
  });

  test('an answer, even an error, is the agent and is not retried elsewhere', () async {
    final (addr, paths) = await agent(capabilities: 500);
    final (fallback, fallbackPaths) = await agent();
    await expectLater(client(addr, fallback: fallback).capabilities(), throwsA(isA<MonitorHttpErr>()));
    expect(paths.last, '/api/v1/capabilities');
    expect(fallbackPaths, isEmpty);
  });

  // What dio reports as a connection error after the request was sent: the
  // agent may have run it, so sending it again elsewhere could run it twice.
  test('a connection closed before the answer is not resent elsewhere', () async {
    final dropping = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(dropping.close);
    dropping.listen((socket) {
      socket.listen((_) => socket.destroy());
    });
    final (fallback, fallbackPaths) = await agent();
    final c = client('http://127.0.0.1:${dropping.port}', fallback: fallback);
    await expectLater(c.capabilities(), throwsA(isA<MonitorHttpErr>()));
    expect(fallbackPaths, isEmpty);
  });

  test('neither answering fails as the link it is', () async {
    final c = client(await closed(), fallback: await closed());
    await expectLater(
      c.capabilities(),
      throwsA(isA<MonitorHttpErr>().having((e) => e.type, 'type', MonitorHttpErrType.net)),
    );
  });

  group('back to the address', () {
    /// A client on [primary]'s fallback after [primary] refused it.
    Future<MonitorHttpClient> movedOff(String primary) async {
      final (fallback, _) = await agent();
      final c = client(primary, fallback: fallback);
      await c.capabilities();
      expect(c.agentUri.toString(), fallback);
      return c;
    }

    test('once it can be connected to again', () async {
      final primary = await closed();
      final c = await movedOff(primary);
      final port = Uri.parse(primary).port;
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, port);
      servers.add(server);
      server.listen((req) => req.response.close());

      await c.probePrimary();
      expect(c.agentUri.toString(), primary);
    });

    // A port that takes the connection and never completes TLS: a captive
    // portal, a proxy still starting. Requests there would fail with a
    // handshake error, which does not fail over.
    test('not while TLS there never completes', () async {
      final primary = (await closed()).replaceFirst('http://', 'https://');
      final c = await movedOff(primary);
      final silent = await ServerSocket.bind(
        InternetAddress.loopbackIPv4,
        Uri.parse(primary).port,
      );
      addTearDown(silent.close);
      final held = <Socket>[];
      silent.listen(held.add);
      addTearDown(() {
        for (final s in held) {
          s.destroy();
        }
      });

      await c.probePrimary();
      expect(c.agentUri.toString(), isNot(primary));
    });
  });

  test('a plaintext fallback needs the same opt-in the address does', () {
    const https = MonitorHttpCredential(addr: 'https://a.example:3770');
    expect(https.needsInsecureOptIn, isFalse);
    const plainFallback = MonitorHttpCredential(
      addr: 'https://a.example:3770',
      fallbackAddr: 'http://100.64.0.1:3770',
    );
    expect(plainFallback.needsInsecureOptIn, isTrue);
    expect(
      MonitorHttpCredential.fromJson(plainFallback.allowingInsecure().toJson()),
      plainFallback.allowingInsecure(),
    );
  });
}
