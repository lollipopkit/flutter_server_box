/// Opt-in end-to-end test of the app's MCP server against a real SSH host:
/// the listener, the Rust server behind it, and `ServerNotifier` connecting
/// unattended with the app's own client — host key check and `$SSH_AUTH_SOCK`
/// agent included. Nothing below the network is faked.
///
/// Each host is opt-in, from the environment or the workspace-root `.env`:
/// - `SBM_E2E_SSH_HOST`, with an agent at `$SSH_AUTH_SOCK` holding a key it
///   accepts: a server reached over SSH.
/// - `SBM_E2E_MONITOR_WEBAPPS_ADDR`, `SBM_E2E_MONITOR_WEBAPPS_PASSWORD`
///   (`SBM_E2E_MONITOR_WEBAPPS_INSECURE=1` for plain HTTP): a server reached
///   only through its Monitor. On macOS the test runner has no Local Network
///   permission: give a Monitor's address outside the LAN (Tailscale).
///
/// Only reads run there, `uptime` aside; over SSH the status script is
/// installed where the app keeps it. On a desktop this device is read too.
library;

import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart' show sha256;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/core/local/device.dart';
import 'package:server_box/core/service/app_mcp.dart';
import 'package:server_box/core/service/app_mcp_tokens.dart';
import 'package:server_box/core/ssh/host_keys.dart';
import 'package:server_box/data/model/server/monitor/monitor_http_credential.dart';
import 'package:server_box/data/model/server/server_private_info.dart';
import 'package:server_box/data/model/server/ssh_credential.dart';
import 'package:server_box/data/provider/server/all.dart';
import 'package:server_box/data/store/setting.dart';
import 'package:server_box/data/store/stores.dart';

import '../helpers/rust_lib_helper.dart';
import '../helpers/ssh_e2e.dart';
import '../helpers/test_db.dart';

class _Servers extends ServersNotifier {
  _Servers(this.spis);
  final List<Spi> spis;
  @override
  ServersState build() => ServersState(servers: {for (final s in spis) s.id: s});
}

/// The host's keys as the app stores an accepted one: `type` to its
/// OpenSSH SHA-256 fingerprint, from `ssh-keyscan`.
Future<Map<String, String>> _hostKeys(String host, int port) async {
  final scan = await Process.run('ssh-keyscan', ['-p', '$port', host]);
  return {
    for (final line in LineSplitter.split(scan.stdout as String))
      if (line.split(' ') case [_, final type, final blob, ...] when !line.startsWith('#'))
        type: 'SHA256:${base64.encode(sha256.convert(base64.decode(blob)).bytes).replaceAll('=', '')}',
  };
}

