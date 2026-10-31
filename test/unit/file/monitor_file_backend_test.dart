import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/core/utils/monitor_file_backend.dart';
import 'package:server_box/data/model/app/error.dart';
import 'package:server_box/data/model/server/monitor_http_credential.dart';
import 'package:server_box/data/provider/server/monitor_http.dart';

import '../../helpers/fake_agent_health.dart';
import '../../helpers/local_http.dart';
import '../../helpers/rust_lib_helper.dart';

void main() {
  // `MonitorHttpClient` names its protocol from Rust.
  setUpAll(initRustLibForTest);

  test('monitor file backends share login and roots probes', () async {
    var logins = 0;
    var roots = 0;
    final server = await _serve((request) async {
      if (request.uri.path == '/api/v1/login') {
        logins++;
        return _json(request.response, {'token': 'token'});
      }
      if (request.uri.path == '/api/v1/fs/roots') {
        roots++;
        return _json(request.response, {
          'roots': ['/srv'],
        });
      }
      request.response.statusCode = HttpStatus.notFound;
      await request.response.close();
    });
    final credential = _credential(server);
    final first = MonitorFileBackend(credential);
    final second = MonitorFileBackend(credential);

    try {
      expect(await first.reachableRoots(), ['/srv']);
      expect(await second.reachableRoots(), ['/srv']);
      expect(logins, 1);
      expect(roots, 1);
    } finally {
      await first.close();
      await second.close();
      await server.close(force: true);
    }
  });

  test('monitor upload replays its body after a late 401', () async {
    var logins = 0;
    final uploaded = <List<int>>[];
    final server = await _serve((request) async {
      if (request.uri.path == '/api/v1/login') {
        logins++;
        return _json(request.response, {'token': 'token-$logins'});
      }
      if (request.uri.path == '/api/v1/fs/roots') {
        return _json(request.response, {
          'roots': ['/srv'],
        });
      }
      if (request.uri.path == '/api/v1/fs/write') {
        uploaded.add(
          await request.fold<List<int>>([], (all, chunk) => all..addAll(chunk)),
        );
        if (request.headers.value(HttpHeaders.authorizationHeader) ==
            'Bearer token-1') {
          request.response.statusCode = HttpStatus.unauthorized;
        }
        return request.response.close();
      }
      request.response.statusCode = HttpStatus.notFound;
      await request.response.close();
    });
    final client = MonitorHttpClient(_credential(server));
    var replays = 0;

    try {
      await client.fsWrite(
        '/srv/file',
        Stream.value(const [1, 2, 3]),
        size: 3,
        replayData: () {
          replays++;
          return Stream.value(const [1, 2, 3]);
        },
      );

      expect(logins, 2);
      expect(replays, 1);
      expect(uploaded, [
        [1, 2, 3],
        [1, 2, 3],
      ]);
    } finally {
      client.dispose();
      await server.close(force: true);
    }
  });
  test('failed roots probes can be retried', () async {
    var probes = 0;
    final server = await _serve((request) async {
      if (request.uri.path.endsWith('/login')) {
        return _json(request.response, {'token': 'token'});
      }
      if (++probes == 1) {
        request.response.statusCode = 503;
        await request.response.close();
      } else {
        await _json(request.response, {
          'roots': ['/srv'],
        });
      }
    });
    final backend = MonitorFileBackend(_credential(server));
    try {
      await expectLater(
        backend.reachableRoots(),
        throwsA(isA<MonitorHttpErr>()),
      );
      expect(await backend.reachableRoots(), ['/srv']);
      expect(probes, 2);
    } finally {
      await backend.close();
      await server.close(force: true);
    }
  });

  test(
    'the last backend releases the shared HTTP client exactly once',
    () async {
      final server = await _serve(
        (request) => _json(
          request.response,
          request.uri.path.endsWith('/login')
              ? {'token': 'token'}
              : {
                  'roots': ['/srv'],
                },
        ),
      );
      final http = LocalHttp(server);
      try {
        await HttpOverrides.runWithHttpOverrides(() async {
          final first = MonitorFileBackend(_credential(server));
          final second = MonitorFileBackend(_credential(server));
          await first.reachableRoots();
          expect(http.created, 1);
          await first.close();
          await first.close();
          expect(http.closed, 0);
          expect(await second.reachableRoots(), ['/srv']);
          await second.close();
          await second.close();
          expect(http.closed, 1);
        }, http);
      } finally {
        await server.close(force: true);
      }
    },
  );

  test(
    'an interrupted download fails instead of accepting a partial file',
    () async {
      final server = await _serve((request) async {
        if (request.uri.path.endsWith('/login')) {
          return _json(request.response, {'token': 'token'});
        }
        final socket = await request.response.detachSocket(writeHeaders: false);
        socket.write('HTTP/1.1 200 OK\r\nContent-Length: 100\r\n\r\nabc');
        await socket.flush();
        socket.destroy();
      });
      final backend = MonitorFileBackend(_credential(server));
      try {
        await expectLater(
          backend.read('/srv/file').drain<void>(),
          throwsA(anything),
        );
      } finally {
        await backend.close();
        await server.close(force: true);
      }
    },
  );

  test('a write based on a stale version is refused as modified', () async {
    var current = 'v1';
    final written = <String?>[];
    final server = await _serve((request) async {
      switch (request.uri.path) {
        case '/api/v1/login':
          return _json(request.response, {'token': 'token'});
        case '/api/v1/fs/roots':
          return _json(request.response, {
            'roots': ['/srv'],
          });
        case '/api/v1/fs/stat':
          return _json(request.response, {
            'name': 'file',
            'kind': 'file',
            'version': current,
          });
        case '/api/v1/fs/write':
          await request.drain<void>();
          final expected = request.uri.queryParameters['if_version'];
          written.add(expected);
          if (expected != null && expected != current) {
            request.response.statusCode = HttpStatus.conflict;
            return _json(request.response, {'error': 'modified'});
          }
          current = 'v${written.length + 1}';
          return _json(request.response, {'bytes': 4, 'version': current});
      }
      request.response.statusCode = HttpStatus.notFound;
      await request.response.close();
    });
    final backend = MonitorFileBackend(_credential(server));
    try {
      final opened = await backend.versionOf('/srv/file');
      expect(opened, 'v1');
      // Changed on the server after it was opened.
      current = 'v9';

      await expectLater(
        backend.writeIfUnchanged('/srv/file', utf8.encode('edit'), opened),
        throwsA(
          isA<MonitorHttpErr>().having(
            (e) => e.type,
            'type',
            MonitorHttpErrType.modified,
          ),
        ),
      );
      // Overwriting on purpose names no version, and the write says what it
      // left for the next save to name.
      expect(
        await backend.writeIfUnchanged('/srv/file', utf8.encode('edit'), null),
        'v3',
      );
      expect(written, ['v1', null]);
    } finally {
      await backend.close();
      await server.close(force: true);
    }
  });
}

Future<HttpServer> _serve(
  FutureOr<void> Function(HttpRequest request) handler,
) async {
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  server.listen((request) async {
    if (await answerAgentHealth(request)) return;
    try {
      await handler(request);
    } catch (_) {
      request.response.statusCode = HttpStatus.internalServerError;
      await request.response.close();
    }
  });
  return server;
}

MonitorHttpCredential _credential(HttpServer server) => MonitorHttpCredential(
  addr: 'http://${server.address.address}:${server.port}',
  pwd: 'password',
);

Future<void> _json(HttpResponse response, Map<String, Object?> body) async {
  response.headers.contentType = ContentType.json;
  response.write(jsonEncode(body));
  await response.close();
}
