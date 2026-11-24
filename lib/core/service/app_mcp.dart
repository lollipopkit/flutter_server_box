import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:fl_lib/fl_lib.dart' show Paths;
import 'package:fl_tty/fl_tty.dart' show LocalExec;
import 'package:flutter/foundation.dart' show ValueNotifier;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';
import 'package:server_box/core/extension/context/locale.dart' show l10n;
import 'package:server_box/core/local/device.dart';
import 'package:server_box/core/local/server.dart';
import 'package:server_box/core/monitor/exec.dart';
import 'package:server_box/core/service/app_mcp_settings.dart';
import 'package:server_box/core/service/app_mcp_tokens.dart';
import 'package:server_box/core/ssh/noninteractive.dart';
import 'package:server_box/data/model/app/error.dart';
import 'package:server_box/data/model/app/scripts/shell_func.dart';
import 'package:server_box/data/model/server/server.dart';
import 'package:server_box/data/model/server/server_exec.dart';
import 'package:server_box/data/model/server/server_private_info.dart';
import 'package:server_box/data/provider/server/all.dart';
import 'package:server_box/data/provider/server/single.dart';
import 'package:server_box/data/store/stores.dart';
import 'package:server_box/src/rust/api/app_mcp.dart' as ffi;

const appMcpPort = 49762;

/// `sbm_ffi::api::app_mcp::APP_MCP_MAX_BODY`.
const _maxBody = 64 * 1024;

/// What a command may print and how long it may take: the floor under
/// [ffi.AppMcpRun]'s `room`.
const _minOutput = 256 * 1024;
const _commandTimeout = Duration(seconds: 30);

final _log = Logger('AppMcp');

// A single listener for both desktop launch and the settings page.
final appMcpListener = ValueNotifier<HttpServer?>(null);
File? _selectedRegistry;

/// Resolved when read, never stored: on iOS the app's container moves on
/// update, and a saved absolute path would name the old one.
File get _defaultRegistry => File('${Paths.doc}/app-mcp.json');

/// The registry path as configured: empty for the default.
String get _configuredRegistry =>
    _selectedRegistry?.path ??
    Stores.setting.appMcp.get()?.path ??
    Platform.environment['SERVERBOX_MCP_POLICY'] ??
    '';

File get appMcpRegistryFile {
  final configured = _configuredRegistry;
  return configured.isEmpty ? _defaultRegistry : File(configured);
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
    throw FormatException(l10n.appMcpInvalidAddress);
  }
  return Uri(
    scheme: address.isLoopback ? 'http' : 'https',
    host: address.address,
    port: port,
    path: '/mcp',
  );
}

/// Addresses a client on another machine can reach, including VPN
/// interfaces: not loopback, and not an IPv6 link-local one, whose scope id
/// no URL can carry.
Future<List<({String interfaceName, InternetAddress address})>>
appMcpInterfaces() async {
  final interfaces = await NetworkInterface.list();
  return [
    for (final interface in interfaces)
      for (final address in interface.addresses)
        if (!address.isLoopback && !address.isLinkLocal)
          (interfaceName: interface.name, address: address),
  ];
}

String appMcpListenAt(InternetAddress address, int port) =>
    address.type == InternetAddressType.IPv6
    ? '[${address.address}]:$port'
    : '${address.address}:$port';