Future<void> main() async {
  final sshHost = e2eEnv('SBM_E2E_SSH_HOST');
  final resolved = sshHost == null || Platform.environment['SSH_AUTH_SOCK'] == null
      ? null
      : await SshE2eTarget.resolve(sshHost);
  final target = resolved?.target;
  final ssh = target == null
      ? null
      : Spi(
          id: 'e2e-ssh',
          name: 'E2E SSH',
          ssh: SshCredential(
            ip: target.hostname,
            port: target.port,
            user: target.user,
            identityAgent: SshCredential.authSock,
          ),
        );
  final monitorAddr = e2eEnv('SBM_E2E_MONITOR_WEBAPPS_ADDR');
  final monitorPwd = e2eEnv('SBM_E2E_MONITOR_WEBAPPS_PASSWORD');
  final monitor = monitorAddr == null || monitorPwd == null
      ? null
      : Spi(
          id: 'e2e-monitor',
          name: 'E2E Monitor',
          monitorHttp: MonitorHttpCredential(
            addr: monitorAddr,
            pwd: monitorPwd,
            certSha256: await e2eAgentCertSha256(monitorAddr),
            allowInsecure: e2eEnv('SBM_E2E_MONITOR_WEBAPPS_INSECURE') == '1',
          ),
        );
  if (ssh == null && monitor == null) {
    test('app mcp e2e', () {}, skip: 'no SSH host with an agent, and no Monitor');
    return;
  }

  late HttpServer server;
  late String token;
  late String reader;
  final http = HttpClient();
  var id = 0;

  setUpAll(() async {
    await initRustLibForTest();
    await openTestDb();
    getIt.registerSingleton<SettingStore>(SettingStore.instance);
    Stores.setting.agentLocalExec.put(true);
    final container = ProviderContainer(
      overrides: [serversProvider.overrideWith(() => _Servers([?ssh, ?monitor]))],
    );
    final dir = await Directory.systemTemp.createTemp();
    final registry = File('${dir.path}/app-mcp.json');
    token = await createMcpToken(registry, 'e2e');
    reader = await createMcpToken(registry, 'reader', scopes: ['read']);
    server = await bindAppMcp(registry, container, port: 0);
    addTearDown(() async {
      await server.close(force: true);
      http.close(force: true);
      container.dispose();
      await dir.delete(recursive: true);
      await getIt.unregister<SettingStore>();
      await closeTestDb();
    });
  });

  Future<Map<String, dynamic>> rpc(
    String method,
    Map<String, Object?> params, {
    String? as,
  }) async {
    final req = await http.post('127.0.0.1', server.port, '/mcp');
    req.headers.set('Authorization', 'Bearer ${as ?? token}');
    req.headers.set('Accept', 'application/json, text/event-stream');
    req.headers.contentType = ContentType.json;
    req.write(jsonEncode({'jsonrpc': '2.0', 'id': ++id, 'method': method, 'params': params}));
    final res = await req.close();
    expect(res.statusCode, 200);
    return jsonDecode(await utf8.decoder.bind(res).join()) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> call(
    String name, [
    Map<String, Object?> args = const {},
    String? as,
  ]) async =>
      (await rpc('tools/call', {'name': name, 'arguments': args}, as: as))['result']
          as Map<String, dynamic>;

  Future<String> hostId(bool Function(Map<String, dynamic>) which) async {
    final hosts = (await call('list'))['structuredContent']['hosts'] as List;
    return hosts.cast<Map<String, dynamic>>().singleWhere(which)['id'] as String;
  }

  Future<String> named(Spi spi) => hostId((h) => h['name'] == spi.name);

  /// Every read tool on [h], each with a real answer.
  Future<void> expectReads(String h) async {
    final caps = await call('machine_capabilities', {'host': h});
    expect(caps['isError'], false, reason: '$caps');
    expect(caps['structuredContent']['platform'], 'linux');

    final ran = await call('run_command', {'host': h, 'command': 'uptime'});
    expect(ran['structuredContent']['exit_code'], 0, reason: '$ran');
    expect(ran['structuredContent']['stdout'], contains('load average'));

    final procs = await call('processes', {'host': h, 'ascending': true});
    expect(procs['structuredContent']['available'], true, reason: '$procs');
    expect(procs['structuredContent']['procs'], isNotEmpty);
    expect(procs['structuredContent']['ascending'], true);

    final services = await call('services', {'host': h});
    expect(services['isError'], false, reason: '$services');
    expect(services['structuredContent']['manager'], isNotNull, reason: '$services');

    final containers = await call('containers', {'host': h});
    final c = containers['structuredContent'] as Map;
    expect(containers['isError'], false, reason: '$containers');
    // Available, or a known reason: never an empty list standing for a
    // runtime that did not answer.
    expect(c['available'] == true || c['reason_kind'] != null, true, reason: '$c');

    final tmux = await call('tmux', {'host': h});
    expect(tmux['isError'], false, reason: '$tmux');
    expect(tmux['structuredContent']['available'] == true || tmux['structuredContent']['error'] == null, true);
  }

  /// What is refused on [h] reaches nothing there.
  Future<void> expectRefusals(String h) async {
    final denied = await rpc('tools/call', {
      'name': 'run_command',
      'arguments': {'host': h, 'command': 'uptime'},
    }, as: reader);
    expect(denied['error']['code'], -32602);

    final invalid = await call('container_action', {'host': h, 'action': 'stop', 'id': '-rf'});
    expect(invalid['isError'], true, reason: '$invalid');
    final unknown = await call('service_action', {'host': h, 'key': 'system:sbm-e2e-none.service', 'action': 'restart'});
    expect(unknown['isError'], true, reason: '$unknown');
  }

  group('over SSH', skip: ssh == null ? (resolved?.problem ?? 'SBM_E2E_SSH_HOST or an agent not set') : null, () {
    test('an unknown host key is left to the person', () async {
      final ran = await call('run_command', {'host': await named(ssh!), 'command': 'uptime'});
      expect(ran['isError'], true, reason: '$ran');
      expect(ran['content'][0]['text'], contains('needs the person'));
    });

    test('every read tool answers', () async {
      final keys = await _hostKeys(target!.hostname, target.port);
      expect(keys, isNotEmpty);
      for (final MapEntry(:key, :value) in keys.entries) {
        await persistHostKeyFingerprint(hostKeyStorageKey(ssh!, key), value);
      }
      await expectReads(await named(ssh!));
    });

    test('a refusal reaches nothing', () async => expectRefusals(await named(ssh!)));
  });

  group('through the Monitor', skip: monitor == null ? 'SBM_E2E_MONITOR_WEBAPPS_ADDR / _PASSWORD not set' : null, () {
    test('every read tool answers', () async => expectReads(await named(monitor!)));
    test('a refusal reaches nothing', () async => expectRefusals(await named(monitor!)));
  });

  test('this device lists its processes from the script on stdin', () async {
    if (!LocalDevice.isOffered) {
      markTestSkipped('this device is not offered here');
      return;
    }
    final here = await hostId((h) => (h['transports'] as List).contains('local'));
    final procs = await call('processes', {'host': here});
    expect(procs['structuredContent']['available'], true, reason: '$procs');
    expect(procs['structuredContent']['procs'], isNotEmpty);
  });
}
