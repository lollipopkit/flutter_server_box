/// `sb.http.fetch`, against a TLS server that really presents a certificate.
/// PLUGINS.md section 4.3.
///
/// The pin is the whole trust decision, and a wrong answer from it is silent:
/// a refused certificate drops a request, an accepted one lets a password
/// reach whatever answered. So every branch of the decision is exercised
/// against a real handshake rather than a mocked client — the part worth
/// checking is the one `dart:io` performs.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/data/provider/plugin/http.dart';

/// The same certificate `packages/redfish` tests against.
///
/// Shared rather than copied: it is a fixture whose only property that matters
/// is that it is self-signed, and two of them would be two things to renew.
const _certDir = 'packages/redfish/test/fixtures';

/// Answers anything, and records what it was asked.
class _Server {
  _Server(this._http) {
    _http.listen((request) async {
      seen.add('${request.method} ${request.uri.path}');
      seenHeaders.add({
        for (final name in ['accept', 'x-token'])
          if (request.headers.value(name) case final v?) name: v,
      });
      body = await utf8.decoder.bind(request).join();
      request.response
        ..statusCode = status
        ..headers.set('content-type', 'application/json')
        ..add(payload);
      await request.response.close();
    });
  }

  final HttpServer _http;
  final seen = <String>[];
  final seenHeaders = <Map<String, String>>[];
  String? body;
  int status = 200;
  List<int> payload = utf8.encode('{"ok":true}');

  int get port => _http.port;
  String get url => 'https://127.0.0.1:$port';

  static Future<_Server> startTls() async {
    final ctx = SecurityContext()
      ..useCertificateChain('$_certDir/redfish_test_cert.pem')
      ..usePrivateKey('$_certDir/redfish_test_key.pem');
    return _Server(
      await HttpServer.bindSecure(InternetAddress.loopbackIPv4, 0, ctx),
    );
  }

  static Future<_Server> startPlain() async =>
      _Server(await HttpServer.bind(InternetAddress.loopbackIPv4, 0));

  Future<void> close() => _http.close(force: true);
}

