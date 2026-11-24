import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:server_box/core/service/app_mcp.dart';
import 'package:server_box/core/service/app_mcp_tokens.dart';
import 'package:server_box/core/service/monitor_login_devices.dart';
import 'package:server_box/core/ssh/host_keys.dart';
import 'package:server_box/core/ssh/keygen.dart';
import 'package:server_box/data/model/server/monitor/monitor_http_credential.dart';
import 'package:server_box/data/model/server/server_private_info.dart';
import 'package:server_box/data/model/server/ssh_credential.dart';
import 'package:server_box/data/model/server/try_limiter.dart';
import 'package:server_box/data/provider/server/single.dart';
import 'package:server_box/data/store/server.dart';
import 'package:server_box/data/store/setting.dart';
import 'package:server_box/data/store/stores.dart';
import 'package:server_box/src/rust/frb_generated.dart';

import '../test/helpers/test_db.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('an external stdio client reaches every server through the app', (
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
    final directory = await Directory.systemTemp.createTemp('app-mcp-');
    addTearDown(() => directory.delete(recursive: true));
    final locked = File('${directory.path}/deferred');
    if (port != 0) {
      await locked.writeAsString(
        generateSshKeyPair([
          SshKeyAlgorithm.ed25519.name,
          'fixture',
          'locked fixture',
        ])[0],
      );
    }
    final remote = Spi(
      id: 'mcp-ssh-fixture',
      name: 'OpenSSH fixture',
      ssh: SshCredential(
        ip: '127.0.0.1',
        port: port,
        user: 'fixture',
        identityFiles: [
          if (port != 0) locked.path,
          const String.fromEnvironment('MCP_SSH_KEY'),
        ],
        identityAgent: 'none',
      ),
    );
    final onlyLocked = remote.copyWith(
      id: 'mcp-locked',
      name: 'Locked fixture',
      ssh: remote.ssh!.copyWith(identityFiles: [locked.path]),
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
      for (final target in [...targets, onlyLocked]) {
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

    final policy = File('${directory.path}/app-mcp.json');
    Stores.setting.agentLocalExec.put(true);
    const probe = 'printf "local-%s" 42';
    final cert = '${policy.path}.crt';
    final config = File('${directory.path}/openssl.cnf');
    await config.writeAsString(
      '[req]\ndistinguished_name=dn\nx509_extensions=test_cert\nprompt=no\n'
      '[dn]\nCN=localhost\n[test_cert]\nsubjectAltName=DNS:localhost,IP:127.0.0.1\n'
      'basicConstraints=critical,CA:TRUE\nkeyUsage=critical,digitalSignature,keyCertSign\nsubjectKeyIdentifier=hash\nauthorityKeyIdentifier=keyid:always\n',
    );
    final certificate = await Process.run('openssl', [
      'req',
      '-x509',
      '-newkey',
      'rsa:2048',
      '-nodes',
      '-days',
      '1',
      '-config',
      config.path,
      '-keyout',
      '${policy.path}.key',
      '-out',
      cert,
    ]);
    expect(certificate.exitCode, 0);
    final token = await createMcpToken(policy, 'Fixture');
    final free = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    final customPort = free.port;
    await free.close();
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
    final beforeFailedBind = appMcpListener.value;
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
      expect(appMcpListener.value, same(beforeFailedBind));
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
    // The fixture certificate names localhost. Reach the wildcard TLS
    // listener through that verified name regardless of available interfaces.
    await configureAppMcp(container, enabled: true, listen: listen);
    const clientHost = '127.0.0.1';

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
        'SERVERBOX_MCP_SCHEME': 'https',
        'SSL_CERT_FILE': cert,
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
      final message = jsonDecode(await reply) as Map<String, dynamic>;
      expect(message['id'], id);
      return message;
    }

    final init = await send('initialize', {
      'protocolVersion': '2025-11-25',
      'capabilities': {},
      'clientInfo': {'name': 'e2e', 'version': '1'},
    });
    expect(init['error'], isNull);
    expect(init['result']['serverInfo']['name'], 'serverbox');
    client.stdin.writeln(
      jsonEncode({'jsonrpc': '2.0', 'method': 'notifications/initialized'}),
    );
    final tools = await send('tools/list', {});
    expect(
      (tools['result']['tools'] as List).map((tool) => tool['name']),
      containsAll(['run_command', 'processes', 'services', 'app_setting_set']),
    );
    Future<Map> call(String name, Map arguments) async =>
        (await send('tools/call', {'name': name, 'arguments': arguments}))['result']
            as Map;
    final hosts =
        (await call('list', {}))['structuredContent']['hosts'] as List;
    Map row(String name) => hosts.singleWhere((r) => r['name'] == name) as Map;
    void ranProbe(Map result, String reason) {
      expect(result['isError'], false, reason: '$reason: $result');
      expect(result['structuredContent']['stdout'], 'local-42', reason: reason);
      expect(result['structuredContent']['exit_code'], 0, reason: reason);
    }

    if (monitorPort != 0) {
      final monitor = row('Monitor fixture')['id'];
      ranProbe(
        await call('run_command', {'host': monitor, 'command': probe}),
        'monitor',
      );
      final listing = await call('processes', {'host': monitor});
      expect(listing['structuredContent']['available'], true);
    }
    if (port != 0) {
      final refused = await call('run_command', {
        'host': row(remote.name)['id'],
        'command': probe,
      });
      // The host key is unknown: a question for the person, and no connection.
      expect(refused['isError'], true);
      expect(container.read(serverProvider(remote.id)).client, isNull);
      expect(Stores.setting.sshKnownHostFingerprints.fetch(), isEmpty);
      Stores.setting.sshKnownHostFingerprints.putSync({
        for (final target in [...targets, onlyLocked])
          hostKeyStorageKey(target, 'ssh-ed25519'):
              const String.fromEnvironment('MCP_SSH_HOST_FINGERPRINT'),
      });
      // A key that needs its passphrase is a question for the person, and
      // asking it is not a failed attempt: however often it is asked, the
      // person can still connect.
      for (var i = 0; i <= Stores.setting.maxRetryCount.fetch(); i++) {
        final needsUnlock = await call('run_command', {
          'host': row(onlyLocked.name)['id'],
          'command': probe,
        });
        expect(needsUnlock['isError'], true);
      }
      expect(TryLimiter.canTry('${onlyLocked.id}#shell'), true);
      for (final target in targets) {
        final id = row(target.name)['id'];
        expect(row(target.name)['online'], false);
        ranProbe(await call('run_command', {'host': id, 'command': probe}), target.name);
        expect(
          container.read(serverProvider(target.id)).client?.isClosed,
          false,
        );
      }
      final id = row(remote.name)['id'];
      final caps = await call('machine_capabilities', {'host': id});
      expect(caps['structuredContent']['platform'], 'linux');
      for (final name in ['processes', 'services', 'containers', 'tmux']) {
        final reading = await call(name, {'host': id});
        expect(reading['isError'], false, reason: '$name: $reading');
      }
    }
    final local = hosts.singleWhere(
      (r) => (r['transports'] as List).contains('local'),
    )['id'];
    final args = {'host': local, 'command': probe};
    for (final name in ['services', 'containers', 'tmux']) {
      final reading = await call(name, {'host': local});
      expect(reading['isError'], false, reason: '$name: $reading');
    }
    final changed = await call('app_setting_set', {
      'key': 'editorSoftWrap',
      'value': true,
    });
    expect(changed['structuredContent']['editorSoftWrap'], true);
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
      final reply = await call('app_setting_set', {
        'key': entry.key,
        'value': entry.value,
      });
      expect(reply['structuredContent'][entry.key], entry.value);
    }
    final keybinding = await call('app_setting_set', {
      'key': 'keybindings',
      'value': {'settings.search': 'Ctrl+Shift+F'},
    });
    expect(
      keybinding['structuredContent']['keybindings']['settings.search'],
      'Ctrl+Shift+F',
    );
    final values = (await call('app_settings', {}))['structuredContent'];
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
      expect((await call('app_setting_set', bad))['isError'], true);
    }
    ranProbe(await call('run_command', args), 'this device');
    final fixture = (await loadMcpRegistry(policy)).tokens.single;
    await revokeMcpToken(policy, fixture.id);
    expect(
      (await send('tools/call', {'name': 'run_command', 'arguments': args}))['error'],
      isNotNull,
    );
    await client.stdin.close();
    expect(await client.exitCode, 0);
  }, skip: !Platform.isMacOS && !Platform.isLinux);
}
