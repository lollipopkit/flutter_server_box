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

  @override
  PortForwardState build(String serverId) {
    ref.onDispose(() => dispose());
    ref.listen(serverProvider(serverId), (prev, next) {
      if (next.client == null && prev?.client != null) {
        for (final entry in _forwards.values) {
          entry.close().catchError((_) {});
        }
        _forwards.clear();
        state = state.copyWith(activeForwards: {});
      }
    });
    final configs = Stores.portForward.fetch(serverId);
    return PortForwardState(serverId: serverId, configs: configs);
  }

  String get _serverId => state.serverId;

  SSHClient get _client {
    final serverState = ref.read(serverProvider(_serverId));
    final client = serverState.client;
    if (client == null) {
      throw StateError('SSH client is not connected');
    }
    return client;
  }

  void dispose() {
    for (final entry in _forwards.values) {
      entry.close().catchError((_) {});
    }
    _forwards.clear();
  }

  Future<void> addConfig(PortForwardConfig config) async {
    final configWithServerId = config.copyWith(serverId: _serverId);
    Stores.portForward.put(configWithServerId);
    final configs = [...state.configs, configWithServerId];
    state = state.copyWith(configs: configs);
  }

  Future<void> updateConfig(PortForwardConfig oldConfig, PortForwardConfig newConfig) async {
    await stopForward(oldConfig.id);
    final configWithServerId = newConfig.copyWith(serverId: _serverId);
    Stores.portForward.update(oldConfig, configWithServerId);
    final configs = state.configs.map((c) => c.id == oldConfig.id ? configWithServerId : c).toList();
    state = state.copyWith(configs: configs);
  }

  Future<void> removeConfig(String id) async {
    await stopForward(id);
    final config = state.configs.firstWhereOrNull((c) => c.id == id);
    if (config != null) {
      Stores.portForward.delete(config);
    }
    final configs = state.configs.where((c) => c.id != id).toList();
    final activeForwards = Map<String, PortForwardStatus>.from(state.activeForwards)..remove(id);
    state = state.copyWith(configs: configs, activeForwards: activeForwards);
  }

  Future<void> startForward(String id) async {
    if (!_inFlight.add(id)) return;
    try {
      final config = state.configs.firstWhereOrNull((c) => c.id == id);
      if (config == null) {
        Loggers.app.warning('Port forward config not found: $id');
        return;
      }

      final existing = _forwards[id];
      if (existing != null) {
        await existing.close().catchError((_) {});
        _forwards.remove(id);
      }

      try {
        switch (config.type) {
          case PortForwardType.local:
            await _startLocalForward(config);
          case PortForwardType.remote:
            await _startRemoteForward(config);
          case PortForwardType.dynamic:
            await _startDynamicForward(config);
        }
      } catch (e) {
        Loggers.app.warning('Port forward failed to start: $e');
        _updateStatus(id, PortForwardStatus(id: id, isActive: false, error: e.toString()));
      }
    } finally {
      _inFlight.remove(id);
    }
  }

  Future<void> _startLocalForward(PortForwardConfig config) async {
    if (config.remoteHost == null || config.remotePort == null) {
      throw Exception('Invalid local port forward: remote destination not set');
    }
    final serverSocket = await ServerSocket.bind(config.localHost ?? 'localhost', config.localPort);
    Loggers.app.info('Local port forward started: ${config.localHost ?? "localhost"}:${config.localPort} -> ${config.remoteHost}:${config.remotePort}');
    final entry = _LocalForwardEntry(
      serverSocket: serverSocket,
      remoteHost: config.remoteHost!,
      remotePort: config.remotePort!,
      clientGetter: () => _client,
    );
    entry.start();
    _forwards[config.id] = entry;
    _updateStatus(config.id, PortForwardStatus(id: config.id, isActive: true));
  }

  Future<void> _startRemoteForward(PortForwardConfig config) async {
    if (config.remoteHost == null || config.remotePort == null) {
      throw Exception('Invalid remote port forward: remote destination not set');
    }
    final forward = await _client.forwardRemote(
      host: config.remoteHost!,
      port: config.remotePort!,
    );
    if (forward == null) {
      throw Exception('Failed to start remote port forward: server rejected');
    }
    Loggers.app.info('Remote port forward started: ${config.remoteHost}:${config.remotePort}');
    final entry = _RemoteForwardEntry(forward: forward);
    _forwards[config.id] = entry;
    _updateStatus(config.id, PortForwardStatus(id: config.id, isActive: true));
  }

  Future<void> _startDynamicForward(PortForwardConfig config) async {
    final dynamicForward = await _client.forwardDynamic(
      bindHost: config.localHost ?? 'localhost',
      bindPort: config.localPort,
    );
    Loggers.app.info('Dynamic port forward (SOCKS5) started: ${config.localHost}:${config.localPort}');
    final entry = _DynamicForwardEntry(dynamicForward: dynamicForward);
    _forwards[config.id] = entry;
    _updateStatus(config.id, PortForwardStatus(id: config.id, isActive: true));
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
    final activeForwards = Map<String, PortForwardStatus>.from(state.activeForwards);
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
        final forward = await clientGetter().forwardLocal(remoteHost, remotePort);
        final conn = _ActiveConnection(socket: socket, forward: forward);
        _connections.add(conn);
        final pipe1 = forward.stream.cast<List<int>>().pipe(socket).catchError((_) {});
        final pipe2 = socket.cast<List<int>>().pipe(forward.sink).catchError((_) {});
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

  _RemoteForwardEntry({required this.forward});

  @override
  Future<void> close() async => forward.close();
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

  _ActiveConnection({
    required this.socket,
    required this.forward,
  });

  Future<void> close() async {
    try {
      socket.destroy();
    } catch (_) {}
    try {
      await forward.close();
    } catch (_) {}
  }
}