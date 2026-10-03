import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:fl_lib/fl_lib.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/core/extension/context/locale.dart';
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

/// A fake monitor agent on loopback. A real socket rather than a mocked
/// client: what is asserted is what went over the wire.
final class _Fake {
  _Fake(this.server, this.seen);

  final HttpServer server;
  final List<_Seen> seen;

  Iterable<_Seen> get calls => seen.where((r) => r.path != '/api/v1/login');
}

Future<_Fake> _serve(FutureOr<void> Function(HttpRequest, _Seen) handler) async {
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  final seen = <_Seen>[];
  server.listen((request) async {
    final body = <int>[];
    await for (final chunk in request) {
      body.addAll(chunk);
    }
    final headers = <String, String>{};
    request.headers.forEach((name, values) => headers[name] = values.join(','));
    final one = _Seen(
      request.method,
      request.uri.path,
      request.uri.queryParameters,
      headers,
      body,
    );
    seen.add(one);
    try {
      if (request.uri.path == '/api/v1/login') {
        await _json(request.response, {'token': 'token'});
      } else {
        await handler(request, one);
      }
    } catch (_) {
      request.response.statusCode = HttpStatus.internalServerError;
      await request.response.close();
    }
  });
  return _Fake(server, seen);
}

Future<void> _json(
  HttpResponse response,
  Map<String, Object?> body, {
  int status = HttpStatus.ok,
}) async {
  response.statusCode = status;
  response.headers.contentType = ContentType.json;
  response.write(jsonEncode(body));
  await response.close();
}

const _name = 'srvbox_bak_v3.json';

