import 'dart:async';
import 'dart:io';

import 'package:dartssh2/dartssh2.dart';
import 'package:fl_lib/fl_lib.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:server_box/data/model/server/port_forward.dart';
import 'package:server_box/data/provider/server/single.dart';
import 'package:server_box/data/res/store.dart';

part 'port_forward_provider.g.dart';

@Riverpod(keepAlive: true)
class PortForwardNotifier extends _$PortForwardNotifier {
  final Map<String, _ForwardEntry> _forwards = {};
  final Set<String> _inFlight = {};
  final Map<String, Future<void>> _starts = {};
  Future<void>? _clearFuture;
  var _generation = 0;
  var _clearing = false;

  @override
  PortForwardState build(String serverId) {
    ref.onDispose(() => dispose());
    ref.listen(serverProvider(serverId), (prev, next) {
      if (next.client == null && prev?.client != null) {
        final forwards = _forwards.values.toList();
        _forwards.clear();
        for (final entry in forwards) {
          entry.close().catchError((_) {});
        }
        state = state.copyWith(activeForwards: {});
      }
    });
    final configs = Stores.portForward.fetchForServer(serverId);
    return PortForwardState(serverId: serverId, configs: configs);
  }

  String get _serverId => state.serverId;

  /// The connected client, without waiting for one.
  ///
  /// Used where a forward is already running and needs the live client per
  /// connection; [_connectedClient] is the one to call when starting a
  /// forward, since a monitor-backed server may not have connected yet.
  SSHClient get _client {
    final serverState = ref.read(serverProvider(_serverId));
    final client = serverState.client;
    if (client == null) {
      throw StateError('SSH client is not connected');
    }
    return client;
  }

  /// Connects the shell if it isn't already, then returns the client.
  ///
  /// A server reached through its monitor agent opens SSH lazily, so starting
  /// a forward is one of the things that has to bring the connection up
  /// rather than assume it.
  Future<SSHClient> _connectedClient() =>
      ref.read(serverProvider(_serverId).notifier).ensureShellClient();

  void dispose() {
    _clearing = true;
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
      await Future.wait(_starts.values.toList());
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
    if (_clearing || !_inFlight.add(id)) return Future.value();
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
      if (_clearing || generation != _generation) {
        await entry.close().catchError((_) {});
        return;
      }
      _forwards[config.id] = entry;
      _updateStatus(
        config.id,
        PortForwardStatus(id: config.id, isActive: true),
      );
    } catch (e) {
      Loggers.app.warning('Port forward failed to start: $e');
      if (!_clearing && generation == _generation) {
        _updateStatus(
          id,
          PortForwardStatus(id: id, isActive: false, error: e.toString()),
        );
      }
    }
  }

  Future<_ForwardEntry> _startLocalForward(PortForwardConfig config) async {
    if (config.remoteHost == null || config.remotePort == null) {
      throw Exception('Invalid local port forward: remote destination not set');
    }
    // Connect before binding: the listener accepts connections lazily and
    // resolves the client per connection, so without this a forward would
    // appear to start on a server SSH can't reach and only fail later, once
    // something connected to the local port.
    await _connectedClient();
    final serverSocket = await ServerSocket.bind(
      config.localHost ?? 'localhost',
      config.localPort,
    );
    Loggers.app.info(
      'Local port forward started: ${config.localHost ?? "localhost"}:${config.localPort} -> ${config.remoteHost}:${config.remotePort}',
    );
    final entry = _LocalForwardEntry(
      serverSocket: serverSocket,
      remoteHost: config.remoteHost!,
      remotePort: config.remotePort!,
      clientGetter: () => _client,
    );
    entry.start();
    return entry;
  }

  Future<_ForwardEntry> _startRemoteForward(PortForwardConfig config) async {
    if (config.remoteHost == null || config.remotePort == null) {
      throw Exception(
        'Invalid remote port forward: remote destination not set',
      );
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
      remoteHost: config.localHost ?? 'localhost',
      remotePort: config.localPort,
    );
    entry.start();
    return entry;
  }

  Future<_ForwardEntry> _startDynamicForward(PortForwardConfig config) async {
    final bindHost = config.localHost ?? 'localhost';
    final dynamicForward = await (await _connectedClient()).forwardDynamic(
      bindHost: bindHost,
      bindPort: config.localPort,
    );
    Loggers.app.info(
      'Dynamic port forward (SOCKS5) started: $bindHost:${config.localPort}',
    );
    return _DynamicForwardEntry(dynamicForward: dynamicForward);
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
}

class _LocalForwardEntry extends _ForwardEntry {
  final ServerSocket serverSocket;
  final String remoteHost;
  final int remotePort;
  final SSHClient Function() clientGetter;
  final List<_ActiveConnection> _connections = [];
  StreamSubscription<Socket>? _subscription;

  _LocalForwardEntry({
    required this.serverSocket,
    required this.remoteHost,
    required this.remotePort,
    required this.clientGetter,
  });

  void start() {
    _subscription = serverSocket.listen((socket) async {
      try {
        final forward = await clientGetter().forwardLocal(
          remoteHost,
          remotePort,
        );
        final conn = _ActiveConnection(socket: socket, forward: forward);
        _connections.add(conn);
        final pipe1 = forward.stream
            .cast<List<int>>()
            .pipe(socket)
            .catchError((_) {});
        final pipe2 = socket
            .cast<List<int>>()
            .pipe(forward.sink)
            .catchError((_) {});
        Future.wait([pipe1, pipe2]).whenComplete(() {
          _connections.remove(conn);
          conn.close();
        });
      } catch (e, s) {
        Loggers.app.warning('Port forward connection failed', e, s);
        socket.destroy();
      }
    });
  }

  @override
  Future<void> close() async {
    await _subscription?.cancel();
    await serverSocket.close();
    final connections = _connections.toList();
    for (final conn in connections) {
      await conn.close();
    }
    _connections.clear();
  }
}

class _RemoteForwardEntry extends _ForwardEntry {
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
        Future.wait([pipe1, pipe2]).whenComplete(() {
          _connections.remove(conn);
          conn.close();
        });
      } catch (e, s) {
        Loggers.app.warning('Remote forward connection failed', e, s);
        channel.close();
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

class _DynamicForwardEntry extends _ForwardEntry {
  final SSHDynamicForward dynamicForward;

  _DynamicForwardEntry({required this.dynamicForward});

  @override
  Future<void> close() => dynamicForward.close();
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
