/// `MonitorHttpClient`'s account and role requests against a stand-in for an
/// agent with roles: the shapes `docs/dev/monitor-permissions.md` fixes, and
/// each refusal arriving as its own [MonitorHttpErrType].
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/data/model/app/error.dart';
import 'package:server_box/data/model/server/monitor_grants.dart';
import 'package:server_box/data/model/server/monitor_http_credential.dart';
import 'package:server_box/data/provider/server/monitor_http.dart';

void main() {
  late HttpServer server;
  late MonitorHttpClient client;
  late List<(String, String, Object?)> seen;

  const desktop = {
    'name': 'desktop',
    'admin': false,
    'builtin': false,
    'grants': {
      'shell': false,
      'ssh_terminal': false,
      'files': {'mode': 'read'},
      'connect': {
        'allow': ['127.0.0.1:3389'],
      },
      'listen': {
        'public': false,
        'ports': [1024, 2048],
      },
    },
  };

  setUp(() async {
    seen = [];
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((req) async {
      final raw = await utf8.decoder.bind(req).join();
      final body = raw.isEmpty ? null : jsonDecode(raw);
      final path = req.uri.path;
      if (path != '/api/v1/login') seen.add((req.method, path, body));
      final current = body is Map ? body['current_password'] : null;
      final (int status, Object? out) = switch ((req.method, path)) {
        (_, '/api/v1/login') => (200, {'token': 't'}),
        ('GET', '/api/v1/me') => (200, {'username': 'alice', 'role': desktop}),
        ('PUT', '/api/v1/me/password') => (204, null),
        ('GET', '/api/v1/users') => (200, [
          {
            'username': 'alice',
            'role': 'desktop',
            'created_at': '2026-01-01T00:00:00Z',
            'last_login': null,
          },
        ]),
        ('POST', '/api/v1/users') => (201, {'username': 'bob', 'role': 'viewer'}),
        ('PUT', '/api/v1/users/bob') when current != 'pw' => (403, {
          'error': 'reauth',
          'message': 'Wrong password',
        }),
        ('PUT', '/api/v1/users/bob') => (200, {'username': 'bob', 'role': 'admin'}),
        ('DELETE', '/api/v1/users/admin') => (409, {
          'error': 'last_admin',
          'message': 'The last admin',
        }),
        ('GET', '/api/v1/roles') => (200, [desktop]),
        ('POST', '/api/v1/roles') => (409, {
          'error': 'conflict',
          'message': 'exists',
        }),
        ('DELETE', '/api/v1/roles/admin') => (403, {
          'error': 'forbidden',
          'message': 'built-in',
        }),
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
        user: 'alice',
        pwd: 'pw',
      ),
    );
  });

  tearDown(() async {
    client.dispose();
    await server.close(force: true);
  });

  Matcher err(MonitorHttpErrType type) =>
      throwsA(isA<MonitorHttpErr>().having((e) => e.type, 'type', type));

  test('me answers the account and its role, options and all', () async {
    final me = await client.fetchMe();
    expect(me.username, 'alice');
    expect(me.role.name, 'desktop');
    expect(me.role.grants.files, MonitorFilesMode.read);
    expect(me.role.grants.connectAllow, ['127.0.0.1:3389']);
    expect(me.role.grants.listen?.ports, (1024, 2048));
    expect(me.role.grants.shell, isFalse);
  });

  test('a role goes back in the shape it came', () async {
    final role = MonitorRole.fromJson(desktop);
    final json = role.toJson();
    expect(json['grants'], desktop['grants']);
    expect(json['name'], 'desktop');
  });

  test('changing your own password sends both', () async {
    await client.changeOwnPassword(currentPassword: 'pw', newPassword: 'n3w-pass');
    final (method, path, body) = seen.single;
    expect((method, path), ('PUT', '/api/v1/me/password'));
    expect(body, {'current_password': 'pw', 'new_password': 'n3w-pass'});
  });

  test('accounts are listed, created with the admin\'s password', () async {
    final users = await client.fetchUsers();
    expect(users.single.username, 'alice');
    expect(users.single.role, 'desktop');
    expect(users.single.createdAt, isNotNull);
    expect(users.single.lastLogin, isNull);

    await client.createUser(
      username: 'bob',
      password: 'secret123',
      role: 'viewer',
      currentPassword: 'pw',
    );
    expect(seen.last.$3, {
      'username': 'bob',
      'password': 'secret123',
      'role': 'viewer',
      'current_password': 'pw',
    });
  });

  test('an update sends only what changes', () async {
    await client.updateUser('bob', role: 'admin', currentPassword: 'pw');
    expect(seen.last.$3, {'role': 'admin', 'current_password': 'pw'});
  });

  test('each refusal is its own type', () async {
    await expectLater(
      client.updateUser('bob', role: 'admin', currentPassword: 'wrong'),
      err(MonitorHttpErrType.reauth),
    );
    await expectLater(
      client.deleteUser('admin', currentPassword: 'pw'),
      err(MonitorHttpErrType.lastAdmin),
    );
    await expectLater(
      client.createRole(
        const MonitorRole(name: 'desktop'),
        currentPassword: 'pw',
      ),
      err(MonitorHttpErrType.conflict),
    );
    await expectLater(
      client.deleteRole('admin', currentPassword: 'pw'),
      err(MonitorHttpErrType.forbidden),
    );
    await expectLater(
      client.deleteUser('nobody', currentPassword: 'pw'),
      err(MonitorHttpErrType.notFound),
    );
    // The body travels with a DELETE.
    expect(seen.last.$3, {'current_password': 'pw'});
  });

  test('roles are listed', () async {
    final roles = await client.fetchRoles();
    expect(roles.single.name, 'desktop');
    expect(roles.single.builtin, isFalse);
  });

  test('a 401 is left to the login retry', () {
    expect(MonitorHttpClient.accessErr(401, {'error': 'unauthorized'}), isNull);
    expect(MonitorHttpClient.accessErr(500, null), isNull);
  });
}
