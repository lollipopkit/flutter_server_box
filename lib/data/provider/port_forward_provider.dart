import 'dart:async';
import 'dart:io';

import 'package:dartssh2/dartssh2.dart';
import 'package:fl_lib/fl_lib.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:server_box/core/diag.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/core/monitor/http.dart';
import 'package:server_box/core/monitor/listener.dart';
import 'package:server_box/core/monitor/tunnel.dart';
import 'package:server_box/core/ssh/local_tunnel.dart';
import 'package:server_box/core/utils/cancel_scope.dart';
import 'package:server_box/core/utils/server_tcp.dart';
import 'package:server_box/data/model/app/menu/server_func.dart';
import 'package:server_box/data/model/server/capabilities.dart';
import 'package:server_box/data/model/server/port_forward.dart';
import 'package:server_box/data/model/server/server_private_info.dart';
import 'package:server_box/data/provider/server/single.dart';
import 'package:server_box/data/provider/server/tcp_dialer.dart';
import 'package:server_box/data/store/stores.dart';

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
    granted: server.agentAccess,
  );
  final unknown =
      ServerCapabilities.forwardsViaAgent(server.spi) && server.agentAccess == null;
  return (
    relay: caps.tcpRelay || unknown,
    listen: caps.remoteListen || unknown,
  );
}

/// Why [server] cannot make a forward of the [listen] kind — see
/// [portForwardKinds] — or null when it can.
///
/// Relay and listen are one answer on an agent ([MonitorAccess.ok]), so the
/// reason is [ServerFuncBtn.unavailableReason]'s for either.
String? portForwardUnavailable(ServerState server, {required bool listen}) {
  final kinds = portForwardKinds(server);
  if (listen ? kinds.listen : kinds.relay) return null;
  return ServerFuncBtn.portForward.unavailableReason(
    server.spi,
    server.agentAccess,
  );
}

@Riverpod(keepAlive: true)
class PortForwardNotifier extends _$PortForwardNotifier {
  final Map<String, _ForwardEntry> _forwards = {};
  final Map<String, CancelScope> _scopes = {};
  final Set<Future<void>> _localTeardowns = {};
  final Map<String, Future<void>> _remoteReclaims = {};
  final Map<String, Object> _stops = {};
  Future<void>? _clearFuture;
  var _clearing = false;

  /// Set once, by [dispose], and never unset.
  var _disposed = false;

