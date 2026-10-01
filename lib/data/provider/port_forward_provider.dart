import 'dart:async';
import 'dart:io';

import 'package:dartssh2/dartssh2.dart';
import 'package:fl_lib/fl_lib.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:server_box/core/diag.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/core/utils/monitor_listener.dart';
import 'package:server_box/core/utils/monitor_tunnel.dart';
import 'package:server_box/core/utils/server_tcp.dart';
import 'package:server_box/core/utils/ssh_local_tunnel.dart';
import 'package:server_box/data/model/app/menu/server_func.dart';
import 'package:server_box/data/model/server/capabilities.dart';
import 'package:server_box/data/model/server/port_forward.dart';
import 'package:server_box/data/model/server/server_private_info.dart';
import 'package:server_box/data/provider/server/monitor_http.dart';
import 'package:server_box/data/provider/server/single.dart';
import 'package:server_box/data/res/store.dart';

part 'port_forward_provider.g.dart';

/// Which forwards [server] can make: [relay] a local or dynamic one, a
/// connection dialled from the server per connection; [listen] a remote one,
/// the server listening.
///
/// Asked of [ServerCapabilities.forwardsOf], so an agent-led server answers
/// with its agent alone. An agent that has not answered yet is given the
/// benefit of the doubt: it refuses for itself, and a forward started before
/// the first poll should not fail on an answer nobody has heard.
({bool relay, bool listen}) portForwardKinds(ServerState server) {
  final caps = ServerCapabilities.forwardsOf(
    server.spi,
    granted: server.remoteAccess,
  );
  final unknown =
      server.spi.transport == ServerTransport.monitorHttp &&
      server.remoteAccess == null;
  return (
    relay: caps.tcpRelay || unknown,
    listen: caps.remoteListen || unknown,
  );
}

/// Why [server] cannot make a forward of the [listen] kind — see
/// [portForwardKinds] — or null when it can.
///
/// An agent that has not granted `full_access` cannot carry any forward and
/// is told so, as [ServerFuncBtn.unavailableReason] does; one that has, and
/// relays but cannot listen, predates the listener and needs updating.
String? portForwardUnavailable(ServerState server, {required bool listen}) {
  final kinds = portForwardKinds(server);
  if (listen ? kinds.listen : kinds.relay) return null;
  final granted = server.remoteAccess;
  final grants = server.spi.transport == ServerTransport.monitorHttp
      ? granted?.grants
      : null;
  if (grants != null) {
    return monitorGrantReason(
          libL10n.portForward,
          listen ? grants.listen : grants.connect,
        ) ??
        l10n.funcUnavailableFmt(libL10n.portForward);
  }
  if (listen &&
      server.spi.transport == ServerTransport.monitorHttp &&
      granted != null &&
      granted.fullAccess &&
      granted.stream) {
    return l10n.portForwardRemoteNeedsAgent;
  }
  return ServerFuncBtn.portForward.unavailableReason(server.spi, granted);
}

@Riverpod(keepAlive: true)
class PortForwardNotifier extends _$PortForwardNotifier {
  final Map<String, _ForwardEntry> _forwards = {};
  final Set<String> _inFlight = {};
  final Map<String, Future<void>> _starts = {};
  Future<void>? _clearFuture;
  var _generation = 0;
  var _clearing = false;

  /// Set once, by [dispose], and never unset.
  ///
  /// Kept apart from [_clearing] because the two have different lifetimes and
  /// used to share a field: `delServer` awaits `clear()`, which awaits every
  /// entry closing, and the notifier can be torn down inside that window. The
  /// `finally` that ends a clear then wiped the flag `dispose` had just set,
  /// and a later `startForward` walked through the guard onto a disposed
  /// notifier and threw reading `state`.
  var _disposed = false;

