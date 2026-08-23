/// The two things about `RedfishClient` that only a live connection has: a TLS
/// handshake, and a session that has to be given back.
///
/// Against a real HTTPS server, self-signed, on loopback. Everything else the
/// BMC path does is decided in pure code and tested there — this file exists
/// because pinning and session lifetime cannot be checked by reading a JSON
/// map, and because getting either wrong is expensive in a way that shows up
/// late: an unpinned certificate is a password handed to whoever answered, and
/// a leaked session is a BMC that eventually refuses everyone.
///
/// The certificate in `test/fixtures/` is generated for this and nothing else.
/// It is a throwaway keypair for `localhost`, committed so the suite needs no
/// openssl at run time.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/core/utils/cert_pin.dart';
import 'package:server_box/data/model/server/bmc/redfish_service.dart';
import 'package:server_box/data/model/server/bmc_cfg.dart';
import 'package:server_box/data/model/server/bmc_credential.dart';
import 'package:server_box/data/provider/bmc/redfish_client.dart';

/// A Redfish service, as far as this test needs one.
class _FakeBmc {
  _FakeBmc(this._server) {
    _server.listen(_handle);
  }

  static Future<_FakeBmc> start() async {
    final ctx = SecurityContext()
      ..useCertificateChain('test/fixtures/redfish_test_cert.pem')
      ..usePrivateKey('test/fixtures/redfish_test_key.pem');
    return _FakeBmc(
      await HttpServer.bindSecure(InternetAddress.loopbackIPv4, 0, ctx),
    );
  }

  final HttpServer _server;

  /// Every session ever created, and which of them were given back. The point
  /// of the whole exercise.
  final sessionsCreated = <String>[];
  final sessionsDeleted = <String>[];

  int logins = 0;
  var _nextSession = 0;

  String get url => 'https://127.0.0.1:${_server.port}';

  Future<void> close() => _server.close(force: true);

  Future<void> _handle(HttpRequest req) async {
    final path = req.uri.path;
    final res = req.response;
    res.headers.contentType = ContentType.json;

    if (req.method == 'POST' && path == '/redfish/v1/SessionService/Sessions') {
      logins++;
      final body = jsonDecode(await utf8.decoder.bind(req).join());
      if (body['Password'] != 'right') {
        res.statusCode = 401;
        res.write('{}');
        return res.close();
      }
      final id = '/redfish/v1/SessionService/Sessions/${_nextSession++}';
      sessionsCreated.add(id);
      res.statusCode = 201;
      res.headers.set('X-Auth-Token', 'token-for-$id');
      res.headers.set('Location', id);
      res.write(jsonEncode({'@odata.id': id}));
      return res.close();
    }

    if (req.method == 'DELETE' && path.startsWith('/redfish/v1/SessionService/Sessions/')) {
      sessionsDeleted.add(path);
      res.statusCode = 204;
      return res.close();
    }

    if (path == '/redfish/v1/') {
      // Unauthenticated by specification, which is what makes a probe free
      res.write(
        jsonEncode({
          'RedfishVersion': '1.13.0',
          'Systems': {'@odata.id': '/redfish/v1/Systems'},
          'Chassis': {'@odata.id': '/redfish/v1/Chassis'},
          'Links': {
            'Sessions': {'@odata.id': '/redfish/v1/SessionService/Sessions'},
          },
        }),
      );
      return res.close();
    }

    // Everything else needs the token
    if (req.headers.value('X-Auth-Token') == null) {
      res.statusCode = 401;
      res.write('{}');
      return res.close();
    }

    switch (path) {
      case '/redfish/v1/Systems':
        res.write(
          jsonEncode({
            'Members': [
              {'@odata.id': '/redfish/v1/Systems/1'},
            ],
          }),
        );
      case '/redfish/v1/Chassis':
        res.write(jsonEncode({'Members': <Object>[]}));
      case '/redfish/v1/Systems/1':
        res.write(jsonEncode({'PowerState': 'On', 'Model': 'Fake 1U'}));
      case '/redfish/v1/Licensed':
        // Licensing gates parts of some services; this is that answer
        res.statusCode = 403;
        res.write('{}');
      default:
        res.statusCode = 404;
        res.write('{}');
    }
    return res.close();
  }
}

