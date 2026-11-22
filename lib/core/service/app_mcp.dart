import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:dartssh2/dartssh2.dart';
import 'package:fl_lib/fl_lib.dart' show Paths;
import 'package:fl_tty/fl_tty.dart' show ExecResult, LocalExec, Rootfs;
import 'package:flutter/foundation.dart' show ValueNotifier;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';
import 'package:server_box/core/local/device.dart';
import 'package:server_box/core/local/server.dart';
import 'package:server_box/core/monitor/exec.dart';
import 'package:server_box/core/service/app_mcp_settings.dart';
import 'package:server_box/core/service/app_mcp_tokens.dart';
import 'package:server_box/core/service/app_mcp_tools.dart';
import 'package:server_box/core/ssh/exec.dart';
import 'package:server_box/core/ssh/noninteractive.dart';
import 'package:server_box/data/model/app/error.dart';
import 'package:server_box/data/model/server/server.dart';
import 'package:server_box/data/model/server/server_private_info.dart';
import 'package:server_box/data/model/server/system.dart';
import 'package:server_box/data/provider/server/all.dart';
import 'package:server_box/data/provider/server/single.dart';
import 'package:server_box/data/store/stores.dart';

const appMcpPort = 49762;
final appMcpToolNames = List<String>.unmodifiable([
  'list',
  'machine_capabilities',
  ...AppMcpInspection.values.map((tool) => tool.name),
  'app_settings',
  'app_setting_set',
  'container_logs',
  'container_stats',
  'container_action',
  'service_action',
  'service_logs',
  'process_detail',
  'image_inspect',
  'image_remove',
  'run_command',
]);

// A single listener for both desktop launch and the settings page.
final appMcpListener = ValueNotifier<HttpServer?>(null);
File? _selectedRegistry;
File get appMcpRegistryFile {
  final configured =
      Stores.setting.appMcp.get()?.path ??
      Platform.environment['SERVERBOX_MCP_POLICY'];
  return _selectedRegistry ??
      File(
        configured == null || configured.isEmpty
            ? '${Paths.doc}/app-mcp-policy.json'
            : configured,
      );
}

const defaultAppMcpListen = '127.0.0.1:$appMcpPort';

String get appMcpListen =>
    Stores.setting.appMcp.get()?.listen ?? defaultAppMcpListen;

Uri appMcpEndpoint(String listen) {
  final match = RegExp(
    r'^(?:\[([^\]]+)\]|([^:\[\]]+)):(\d+)$',
  ).firstMatch(listen.trim());
  final address = InternetAddress.tryParse(
    match?.group(1) ?? match?.group(2) ?? '',
  );
  final port = int.tryParse(match?.group(3) ?? '');
  if (address == null || port == null || port < 1 || port > 65535) {
    throw const FormatException(
      'Expected an IP address and port, e.g. 0.0.0.0:49762 or [::]:49762.',
    );
  }
  return Uri(scheme: 'http', host: address.address, port: port, path: '/mcp');
}

/// Addresses the OS can bind on individual interfaces, including VPN interfaces.
Future<List<({String interfaceName, InternetAddress address})>>
appMcpInterfaces() async {
  final interfaces = await NetworkInterface.list();
  return [
    for (final interface in interfaces)
      for (final address in interface.addresses)
        (interfaceName: interface.name, address: address),
  ];
}

String appMcpListenAt(InternetAddress address, int port) =>
    address.type == InternetAddressType.IPv6
    ? '[${address.address}]:$port'
    : '${address.address}:$port';

Uri appMcpListenerEndpoint(HttpServer listener) => Uri(
  scheme: 'http',
  host: listener.address.address,
  port: listener.port,
  path: '/mcp',
);

bool _changingListener = false;