  @override
  PortForwardState build(String serverId) {
    ref.onDispose(() => dispose());
    ref.listen(serverProvider(serverId), (prev, next) {
      if (next.client == null && prev?.client != null) {
        // Only what SSH carried. A forward through the agent never used the
        // session, and went down with it all the same.
        final dropped = _forwards.entries
            .where((e) => e.value.viaSsh)
            .toList();
        if (dropped.isEmpty) return;
        _generation++;
        final active = Map<String, PortForwardStatus>.from(
          state.activeForwards,
        );
        for (final MapEntry(:key, :value) in dropped) {
          _forwards.remove(key);
          active.remove(key);
          value.close().catchError((_) {});
        }
        state = state.copyWith(activeForwards: active);
      }
    });
    final configs = Stores.portForward.fetchForServer(serverId);
    return PortForwardState(serverId: serverId, configs: configs);
  }

  String get _serverId => state.serverId;

  /// Connects the shell if it isn't already, then returns the client.
  ///
  /// A server reached through its monitor agent opens SSH lazily, so starting
  /// a forward is one of the things that has to bring the connection up
  /// rather than assume it.
  Future<SSHClient> _connectedClient() =>
      ref.read(serverProvider(_serverId).notifier).ensureShellClient();

  void dispose() {
    // Permanent, and not [_clearing]: a clear running underneath ends with a
    // `finally` that puts that flag back.
    _disposed = true;
    _generation++;
    final forwards = _forwards.values.toList();
    _forwards.clear();
    for (final entry in forwards) {
      entry.close().catchError((_) {});
    }
  }

  /// Stops every live listener before removing the saved configurations.
  ///
  /// Server deletion calls this explicitly. Waiting for the SSH client to
  /// disconnect leaves local, remote, or SOCKS forwards reachable after their
  /// server has disappeared from the app.
  Future<void> clear() {
    final existing = _clearFuture;
    if (existing != null) return existing;

    late final Future<void> clear;
    clear = _clear().whenComplete(() {
      if (identical(_clearFuture, clear)) _clearFuture = null;
    });
    _clearFuture = clear;
    return clear;
  }

  Future<void> _clear() async {
    _clearing = true;
    _generation++;
    final forwards = _forwards.values.toList();
    _forwards.clear();
    for (final entry in forwards) {
      await entry.close().catchError((_) {});
    }
    try {
      // A start may be awaiting SSH or a listener bind. It owns any entry it
      // creates while cleanup is active and closes it before completing.
      await Future.wait(
        _starts.values.map((start) => start.catchError((_) {})).toList(),
      );
      if (!ref.mounted) return;
      Stores.portForward.clearServer(_serverId);
      state = state.copyWith(configs: const [], activeForwards: {});
    } finally {
      _clearing = false;
    }
  }

  Future<void> addConfig(PortForwardConfig config) async {
    final configWithServerId = config.copyWith(serverId: _serverId);
    Stores.portForward.put(configWithServerId);
    final configs = [...state.configs, configWithServerId];
    state = state.copyWith(configs: configs);
  }

  Future<void> updateConfig(
    PortForwardConfig oldConfig,
    PortForwardConfig newConfig,
  ) async {
    await stopForward(oldConfig.id);
    final configWithServerId = newConfig.copyWith(serverId: _serverId);
    Stores.portForward.delete(oldConfig);
    Stores.portForward.put(configWithServerId);
    final configs = state.configs
        .map((c) => c.id == oldConfig.id ? configWithServerId : c)
        .toList();
    state = state.copyWith(configs: configs);
  }

  Future<void> removeConfig(String id) async {
    await stopForward(id);
    final config = state.configs.firstWhereOrNull((c) => c.id == id);
    if (config != null) {
      Stores.portForward.delete(config);
    }
    final configs = state.configs.where((c) => c.id != id).toList();
    final activeForwards = Map<String, PortForwardStatus>.from(
      state.activeForwards,
    )..remove(id);
    state = state.copyWith(configs: configs, activeForwards: activeForwards);
  }

  Future<void> startForward(String id) {
    if (_disposed || _clearing || !_inFlight.add(id)) return Future.value();
    final generation = _generation;
    late final Future<void> start;
    start = _startForward(id, generation).whenComplete(() {
      _inFlight.remove(id);
      if (identical(_starts[id], start)) _starts.remove(id);
    });
    _starts[id] = start;
    return start;
  }

