import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:server_box/core/service/app_mcp.dart';
import 'package:server_box/core/service/app_mcp_tokens.dart';
import 'package:server_box/core/service/monitor_login_devices.dart';
import 'package:server_box/core/ssh/host_keys.dart';
import 'package:server_box/data/model/server/monitor/monitor_http_credential.dart';
import 'package:server_box/data/model/server/server_private_info.dart';
import 'package:server_box/data/model/server/ssh_credential.dart';
import 'package:server_box/data/provider/server/single.dart';
import 'package:server_box/data/store/server.dart';
import 'package:server_box/data/store/setting.dart';
import 'package:server_box/data/store/stores.dart';
import 'package:server_box/src/rust/frb_generated.dart';

import '../test/helpers/test_db.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('external stdio client runs a local preset through the app', (
    _,
  ) async {
    await RustLib.init();
    final previousStore = MonitorLoginDevices.store;
    MonitorLoginDevices.store = MemoryDeviceTokenStore();
    addTearDown(() {
      MonitorLoginDevices.store = previousStore;
      MonitorLoginDevices.resetForTest();
    });
    await openTestDb();
    addTearDown(closeTestDb);
    getIt.registerSingleton<SettingStore>(SettingStore.instance);
    getIt.registerSingleton<ServerStore>(ServerStore.instance);
    addTearDown(getIt.unregister<ServerStore>);
    addTearDown(getIt.unregister<SettingStore>);
    const port = int.fromEnvironment('MCP_SSH_PORT');
    const remote = Spi(
      id: 'mcp-ssh-fixture',
      name: 'OpenSSH fixture',
      ssh: SshCredential(
        ip: '127.0.0.1',
        port: port,
        user: 'fixture',
        identityFiles: [String.fromEnvironment('MCP_SSH_KEY')],
        identityAgent: 'none',
      ),
    );
    final targets = [
      remote,
      remote.copyWith(
        id: 'mcp-jump-target',
        name: 'Jump target',
        ssh: remote.ssh!.copyWith(port: 22, jumpIds: [remote.id]),
      ),
      remote.copyWith(
        id: 'mcp-proxy-target',
        name: 'Proxy target',
        ssh: remote.ssh!.copyWith(proxyCommand: '/usr/bin/nc %h %p'),
      ),
    ];
    if (port != 0) {
      for (final target in targets) {
        Stores.server.put(target);
      }
    }
    const monitorPort = int.fromEnvironment('MCP_MONITOR_PORT');
    if (monitorPort != 0) {
      final lines = await File(
        const String.fromEnvironment('MCP_MONITOR_CREDENTIAL_FILE'),
      ).readAsLines();
      final password = lines
          .singleWhere((line) => line.startsWith('password: '))
          .substring(10);
      Stores.server.put(
        Spi(
          id: 'mcp-monitor',
          name: 'Monitor fixture',
          monitorHttp: MonitorHttpCredential(
            addr: 'http://127.0.0.1:$monitorPort',
            pwd: password,
          ),
        ),
      );
    }
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final directory = await Directory.systemTemp.createTemp('app-mcp-');
    addTearDown(() => directory.delete(recursive: true));
    final policy = File('${directory.path}/policy.json');
    await policy.writeAsString(
      jsonEncode({
        'commands': {'probe': 'printf "local-%s" 42'},
      }),
    );
    final token = await createMcpToken(policy, 'Fixture');
    final digest = sha256.convert(utf8.encode(token)).toString();
    final probe = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    final customPort = probe.port;
    await probe.close();
    await configureAppMcp(
      container,
      enabled: true,
      file: policy,
      listen: '127.0.0.1:$customPort',
    );
    addTearDown(() => configureAppMcp(container, enabled: false));
    final listen = '0.0.0.0:$customPort';
    await configureAppMcp(container, enabled: true, listen: listen);
    expect(Stores.setting.appMcp.get(), (
      enabled: true,
      path: policy.path,
      listen: listen,
    ));
    final occupied = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    try {
      await expectLater(
        configureAppMcp(
          container,
          enabled: true,
          listen: '127.0.0.1:${occupied.port}',
        ),
        throwsA(isA<SocketException>()),
      );
      expect(appMcpListener.value!.address.address, '0.0.0.0');
      expect(appMcpListen, listen);
    } finally {
      await occupied.close();
    }
    await configureAppMcp(container, enabled: false, remember: false);
    await startAppMcp(container);
    expect(appMcpListener.value!.address.address, '0.0.0.0');
    expect(appMcpListener.value!.port, customPort);
    final interfaces = await appMcpInterfaces();
    final lan = interfaces
        .where((i) => i.address.type == InternetAddressType.IPv4)
        .firstOrNull;
    final clientAddress = lan?.address ?? InternetAddress.loopbackIPv4;
    await configureAppMcp(
      container,
      enabled: true,
      listen: appMcpListenAt(clientAddress, customPort),
    );
    expect(appMcpListener.value!.address.address, clientAddress.address);
    final clientHost = clientAddress.address;

    final client = await Process.start(
      'python3',
      [
        const String.fromEnvironment(
          'MCP_STDIO_SCRIPT',
          defaultValue: 'scripts/app-mcp-stdio.py',
        ),
      ],
      environment: {
        'SERVERBOX_MCP_TOKEN': token,
        'SERVERBOX_MCP_PORT': '$customPort',
        'SERVERBOX_MCP_HOST': clientHost,
      },
    );
    addTearDown(client.kill);
    final responses = client.stdout
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .asBroadcastStream();
    var id = 0;
    Future<Map> send(String method, Map params) async {
      final reply = responses.first.timeout(const Duration(seconds: 15));
      client.stdin.writeln(
        jsonEncode({
          'jsonrpc': '2.0',
          'id': ++id,
          'method': method,
          'params': params,
        }),
      );
      await client.stdin.flush();
      final message = jsonDecode(await reply);
      expect(message['id'], id);
      return message;
    }

    final init = await send('initialize', {
      'protocolVersion': '2025-11-25',
      'capabilities': {},
      'clientInfo': {'name': 'e2e', 'version': '1'},
    });
    expect(init['result']['serverInfo']['name'], 'ServerBox');
    client.stdin.writeln(
      jsonEncode({'jsonrpc': '2.0', 'method': 'notifications/initialized'}),
    );
    final tools = await send('tools/list', {});
    expect(
      (tools['result']['tools'] as List).map((tool) => tool['name']),
      contains('run_command'),
    );
    final listed = await send('tools/call', {'name': 'list'});
    final hosts =
        jsonDecode(listed['result']['content'][0]['text'])['hosts'] as List;
    if (monitorPort != 0) {
      final monitor = hosts.singleWhere(
        (row) => row['name'] == 'Monitor fixture',
      );
      final reply = await send('tools/call', {
        'name': 'run_command',
        'arguments': {'host': monitor['id'], 'preset': 'probe'},
      });
      expect(
        reply['result']['isError'],
        isNull,
        reason: reply['result']['content'][0]['text'],
      );
      expect(
        jsonDecode(reply['result']['content'][0]['text'])['stdout'],
        'local-42',
      );
    }
    final host = hosts.singleWhere((row) => row['id'] == '#local');
    if (port != 0) {
      final row = hosts.singleWhere((row) => row['name'] == remote.name);
      expect(row['online'], false);
      final call = {
        'name': 'run_command',
        'arguments': {'host': row['id'], 'preset': 'probe'},
      };
      final refused = await send('tools/call', call);
      expect(refused['result']['isError'], true);
      expect(refused['result']['content'][0]['text'], contains('in ServerBox'));
      expect(container.read(serverProvider(remote.id)).client, isNull);
      expect(Stores.setting.sshKnownHostFingerprints.fetch(), isEmpty);
      Stores.setting.sshKnownHostFingerprints.putSync({
        for (final target in targets)
          hostKeyStorageKey(target, 'ssh-ed25519'):
              const String.fromEnvironment('MCP_SSH_HOST_FINGERPRINT'),
      });
      for (final target in targets) {
        final targetRow = hosts.singleWhere((r) => r['name'] == target.name);
        expect(targetRow['online'], false);
        final reply = await send('tools/call', {
          'name': 'run_command',
          'arguments': {'host': targetRow['id'], 'preset': 'probe'},
        });
        expect(reply['result']['isError'], isNull, reason: target.name);
        expect(jsonDecode(reply['result']['content'][0]['text']), {
          'stdout': 'local-42',
          'stderr': '',
          'exitCode': 0,
        });
        expect(
          container.read(serverProvider(target.id)).client?.isClosed,
          false,
        );
      }
    }
    final args = {
      'name': 'run_command',
      'arguments': {'host': host['id'], 'preset': 'probe'},
    };
    for (final name in [
      'machine_status',
      'machine_metrics',
      'cpu',
      'network',
      'disk_io',
      'storage',
      'processes',
    ]) {
      final inspection = await send('tools/call', {
        'name': name,
        'arguments': {'host': host['id']},
      });
      expect(inspection['result']['isError'], isNull, reason: name);
      final output = jsonDecode(inspection['result']['content'][0]['text']);
      expect(output['stdout'], isNotEmpty, reason: name);
    }
    final changed = await send('tools/call', {
      'name': 'app_setting_set',
      'arguments': {'key': 'editorSoftWrap', 'value': true},
    });
    expect(
      jsonDecode(changed['result']['content'][0]['text'])['editorSoftWrap'],
      true,
    );
    expect(Stores.setting.editorSoftWrap.fetch(), true);
    final edits = <String, Object>{
      'editorFontSize': 15.5,
      'locale': 'en',
      'timeOut': 7,
      'homeTabs': ['server', 'file'],
      'serverStatusUpdateInterval': 4,
      'editorFontFamily': 'monospace',
      'motionPref': 'reduce',
      'trayMetrics': ['cpu', 'disk'],
      'distNameMap': {'arch': 'archlinux'},
    };
    for (final entry in edits.entries) {
      final reply = await send('tools/call', {
        'name': 'app_setting_set',
        'arguments': {'key': entry.key, 'value': entry.value},
      });
      expect(
        jsonDecode(reply['result']['content'][0]['text'])[entry.key],
        entry.value,
      );
    }
    final keybinding = await send('tools/call', {
      'name': 'app_setting_set',
      'arguments': {
        'key': 'keybindings',
        'value': {'settings.search': 'Ctrl+Shift+F'},
      },
    });
    expect(
      jsonDecode(
        keybinding['result']['content'][0]['text'],
      )['keybindings']['settings.search'],
      'Ctrl+Shift+F',
    );
    final detail = await send('tools/call', {
      'name': 'process_detail',
      'arguments': {'host': host['id'], 'pid': pid},
    });
    expect(detail['result']['isError'], isNull);
    final reread = await send('tools/call', {
      'name': 'app_settings',
      'arguments': {},
    });
    final values = jsonDecode(reread['result']['content'][0]['text']);
    for (final entry in edits.entries) {
      expect(values[entry.key], entry.value);
    }
    expect(Stores.setting.editorFontSize.fetch(), 15.5);
    expect(Stores.setting.trayMetrics.fetch(), ['cpu', 'disk']);
    expect(Stores.setting.distNameMap.fetch(), {'arch': 'archlinux'});
    for (final bad in [
      {'key': 'editorFontSize', 'value': '15.5'},
      {'key': 'serverStatusUpdateInterval', 'value': 1},
      {
        'key': 'trayMetrics',
        'value': ['cpu', 'cpu'],
      },
      {
        'key': 'distNameMap',
        'value': {'arch': 42},
      },
    ]) {
      expect(
        (await send('tools/call', {
          'name': 'app_setting_set',
          'arguments': bad,
        }))['error']['code'],
        -32602,
      );
    }
    final run = await send('tools/call', args);
    expect(jsonDecode(run['result']['content'][0]['text']), {
      'stdout': 'local-42',
      'stderr': '',
      'exitCode': 0,
    });
    await revokeMcpToken(policy, digest);
    expect((await send('tools/call', args))['error'], isNotNull);
    await client.stdin.close();
    expect(await client.exitCode, 0);
  }, skip: !Platform.isMacOS && !Platform.isLinux);
}