Future<void> configureAppMcp(
  ProviderContainer container, {
  required bool enabled,
  File? file,
  String? listen,
  bool remember = true,
}) async {
  if (_changingListener) throw StateError('MCP server is changing state.');
  _changingListener = true;
  try {
    final endpointText = (listen ?? appMcpListen).trim();
    final endpoint = appMcpEndpoint(endpointText);
    final registry = file ?? appMcpRegistryFile;
    final previous = appMcpListener.value;
    final previousRegistry = _selectedRegistry ?? registry;
    void save() {
      if (remember) {
        Stores.setting.appMcp.putSync((
          enabled: enabled,
          path: registry.path,
          listen: endpointText,
        ));
      }
    }

    if (!enabled) {
      save();
      await previous?.close(force: true);
      appMcpListener.value = null;
      return;
    }
    await loadMcpRegistry(registry);
    final previousEndpoint = previous == null
        ? null
        : appMcpListenerEndpoint(previous);
    if (previousEndpoint == endpoint &&
        registry.path == previousRegistry.path) {
      save();
      return;
    }
    // Wildcard and interface-specific binds can overlap on the same port.
    if (previous != null) {
      await previous.close(force: true);
      appMcpListener.value = null;
    }
    HttpServer? replacement;
    try {
      replacement = await bindAppMcp(
        registry,
        container,
        address: endpoint.host,
        port: endpoint.port,
      );
      save();
    } catch (_) {
      await replacement?.close(force: true);
      if (previousEndpoint != null) {
        appMcpListener.value = await bindAppMcp(
          previousRegistry,
          container,
          address: previousEndpoint.host,
          port: previousEndpoint.port,
        );
      }
      rethrow;
    }
    _selectedRegistry = registry;
    appMcpListener.value = replacement;
  } finally {
    _changingListener = false;
  }
}

Future<void> startAppMcp(ProviderContainer container) async {
  final path = Platform.environment['SERVERBOX_MCP_POLICY'];
  try {
    if (!(Stores.setting.appMcp.get()?.enabled ??
        (path != null && path.isNotEmpty))) {
      return;
    }
    await configureAppMcp(container, enabled: true, remember: false);
  } catch (_) {
    Logger(
      'AppMcp',
    ).warning('Could not start the configured App MCP listener.');
  }
}

Future<HttpServer> bindAppMcp(
  File registryFile,
  ProviderContainer container, {
  String address = '127.0.0.1',
  int port = appMcpPort,
}) async {
  final server = await HttpServer.bind(InternetAddress(address), port);
  server.listen((request) => _handle(request, registryFile, container));
  return server;
}

String _digest(String value) => sha256.convert(utf8.encode(value)).toString();

