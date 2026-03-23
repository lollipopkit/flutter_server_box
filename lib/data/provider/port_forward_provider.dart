import 'dart:async';
import 'dart:io';

import 'package:dartssh2/dartssh2.dart';
import 'package:fl_lib/fl_lib.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:server_box/data/model/server/port_forward.dart';
import 'package:server_box/data/model/server/server_private_info.dart';
import 'package:server_box/data/provider/server/single.dart';
import 'package:server_box/data/res/store.dart';

part 'port_forward_provider.g.dart';

@Riverpod(keepAlive: true)
class PortForwardNotifier extends _$PortForwardNotifier {
  final Map<String, _LocalForwardEntry> _forwards = {};
  late final String _serverId;

  @override
  PortForwardState build(Spi spiParam) {
    _serverId = spiParam.id;
    ref.onDispose(() => dispose());
    final configs = Stores.portForward.fetch(_serverId);
    return PortForwardState(configs: configs);
  }

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
    final config = state.configs.firstWhereOrNull((c) => c.id == id);
    if (config == null) {
      Loggers.app.warning('Port forward config not found: $id');
      return;
    }

    try {
      final serverSocket = await ServerSocket.bind(config.localHost, config.localPort);

      Loggers.app.info('Port forward started: ${config.localHost}:${config.localPort} -> ${config.remoteHost}:${config.remotePort}');

      final entry = _LocalForwardEntry(serverSocket: serverSocket);
      entry.start(config.remoteHost, config.remotePort, () => _client);
      _forwards[id] = entry;

      _updateStatus(id, PortForwardStatus(id: id, isActive: true));
    } catch (e) {
      Loggers.app.warning('Port forward failed to start: $e');
      _updateStatus(id, PortForwardStatus(id: id, isActive: false, error: e.toString()));
    }
  }

  Future<void> stopForward(String id) async {
    final entry = _forwards.remove(id);
    if (entry != null) {
      await entry.close();
      Loggers.app.info('Port forward stopped: $id');
    }
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
    final activeForwards = Map<String, PortForwardStatus>.from(state.activeForwards);
    activeForwards[id] = status;
    state = state.copyWith(activeForwards: activeForwards);
  }
}

class _LocalForwardEntry {
  final ServerSocket serverSocket;
  final List<_ActiveConnection> _connections = [];
  StreamSubscription<Socket>? _subscription;

  _LocalForwardEntry({required this.serverSocket});

  void start(String remoteHost, int remotePort, SSHClient Function() clientGetter) {
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

  Future<void> close() async {
    await _subscription?.cancel();
    await serverSocket.close();
    for (final conn in _connections) {
      await conn.close();
    }
    _connections.clear();
  }
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
