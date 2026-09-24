import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:fl_lib/fl_lib.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/core/utils/monitor_backup_storage.dart';
import 'package:server_box/data/model/app/error.dart';
import 'package:server_box/data/model/server/monitor_http_credential.dart';

import '../../helpers/local_http.dart';

/// One request as the fake agent read it.
final class _Seen {
  _Seen(this.method, this.path, this.query, this.headers, this.body);

  final String method;
  final String path;
  final Map<String, String> query;
  final Map<String, String> headers;
  final List<int> body;
}

/// A fake monitor agent on loopback, with everything it was asked for.
///
/// A real socket rather than a mocked client, for `monitor_file_backend_test`'s
/// reason: what is asserted here is what went over the wire — the name in the
/// query, the length header, the bytes — and a mock would assert what this test
/// believed the client does.
final class _Fake {
  _Fake(this.server, this.seen);

  final HttpServer server;
  final List<_Seen> seen;
}

Future<_Fake> _serve(FutureOr<void> Function(HttpRequest) handler) async {
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  final seen = <_Seen>[];
  server.listen((request) async {
    final body = <int>[];
    await for (final chunk in request) {
      body.addAll(chunk);
    }
    final headers = <String, String>{};
    request.headers.forEach((name, values) => headers[name] = values.join(','));
    seen.add(
      _Seen(request.method, request.uri.path, request.uri.queryParameters, headers, body),
    );
    try {
      await handler(request);
    } catch (_) {
      request.response.statusCode = HttpStatus.internalServerError;
      await request.response.close();
    }
  });
  return _Fake(server, seen);
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

/// The answer a login gets, which every test needs for its first call.
Future<bool> _loginOr(
  HttpRequest request,
  FutureOr<void> Function() rest,
) async {
  if (request.uri.path.endsWith('/login')) {
    await _json(request.response, {'token': 'token'});
    return true;
  }
  await rest();
  return false;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late _Fake agent;
  late MonitorBackupStorage storage;

  Future<void> start(FutureOr<void> Function(HttpRequest) handler) async {
    agent = await _serve(handler);
    storage = MonitorBackupStorage('server-1', _credential(agent.server));
  }

  /// Runs [body] with the fake agent reachable.
  ///
  /// The test binding answers every real HTTP request with a 400 of its own —
  /// which is what stops a test in this suite from reaching the network — so a
  /// test that *means* to reach one has to override it, which is what
  /// `LocalHttp` is for. Everything it is asked for is counted there, and what
  /// this file asserts about is the request the client composed.
  Future<T> onAgent<T>(Future<T> Function() body) =>
      HttpOverrides.runWithHttpOverrides(body, LocalHttp(agent.server));

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('sbm-monitor-backup-');
    Paths.doc = tempDir.path;
  });

  tearDownAll(() => tempDir.delete(recursive: true));

  tearDown(() async {
    storage.close();
    await agent.server.close(force: true);
  });

  test('the bytes go up under the name the caller gave', () async {
    final path = tempDir.path.joinPath('srvbox_bak_v3.json');
    final content = utf8.encode('LKFL_ENC_V01-not-really');
    await File(path).writeAsBytes(content);

    late List<int> uploaded;
    await start((request) async {
      final handled = await _loginOr(request, () async {
        uploaded = agent.seen.last.body;
        await _json(request.response, {
          'name': 'srvbox_bak_v3.json',
          'size': content.length,
          'updated_at': '2026-09-24T12:00:00+00:00',
        });
      });
      if (handled) return;
    });

    await onAgent(() => storage.upload(relativePath: 'srvbox_bak_v3.json'));

    final put = agent.seen.firstWhere((r) => r.method == 'PUT');
    expect(put.path, '/api/v1/backup/blob');
    expect(put.query['name'], 'srvbox_bak_v3.json');
    // The length, so the agent is told where the body ends rather than reading
    // until the connection closes.
    expect(put.headers['content-length'], contains('${content.length}'));
    expect(uploaded, content);
  });

  test('what the agent holds comes down to the local path', () async {
    final content = utf8.encode('ciphertext-from-the-agent');
    await start((request) async {
      await _loginOr(request, () async {
        request.response.headers.contentType = ContentType.binary;
        request.response.add(content);
        await request.response.close();
      });
    });

    await onAgent(
      () => storage.download(relativePath: 'srvbox_bak_v3.json'),
    );

    final read = agent.seen.firstWhere((r) => r.method == 'GET');
    expect(read.query['name'], 'srvbox_bak_v3.json');
    final written = await File(
      tempDir.path.joinPath('srvbox_bak_v3.json'),
    ).readAsBytes();
    expect(written, content);
  });

  test('a name it is given is a name it asks for, not a path', () async {
    await start((request) async {
      await _loginOr(request, () async {
        await _json(request.response, {'blobs': []});
      });
    });

    expect(await onAgent(() => storage.exists('nothing-here')), isFalse);
    expect(await onAgent(() => storage.list()), isEmpty);

    final listing = agent.seen.firstWhere((r) => r.method == 'GET');
    expect(listing.path, '/api/v1/backup');
  });

  test('a version tag is the size and the timestamp, or absent', () async {
    await start((request) async {
      await _loginOr(request, () async {
        await _json(request.response, {
          'blobs': [
            {
              'name': 'srvbox_bak_v3.json',
              'size': 20,
              'updated_at': '2026-09-24T12:00:00+00:00',
            },
            {'name': 'dated.json', 'size': 4, 'updated_at': '2026-01-01T00:00:00Z'},
          ],
        });
      });
    });

    expect(
      await onAgent(() => storage.versionTag('srvbox_bak_v3.json')),
      '2026-09-24T12:00:00+00:00/20',
    );
    // Null means "assume it changed", which is what a copy that is not there
    // has to read as — the shortcut must not skip the first upload.
    expect(await onAgent(() => storage.versionTag('absent.json')), isNull);
    expect(await onAgent(() => storage.list()), ['srvbox_bak_v3.json', 'dated.json']);
  });

  test('identity is the address, so two agents are two stores', () {
    expect(storage.identity, contains('127.0.0.1'));

    final other = MonitorBackupStorage(
      'server-2',
      MonitorHttpCredential(addr: 'http://127.0.0.1:1', user: 'u'),
    );
    expect(other.identity, isNot(storage.identity));
    other.close();
  });

  test('a refusal surfaces rather than passing for a success', () async {
    await start((request) async {
      await _loginOr(request, () async {
        request.response.statusCode = HttpStatus.requestEntityTooLarge;
        await _json(request.response, {'error': 'tooLarge'});
      });
    });

    await expectLater(
      onAgent(() => storage.exists('srvbox_bak_v3.json')),
      throwsA(isA<MonitorHttpErr>()),
    );
  });

  test('an upload refused with a 401 is retried from a fresh read', () async {
    final path = tempDir.path.joinPath('srvbox_bak_v3.json');
    final content = utf8.encode('the-whole-file');
    await File(path).writeAsBytes(content);

    var puts = 0;
    final bodies = <List<int>>[];
    await start((request) async {
      final handled = await _loginOr(request, () async {
        if (request.method != 'PUT') {
          await _json(request.response, {'blobs': []});
          return;
        }
        puts++;
        bodies.add(agent.seen.last.body);
        if (puts == 1) {
          // A token that expired between the refresh and the write.
          request.response.statusCode = HttpStatus.unauthorized;
          await request.response.close();
          return;
        }
        await _json(request.response, {'name': 'x', 'size': 0, 'updated_at': ''});
      });
      if (handled) return;
    });

    await onAgent(() => storage.upload(relativePath: 'srvbox_bak_v3.json'));

    // The point of `replayData`: the retry has to carry the whole body again,
    // and a `File.openRead()` stream given to the first attempt cannot.
    expect(puts, 2);
    expect(bodies[0], content);
    expect(bodies[1], content);
  });
}