  Future<void> _startForward(String id, int generation) async {
    final config = state.configs.firstWhereOrNull((c) => c.id == id);
    if (config == null) {
      Loggers.app.warning('Port forward config not found: $id');
      return;
    }

    // The kind, not the ports or the host. Which of the three is actually used
    // is the question — dynamic is a SOCKS proxy and a different feature from
    // the other two wearing the same name.
    Diag.crumb(SbDiag.forward, 'start', data: {'type': config.type.name});

    final existing = _forwards[id];
    if (existing != null) {
      _forwards.remove(id);
      await existing.close().catchError((_) {});
    }

    try {
      final entry = switch (config.type) {
        PortForwardType.local => await _startLocalForward(config),
        PortForwardType.remote => await _startRemoteForward(config),
        PortForwardType.dynamic => await _startDynamicForward(config),
      };
      if (_disposed || _clearing || generation != _generation) {
        await entry.close().catchError((_) {});
        return;
      }
      _forwards[config.id] = entry;
      // A forward can end from the far side — the agent stopping its listener,
      // its grant taken away — and is no longer active once it has.
      unawaited(
        entry.ended.then((_) {
          if (_disposed || !identical(_forwards[config.id], entry)) return;
          _forwards.remove(config.id);
          _updateStatus(
            config.id,
            PortForwardStatus(id: config.id, isActive: false),
          );
        }),
      );
      _updateStatus(
        config.id,
        PortForwardStatus(id: config.id, isActive: true),
      );
      Diag.crumb(SbDiag.forward, 'start ok', data: {'type': config.type.name});
    } catch (e) {
      // A local forward binds a port on this device and a remote one asks the
      // server to, which fails for reasons the other cannot have — an address
      // already in use here, against a sshd that refuses to listen.
      Diag.crumb(
        SbDiag.forward,
        'start failed',
        level: DiagLevel.warning,
        data: {'type': config.type.name, 'error': Redact.error(e)},
      );
      Loggers.app.warning('Port forward failed to start: $e');
      if (!_disposed && !_clearing && generation == _generation) {
        _updateStatus(
          id,
          PortForwardStatus(id: id, isActive: false, error: e.toString()),
        );
      }
    }
  }

  /// Whether this server's forwards go through its agent alone: when the
  /// agent leads, a forward never touches SSH — no session opened first, no
  /// falling back to sshd when the agent refuses.
  bool _viaAgent(ServerState server) =>
      server.spi.transport == ServerTransport.monitorHttp;

  /// Before binding, so a forward cannot look active with nothing behind its
  /// listener: what the leading transport can do, and an SSH session where SSH
  /// leads.
  Future<void> _ensureCarried(
    ServerState server, {
    required bool listen,
  }) async {
    final reason = portForwardUnavailable(server, listen: listen);
    if (reason != null) throw Exception(reason);
    if (server.spi.transport == ServerTransport.ssh) await _connectedClient();
  }

  /// Dials per connection, over the agent alone where it leads — see
  /// [_viaAgent] — and otherwise over SSH, falling back to the agent.
  ServerTcpDialer _dialer(ServerState server) => ServerTcpDialer.of(
    ref,
    server.spi,
    transports: _viaAgent(server)
        ? const {ServerTransport.monitorHttp}
        : const {...ServerTransport.values},
  );