Future<void> _handle(
  HttpRequest request,
  File registryFile,
  ProviderContainer container,
) async {
  Future<void> reject(int status) async {
    request.response.statusCode = status;
    await request.response.close();
  }

  try {
    if (request.uri.path != '/mcp') return await reject(404);
    if (request.method != 'POST') return await reject(405);
    if (request.headers['origin'] != null) return await reject(403);
    final auth = request.headers.value(HttpHeaders.authorizationHeader);
    if (auth == null || !auth.startsWith('Bearer ') || auth.length <= 7) {
      return await reject(401);
    }
    final body = BytesBuilder(copy: false);
    await for (final chunk in request.timeout(const Duration(seconds: 15))) {
      if (body.length + chunk.length > 65536) return await reject(413);
      body.add(chunk);
    }
    final dynamic message;
    try {
      message = jsonDecode(utf8.decode(body.takeBytes()));
    } on FormatException {
      return await reject(400);
    }
    // Read after the body so edits and revocations take effect before dispatch.
    final registry = await loadMcpRegistry(registryFile);
    final tokenId = _digest(auth.substring(7));
    if (!registry.tokens.containsKey(tokenId)) return await reject(401);
    final commands = registry.commands;
    final exec = LocalExec.forThisDevice();
    final local = exec != null && (!exec.inRootfs || Rootfs.isReady);
    final hosts = {
      for (final spi in container.read(serversProvider).servers.values)
        if (spi.sshOn != null || spi.monitorOn != null) _digest(spi.id): spi,
    };
    final id = message is Map ? message['id'] : null;
    Map<String, dynamic> error(int code, String description) => {
      'error': {'code': code, 'message': description},
    };
    final Map<String, dynamic> reply;
    if (message is! Map ||
        message['jsonrpc'] != '2.0' ||
        (message.containsKey('id') && id is! int && id is! String)) {
      reply = error(-32600, 'Invalid request');
    } else if (message['method'] is! String) {
      if (id != null &&
          (message.containsKey('result') != message.containsKey('error'))) {
        return await reject(202);
      }
      reply = error(-32600, 'Invalid request');
    } else if (id == null) {
      return await reject(202);
    } else {
      final params = message['params'];
      final version = request.headers.value('mcp-protocol-version');
      if (version != null && !_versions.contains(version)) {
        return await reject(400);
      }
      reply = switch (message['method']) {
        'initialize' => {
          'result': {
            'protocolVersion':
                params is Map && _versions.contains(params['protocolVersion'])
                ? params['protocolVersion']
                : _versions.first,
            'capabilities': {'tools': {}},
            'serverInfo': {'name': 'ServerBox', 'version': '1'},
          },
        },
        'ping' => {'result': {}},
        'tools/list' => {
          'result': {
            'tools': [
              _tool('list', 'List available hosts and preset names.', []),
              _tool(
                'machine_capabilities',
                'Inspect host transports and inspection tools for its platform.',
                ['host'],
              ),
              _tool('app_settings', 'Read editable ServerBox preferences.', []),
              mcpPreferenceTool(container),
              for (final name in [
                'container_logs',
                'container_stats',
                'container_action',
              ])
                _tool(
                  name,
                  switch (name) {
                    'container_logs' =>
                      'Read the last 100 container log lines.',
                    'container_stats' =>
                      'Read a container resource usage snapshot.',
                    _ => 'Start, stop or restart a container by its Docker ID.',
                  },
                  ['host', 'id', if (name == 'container_action') 'action'],
                  types: {
                    'id': {'type': 'string', 'pattern': _containerId.pattern},
                    if (name == 'container_action')
                      'action': {'type': 'string', 'enum': _lifecycleActions},
                  },
                ),
              for (final name in ['service_logs', 'service_action'])
                _tool(
                  name,
                  name == 'service_logs'
                      ? 'Read the last 100 journal entries for a systemd service.'
                      : 'Start, stop or restart a systemd service.',
                  ['host', 'key', if (name == 'service_action') 'action'],
                  types: {
                    'key': {'type': 'string', 'pattern': _serviceUnit.pattern},
                    if (name == 'service_action')
                      'action': {'type': 'string', 'enum': _lifecycleActions},
                  },
                ),
              _tool(
                'process_detail',
                'Read CPU and memory use for one process.',
                ['host', 'pid'],
                types: {
                  'pid': {
                    'type': 'integer',
                    'minimum': 1,
                    'maximum': 4294967295,
                  },
                },
              ),
              for (final name in ['image_inspect', 'image_remove'])
                _tool(
                  name,
                  name == 'image_remove'
                      ? 'Remove a Docker image by its full ID.'
                      : 'Read Docker image size and architecture.',
                  ['host', 'id'],
                  types: {
                    'id': {'type': 'string', 'pattern': _imageId.pattern},
                  },
                ),
              for (final probe in AppMcpInspection.values)
                _tool(probe.name, probe.description, ['host']),
              if (commands.isNotEmpty)
                _tool('run_command', 'Run a named preset on a host.', [
                  'host',
                  'preset',
                ]),
            ],
          },
        },
        'tools/call' when params is Map => await _call(
          container,
          hosts,
          commands,
          local,
          params,
          tokenId,
        ),
        'tools/call' => error(-32602, 'Invalid parameters'),
        _ => error(-32601, 'Unknown method'),
      };
    }
    request.response.headers.contentType = ContentType.json;
    request.response.write(
      jsonEncode({
        'jsonrpc': '2.0',
        'id': id is int || id is String ? id : null,
        ...reply,
      }),
    );
    await request.response.close();
  } catch (_) {
    try {
      await reject(503);
    } catch (_) {
      // The client may have disconnected while a command was running.
    }
  }
}

const _lifecycleActions = ['start', 'stop', 'restart'];
final _serviceUnit = RegExp(r'^[a-zA-Z0-9][a-zA-Z0-9_.@:-]{0,246}\.service$');
final _imageId = RegExp(r'^sha256:[0-9a-f]{64}$');
final _containerId = RegExp(r'^(?:[0-9a-f]{12}|[0-9a-f]{64})$');

const _versions = ['2025-11-25', '2025-06-18'];

Map<String, Object?> _tool(
  String name,
  String description,
  List<String> keys, {
  Map<String, Object> types = const {},
}) => {
  'name': name,
  'description': description,
  'inputSchema': {
    'type': 'object',
    'properties': {
      for (final key in keys) key: types[key] ?? {'type': 'string'},
    },
    'required': keys,
    'additionalProperties': false,
  },
};

