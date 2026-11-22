import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dartssh2/dartssh2.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/core/service/app_mcp.dart';
import 'package:server_box/core/service/app_mcp_tokens.dart';
import 'package:server_box/data/model/server/monitor/monitor_http_credential.dart';
import 'package:server_box/data/model/server/server.dart';
import 'package:server_box/data/model/server/server_private_info.dart';
import 'package:server_box/data/model/server/ssh_credential.dart';
import 'package:server_box/data/provider/server/all.dart';
import 'package:server_box/data/provider/server/single.dart';
import 'package:server_box/data/res/status.dart';
import 'package:server_box/data/store/setting.dart';
import 'package:server_box/data/store/stores.dart';

import '../../helpers/fake_agent_health.dart';
import '../../helpers/rust_lib_helper.dart';
import '../../helpers/test_db.dart';

const host = Spi(
  id: 'private-host-id',
  name: 'Test',
  ssh: SshCredential(ip: 'private-host'),
);

class _Servers extends ServersNotifier {
  _Servers(this.monitor);
  final Spi monitor;
  @override
  ServersState build() => ServersState(
    servers: {
      host.id: host,
      monitor.id: monitor,
      'off': monitor.copyWith(id: 'off', monitorEnabled: false),
      'disabled': host.copyWith(id: 'disabled', sshEnabled: false),
      'local': host.copyWith(id: 'local', local: true),
    },
  );
}

class _Session extends Fake implements SSHSession {
  @override
  Stream<Uint8List> get stdout =>
      Stream.value(Uint8List.fromList(utf8.encode('ok')));
  @override
  Stream<Uint8List> get stderr => const Stream.empty();
  @override
  Future<int?> waitForExit({Duration? timeout}) =>
      Future.delayed(Duration.zero, () => 0);
  @override
  StreamSink<Uint8List> get stdin =>
      StreamController<Uint8List>()..stream.listen((_) {});
  @override
  Future<void> get done => Future.value();
  @override
  int? get exitCode => 0;
  @override
  void close() {}
}

class _Client extends Fake implements SSHClient {
  final calls = <String>[];
  @override
  bool get isClosed => false;
  @override
  Future<SSHSession> execute(
    String command, {
    SSHPtyConfig? pty,
    SSHX11Config? x11,
    Map<String, String>? environment,
    bool forwardAgent = false,
  }) async {
    calls.add(command);
    return _Session();
  }
}

class _Server extends ServerNotifier {
  _Server(this.client, this.monitor);
  final Spi monitor;
  final _Client client;
  @override
  ServerState build(String id) => ServerState(
    spi: id == host.id ? host : monitor,
    status: InitStatus.status,
    conn: ServerConn.finished,
    client: id == host.id ? client : null,
  );
}