  Future<_ForwardEntry> _startLocalForward(PortForwardConfig config) async {
    if (config.remoteHost == null || config.remotePort == null) {
      throw Exception('Invalid local port forward: remote destination not set');
    }
    final server = ref.read(serverProvider(_serverId));
    await _ensureCarried(server, listen: false);
    // Each connection is dialled as it arrives, as a remote desktop's is —
    // see [ServerTcpDialer].
    final dialer = _dialer(server);
    final SshLocalTunnel tunnel;
    try {
      tunnel = await SshLocalTunnel.bindWithDialer(
        bindHost: config.localHost ?? 'localhost',
        bindPort: config.localPort,
        // Nothing to end with: the dialer reconnects per connection, and a
        // dropped SSH session stops the forwards it carried (see [build]).
        sshDone: Completer<void>().future,
        dialer: () => dialer.open(config.remoteHost!, config.remotePort!),
      );
    } catch (_) {
      dialer.close();
      rethrow;
    }
    Loggers.app.info(
      'Local port forward started: ${tunnel.address.address}:${tunnel.port} '
      '-> ${config.remoteHost}:${config.remotePort}',
    );
    return _TunnelForwardEntry(tunnel, dialer, viaSsh: !_viaAgent(server));
  }

  Future<_ForwardEntry> _startRemoteForward(PortForwardConfig config) async {
    if (config.remoteHost == null || config.remotePort == null) {
      throw Exception(
        'Invalid remote port forward: remote destination not set',
      );
    }
    final server = ref.read(serverProvider(_serverId));
    await _ensureCarried(server, listen: true);
    final localHost = config.localHost ?? 'localhost';
    if (_viaAgent(server)) {
      return _startAgentRemoteForward(server, config, localHost);
    }
    final forward = await (await _connectedClient()).forwardRemote(
      host: config.remoteHost!,
      port: config.remotePort!,
    );
    if (forward == null) {
      throw Exception('Failed to start remote port forward: server rejected');
    }
    Loggers.app.info(
      'Remote port forward started: ${config.remoteHost}:${config.remotePort}',
    );
    final entry = _RemoteForwardEntry(
      forward: forward,
      remoteHost: localHost,
      remotePort: config.localPort,
    );
    entry.start();
    return entry;
  }

  /// The agent listens on the server; each connection it takes is claimed
  /// over its relay and carried to [localHost] — see [MonitorRemoteListener].
  Future<_ForwardEntry> _startAgentRemoteForward(
    ServerState server,
    PortForwardConfig config,
    String localHost,
  ) async {
    final monitor = server.spi.monitorOn;
    if (monitor == null) {
      throw Exception(l10n.funcUnavailableFmt(libL10n.portForward));
    }
    final client = MonitorHttpClient(monitor);
    try {
      final listener = await MonitorRemoteListener.start(
        socket: await client.openListen(),
        bindHost: config.remoteHost!,
        bindPort: config.remotePort!,
        claim: (id) => MonitorTunnelChannel.accept(client: client, id: id),
        connectLocal: () => Socket.connect(
          localHost,
          config.localPort,
          timeout: ServerTcpDialer.openTimeout,
        ),
      );
      Loggers.app.info(
        'Remote port forward started through the agent: '
        '${config.remoteHost}:${listener.port}',
      );
      return _AgentRemoteForwardEntry(listener, client);
    } catch (_) {
      client.dispose();
      rethrow;
    }
  }

  /// A SOCKS5 proxy here whose every connection is dialled from the server,
  /// as a local forward's is — see [SshLocalTunnel.bindSocks].
  Future<_ForwardEntry> _startDynamicForward(PortForwardConfig config) async {
    final server = ref.read(serverProvider(_serverId));
    await _ensureCarried(server, listen: false);
    final dialer = _dialer(server);
    final SshLocalTunnel tunnel;
    try {
      tunnel = await SshLocalTunnel.bindSocks(
        bindHost: config.localHost ?? 'localhost',
        bindPort: config.localPort,
        sshDone: Completer<void>().future,
        dial: dialer.open,
      );
    } catch (_) {
      dialer.close();
      rethrow;
    }
    Loggers.app.info(
      'Dynamic port forward (SOCKS5) started: '
      '${tunnel.address.address}:${tunnel.port}',
    );
    return _TunnelForwardEntry(tunnel, dialer, viaSsh: !_viaAgent(server));
  }

