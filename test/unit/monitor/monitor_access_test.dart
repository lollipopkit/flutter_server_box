/// `MonitorHttpClient` against a stand-in for an agent with one account: the
/// login and password shapes `docs/dev/monitor-permissions.md` fixes, and the
/// `access` answer of `/capabilities`.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/core/service/monitor_login_devices.dart';
import 'package:server_box/data/model/app/error.dart';
import 'package:server_box/data/model/server/capabilities.dart';
import 'package:server_box/data/model/server/monitor_access.dart';
import 'package:server_box/data/model/server/monitor_capabilities.dart';
import 'package:server_box/data/model/server/monitor_http_credential.dart';
import 'package:server_box/data/provider/server/monitor_http.dart';

void main() {
  group('the client', () {
    late HttpServer server;
    late MonitorHttpClient client;
    late List<(String, String, Object?)> seen;

    late MemoryDeviceTokenStore devices;

    setUp(() async {
      seen = [];
      devices = MemoryDeviceTokenStore();
      MonitorLoginDevices.store = devices;
      MonitorLoginDevices.resetForTest();
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      server.listen((req) async {
        final raw = await utf8.decoder.bind(req).join();
        final body = raw.isEmpty ? null : jsonDecode(raw);
        final path = req.uri.path;
        seen.add((req.method, path, body));
        final current = body is Map ? body['current_password'] : null;
        final (int status, Object? out) = switch ((req.method, path)) {
          (_, '/api/v1/login') when body is Map && body['device'] == null =>
            (200, {'token': 't', 'device': 'sbd_1'}),
          (_, '/api/v1/login') => (200, {'token': 't'}),
          ('PUT', '/api/v1/me/password') when current != 'pw' => (403, {
            'error': 'reauth',
            'message': 'Wrong password',
          }),
          ('PUT', '/api/v1/me/password') => (204, null),
          _ => (404, {'error': 'not_found', 'message': 'no'}),
        };
        req.response.statusCode = status;
        if (out != null) {
          req.response
            ..headers.contentType = ContentType.json
            ..write(jsonEncode(out));
        }
        await req.response.close();
      });
      client = MonitorHttpClient(
        MonitorHttpCredential(
          addr: 'http://127.0.0.1:${server.port}',
          pwd: 'pw',
        ),
      );
    });

    tearDown(() async {
      client.dispose();
      await server.close(force: true);
    });

    test('logs in with the password alone', () async {
      await client.changeOwnPassword(
        currentPassword: 'pw',
        newPassword: 'n3w-pass',
      );
      final (method, path, body) = seen.first;
      expect((method, path), ('POST', '/api/v1/login'));
      expect(body, {'password': 'pw', 'name': MonitorHttpClient.deviceName});
    });

    // TODO: remove with `MonitorHttpCredential.legacyUser`.
    test('signs in to an agent from before one account as the name it keeps', () async {
      final endpoint = 'http://127.0.0.1:${server.port}';
      final credential = MonitorHttpCredential(addr: endpoint, pwd: 'pw').withLegacyUser('admin');
      // Kept where it always was, so a restored backup still reaches such an agent.
      expect(credential.toJson()['user'], 'admin');
      expect(MonitorHttpCredential.fromJson(credential.toJson()), credential);
      final legacy = MonitorHttpClient(credential);
      addTearDown(legacy.dispose);
      await legacy.changeOwnPassword(currentPassword: 'pw', newPassword: 'n3w-pass');
      final (_, path, body) = seen.first;
      expect(path, '/api/v1/login');
      expect(body, {'username': 'admin', 'password': 'pw', 'name': MonitorHttpClient.deviceName});
    });

    test('keeps the device token a sign-in gives and sends it next time', () async {
      await client.changeOwnPassword(currentPassword: 'pw', newPassword: 'n3w-pass');
      final endpoint = 'http://127.0.0.1:${server.port}';
      expect(devices.saved, {endpoint: 'sbd_1'});

      // A new client, and a cold cache: read back from the store.
      MonitorLoginDevices.resetForTest();
      final again = MonitorHttpClient(MonitorHttpCredential(addr: '$endpoint/', pwd: 'pw'));
      addTearDown(again.dispose);
      seen.clear();
      await again.changeOwnPassword(currentPassword: 'pw', newPassword: 'n3w-pass');
      final (_, path, body) = seen.first;
      expect(path, '/api/v1/login');
      expect(body, {'password': 'pw', 'device': 'sbd_1', 'name': MonitorHttpClient.deviceName});
    });

    test('clients signing in together are one device', () async {
      final endpoint = 'http://127.0.0.1:${server.port}';
      final others = [
        for (var i = 0; i < 3; i++) MonitorHttpClient(MonitorHttpCredential(addr: endpoint, pwd: 'pw')),
      ];
      for (final c in others) {
        addTearDown(c.dispose);
      }
      await Future.wait([
        client.changeOwnPassword(currentPassword: 'pw', newPassword: 'n3w-pass'),
        for (final c in others) c.changeOwnPassword(currentPassword: 'pw', newPassword: 'n3w-pass'),
      ]);
      final logins = [for (final (_, path, body) in seen) if (path == '/api/v1/login') body as Map];
      expect(logins, hasLength(4));
      // The first asked without a token; the rest waited and brought it.
      expect(logins.where((b) => b['device'] == null), hasLength(1));
      expect(logins.where((b) => b['device'] == 'sbd_1'), hasLength(3));
    });

    test('changing the password sends both', () async {
      await client.changeOwnPassword(
        currentPassword: 'pw',
        newPassword: 'n3w-pass',
      );
      final (method, path, body) = seen.last;
      expect((method, path), ('PUT', '/api/v1/me/password'));
      expect(body, {'current_password': 'pw', 'new_password': 'n3w-pass'});
    });

    test('a wrong current password is reauth', () async {
      await expectLater(
        client.changeOwnPassword(
          currentPassword: 'wrong',
          newPassword: 'n3w-pass',
        ),
        throwsA(
          isA<MonitorHttpErr>().having(
            (e) => e.type,
            'type',
            MonitorHttpErrType.reauth,
          ),
        ),
      );
    });
  });

  test('an agent from before one account says it is too old, not Dio\'s paragraph', () async {
    final old = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => old.close(force: true));
    old.listen((req) async {
      await req.drain<void>();
      req.response
        ..statusCode = 400
        ..write('Json deserialize error: missing field `username` at line 1 column 40');
      await req.response.close();
    });
    MonitorLoginDevices.store = MemoryDeviceTokenStore();
    MonitorLoginDevices.resetForTest();
    final client = MonitorHttpClient(MonitorHttpCredential(addr: 'http://127.0.0.1:${old.port}', pwd: 'pw'));
    addTearDown(client.dispose);
    await expectLater(
      client.changeOwnPassword(currentPassword: 'pw', newPassword: 'n3w-pass'),
      throwsA(
        isA<MonitorHttpErr>()
            .having((e) => e.type, 'type', MonitorHttpErrType.agentTooOld)
            .having((e) => e.message, 'message', l10n.monitorAgentTooOld),
      ),
    );
  });

  test('a sign-in nobody waits for any more does not hold the next', () async {
    final agent = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => agent.close(force: true));
    var logins = 0;
    agent.listen((req) async {
      await req.drain<void>();
      // The first sign-in is never answered.
      if (req.uri.path == '/api/v1/login' && ++logins == 1) return;
      req.response
        ..statusCode = req.uri.path == '/api/v1/login' ? 200 : 204
        ..headers.contentType = ContentType.json
        ..write(req.uri.path == '/api/v1/login' ? jsonEncode({'token': 't', 'device': 'sbd_9'}) : '');
      await req.response.close();
    });
    MonitorLoginDevices.store = MemoryDeviceTokenStore();
    MonitorLoginDevices.resetForTest();
    final cred = MonitorHttpCredential(addr: 'http://127.0.0.1:${agent.port}', pwd: 'pw');
    final stuck = MonitorHttpClient(cred);
    unawaited(stuck.changeOwnPassword(currentPassword: 'pw', newPassword: 'n3w-pass').then((_) {}, onError: (_) {}));
    await Future<void>.delayed(const Duration(milliseconds: 100));
    stuck.dispose();

    final next = MonitorHttpClient(cred);
    addTearDown(next.dispose);
    await next
        .changeOwnPassword(currentPassword: 'pw', newPassword: 'n3w-pass')
        .timeout(const Duration(seconds: 3), onTimeout: () => fail('waited on the abandoned sign-in'));
    expect(logins, 2);
  });

  test('a backup or sync payload that still names a user reads', () {
    // Written before the agent had one account; the name is kept for such an
    // agent. TODO: remove with `MonitorHttpCredential.legacyUser`.
    final cred = MonitorHttpCredential.fromJson(const {
      'addr': 'https://agent:3770',
      'user': 'admin',
      'pwd': 'pw',
      'ignoreCert': true,
    });
    expect(
      cred,
      const MonitorHttpCredential(
        addr: 'https://agent:3770',
        pwd: 'pw',
        legacyUser: 'admin',
        ignoreCert: true,
      ),
    );
    expect(cred.toJson()['user'], 'admin');
  });

  test('a 401 is left to the login retry', () {
    expect(MonitorHttpClient.accessErr(401, {'error': 'unauthorized'}), isNull);
    expect(MonitorHttpClient.accessErr(500, null), isNull);
  });

  group('capabilities.access', () {
    MonitorAccess read(Object? access) =>
        MonitorCapabilities.fromJson({'access': ?access}).access;

    test('ok', () {
      expect(read({'ok': true}), MonitorAccess.granted);
      expect(read({'ok': true}).why, isNull);
    });

    test('refused over plaintext, with the reason', () {
      final access = read({'ok': false, 'why': 'insecure_transport'});
      expect(access.ok, isFalse);
      expect(access.why, MonitorAccessWhy.insecureTransport);
    });

    test('a reason this app does not know is still a refusal', () {
      final access = read({'ok': false, 'why': 'later'});
      expect(access.ok, isFalse);
      expect(access.why, MonitorAccessWhy.unknown);
    });

    test('a watch token answers refused with no reason', () {
      final access = read({'ok': false});
      expect(access.ok, isFalse);
      expect(access.why, isNull);
    });

    test('absent is refused, not granted', () {
      expect(read(null), MonitorAccess.none);
      expect(read('yes'), MonitorAccess.none);
    });

    test('one answer for everything the agent offers', () {
      for (final (access, expected) in [
        (MonitorAccess.granted, true),
        (MonitorAccess.none, false),
      ]) {
        final caps = MonitorHttpCapabilities(access);
        expect(caps.shell, expected);
        expect(caps.terminal, expected);
        expect(caps.files, expected);
        expect(caps.tcpRelay, expected);
        expect(caps.remoteListen, expected);
        expect(caps.byteStream, isFalse);
      }
    });
  });
}