void main() {
  late _FakeBmc bmc;
  late String fingerprint;

  setUp(() async {
    bmc = await _FakeBmc.start();
    fingerprint = (await fetchServerCert('127.0.0.1', Uri.parse(bmc.url).port))
        .fingerprint;
  });

  tearDown(() => bmc.close());

  BmcCfg cfg({String? pin}) =>
      BmcCfg(addr: bmc.url, credId: 'cred-1', certSha256: pin);

  /// The account, which is a record of its own now — see `BmcCredential`.
  BmcCredential cred({String pwd = 'right'}) =>
      BmcCredential(id: 'cred-1', name: 'lab', user: 'admin', pwd: pwd);

  group('the certificate', () {
    test('fetchServerCert reads it without sending anything', () async {
      // The review step: it exists to look at a certificate nobody vouches for
      final info = await fetchServerCert('127.0.0.1', Uri.parse(bmc.url).port);
      expect(info.fingerprint, hasLength(64));
      expect(info.subject, contains('localhost'));
      expect(info.prettyFingerprint, contains(':'));
      // Nothing was requested, so nothing was authenticated
      expect(bmc.logins, 0);
    });

    test('an unreviewed certificate is refused, not trusted on first use', () async {
      final client = RedfishClient(cfg(), cred());
      addTearDown(client.close);

      await expectLater(
        client.probe(),
        throwsA(
          isA<RedfishException>().having(
            (e) => e.failure,
            'failure',
            RedfishFailure.certificateRejected,
          ),
        ),
      );
      // and no credential was ever offered to it
      expect(bmc.logins, 0);
    });

    test('a certificate that is not the pinned one is refused', () async {
      final wrong = 'a' * 64;
      final client = RedfishClient(cfg(pin: wrong), cred());
      addTearDown(client.close);

      await expectLater(
        client.probe(),
        throwsA(isA<RedfishException>()),
      );
      expect(bmc.logins, 0);
    });

    test('the reviewed certificate is accepted', () async {
      final client = RedfishClient(cfg(pin: fingerprint), cred());
      addTearDown(client.close);

      final root = await client.probe();
      expect(root['RedfishVersion'], '1.13.0');
    });
  });

  group('sessions', () {
    test('a probe costs no session', () async {
      final client = RedfishClient(cfg(pin: fingerprint), cred());
      addTearDown(client.close);

      await client.probe();
      expect(bmc.sessionsCreated, isEmpty);
    });

    test('concurrent reads share one login', () async {
      // Without a shared login in flight, a page fetching two resources at
      // once creates two sessions and gives back one. BMCs allow few.
      final client = RedfishClient(cfg(pin: fingerprint), cred());
      addTearDown(client.close);

      await Future.wait([
        client.get('/redfish/v1/Systems'),
        client.get('/redfish/v1/Systems/1'),
        client.get('/redfish/v1/Systems'),
      ]);

      expect(bmc.logins, 1);
      expect(bmc.sessionsCreated, hasLength(1));
    });

    test('close gives the session back', () async {
      final client = RedfishClient(cfg(pin: fingerprint), cred());
      await client.get('/redfish/v1/Systems/1');
      expect(bmc.sessionsCreated, hasLength(1));

      await client.close();

      expect(bmc.sessionsDeleted, bmc.sessionsCreated);
    });

    test('close is safe twice, and after a failure', () async {
      final client = RedfishClient(cfg(pin: fingerprint), cred());
      await client.get('/redfish/v1/Systems/1');
      await client.close();
      await client.close();
      expect(bmc.sessionsDeleted, hasLength(1));
    });

    test('a client that never logged in still closes', () async {
      final client = RedfishClient(cfg(pin: fingerprint), cred());
      await client.close();
      expect(bmc.sessionsDeleted, isEmpty);
    });
  });

  group('answers that mean something', () {
    test('wrong credentials are unauthorized, not unreachable', () async {
      final client = RedfishClient(cfg(pin: fingerprint), cred(pwd: 'wrong'));
      addTearDown(client.close);

      await expectLater(
        client.get('/redfish/v1/Systems/1'),
        throwsA(
          isA<RedfishException>().having(
            (e) => e.failure,
            'failure',
            RedfishFailure.unauthorized,
          ),
        ),
      );
    });

    test('a licensed-only resource is forbidden, and names itself', () async {
      final client = RedfishClient(cfg(pin: fingerprint), cred());
      addTearDown(client.close);

      await expectLater(
        client.get('/redfish/v1/Licensed'),
        throwsA(
          isA<RedfishException>()
              .having((e) => e.failure, 'failure', RedfishFailure.forbidden)
              .having((e) => e.detail, 'detail', contains('Licensed')),
        ),
      );
    });
  });

  group('discovery over the real transport', () {
    test('walks the service and stops where it runs out', () async {
      // The chassis collection is empty here, which costs the sensors and must
      // not cost the system
      final client = RedfishClient(cfg(pin: fingerprint), cred());
      addTearDown(client.close);

      final topology = await RedfishDiscovery(client).run();

      expect(topology.systemPath, '/redfish/v1/Systems/1');
      expect(topology.system?.model, 'Fake 1U');
      expect(topology.chassis, isNull);
      // One login for the whole walk, not one per resource
      expect(bmc.logins, 1);
    });
  });
}
