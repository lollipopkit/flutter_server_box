import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/core/utils/monitor_file_backend.dart';
import 'package:server_box/data/model/server/monitor_http_credential.dart';
import 'package:server_box/data/provider/server/monitor_http.dart';

void main() {
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
}

Future<HttpServer> _serve(
  FutureOr<void> Function(HttpRequest request) handler,
) async {
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  server.listen((request) async {
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
  user: 'user',
  pwd: 'password',
);

Future<void> _json(HttpResponse response, Map<String, Object?> body) async {
  response.headers.contentType = ContentType.json;
  response.write(jsonEncode(body));
  await response.close();
}