  static const _remoteReclaimWait = Duration(seconds: 2);

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
        final active = Map<String, PortForwardStatus>.from(
          state.activeForwards,
        );
        for (final MapEntry(:key, :value) in dropped) {
          _forwards.remove(key);
          active.remove(key);
          final scope = _scopes.remove(key);
          if (scope != null) {
            unawaited(_cancelScope(key, scope));
          } else {
            unawaited(_trackLocalTeardown(value.close(waitRemote: false)));
          }
        }
        state = state.copyWith(activeForwards: active);
      }
    });
    final configs = Stores.portForward.fetchForServer(serverId);
    return PortForwardState(serverId: serverId, configs: configs);
  }

  String get _serverId => state.serverId;

  bool _isCurrent(String id, CancelScope scope) =>
      !_disposed && !_clearing && !scope.isCanceled && identical(_scopes[id], scope);

  void _trackRemoteReclaim(String id, CancelScope scope) {
    final pending = _remoteReclaims[id];
    final remoteDone = scope.remoteDone.catchError((_) {});
    late final Future<void> reclaim;
    reclaim = Future.wait<void>([?pending, remoteDone]).then<void>((_) {
      if (identical(_remoteReclaims[id], reclaim)) _remoteReclaims.remove(id);
    });
    _remoteReclaims[id] = reclaim;
  }

  Future<void> _trackLocalTeardown(Future<void> close) {
    late final Future<void> tracked;
    tracked = close.catchError((_) {}).whenComplete(() {
      _localTeardowns.remove(tracked);
    });
    _localTeardowns.add(tracked);
    return tracked;
  }

  Future<void> _cancelScope(String id, CancelScope scope) {
    _forwards.remove(id);
    // Invoke `cancel` first (synchronously initializes `remoteDone`), register
    // the reclaim immediately so an overlapping `startForward` sees it, then
    // await local teardown.
    final cancel = scope.cancel(waitRemote: false);
    _trackRemoteReclaim(id, scope);
    return _trackLocalTeardown(cancel);
  }

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
    final scopes = _scopes.values.toList();
    _scopes.clear();
    _forwards.clear();
    _remoteReclaims.clear();
    _stops.clear();
    for (final scope in scopes) {
      unawaited(scope.cancel(waitRemote: false));
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
    _stops.clear();
    final entries = _scopes.entries.toList();
    _scopes.clear();
    _forwards.clear();
    try {
      // Cancel every registered scope right away: local listeners and sockets
      // close immediately while remote close handshakes finish in the
      // background.
      await Future.wait([
        ..._localTeardowns,
        for (final MapEntry(:key, :value) in entries) _cancelScope(key, value),
      ]);
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
    if (_disposed || _clearing) return Future.value();
    _stops.remove(id);
    // Register a fresh scope synchronously before the first await so `stop` or
    // `clear` can immediately cancel this start and supersede any prior scope.
    final prior = _scopes[id];
    final scope = CancelScope();
    _scopes[id] = scope;
    return _startForward(id, scope, prior: prior);
  }

  Future<void> _startForward(
    String id,
    CancelScope scope, {
    CancelScope? prior,
  }) async {
    if (prior != null) {
      await _cancelScope(id, prior);
      if (!_isCurrent(id, scope)) return;
    }

    final config = state.configs.firstWhereOrNull((c) => c.id == id);
    if (config == null) {
      Loggers.app.warning('Port forward config not found: $id');
      if (identical(_scopes[id], scope)) _scopes.remove(id);
      return;
    }

    // The kind, not the ports or the host. Which of the three is actually used
    // is the question — dynamic is a SOCKS proxy and a different feature from
    // the other two wearing the same name.
    Diag.crumb(SbDiag.forward, 'start', data: {'type': config.type.name});

    // For an immediate restart of the same remote port, give the previous
    // remote listener a bounded window to release the port on the server,
    // aborting immediately if this new start is itself canceled.
    if (config.type == PortForwardType.remote) {
      final reclaim = _remoteReclaims[id];
      if (reclaim != null) {
        await Future.any([reclaim, scope.onCanceled]).timeout(
          _remoteReclaimWait,
          onTimeout: () {},
        );
        if (!_isCurrent(id, scope)) return;
      }
    }

    try {
      final entry = switch (config.type) {
        PortForwardType.local => await _startLocalForward(config, scope),
        PortForwardType.remote => await _startRemoteForward(config, scope),
        PortForwardType.dynamic => await _startDynamicForward(config, scope),
      };
      if (entry == null) return;
      if (!_isCurrent(id, scope)) {
        await entry.close(waitRemote: false).catchError((_) {});
        return;
      }
      _forwards[config.id] = entry;
      if (config.type == PortForwardType.remote) {
        scope.onLocalDispose(() => entry.close(waitRemote: false));
      }
      // A forward can end from the far side — the agent stopping its listener,
      // its grant taken away — and is no longer active once it has.
      unawaited(
        entry.ended.then((_) async {
          if (!_isCurrent(config.id, scope)) return;
          await entry.close(waitRemote: false).catchError((_) {});
          if (!_isCurrent(config.id, scope)) return;
          _scopes.remove(config.id);
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
      if (!_isCurrent(id, scope)) return;
      _scopes.remove(id);
      unawaited(_cancelScope(id, scope));
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
      _updateStatus(
        id,
        PortForwardStatus(id: id, isActive: false, error: e.toString()),
      );
    }
  }

  bool _viaAgent(ServerState server) => ServerCapabilities.forwardsViaAgent(server.spi);

  /// Before binding, so a forward cannot look active with nothing behind its
  /// listener: what the leading transport can do, and an SSH session where SSH
  /// leads.
  Future<void> _ensureCarried(
    ServerState server, {
    required bool listen,
  }) async {
    final reason = portForwardUnavailable(server, listen: listen);
    if (reason != null) throw PortForwardUnavailable(reason);
    if (server.spi.transport == ServerTransport.ssh) await _connectedClient();
  }

  /// Dials per connection, over the agent alone where it leads — see
  /// [_viaAgent] — and otherwise over SSH, falling back to the agent.
  ServerTcpDialer _dialer(ServerState server) => ref.serverTcpDialer(
    server.spi,
    transports: _viaAgent(server)
        ? const {ServerTransport.monitorHttp}
        : const {...ServerTransport.values},
  );

  Future<_ForwardEntry?> _startLocalForward(
    PortForwardConfig config,
    CancelScope scope,
  ) async {
    if (config.remoteHost == null || config.remotePort == null) {
      throw StateError('A local forward without a destination');
    }
    final server = ref.read(serverProvider(_serverId));
    await _ensureCarried(server, listen: false);
    if (scope.isCanceled) return null;
    // Each connection is dialled as it arrives, as a remote desktop's is —
    // see [ServerTcpDialer].
    final dialer = _dialer(server);
    final entry = await _bindTunnel(
      scope: scope,
      dialer: dialer,
      viaSsh: !_viaAgent(server),
      bind: () => SshLocalTunnel.bindWithDialer(
        bindHost: config.localHost ?? 'localhost',
        bindPort: config.localPort,
        // Nothing to end with: the dialer reconnects per connection, and a
        // dropped SSH session stops the forwards it carried (see [build]).
        sshDone: Completer<void>().future,
        dialer: () => dialer.open(config.remoteHost!, config.remotePort!),
      ),
    );
    if (entry == null || scope.isCanceled) return null;
    final tunnel = entry.tunnel;
    Loggers.app.info(
      'Local port forward started: ${tunnel.address.address}:${tunnel.port} '
      '-> ${config.remoteHost}:${config.remotePort}',
    );
    return entry;
  }

  Future<_ForwardEntry?> _startRemoteForward(
    PortForwardConfig config,
    CancelScope scope,
  ) async {
    if (config.remoteHost == null || config.remotePort == null) {
      throw StateError('A remote forward without a destination');
    }
    final server = ref.read(serverProvider(_serverId));
    await _ensureCarried(server, listen: true);
    if (scope.isCanceled) return null;
    final localHost = config.localHost ?? 'localhost';
    if (_viaAgent(server)) {
      return _startAgentRemoteForward(server, config, localHost, scope);
    }
    final client = await _connectedClient();
    if (scope.isCanceled) return null;
    final setup = client.forwardRemote(
      host: config.remoteHost!,
      port: config.remotePort!,
    ).then((forward) {
      if (forward == null) {
        throw PortForwardUnavailable(l10n.sshTcpForwardingProhibited);
      }
      final entry = _RemoteForwardEntry(
        client: client,
        forward: forward,
        remoteHost: localHost,
        remotePort: config.localPort,
      );
      if (!scope.isCanceled) {
        Loggers.app.info(
          'Remote port forward started: ${config.remoteHost}:${config.remotePort}',
        );
        entry.start();
      }
      return entry;
    });
    // Cancellation may happen before sshd replies. Reserve the reclaim now
    // so a restart waits for both the reply and the cancellation request.
    scope.onRemoteDispose(() async => (await setup).close());
    return setup;
  }

  /// The agent listens on the server; each connection it takes is claimed
  /// over its relay and carried to [localHost] — see [MonitorRemoteListener].
  Future<_ForwardEntry?> _startAgentRemoteForward(
    ServerState server,
    PortForwardConfig config,
    String localHost,
    CancelScope scope,
  ) async {
    final monitor = server.spi.monitorOn;
    if (monitor == null) {
      throw PortForwardUnavailable(l10n.funcUnavailableFmt(libL10n.portForward));
    }
    final lease = MonitorClientLease(monitor);
    final client = lease.client;
    try {
      final opening = client.openListen();
      MonitorRemoteListener? listener;
      scope.onRemoteDispose(() async {
        if (listener case final current?) {
          await current.close();
        } else {
          final socket = await opening;
          await socket.close();
        }
      });
      final socket = await opening;
      if (scope.isCanceled) {
        lease.release();
        return null;
      }
      final started = await MonitorRemoteListener.start(
        socket: socket,
        bindHost: config.remoteHost!,
        bindPort: config.remotePort!,
        claim: (id) => MonitorTunnelChannel.accept(client: client, id: id),
        connectLocal: () => Socket.connect(
          localHost,
          config.localPort,
          timeout: ServerTcpDialer.openTimeout,
        ),
        // Registered synchronously before `listen` is sent so `stop` / `clear`
        // closes locally right away and tracks remote reclamation separately.
        onCreated: (l) {
          listener = l;
          scope.onLocalDispose(() => l.close(waitRemote: false));
        },
      );
      if (scope.isCanceled) {
        await started.close(waitRemote: false).catchError((_) {});
        lease.release();
        return null;
      }
      Loggers.app.info(
        'Remote port forward started through the Monitor: '
        '${config.remoteHost}:${started.port}',
      );
      return _AgentRemoteForwardEntry(started, lease);
    } catch (_) {
      lease.release();
      rethrow;
    }
  }

  /// A SOCKS5 proxy here whose every connection is dialled from the server,
  /// as a local forward's is — see [SshLocalTunnel.bindSocks].
  Future<_ForwardEntry?> _startDynamicForward(
    PortForwardConfig config,
    CancelScope scope,
  ) async {
    final server = ref.read(serverProvider(_serverId));
    await _ensureCarried(server, listen: false);
    if (scope.isCanceled) return null;
    final dialer = _dialer(server);
    final entry = await _bindTunnel(
      scope: scope,
      dialer: dialer,
      viaSsh: !_viaAgent(server),
      bind: () => SshLocalTunnel.bindSocks(
        bindHost: config.localHost ?? 'localhost',
        bindPort: config.localPort,
        sshDone: Completer<void>().future,
        dial: dialer.open,
      ),
    );
    if (entry == null || scope.isCanceled) return null;
    final tunnel = entry.tunnel;
    Loggers.app.info(
      'Dynamic port forward (SOCKS5) started: '
      '${tunnel.address.address}:${tunnel.port}',
    );
    return entry;
  }

  Future<_TunnelForwardEntry?> _bindTunnel({
    required CancelScope scope,
    required ServerTcpDialer dialer,
    required bool viaSsh,
    required Future<SshLocalTunnel> Function() bind,
  }) async {
    // Register only the bind and its handoff, after SSH setup has finished.
    // If canceled during bind, its listener must close before this settles.
    final bound = Completer<void>();
    scope.onLocalDispose(() => bound.future);
    try {
      final tunnel = await bind();
      final entry = _TunnelForwardEntry(tunnel, dialer, viaSsh: viaSsh);
      if (scope.isCanceled) {
        await entry.close(waitRemote: false).catchError((_) {});
        return null;
      }
      scope.onLocalDispose(() => entry.close(waitRemote: false));
      scope.onRemoteDispose(() => entry.close(waitRemote: true));
      return entry;
    } catch (_) {
      dialer.close();
      rethrow;
    } finally {
      bound.complete();
    }
  }

  Future<void> stopForward(String id) async {
    if (_disposed || _clearing) return;
    final stop = _stops[id] = Object();
    final scope = _scopes.remove(id);
    if (scope != null) {
      await _cancelScope(id, scope);
      Loggers.app.info('Port forward stopped: $id');
    } else {
      final entry = _forwards.remove(id);
      if (entry != null) {
        await _trackLocalTeardown(entry.close(waitRemote: false));
        Loggers.app.info('Port forward stopped: $id');
      }
    }
    if (!identical(_stops[id], stop)) return;
    _stops.remove(id);
    if (_disposed || _clearing || _scopes.containsKey(id)) return;
    _updateStatus(id, PortForwardStatus(id: id, isActive: false));
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
  Future<void> close({bool waitRemote = true});

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
  Future<void> close({bool waitRemote = true}) async {
    await tunnel.close(waitRemote: waitRemote);
    dialer.close();
  }
}

class _AgentRemoteForwardEntry extends _ForwardEntry {
  _AgentRemoteForwardEntry(this.listener, this.lease);

  final MonitorRemoteListener listener;

  /// The server's shared client, held while the forward runs.
  final MonitorClientLease lease;

  @override
  bool get viaSsh => false;

  @override
  Future<void> get ended => listener.done;

  @override
  Future<void> close({bool waitRemote = true}) async {
    try {
      await listener.close(waitRemote: waitRemote);
    } finally {
      lease.release();
    }
  }
}

class _RemoteForwardEntry extends _ForwardEntry {
  @override
  bool get viaSsh => true;

  final SSHClient client;
  final SSHRemoteForward forward;
  final String remoteHost;
  final int remotePort;
  final List<_ActiveConnection> _connections = [];
  StreamSubscription<SSHForwardChannel>? _subscription;
  Future<void>? _localClose;
  Future<void>? _remoteClose;
  var _closed = false;

  _RemoteForwardEntry({
    required this.client,
    required this.forward,
    required this.remoteHost,
    required this.remotePort,
  });

  void start() {
    _subscription = forward.connections.listen((channel) async {
      if (_closed) {
        unawaited(channel.close().catchError((_) {}));
        return;
      }
      try {
        final socket = await Socket.connect(remoteHost, remotePort);
        if (_closed) {
          socket.destroy();
          unawaited(channel.close().catchError((_) {}));
          return;
        }
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
  Future<void> close({bool waitRemote = true}) async {
    await (_localClose ??= _close());
    if (waitRemote) await _remoteClose;
  }

  Future<void> _close() async {
    _closed = true;
    final subscription = _subscription?.cancel();
    final connections = _connections.toList();
    _connections.clear();
    _remoteClose = Future.wait<void>([
      _cancelListener(),
      for (final conn in connections) conn.close(),
    ]).then<void>((_) {}, onError: (Object _) {});
    await subscription;
  }

  Future<void> _cancelListener() async {
    try {
      // dartssh2's close() fires the request without awaiting the reply.
      await client.cancelForwardRemote(forward);
    } catch (_) {
      // The SSH session may have dropped already.
    } finally {
      // Cancel removed the handle from the client, so close only its stream.
      forward.close();
    }
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

/// Why a forward could not start, in the user's words.
final class PortForwardUnavailable implements Exception {
  const PortForwardUnavailable(this.message);

  final String message;

  @override
  String toString() => message;
}