  Future<void> stopForward(String id) async {
    if (!_inFlight.add(id)) return;
    try {
      final entry = _forwards[id];
      if (entry != null) {
        await entry.close().catchError((_) {});
        _forwards.remove(id);
        Loggers.app.info('Port forward stopped: $id');
      }
      // `close` is awaited, and `dispose` can run underneath it. Every other
      // path here already checks; this one wrote to a disposed notifier.
      if (_disposed) return;
      _updateStatus(id, PortForwardStatus(id: id, isActive: false));
    } finally {
      _inFlight.remove(id);
    }
  }

  Future<void> toggleForward(String id) async {
    final isActive = state.activeForwards[id]?.isActive ?? false;
    if (isActive) {
      await stopForward(id);
    } else {
      await startForward(id);
    }
  }

  void _updateStatus(String id, PortForwardStatus status) {
    final activeForwards = Map<String, PortForwardStatus>.from(
      state.activeForwards,
    );
    activeForwards[id] = status;
    state = state.copyWith(activeForwards: activeForwards);
  }
}

abstract class _ForwardEntry {
  Future<void> close();

  /// Whether an SSH session carries it, so that losing the session ends it —
  /// see [PortForwardNotifier.build].
  bool get viaSsh;

  /// Completes when it has ended from the far side. Never, for one that only
  /// ends when it is closed here.
  Future<void> get ended => Completer<void>().future;
}

/// A local listener whose connections are dialled from the server: a local
/// forward to one address, or a dynamic one to whatever each names.
class _TunnelForwardEntry extends _ForwardEntry {
  _TunnelForwardEntry(this.tunnel, this.dialer, {required this.viaSsh});

  final SshLocalTunnel tunnel;
  final ServerTcpDialer dialer;

  @override
  final bool viaSsh;

  @override
  Future<void> close() async {
    await tunnel.close();
    dialer.close();
  }
}

class _AgentRemoteForwardEntry extends _ForwardEntry {
  _AgentRemoteForwardEntry(this.listener, this.client);

  final MonitorRemoteListener listener;
  final MonitorHttpClient client;

  @override
  bool get viaSsh => false;

  @override
  Future<void> get ended => listener.done;

  @override
  Future<void> close() async {
    await listener.close();
    client.dispose();
  }
}

class _RemoteForwardEntry extends _ForwardEntry {
  @override
  bool get viaSsh => true;

  final SSHRemoteForward forward;
  final String remoteHost;
  final int remotePort;
  final List<_ActiveConnection> _connections = [];
  StreamSubscription<SSHForwardChannel>? _subscription;

  _RemoteForwardEntry({
    required this.forward,
    required this.remoteHost,
    required this.remotePort,
  });

  void start() {
    _subscription = forward.connections.listen((channel) async {
      try {
        final socket = await Socket.connect(remoteHost, remotePort);
        final conn = _ActiveConnection(socket: socket, forward: channel);
        _connections.add(conn);
        final pipe1 = channel.stream
            .cast<List<int>>()
            .pipe(socket)
            .catchError((_) {});
        final pipe2 = socket
            .cast<List<int>>()
            .pipe(channel.sink)
            .catchError((_) {});
        unawaited(
          Future.wait([pipe1, pipe2]).whenComplete(() {
            _connections.remove(conn);
            return conn.close();
          }),
        );
      } catch (e, s) {
        Loggers.app.warning('Remote forward connection failed', e, s);
        unawaited(channel.close().catchError((_) {}));
      }
    });
  }

  @override
  Future<void> close() async {
    await _subscription?.cancel();
    final connections = _connections.toList();
    for (final conn in connections) {
      await conn.close().catchError((_) {});
    }
    _connections.clear();
    try {
      await Future.microtask(() => forward.close());
    } catch (_) {}
  }
}

class _ActiveConnection {
  final Socket socket;
  final SSHForwardChannel forward;

  _ActiveConnection({required this.socket, required this.forward});

  Future<void> close() async {
    try {
      socket.destroy();
    } catch (_) {}
    try {
      await forward.close();
    } catch (_) {}
  }
}