Uri appMcpListenerEndpoint(HttpServer listener) => Uri(
  scheme: listener.address.isLoopback ? 'http' : 'https',
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
  if (_changingListener) throw StateError(l10n.appMcpListenBusy);
  _changingListener = true;
  try {
    final endpointText = (listen ?? appMcpListen).trim();
    final endpoint = appMcpEndpoint(endpointText);
    final registry = file ?? appMcpRegistryFile;
    // Empty: the default, wherever the documents folder is then.
    final storedPath = file?.path ?? _configuredRegistry;
    final previous = appMcpListener.value;
    final previousRegistry = _selectedRegistry ?? registry;
    void save() {
      if (remember) {
        Stores.setting.appMcp.putSync((
          enabled: enabled,
          path: storedPath,
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
    final overlap =
        previousEndpoint != null &&
        previousEndpoint.port == endpoint.port &&
        (previousEndpoint.host == endpoint.host ||
            previousEndpoint.host == '::' ||
            endpoint.host == '::' ||
            (!previousEndpoint.host.contains(':') &&
                !endpoint.host.contains(':') &&
                (previousEndpoint.host == '0.0.0.0' ||
                    endpoint.host == '0.0.0.0')));
    if (overlap && previous != null) {
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
      if (overlap) {
        appMcpListener.value = await bindAppMcp(
          previousRegistry,
          container,
          address: previousEndpoint.host,
          port: previousEndpoint.port,
        );
      }
      rethrow;
    }
    if (!overlap) await previous?.close(force: true);
    _selectedRegistry = storedPath.isEmpty ? null : registry;
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
    _log.warning('Could not start the configured App MCP listener.');
  }
}

Future<HttpServer> bindAppMcp(
  File registryFile,
  ProviderContainer container, {
  String address = '127.0.0.1',
  int port = appMcpPort,
}) async {
  final ip = InternetAddress(address);
  final HttpServer server;
  if (ip.isLoopback) {
    server = await HttpServer.bind(ip, port);
  } else {
    final tls = SecurityContext();
    if (Platform.isIOS) {
      // iOS reads PKCS#12 only; each call takes its own half of the bundle.
      tls.useCertificateChain('${registryFile.path}.p12');
      tls.usePrivateKey('${registryFile.path}.p12');
    } else {
      tls.useCertificateChain('${registryFile.path}.crt');
      tls.usePrivateKey('${registryFile.path}.key');
    }
    server = await HttpServer.bindSecure(ip, port, tls);
  }
  server.listen(
    (request) => _handle(request, registryFile, container),
    onError: (Object error) =>
        _log.warning('Listener connection failed: ${error.runtimeType}'),
  );
  return server;
}

Future<void> _handle(
  HttpRequest request,
  File registryFile,
  ProviderContainer container,
) async {
  var readingBody = false;
  Future<void> answer(int status, [String? body]) async {
    final response = request.response;
    response.statusCode = status;
    if (status >= 400) response.persistentConnection = false;
    if (body == null) {
      response.contentLength = 0;
    } else {
      response.headers.contentType = ContentType.json;
      response.write(body);
    }
    // HttpResponse otherwise drains an unconsumed upload before sending headers.
    final unread = readingBody ? null : (request.listen(null)..pause());
    try {
      await response.close();
    } finally {
      await unread?.cancel();
    }
  }

  try {
    if (request.uri.path != '/mcp') return await answer(404);
    if (request.method != 'POST') {
      request.response.headers.set(HttpHeaders.allowHeader, 'POST');
      return await answer(405);
    }
    // A page in a browser is never a client of this listener.
    if (request.headers['origin'] != null) return await answer(403);
    final authorization = request.headers.value(
      HttpHeaders.authorizationHeader,
    );
    switch (ffi.appMcpAuthorized(
      text: await readMcpRegistryText(registryFile),
      authorization: authorization,
    )) {
      case ffi.AppMcpAuth.authorized:
        break;
      case ffi.AppMcpAuth.unauthorized:
        return await answer(401);
      // A registry with a typo is no token's fault.
      case ffi.AppMcpAuth.unreadable:
        return await answer(503);
    }

    final body = BytesBuilder(copy: false);
    readingBody = true;
    final chunks = StreamIterator(request);
    final elapsed = Stopwatch()..start();
    const deadline = Duration(seconds: 15);
    try {
      while (true) {
        final remaining = deadline - elapsed.elapsed;
        if (remaining <= Duration.zero) throw TimeoutException('body');
        if (!await chunks.moveNext().timeout(remaining)) break;
        final chunk = chunks.current;
        if (body.length + chunk.length > _maxBody) return await answer(413);
        body.add(chunk);
      }
    } on TimeoutException {
      return await answer(408);
    } finally {
      await chunks.cancel();
    }

    // One view of the servers for the whole call: a server edited while it
    // runs is a different server, and no later command of the call reaches it.
    final servers = container.read(serversProvider).servers;
    // Read after the body so edits and revocations take effect before dispatch.
    final response = await ffi.appMcpServe(
      request: ffi.AppMcpRequest(
        registry: await readMcpRegistryText(registryFile),
        authorization: authorization,
        protocolVersion: request.headers.value('mcp-protocol-version'),
        accept: request.headers[HttpHeaders.acceptHeader] ?? const [],
        contentType: request.headers.value(HttpHeaders.contentTypeHeader),
        body: body.takeBytes(),
        hosts: _hosts(container, servers),
        settingsSchema: jsonEncode(mcpPreferenceSchema(container)),
      ),
      run: (run) => _run(container, servers, run),
      settings: (name, arguments) => _settings(container, name, arguments),
    );
    if (response.call case final call?) {
      // Opaque digest prefix only: arguments and output can hold credentials.
      final callerId = call.token;
      _log.info('${call.tool} caller=$callerId host=${call.host ?? '-'}');
    }
    await answer(response.status, response.body);
  } catch (_) {
    try {
      await answer(503);
    } catch (_) {
      // The client may have disconnected while a command was running.
    }
  }
}

List<ffi.AppMcpHost> _hosts(
  ProviderContainer container,
  Map<String, Spi> servers,
) => [
  if (LocalDevice.isOffered)
    ffi.AppMcpHost(
      id: LocalDevice.id,
      name: l10n.thisDevice,
      online: true,
      transports: const ['local'],
      system: LocalServer.systemType.ffi,
      // No status script is kept for this device.
      script: false,
    ),
  for (final spi in servers.values)
    // A server with every way there turned off is not one to reach, and this
    // device only with the person's consent, however it is configured.
    if (spi.local ? LocalDevice.isOffered : spi.sshOn != null || spi.monitorOn != null)
      _host(spi, container.read(serverProvider(spi.id))),
];

ffi.AppMcpHost _host(Spi spi, ServerState state) => ffi.AppMcpHost(
  id: spi.id,
  name: spi.name,
  online:
      state.client?.isClosed == false ||
      (spi.monitorOn != null && !(state.conn < ServerConn.connected)),
  transports: [
    if (spi.local) 'local',
    if (spi.sshOn != null) 'ssh',
    if (spi.monitorOn != null) 'monitor',
  ],
  // Only what a reading has said: before one, the default would be a guess.
  system: (spi.customSystemType ??
          (state.conn == ServerConn.finished ? state.status.system : null))
      ?.ffi,
  script: true,
);

ffi.AppMcpRan _failed(ffi.AppMcpFailure failure) => ffi.AppMcpRan(
  stdout: '',
  stderr: '',
  truncated: false,
  timedOut: false,
  failure: failure,
);

Future<ffi.AppMcpRan> _run(
  ProviderContainer container,
  Map<String, Spi> servers,
  ffi.AppMcpRun run,
) async {
  final host = switch (run) {
    ffi.AppMcpRun_Command(:final host) || ffi.AppMcpRun_Script(:final host) =>
      host,
  };
  final room = switch (run) {
    ffi.AppMcpRun_Command(:final room) || ffi.AppMcpRun_Script(:final room) =>
      room.toInt(),
  };
  try {
    if (host == LocalDevice.id) {
      final exec = LocalExec.forThisDevice();
      if (exec == null || !LocalDevice.isOffered) {
        return _failed(ffi.AppMcpFailure.unavailable);
      }
      return switch (run) {
        ffi.AppMcpRun_Command(:final script, :final entry, :final stdin) =>
          await _bounded(exec, script, entry: entry, stdin: stdin, room: room),
        // Asked only of a host with `script` set.
        ffi.AppMcpRun_Script() => _failed(ffi.AppMcpFailure.unavailable),
      };
    }

    final spi = servers[host];
    bool unchanged() => container.read(serversProvider).servers[host] == spi;
    if (spi == null || !unchanged()) {
      return _failed(ffi.AppMcpFailure.hostChanged);
    }
    if (spi.local && !LocalDevice.isOffered) {
      return _failed(ffi.AppMcpFailure.unavailable);
    }
    final notifier = container.read(serverProvider(spi.id).notifier);
    final exec = run is ffi.AppMcpRun_Script
        ? await notifier.ensureScriptExec(unattended: true)
        : await notifier.ensureUnattendedExec();
    // Again once connected: the server may have been edited or removed
    // while the connection was made.
    if (!unchanged() || !notifier.isExecCurrent(exec, spi)) {
      return _failed(ffi.AppMcpFailure.hostChanged);
    }
    return switch (run) {
      ffi.AppMcpRun_Command(:final script, :final entry, :final stdin) =>
        await _bounded(exec, script, entry: entry, stdin: stdin, room: room),
      ffi.AppMcpRun_Script(:final func) => await _bounded(
        exec,
        func.exec(
          spi.id,
          systemType:
              spi.customSystemType ??
              container.read(serverProvider(spi.id)).status.system,
          customDir: spi.custom?.scriptDir,
        ),
        room: room,
      ),
    };
  } on SshInteractionRequired {
    return _failed(ffi.AppMcpFailure.needsUser);
  } catch (_) {
    return _failed(ffi.AppMcpFailure.unavailable);
  }
}

/// [script] on [exec], stopped at [_commandTimeout] or once it has printed
/// more than [room] (at least [_minOutput]) bytes; what it printed until then
/// is kept.
Future<ffi.AppMcpRan> _bounded(
  CommandExec exec,
  String script, {
  String? entry,
  String? stdin,
  required int room,
}) async {
  final cap = max(room, _minOutput);
  final cancel = Completer<void>();
  final stdout = StringBuffer();
  final stderr = StringBuffer();
  var timedOut = false;
  var truncated = false;
  var kept = 0;
  void keep(StringBuffer into, String chunk) {
    if (truncated) return;
    final bytes = utf8.encode(chunk);
    if (kept + bytes.length <= cap) {
      kept += bytes.length;
      into.write(chunk);
      return;
    }
    into.write(utf8.decode(bytes.sublist(0, cap - kept), allowMalformed: true));
    kept = cap;
    truncated = true;
    if (!cancel.isCompleted) cancel.complete();
  }

  final timer = Timer(_commandTimeout, () {
    if (cancel.isCompleted) return;
    timedOut = true;
    cancel.complete();
  });
  try {
    // Not every transport can stop a command: the answer does not wait for it.
    final result = await Future.any<ExecResult?>([
      exec.run(
        script,
        entry: entry,
        stdin: stdin,
        onStdout: (chunk) => keep(stdout, chunk),
        onStderr: (chunk) => keep(stderr, chunk),
        cancel: cancel.future,
      ),
      cancel.future.then((_) => null),
    ]);
    final stopped = result == null || timedOut || truncated;
    return ffi.AppMcpRan(
      stdout: stopped ? stdout.toString() : result.stdout,
      stderr: stopped ? stderr.toString() : result.stderr,
      exitCode: stopped ? null : result.exitCode,
      truncated: truncated || (result?.outputIncomplete ?? false),
      timedOut:
          timedOut || (result is MonitorExecResult && result.timedOut),
    );
  } catch (e) {
    return _failed(_failureOf(e));
  } finally {
    timer.cancel();
  }
}

/// Why [e] kept a command from its answer: a Monitor that refused before the
/// command was sent did not run it, and a certificate to confirm is the
/// person's; anything else may have run.
ffi.AppMcpFailure _failureOf(Object e) => switch (e) {
  MonitorHttpErr(
    type: MonitorHttpErrType.certUnconfirmed || MonitorHttpErrType.certChanged,
  ) =>
    ffi.AppMcpFailure.needsUser,
  MonitorHttpErr(
    type: MonitorHttpErrType.loginFailed ||
        MonitorHttpErrType.auth ||
        MonitorHttpErrType.notGranted ||
        MonitorHttpErrType.forbidden ||
        MonitorHttpErrType.agentTooOld ||
        MonitorHttpErrType.clientTooOld,
  ) =>
    ffi.AppMcpFailure.unavailable,
  _ => ffi.AppMcpFailure.failed,
};

Future<String?> _settings(
  ProviderContainer container,
  String name,
  String arguments,
) async {
  try {
    final args = jsonDecode(arguments);
    if (args is! Map) return null;
    final preferences = mcpPreferences(container);
    if (name == 'app_settings') {
      if (args.isNotEmpty) return null;
      return jsonEncode({
        for (final e in preferences.entries) e.key: e.value.read(),
      });
    }
    final key = args['key'];
    final pref = preferences[key];
    if (args.length != 2 || pref == null || !pref.write(args['value'])) {
      return null;
    }
    return jsonEncode({key as String: pref.read()});
  } catch (e) {
    _log.warning('Preference call failed: ${e.runtimeType}');
    return null;
  }
}