Future<Map<String, dynamic>> _call(
  ProviderContainer container,
  Map<String, Spi> hosts,
  Map<String, String> commands,
  bool local,
  Map params,
  String tokenId,
) async {
  final args = params['arguments'] ?? {};
  Map<String, dynamic> result(Object value, {bool failed = false}) => {
    'result': {
      'content': [
        {'type': 'text', 'text': value is String ? value : jsonEncode(value)},
      ],
      if (failed) 'isError': true,
    },
  };
  final name = params['name'];
  final invalid = {
    'error': {'code': -32602, 'message': 'Unknown tool or invalid arguments'},
  };
  if (!appMcpToolNames.contains(name) ||
      (name == 'run_command' && commands.isEmpty)) {
    return invalid;
  }
  if (name == 'app_settings' || name == 'app_setting_set') {
    final settings = mcpPreferences(container);
    if (args is! Map) return invalid;
    if (name == 'app_settings') {
      if (args.isNotEmpty) return invalid;
      return result({for (final e in settings.entries) e.key: e.value.read()});
    }
    final prop = settings[args['key']];
    final value = args['value'];
    if (args.length != 2 || prop == null || !prop.write(value)) return invalid;
    return result({args['key'] as String: prop.read()});
  }
  if (name == 'list' && args is Map && args.isEmpty) {
    return result({
      'hosts': [
        if (local)
          {'id': LocalDevice.id, 'name': 'This device', 'online': true},
        for (final entry in hosts.entries)
          {
            'id': entry.key,
            'name': entry.value.name,
            'online': _online(container.read(serverProvider(entry.value.id))),
          },
      ],
      'commands': commands.keys.toList(),
    });
  }
  final preset = name == 'run_command';
  final containerTool =
      name == 'container_action' ||
      name == 'container_logs' ||
      name == 'container_stats';
  final serviceTool = name == 'service_action' || name == 'service_logs';
  final imageTool = name == 'image_inspect' || name == 'image_remove';
  final fields = name == 'container_action' || name == 'service_action'
      ? 3
      : preset ||
            containerTool ||
            serviceTool ||
            imageTool ||
            name == 'process_detail'
      ? 2
      : 1;
  if (args is! Map ||
      args['host'] is! String ||
      args.length != fields ||
      (preset && args['preset'] is! String) ||
      name == 'list') {
    return invalid;
  }
  final spi = hosts[args['host']];
  final isLocal = local && args['host'] == LocalDevice.id;
  if (!isLocal && spi == null) return result('Unknown host.', failed: true);
  final state = spi == null ? null : container.read(serverProvider(spi.id));
  final system = isLocal
      ? LocalServer.systemType
      : spi!.customSystemType ?? state!.status.system;
  final inspections = {
    for (final probe in AppMcpInspection.values)
      if (probe.command(system) != null) probe.name: probe.command(system)!,
  };
  if (name == 'machine_capabilities') {
    return result({
      'platform': system.name,
      'transports': [
        if (isLocal) 'local',
        if (spi?.sshOn != null) 'ssh',
        if (spi?.monitorOn != null) 'monitor',
      ],
      'inspections': inspections.keys.toList(),
    });
  }
  String? command;
  if (name == 'process_detail') {
    final pid = args['pid'];
    if (pid is! int || pid < 1 || pid > 4294967295) return invalid;
    command = system == SystemType.windows
        ? 'powershell -NoProfile -Command "Get-Process -Id $pid | Select-Object Id,ProcessName,CPU,WorkingSet64"'
        : 'ps -p $pid -o pid,comm,%cpu,%mem';
  } else if (imageTool) {
    final id = args['id'];
    if (id is! String || _imageId.stringMatch(id) != id) return invalid;
    command = name == 'image_remove'
        ? 'docker image rm $id'
        : 'docker image inspect --format "{{.Size}} {{.Architecture}}" $id';
  } else if (serviceTool) {
    final key = args['key'];
    final action = args['action'];
    if (key is! String ||
        _serviceUnit.stringMatch(key) != key ||
        (name == 'service_action' && !_lifecycleActions.contains(action))) {
      return invalid;
    }
    if (system != SystemType.linux) {
      return result('Requires systemd on Linux.', failed: true);
    }
    command = name == 'service_action'
        ? 'systemctl --no-ask-password $action -- $key'
        : 'journalctl --no-pager -n 100 --unit=$key';
  } else if (containerTool) {
    final id = args['id'];
    final action = args['action'];
    if (id is! String ||
        _containerId.stringMatch(id) != id ||
        (name == 'container_action' && !_lifecycleActions.contains(action))) {
      return invalid;
    }
    command = switch (name) {
      'container_action' => 'docker $action $id',
      'container_logs' => 'docker logs --tail 100 $id',
      _ => 'docker stats --no-stream $id',
    };
  } else {
    command = preset ? commands[args['preset']] : inspections[name];
  }
  if (command == null) {
    return result('Unknown preset or unsupported inspection.', failed: true);
  }
  Map<String, dynamic> executionResult(Map<String, Object?> output) => result(
    output,
    failed:
        (!preset && output['exitCode'] != 0) ||
        output['timedOut'] == true ||
        output['truncated'] == true,
  );
  if (isLocal) {
    final exec = LocalExec.forThisDevice();
    if (exec == null) {
      return result('Local execution unavailable.', failed: true);
    }
    try {
      Logger(
        'AppMcp',
      ).info('$name token=${tokenId.substring(0, 12)} host=local');
      return executionResult(await _executeLocal(exec, command));
    } catch (_) {
      return result(
        'Local command failed, timed out, or exceeded the output limit.',
        failed: true,
      );
    }
  }
  if (spi == null || state?.spi != spi) {
    return result('Host configuration changed.', failed: true);
  }
  final notifier = container.read(serverProvider(spi.id).notifier);
  try {
    final exec = await notifier.ensureUnattendedExec();
    if (!notifier.isExecCurrent(exec, spi)) {
      return result('Host configuration changed.', failed: true);
    }
    // Only record opaque identifiers. Preset bodies and output can contain credentials.
    Logger('AppMcp').info(
      '$name token=${tokenId.substring(0, 12)} host=${_digest(spi.id).substring(0, 12)}',
    );
    if (exec is SshExec) {
      return executionResult(await _execute(exec.client, command));
    }
    if (exec is MonitorExec) {
      final output = await exec.client.exec(command);
      if (utf8.encode(output.stdout).length +
              utf8.encode(output.stderr).length >
          256 * 1024) {
        return result('Command exceeded the output limit.', failed: true);
      }
      return executionResult({
        'stdout': output.stdout,
        'stderr': output.stderr,
        'exitCode': output.exitCode,
        if (output.timedOut) 'timedOut': true,
        if (output.truncated) 'truncated': true,
      });
    }
    return result('Unsupported transport.', failed: true);
  } on MonitorHttpErr catch (e) {
    return result('Monitor request failed (${e.type.name}).', failed: true);
  } on SshInteractionRequired {
    return result('Connect to this host in ServerBox first.', failed: true);
  } catch (_) {
    return result(
      'Command failed, timed out, or exceeded the output limit.',
      failed: true,
    );
  }
}