Map<String, Object?> _listing({int maxBytes = 1 << 20}) => {
  'blobs': [
    {'name': _name, 'size': 20, 'updated_at': '2026-09-24T12:00:00+00:00'},
    {'name': 'dated.json', 'size': 4, 'updated_at': '2026-01-01T00:00:00Z'},
  ],
  'max_bytes': maxBytes,
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late _Fake agent;
  late MonitorBackupStorage storage;

  Future<void> start(FutureOr<void> Function(HttpRequest, _Seen) handler) async {
    agent = await _serve(handler);
    storage = MonitorBackupStorage(
      'server-1',
      MonitorHttpCredential(
        addr: 'http://${agent.server.address.address}:${agent.server.port}',
        user: 'user',
        pwd: 'password',
      ),
    );
  }

  /// The test binding answers real HTTP with its own 400; [LocalHttp] routes
  /// the client to the fake agent instead.
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

  test('list, exists and versionTag read the listing', () async {
    await start((request, _) => _json(request.response, _listing()));

    expect(await onAgent(storage.list), [_name, 'dated.json']);
    expect(await onAgent(() => storage.exists(_name)), isTrue);
    expect(await onAgent(() => storage.exists('absent.json')), isFalse);
    expect(
      await onAgent(() => storage.versionTag(_name)),
      '2026-09-24T12:00:00+00:00/20',
    );
    // Null reads as "changed", so the first upload to a fresh agent is not
    // skipped.
    expect(await onAgent(() => storage.versionTag('absent.json')), isNull);
    expect(agent.calls.map((r) => r.path).toSet(), {'/api/v1/backup'});
  });

  test('upload sends the file under its name with its length', () async {
    final content = utf8.encode('LKFL_ENC_V01-not-really');
    await File(tempDir.path.joinPath(_name)).writeAsBytes(content);
    await start((request, seen) async {
      if (request.method == 'GET') return _json(request.response, _listing());
      await _json(request.response, {
        'name': _name,
        'size': content.length,
        'updated_at': '2026-09-24T12:00:00+00:00',
      });
    });

    await onAgent(() => storage.upload(relativePath: _name));

    final put = agent.seen.singleWhere((r) => r.method == 'PUT');
    expect(put.path, '/api/v1/backup/blob');
    expect(put.query['name'], _name);
    expect(put.headers['content-length'], '${content.length}');
    expect(put.headers['content-type'], 'application/octet-stream');
    expect(put.body, content);
  });

  test('a file over max_bytes is refused before it is sent', () async {
    await File(tempDir.path.joinPath(_name)).writeAsBytes(List.filled(64, 1));
    await start((request, _) => _json(request.response, _listing(maxBytes: 8)));

    await expectLater(
      onAgent(() => storage.upload(relativePath: _name)),
      throwsA(
        isA<MonitorHttpErr>().having(
          (e) => e.message,
          'message',
          l10n.monitorBackupTooLarge(8.bytes2Str),
        ),
      ),
    );
    expect(agent.seen.where((r) => r.method == 'PUT'), isEmpty);
  });

  test('a 413 from the agent is worded as the size limit', () async {
    await File(tempDir.path.joinPath(_name)).writeAsBytes(List.filled(64, 1));
    await start((request, _) async {
      if (request.method == 'GET') return _json(request.response, _listing());
      await _json(request.response, {'error': 'tooLarge'}, status: 413);
    });

    await expectLater(
      onAgent(() => storage.upload(relativePath: _name)),
      throwsA(
        isA<MonitorHttpErr>().having(
          (e) => e.type,
          'type',
          MonitorHttpErrType.badRequest,
        ),
      ),
    );
  });

  test('an upload refused with a 401 is retried with the whole body', () async {
    final content = utf8.encode('the-whole-file');
    await File(tempDir.path.joinPath(_name)).writeAsBytes(content);
    final bodies = <List<int>>[];
    await start((request, seen) async {
      if (request.method == 'GET') return _json(request.response, _listing());
      bodies.add(seen.body);
      if (bodies.length == 1) {
        request.response.statusCode = HttpStatus.unauthorized;
        return request.response.close();
      }
      await _json(request.response, {'name': _name, 'size': 0, 'updated_at': ''});
    });

    await onAgent(() => storage.upload(relativePath: _name));

    expect(bodies, [content, content]);
  });

  test('download writes the bytes to the local path', () async {
    final content = utf8.encode('ciphertext-from-the-agent');
    await start((request, _) async {
      request.response.headers.contentType = ContentType.binary;
      request.response.add(content);
      await request.response.close();
    });

    final local = tempDir.path.joinPath('downloaded.json');
    await onAgent(
      () => storage.download(relativePath: _name, localPath: local),
    );

    final read = agent.calls.single;
    expect(read.path, '/api/v1/backup/blob');
    expect(read.query['name'], _name);
    expect(await File(local).readAsBytes(), content);
    expect(File('$local.part').existsSync(), isFalse);
  });

  test('a missing blob is notFound and leaves the local copy alone', () async {
    final local = tempDir.path.joinPath('kept.json');
    await File(local).writeAsString('previous');
    await start(
      (request, _) =>
          _json(request.response, {'error': 'noSuchBlob'}, status: 404),
    );

    await expectLater(
      onAgent(() => storage.download(relativePath: _name, localPath: local)),
      throwsA(
        isA<MonitorHttpErr>().having(
          (e) => e.type,
          'type',
          MonitorHttpErrType.notFound,
        ),
      ),
    );
    expect(await File(local).readAsString(), 'previous');
  });

  test('delete sends DELETE with the name', () async {
    await start((request, _) async {
      request.response.statusCode = HttpStatus.noContent;
      await request.response.close();
    });

    await onAgent(() => storage.delete(_name));

    final del = agent.calls.single;
    expect(del.method, 'DELETE');
    expect(del.path, '/api/v1/backup/blob');
    expect(del.query['name'], _name);
  });

  test('a 403 says the account is not an admin', () async {
    await start(
      (request, _) =>
          _json(request.response, {'error': 'forbidden'}, status: 403),
    );

    await expectLater(
      onAgent(storage.list),
      throwsA(
        isA<MonitorHttpErr>()
            .having((e) => e.type, 'type', MonitorHttpErrType.forbidden)
            .having((e) => e.message, 'message', l10n.monitorBackupAdminOnly),
      ),
    );
  });

  test('check refuses an agent without the feature, or a non-admin', () async {
    var caps = <String, Object?>{'features': ['power']};
    await start((request, _) => _json(request.response, caps));

    await expectLater(
      onAgent(storage.check),
      throwsA(
        isA<MonitorHttpErr>().having(
          (e) => e.message,
          'message',
          l10n.monitorBackupUnsupported,
        ),
      ),
    );

    caps = {
      'features': ['backup'],
      'me': {'username': 'u', 'role': 'viewer', 'admin': false},
    };
    await expectLater(
      onAgent(storage.check),
      throwsA(
        isA<MonitorHttpErr>().having(
          (e) => e.message,
          'message',
          l10n.monitorBackupAdminOnly,
        ),
      ),
    );

    caps = {
      'features': ['backup'],
      'me': {'username': 'u', 'role': 'admin', 'admin': true},
    };
    await onAgent(storage.check);
  });

  test('identity is the address', () async {
    await start((request, _) => _json(request.response, {}));
    final other = MonitorBackupStorage(
      'server-2',
      MonitorHttpCredential(addr: 'http://127.0.0.1:1', user: 'u'),
    );
    expect(storage.identity, contains('${agent.server.port}'));
    expect(other.identity, isNot(storage.identity));
    other.close();
  });
}
