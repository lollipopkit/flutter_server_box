import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
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
      expect(appMcpEndpoint('[::]:80'), Uri.parse('http://[::]/mcp'));
      expect(appMcpEndpoint('[::1]:2345').port, 2345);
      for (final value in ['::1:2345', '127.0.0.1:0', '0.0.0.0:65536', 'bad']) {
        expect(() => appMcpEndpoint(value), throwsFormatException);
      }
    },
  );
  test('reissuing a preview token never upgrades scoped credentials', () async {
    final dir = await Directory.systemTemp.createTemp();
    addTearDown(() => dir.delete(recursive: true));
    final file = File('${dir.path}/tokens.json');
    final previousId = sha256.convert(utf8.encode('preview')).toString();
    await file.writeAsString(
      jsonEncode({
        previousId: {'hosts': []},
      }),
    );
    expect((await loadMcpRegistry(file)).tokens, isEmpty);
    final created = await createMcpToken(file, 'Laptop');
    final createdId = sha256.convert(utf8.encode(created)).toString();
    expect((await loadMcpRegistry(file)).tokens, {createdId: 'Laptop'});
    expect(await file.readAsString(), isNot(contains(created)));
    await revokeMcpToken(file, createdId);
    expect((await loadMcpRegistry(file)).tokens, isEmpty);
  });
  test(
    'tokens share the tool catalog and can be revoked independently',
    () async {
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
      final policy = File('${dir.path}/policy');
      var token = 'fixture';
      final digest = sha256.convert(utf8.encode(token)).toString();
      final tokens = {
        digest: 'First',
        sha256.convert(utf8.encode('second')).toString(): 'Second',
      };
      final commands = {'check': 'uptime', 'hello': 'echo local-mcp'};
      Future<void> save() => policy.writeAsString(
        jsonEncode({'tokens': tokens, 'commands': commands}),
      );
      await save();
      final server = await bindAppMcp(policy, container, port: 0);
      addTearDown(() => server.close(force: true));
      final http = HttpClient();
      addTearDown(() => http.close(force: true));
      Future<HttpClientResponse> post(String method, Map params) async {
        final req = await http.post('127.0.0.1', server.port, '/mcp');
        req.headers.set('Authorization', 'Bearer $token');
        req.write(
          jsonEncode({
            'jsonrpc': '2.0',
            'id': 1,
            'method': method,
            'params': params,
          }),
        );
        return req.close();
      }

      Future<Map> call(String name, [Map args = const {}]) async {
        final res = await post('tools/call', {'name': name, 'arguments': args});
        expect(res.statusCode, 200);
        return jsonDecode(await utf8.decoder.bind(res).join())['result'] as Map;
      }

      final listed = jsonDecode((await call('list'))['content'][0]['text']);
      expect(listed['hosts'], hasLength(3));
      final monitorRow = (listed['hosts'] as List).singleWhere(
        (row) => row['name'] == monitor.name,
      );
      expect(monitorRow['online'], true);
      final monitorArgs = {'host': monitorRow['id'], 'preset': 'check'};
      final monitorResult = await call('run_command', monitorArgs);
      expect(
        jsonDecode(monitorResult['content'][0]['text'])['stdout'],
        'monitor output',
      );
      expect(monitorCalls, ['uptime']);
      expect(jsonEncode(listed), isNot(contains('private-host')));
      final args = {
        'host': (listed['hosts'] as List).singleWhere(
          (row) => row['id'] != '#local' && row['id'] != monitorRow['id'],
        )['id'],
        'preset': 'check',
      };
      final ran = jsonDecode(
        (await call('run_command', args))['content'][0]['text'],
      );
      expect(ran, {'stdout': 'ok', 'stderr': '', 'exitCode': 0});
      expect(
        (await call('run_command', {...args, 'preset': 'other'}))['isError'],
        true,
      );
      const localArgs = {'host': '#local', 'preset': 'hello'};
      final localResult = await call('run_command', localArgs);
      expect(
        jsonDecode(localResult['content'][0]['text'])['stdout'].trim(),
        'local-mcp',
      );
      final toolList = await post('tools/list', {});
      final catalog =
          jsonDecode(
                await utf8.decoder.bind(toolList).join(),
              )['result']['tools']
              as List;
      expect(
        catalog.map((tool) => tool['name']),
        unorderedEquals(appMcpToolNames),
      );
      expect(
        (await call('storage', {'host': monitorRow['id']}))['isError'],
        isNull,
      );
      expect(monitorCalls.last, 'df -kP');
      expect(
        (await call('storage', {'host': args['host']}))['isError'],
        isNull,
      );
      expect(client.calls.last, 'df -kP');
      expect(
        (await call('app_setting_set', {
          'key': 'editorSoftWrap',
          'value': true,
        }))['isError'],
        isNull,
      );
      expect(Stores.setting.editorSoftWrap.fetch(), true);
      final prefs = jsonDecode(
        (await call('app_settings'))['content'][0]['text'],
      );
      expect(prefs['editorSoftWrap'], true);
      final badKey = await post('tools/call', {
        'name': 'app_setting_set',
        'arguments': {'key': 'agentLocalExec', 'value': true},
      });
      expect(
        jsonDecode(await utf8.decoder.bind(badKey).join())['error']['code'],
        -32602,
      );
      final action = {
        'host': args['host'],
        'id': 'abcdef123456',
        'action': 'restart',
      };
      expect((await call('container_action', action))['isError'], isNull);
      expect(client.calls.last, 'docker restart abcdef123456');
      final badId = await post('tools/call', {
        'name': 'container_action',
        'arguments': {...action, 'id': 'not-a-container-id'},
      });
      expect(
        jsonDecode(await utf8.decoder.bind(badId).join())['error']['code'],
        -32602,
      );
      expect(client.calls.last, 'docker restart abcdef123456');
      expect(
        (await call('service_action', {
          'host': args['host'],
          'key': 'demo.service',
          'action': 'start',
        }))['isError'],
        isNull,
      );
      expect(
        client.calls.last,
        'systemctl --no-ask-password start -- demo.service',
      );
      final image = 'sha256:${'a' * 64}';
      for (final name in ['image_inspect', 'image_remove']) {
        expect(
          (await call(name, {'host': args['host'], 'id': image}))['isError'],
          isNull,
        );
        final bad = await post('tools/call', {
          'name': name,
          'arguments': {'host': args['host'], 'id': 'invalid'},
        });
        expect(
          jsonDecode(await utf8.decoder.bind(bad).join())['error']['code'],
          -32602,
        );
      }
      expect(client.calls.last, 'docker image rm $image');
      tokens.remove(digest);
      await save();
      expect((await post('tools/list', {})).statusCode, 401);
      token = 'second';
      expect((await call('list'))['isError'], isNull);
    },
  );
}