void main() {
  test(
    'parses IPv4 and IPv6 listening endpoints and rejects invalid ports',
    () {
      expect(appMcpEndpoint('0.0.0.0:49762').host, '0.0.0.0');
      expect(appMcpEndpoint('[::]:80'), Uri.parse('https://[::]:80/mcp'));
      expect(appMcpEndpoint('[::1]:2345').port, 2345);
      for (final value in ['::1:2345', '127.0.0.1:0', '0.0.0.0:65536', 'bad']) {
        expect(() => appMcpEndpoint(value), throwsFormatException);
      }
    },
  );
  test('the registry is edited in place and read as written by hand', () async {
    await initRustLibForTest();
    final dir = await Directory.systemTemp.createTemp();
    addTearDown(() => dir.delete(recursive: true));
    final file = File('${dir.path}/app-mcp.json');
    final token = await createMcpToken(file, ' Laptop ', scopes: ['read']);
    expect(token, startsWith('sbt_'));
    expect(await file.readAsString(), isNot(contains(token)));
    var registry = await loadMcpRegistry(file);
    expect(registry.tokens.single.name, 'Laptop');
    expect(registry.tokens.single.scopes, ['read']);

    // A token added in an editor, by its digest, is one like any other.
    final edited = jsonDecode(await file.readAsString()) as Map;
    (edited['tokens'] as List).add({
      'id': 'a' * 64,
      'name': 'CI',
      'created_at': 0,
    });
    await file.writeAsString(jsonEncode(edited));
    registry = await loadMcpRegistry(file);
    expect(registry.tokens.map((t) => t.name), ['Laptop', 'CI']);
    expect(registry.tokens.last.scopes, isNull);

    await revokeMcpToken(file, registry.tokens.first.id);
    expect((await loadMcpRegistry(file)).tokens.map((t) => t.name), ['CI']);

    await file.writeAsString('{"tokens": {}}');
    expect(() => loadMcpRegistry(file), throwsFormatException);
  });

  Future<HttpClientResponse> send(
    HttpClient client,
    int port,
    String token,
    Map<String, Object?> message, {
    String? version,
  }) async {
    final request = await client.post('127.0.0.1', port, '/mcp');
    request.headers.set('Authorization', 'Bearer $token');
    request.headers.set('Accept', 'application/json, text/event-stream');
    request.headers.contentType = ContentType.json;
    if (version != null) request.headers.set('mcp-protocol-version', version);
    request.write(jsonEncode({'jsonrpc': '2.0', ...message}));
    return request.close();
  }

  test('a registry that cannot be read is no token\'s fault', () async {
    await initRustLibForTest();
    await openTestDb();
    addTearDown(closeTestDb);
    getIt.registerSingleton<SettingStore>(SettingStore.instance);
    addTearDown(getIt.unregister<SettingStore>);
    final dir = await Directory.systemTemp.createTemp();
    addTearDown(() => dir.delete(recursive: true));
    final file = File('${dir.path}/app-mcp.json');
    final token = await createMcpToken(file, 'test');
    final container = ProviderContainer(
      overrides: [serversProvider.overrideWith(() => _Servers(host))],
    );
    addTearDown(container.dispose);
    final server = await bindAppMcp(file, container, port: 0);
    addTearDown(() => server.close(force: true));
    final client = HttpClient();
    addTearDown(() => client.close(force: true));
    await file.writeAsString('${await file.readAsString()},');
    final response = await send(client, server.port, token, {
      'id': 1,
      'method': 'ping',
    });
    expect(response.statusCode, 503);
    await response.drain<void>();
  });

  test(
    'rejects unregistered or slow uploads and validates notification and response versions',
    () async {
      await initRustLibForTest();
      await openTestDb();
      addTearDown(closeTestDb);
      getIt.registerSingleton<SettingStore>(SettingStore.instance);
      addTearDown(getIt.unregister<SettingStore>);
      final dir = await Directory.systemTemp.createTemp();
      addTearDown(() => dir.delete(recursive: true));
      final file = File('${dir.path}/app-mcp.json');
      final token = await createMcpToken(file, 'test');
      final container = ProviderContainer(
        overrides: [serversProvider.overrideWith(() => _Servers(host))],
      );
      addTearDown(container.dispose);
      final server = await bindAppMcp(file, container, port: 0);
      addTearDown(() => server.close(force: true));
      final client = HttpClient();
      addTearDown(() => client.close(force: true));
      for (final message in [
        {'method': 'notifications/initialized'},
        {'id': 4, 'result': {}},
      ]) {
        for (final version in [null, '2025-06-18', 'unknown']) {
          final response = await send(
            client,
            server.port,
            token,
            message,
            version: version,
          );
          expect(response.statusCode, version == 'unknown' ? 400 : 202);
          if (version == 'unknown') {
            await response.drain<void>();
          } else {
            expect(await response.toList(), isEmpty);
          }
        }
      }
      Future<Socket> startBody(String bearer) async {
        final socket = await Socket.connect('127.0.0.1', server.port);
        addTearDown(socket.destroy);
        socket.write(
          'POST /mcp HTTP/1.1\r\nHost: localhost\r\nAuthorization: Bearer $bearer\r\n'
          'Content-Length: 1000\r\n\r\n{',
        );
        await socket.flush();
        return socket;
      }

      final denied = await startBody('sbt_unregistered');
      expect(
        utf8.decode(await denied.first.timeout(const Duration(seconds: 3))),
        startsWith('HTTP/1.1 401'),
      );
      final slow = await startBody(token);
      final drip = Timer.periodic(
        const Duration(seconds: 2),
        (_) => slow.write(' '),
      );
      addTearDown(drip.cancel);
      expect(
        utf8.decode(await slow.first.timeout(const Duration(seconds: 20))),
        startsWith('HTTP/1.1 408'),
      );
    },
  );

  test('a token reaches every server through the same tools', () async {
    await initRustLibForTest();
    await openTestDb();
    addTearDown(closeTestDb);
    getIt.registerSingleton<SettingStore>(SettingStore.instance);
    addTearDown(getIt.unregister<SettingStore>);
    final agent = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => agent.close(force: true));
    final monitor = Spi(
      id: 'monitor',
      name: 'Monitor host',
      monitorHttp: MonitorHttpCredential(
        addr: 'http://127.0.0.1:${agent.port}',
        pwd: 'fixture',
      ),
    );
    final monitorCalls = <String>[];
    agent.listen((req) async {
      if (await answerAgentHealth(req)) return;
      final body = jsonDecode(await utf8.decoder.bind(req).join());
      req.response.headers.contentType = ContentType.json;
      if (req.uri.path == '/api/v1/login') {
        req.response.write(jsonEncode({'token': 'fixture'}));
      } else if (req.uri.path == '/api/v1/exec' &&
          req.headers.value('authorization') == 'Bearer fixture') {
        monitorCalls.add(body['cmd'] as String);
        req.response.write(
          jsonEncode({'stdout': 'monitor output', 'exit_code': 0}),
        );
      } else {
        req.response.statusCode = 403;
      }
      await req.response.close();
    });
    final client = _Client();
    final container = ProviderContainer(
      overrides: [
        serversProvider.overrideWith(() => _Servers(monitor)),
        serverProvider.overrideWith2((_) => _Server(client, monitor)),
      ],
    );
    addTearDown(container.dispose);
    final dir = await Directory.systemTemp.createTemp();
    addTearDown(() => dir.delete(recursive: true));
    final file = File('${dir.path}/app-mcp.json');
    final token = await createMcpToken(file, 'First');
    final reader = await createMcpToken(file, 'Reader', scopes: ['read']);
    final server = await bindAppMcp(file, container, port: 0);
    addTearDown(() => server.close(force: true));
    final http = HttpClient();
    addTearDown(() => http.close(force: true));
    var id = 0;
    Future<Map> rpc(String method, Map params, {String? as}) async {
      final res = await send(http, server.port, as ?? token, {
        'id': ++id,
        'method': method,
        'params': params,
      });
      expect(res.statusCode, 200);
      return jsonDecode(await utf8.decoder.bind(res).join()) as Map;
    }

    Future<Map> call(String name, [Map args = const {}, String? as]) async =>
        (await rpc('tools/call', {'name': name, 'arguments': args}, as: as))['result']
            as Map;
    Future<List> names(String as) async => [
      for (final tool in (await rpc('tools/list', {}, as: as))['result']['tools']
          as List)
        tool['name'],
    ];

    expect(
      await names(token),
      containsAll([
        'list',
        'processes',
        'services',
        'containers',
        'run_command',
        'kill_process',
        'service_action',
        'container_action',
        'app_setting_set',
      ]),
    );
    expect(await names(reader), isNot(contains('run_command')));
    expect(
      (await rpc('tools/call', {
        'name': 'run_command',
        'arguments': {},
      }, as: reader))['error']['code'],
      -32602,
    );

    final listed = (await call('list'))['structuredContent'] as Map;
    expect(jsonEncode(listed), isNot(contains('private-host')));
    final hosts = listed['hosts'] as List;
    String idOf(String name) =>
        hosts.singleWhere((h) => h['name'] == name)['id'] as String;
    final ssh = hosts.firstWhere(
      (h) => h['name'] == host.name && (h['transports'] as List).contains('ssh'),
    )['id'];
    final viaMonitor = idOf(monitor.name);

    final ran = await call('run_command', {'host': ssh, 'command': 'uptime'});
    expect(ran['structuredContent']?['stdout'], 'ok', reason: '$ran');
    expect(client.calls.last, 'uptime');
    final remote = await call('run_command', {
      'host': viaMonitor,
      'command': 'uptime',
    });
    expect(remote['structuredContent']['stdout'], 'monitor output');
    expect(monitorCalls, ['uptime']);

    final caps = await call('machine_capabilities', {'host': ssh});
    expect(caps['structuredContent']['platform'], 'linux');
    expect((await call('tmux', {'host': 'nope'}))['isError'], true);

    expect(
      (await call('app_setting_set', {
        'key': 'editorSoftWrap',
        'value': true,
      }))['isError'],
      false,
    );
    expect(Stores.setting.editorSoftWrap.fetch(), true);
    final prefs = (await call('app_settings'))['structuredContent'] as Map;
    expect(prefs['editorSoftWrap'], true);
    expect(
      (await call('app_setting_set', {
        'key': 'agentLocalExec',
        'value': true,
      }))['isError'],
      true,
    );

    await revokeMcpToken(
      file,
      (await loadMcpRegistry(file)).tokens.firstWhere((t) => t.name == 'First').id,
    );
    final revoked = await send(http, server.port, token, {
      'id': 99,
      'method': 'tools/list',
    });
    expect(revoked.statusCode, 401);
    await revoked.drain<void>();
    expect(await names(reader), contains('list'));

    final settings = Stores.setting;
    settings.set('appMcp', {'enabled': true, 'path': 'legacy'});
    expect(settings.appMcp.get()?.listen, defaultAppMcpListen);
    settings.set('appMcp', {'enabled': true, 'path': 'legacy', 'listen': 42});
    expect(settings.appMcp.get(), isNull);
  });
}
