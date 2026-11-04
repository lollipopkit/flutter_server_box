/// `MonitorHttpClient`'s certificate policy against a real TLS agent on
/// loopback, serving `test/fixtures/virt_tls/leaf.pem` (signed by a test CA
/// the system does not trust; see `pve_tls_test.dart`): the pinned
/// certificate is accepted for requests and the WebSocket upgrade alike, no
/// pin shows it (`certUnconfirmed`), and a different pin is `certChanged`.
library;

import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/data/model/app/error.dart';
import 'package:server_box/data/model/server/monitor/monitor_http_credential.dart';
import 'package:server_box/data/provider/server/monitor_http.dart';

import '../../helpers/fake_agent_health.dart';
import '../../helpers/rust_lib_helper.dart';

const _dir = 'test/fixtures/virt_tls';

/// SHA-256 of the leaf's DER form: what the client must report and accept.
String _leafFingerprint() {
  final pem = File('$_dir/leaf.pem').readAsStringSync();
  final body = pem
      .split('\n')
      .where((l) => !l.startsWith('-----') && l.trim().isNotEmpty)
      .join();
  return sha256.convert(base64.decode(body)).toString();
}

void main() {
  // The pin is decided by sbm_ffi (`certPinAccepts`).
  setUpAll(initRustLibForTest);

  late HttpServer server;
  final paths = <String>[];

  setUp(() async {
    paths.clear();
    final ctx = SecurityContext()
      ..useCertificateChain('$_dir/leaf.pem')
      ..usePrivateKey('$_dir/leaf.key');
    server = await HttpServer.bindSecure(InternetAddress.loopbackIPv4, 0, ctx);
    server.listen((req) async {
      paths.add(req.uri.path);
      if (await answerAgentHealth(req)) return;
      if (req.uri.path == '/api/v1/terminal/ws') {
        final ws = await WebSocketTransformer.upgrade(
          req,
          protocolSelector: (protocols) => protocols.first,
        );
        await ws.close();
        return;
      }
      await req.drain<void>();
      final data = switch (req.uri.path) {
        '/api/v1/login' => {'token': 't'},
        '/api/v1/fs/roots' => {
          'roots': ['/'],
        },
        '/api/v1/ws-ticket' => {'ticket': 'k'},
        _ => null,
      };
      req.response
        ..statusCode = data == null ? 404 : 200
        ..headers.contentType = ContentType.json
        ..write(jsonEncode(data ?? {'error': 'not_found'}));
      await req.response.close();
    });
  });

  tearDown(() => server.close(force: true));

  MonitorHttpClient client({String? pin}) {
    final c = MonitorHttpClient(
      MonitorHttpCredential(
        addr: 'https://127.0.0.1:${server.port}',
        pwd: 'pw',
        certSha256: pin,
      ),
    );
    addTearDown(c.dispose);
    return c;
  }

  test('the pinned certificate is trusted, the WebSocket included', () async {
    final c = client(pin: _leafFingerprint());

    expect(await c.fsRoots(), ['/']);
    final ws = await c.openTerminal(timeout: const Duration(seconds: 5));
    await ws.close();
    expect(paths, contains('/api/v1/terminal/ws'));
  });

  test('no pin: refused before anything is sent, and shown', () async {
    final c = client();

    await expectLater(
      c.fsRoots(),
      throwsA(
        isA<MonitorHttpErr>()
            .having((e) => e.type, 'type', MonitorHttpErrType.certUnconfirmed)
            .having((e) => e.cert?.fingerprint, 'cert', _leafFingerprint())
            .having((e) => e.previousFingerprint, 'previous', isNull),
      ),
    );
    // Not even the health check reached the agent, let alone the password.
    expect(paths, isEmpty);
  });

  test('a different pin is certChanged, with both fingerprints', () async {
    final pinned = 'ab' * 32;
    final c = client(pin: pinned);

    await expectLater(
      c.fsRoots(),
      throwsA(
        isA<MonitorHttpErr>()
            .having((e) => e.type, 'type', MonitorHttpErrType.certChanged)
            .having((e) => e.cert?.fingerprint, 'cert', _leafFingerprint())
            .having((e) => e.previousFingerprint, 'previous', pinned),
      ),
    );
    expect(paths, isEmpty);
  });

  test('opening a terminal is refused the same way', () async {
    final c = client();

    await expectLater(
      c.openTerminal(timeout: const Duration(seconds: 5)),
      throwsA(
        isA<MonitorHttpErr>().having(
          (e) => e.type,
          'type',
          MonitorHttpErrType.certUnconfirmed,
        ),
      ),
    );
  });
}