void main() {
  late _Server server;
  late String pin;

  setUp(() async {
    server = await _Server.startTls();
    // The review step, which is also the only way a test learns the
    // fingerprint — exactly the position a user is in.
    pin = (await PluginHttp.probe('127.0.0.1', server.port)).cert!['sha256']
        as String;
  });

  tearDown(() => server.close());

  group('the review step', () {
    test('a probe reads the certificate and sends nothing', () async {
      final result = await PluginHttp.probe('127.0.0.1', server.port);

      expect(result.status, 0);
      expect(result.body, isEmpty);
      final cert = result.cert!;
      expect(cert['sha256'], hasLength(64));
      expect(cert['sha256'], matches(RegExp(r'^[0-9a-f]+$')));
      expect('${cert['subject']}', isNotEmpty);
      expect(cert['issuer'], cert['subject'], reason: 'self-signed');
      expect(cert['expired'], isFalse);
      expect(DateTime.parse('${cert['notAfter']}'), isNotNull);

      // The whole reason accepting any certificate is safe here.
      expect(server.seen, isEmpty);
    });

    /// Not `X509Certificate.sha1`, the only digest `dart:io` offers ready
    /// made. A trust decision does not rest on SHA-1.
    test('the fingerprint is of the DER, and stable', () async {
      final a = await PluginHttp.probe('127.0.0.1', server.port);
      final b = await PluginHttp.probe('127.0.0.1', server.port);

      expect(a.cert!['sha256'], b.cert!['sha256']);
    });
  });

  group('the enforcement step', () {
    test('the reviewed certificate is accepted, and the answer comes back',
        () async {
      final result = await PluginHttp.fetch(
        url: '${server.url}/redfish/v1',
        method: 'POST',
        headers: const {'accept': 'application/json', 'x-token': 'abc'},
        body: '{"Action":"Reset"}',
        pinSha256: pin,
      );

      expect(result.status, 200);
      expect(result.body, '{"ok":true}');
      expect(result.bodyEncoding, 'utf8');
      expect(result.headers['content-type'], contains('application/json'));
      expect(result.cert!['sha256'], pin);
      expect(server.seen, ['POST /redfish/v1']);
      expect(server.seenHeaders.single, {
        'accept': 'application/json',
        'x-token': 'abc',
      });
      expect(server.body, '{"Action":"Reset"}');
    });

    test('an upper-case pin is the same pin', () async {
      final result = await PluginHttp.fetch(
        url: '${server.url}/a',
        pinSha256: pin.toUpperCase(),
      );

      expect(result.status, 200);
    });

    /// The failure that matters. A request carrying a password must not reach
    /// a certificate nobody vouched for — and it must fail during the
    /// handshake, before the body exists.
    test('a different certificate is refused, and nothing is sent', () async {
      await expectLater(
        PluginHttp.fetch(
          url: '${server.url}/redfish/v1',
          method: 'POST',
          body: 'password=hunter2',
          pinSha256: 'de' * 32,
        ),
        throwsA(isA<HandshakeException>()),
      );

      expect(server.seen, isEmpty);
      expect(server.body, isNull);
    });

    /// Absent refuses rather than falling back to ordinary validation. The
    /// hardware this is first for ships certificates no CA has ever seen, so
    /// "valid chain" and "the right machine" have nothing to do with each
    /// other there.
    test('no pin refuses before a connection is opened', () async {
      await expectLater(
        PluginHttp.fetch(url: '${server.url}/a'),
        throwsA(isA<TlsException>()),
      );
      await expectLater(
        PluginHttp.fetch(url: '${server.url}/a', pinSha256: ''),
        throwsA(isA<TlsException>()),
      );

      expect(server.seen, isEmpty);
    });

    /// The client carries no trusted roots at all, so a chain a real CA
    /// vouches for is refused exactly like a self-signed one unless it is the
    /// certificate that was reviewed. Otherwise a plugin could name any host
    /// whose certificate a public CA happens to have signed.
    test('a publicly trusted certificate is not a pass', () async {
      await expectLater(
        PluginHttp.fetch(url: 'https://example.com/', pinSha256: 'de' * 32),
        throwsA(isA<Exception>()),
      );
    }, skip: 'reaches the network');
  });

  group('the rest of a request', () {
    test('plain http carries no certificate and needs no pin', () async {
      final plain = await _Server.startPlain();
      addTearDown(plain.close);

      final result = await PluginHttp.fetch(
        url: 'http://127.0.0.1:${plain.port}/a',
      );

      expect(result.status, 200);
      expect(result.cert, isNull);
      expect(plain.seen, ['GET /a']);
    });

    /// Bytes that are not text come back base64 rather than failing: an image
    /// or a firmware blob is a thing a plugin may legitimately fetch.
    test('an undecodable body falls back to base64', () async {
      server.payload = const [0xff, 0xfe, 0x00, 0x01];

      final result = await PluginHttp.fetch(
        url: '${server.url}/blob',
        pinSha256: pin,
      );

      expect(result.bodyEncoding, 'base64');
      expect(base64Decode(result.body), [0xff, 0xfe, 0x00, 0x01]);
    });

    test('a base64 body is decoded before it is sent', () async {
      await PluginHttp.fetch(
        url: '${server.url}/a',
        method: 'PUT',
        body: base64Encode(utf8.encode('hello')),
        bodyEncoding: 'base64',
        pinSha256: pin,
      );

      expect(server.body, 'hello');
    });

    /// A status is read rather than thrown on: 401 and 403 carry meaning to a
    /// BMC, and licensing makes 403 an ordinary answer there.
    test('an error status is an answer, not a failure', () async {
      server.status = 401;

      final result = await PluginHttp.fetch(
        url: '${server.url}/a',
        pinSha256: pin,
      );

      expect(result.status, 401);
    });

    /// The body crosses the FFI boundary as one string into an interpreter
    /// with a memory ceiling, so it is refused rather than held.
    test('a body over the cap is refused', () async {
      server.payload = List.filled(PluginHttp.maxBodyBytes + 1024, 0x41);

      await expectLater(
        PluginHttp.fetch(url: '${server.url}/big', pinSha256: pin),
        throwsA(isA<HttpException>()),
      );
    });

    /// Off, so a redirect cannot move a pinned request to another host — the
    /// address list was checked against the URL the plugin named.
    test('a redirect is an answer the plugin sees, not one that is followed',
        () async {
      final elsewhere = await _Server.startPlain();
      addTearDown(elsewhere.close);
      server.status = 302;

      final result = await PluginHttp.fetch(
        url: '${server.url}/a',
        pinSha256: pin,
      );

      expect(result.status, 302);
      expect(elsewhere.seen, isEmpty);
    });
  });
}
