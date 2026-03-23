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

@riverpod
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
      entry.close();
    }
    _forwards.clear();
  }

  Future<void> addConfig(PortForwardConfig config) async {
    final configWithServerId = config.copyWith(serverId: _serverId);
    Stores.portForward.put(configWithServerId);
    final configs = [...state.configs, configWithServerId];
    state = state.copyWith(configs: configs);
  }

  Future<void> removeConfig(String id) async {
    await stopForward(id);
    Stores.portForward.delete(state.configs.firstWhere((c) => c.id == id));
    final configs = state.configs.where((c) => c.id != id).toList();
    final activeForwards = Map<String, PortForwardStatus>.from(state.activeForwards)..remove(id);
    state = state.copyWith(configs: configs, activeForwards: activeForwards);
  }

  Future<void> startForward(String id) async {
    final config = state.configs.firstWhere((c) => c.id == id);

    try {
      _updateStatus(id, PortForwardStatus(id: id, isActive: true));

      final serverSocket = await ServerSocket.bind(config.localHost, config.localPort);

      print('Port forward started: ${config.localHost}:${config.localPort} -> ${config.remoteHost}:${config.remotePort}');

      final subscription = serverSocket.listen((socket) async {
        try {
          final forward = await _client.forwardLocal(
            config.remoteHost,
            config.remotePort,
          );
          forward.stream.cast<List<int>>().pipe(socket);
          socket.cast<List<int>>().pipe(forward.sink);
        } catch (e, s) {
          Loggers.app.warning('Port forward connection failed', e, s);
          socket.destroy();
        }
      });

      _forwards[id] = _LocalForwardEntry(
        serverSocket: serverSocket,
        subscription: subscription,
      );

      _updateStatus(id, PortForwardStatus(id: id, isActive: true));
    } catch (e) {
      print('Port forward failed to start: $e');
      _updateStatus(id, PortForwardStatus(id: id, isActive: false, error: e.toString()));
    }
  }

  Future<void> stopForward(String id) async {
    final entry = _forwards.remove(id);
    if (entry != null) {
      await entry.close();
      print('Port forward stopped: $id');
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
  final StreamSubscription<Socket> subscription;

  _LocalForwardEntry({
    required this.serverSocket,
    required this.subscription,
  });

  Future<void> close() async {
    await subscription.cancel();
    await serverSocket.close();
  }
}