Future<Map<String, Object?>> _executeLocal(
  LocalExec exec,
  String command,
) async {
  final cancel = Completer<void>();
  void stop() {
    if (!cancel.isCompleted) cancel.complete();
  }

  var remaining = 256 * 1024;
  void countOutput(String chunk) {
    remaining -= utf8.encode(chunk).length;
    if (remaining < 0) stop();
  }

  final timer = Timer(const Duration(seconds: 30), stop);
  try {
    final out = await Future.any<ExecResult>([
      exec.run(
        command,
        cancel: cancel.future,
        onStdout: countOutput,
        onStderr: countOutput,
      ),
      cancel.future.then((_) => throw StateError('Execution limit reached')),
    ]);
    if (cancel.isCompleted) throw StateError('Execution limit reached');
    return {
      'stdout': out.stdout,
      'stderr': out.stderr,
      'exitCode': out.exitCode,
    };
  } finally {
    timer.cancel();
  }
}

bool _online(ServerState state) =>
    state.client?.isClosed == false ||
    (state.spi.monitorOn != null && !(state.conn < ServerConn.connected));

Future<Map<String, Object?>> _execute(SSHClient client, String command) async {
  final opening = client.execute(command);
  final session = await opening.timeout(
    const Duration(seconds: 15),
    onTimeout: () {
      unawaited(
        opening.then<void>(
          (lateSession) => lateSession.close(),
          onError: (_, _) {},
        ),
      );
      throw TimeoutException('SSH channel open');
    },
  );
  var remaining = 256 * 1024;
  Future<String> collect(Stream<Uint8List> stream) async {
    final bytes = BytesBuilder(copy: false);
    await for (final chunk in stream) {
      remaining -= chunk.length;
      if (remaining < 0) throw StateError('Output limit');
      bytes.add(chunk);
    }
    return utf8.decode(bytes.takeBytes(), allowMalformed: true);
  }

  try {
    unawaited(session.stdin.close());
    final output = await Future.wait<Object?>([
      collect(session.stdout),
      collect(session.stderr),
      session.waitForExit(),
    ], eagerError: true).timeout(const Duration(seconds: 30));
    return {'stdout': output[0], 'stderr': output[1], 'exitCode': output[2]};
  } finally {
    session.close();
  }
}
