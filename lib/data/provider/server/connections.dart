import 'dart:async';

import 'package:fl_lib/fl_lib.dart' hide Provider;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:server_box/core/utils/refresh_interval.dart';
import 'package:server_box/data/model/app/error.dart';
import 'package:server_box/data/model/server/server.dart';
import 'package:server_box/data/model/server/server_private_info.dart';
import 'package:server_box/data/model/server/try_limiter.dart';
import 'package:server_box/data/provider/server/all.dart';
import 'package:server_box/data/provider/server/lifecycle.dart';
import 'package:server_box/data/provider/server/refresh_scheduler.dart';
import 'package:server_box/data/provider/server/single.dart';
import 'package:server_box/data/store/stores.dart';
import 'package:server_box/data/terminal/session_manager.dart';

/// Multi-server connection orchestration: refresh scheduling, auto-refresh
/// timer, bulk connect, and disconnect.
///
/// Layered above `serversProvider` (inventory) and `serverProvider` (per-server
/// state) so the server provider graph remains strictly acyclic.
final class ServerConnections {
  ServerConnections(this._ref);

  static const _maxConcurrentRefreshes = 4;

  final Ref _ref;
  int _autoRefreshGeneration = 0;
  Timer? _autoRefreshTimer;
  ServerRefreshScheduler? _refreshScheduler;

  ServerRefreshScheduler get _refreshes =>
      _refreshScheduler ??= ServerRefreshScheduler(
        maxConcurrent: _maxConcurrentRefreshes,
        refresh: (serverId) =>
            _ref.read(serverProvider(serverId).notifier).refresh(),
      );

  /// If [spi] is specified, refreshes only that server interactively.
  /// If [onlyFailed] is true, refreshes only failed servers.
  Future<void> refresh({Spi? spi, bool onlyFailed = false}) async {
    if (spi != null) {
      _ref.read(serversProvider.notifier).clearManualDisconnected(spi.id);
      final serverNotifier = _ref.read(serverProvider(spi.id).notifier);
      await serverNotifier.refresh(interactive: true);
      return;
    }

    final serversState = _ref.read(serversProvider);
    final serversToRefresh = <MapEntry<String, Spi>>[];
    final idsToResetLimiter = <String>[];

    for (final entry in serversState.servers.entries) {
      final serverId = entry.key;
      final item = entry.value;

      if (serversState.manualDisconnectedIds.contains(serverId)) continue;

      final serverState = _ref.read(serverProvider(serverId));

      final error = serverState.status.err;
      if (error is SSHErr && error.type == SSHErrType.interactiveAuth) {
        continue;
      }

      if (onlyFailed) {
        if (serverState.conn != ServerConn.failed) {
          continue;
        }
        idsToResetLimiter.add(serverId);
      }

      if (serverState.conn == ServerConn.disconnected && !item.autoConnect) {
        continue;
      }

      serversToRefresh.add(entry);
    }

    for (final id in idsToResetLimiter) {
      TryLimiter.reset(id);
    }

    await _refreshEach(serversToRefresh.map((e) => e.key).toList());
  }

  /// Connects every server, including manually disconnected and non-autoConnect
  /// ones, non-interactively.
  Future<void> connectAll() async {
    final ids = _ref.read(serversProvider).servers.keys.toList();
    if (ids.isEmpty) return;
    _ref.read(serversProvider.notifier).clearAllManualDisconnected();
    for (final id in ids) {
      TryLimiter.reset(id);
    }
    await _refreshEach(ids);
  }

  Future<void> _refreshEach(List<String> ids) => _refreshes.refresh(ids);

  Future<void> startAutoRefresh() async {
    stopAutoRefresh();
    final rawDuration = Stores.setting.serverStatusUpdateInterval.fetch();
    final duration = normalizeServerStatusRefreshSeconds(rawDuration);
    if (duration == null) {
      return;
    }
    if (duration != rawDuration) {
      Loggers.app.warning(
        'Invalid duration: $rawDuration, use default $duration',
      );
    }
    final generation = ++_autoRefreshGeneration;
    void schedule() {
      if (generation != _autoRefreshGeneration) return;
      _autoRefreshTimer = Timer(Duration(seconds: duration), () async {
        try {
          await refresh();
        } catch (e, s) {
          Loggers.app.warning('Auto refresh failed', e, s);
        } finally {
          if (generation == _autoRefreshGeneration) schedule();
        }
      });
    }

    schedule();
  }

  void stopAutoRefresh() {
    _autoRefreshGeneration++;
    _autoRefreshTimer?.cancel();
    _autoRefreshTimer = null;
  }

  void closeServer({String? id}) {
    if (id == null) {
      final ids = _ref.read(serversProvider).servers.keys.toList();
      for (final serverId in ids) {
        closeOneServer(serverId);
      }
      return;
    }
    closeOneServer(id);
  }

  void closeOneServer(String id) {
    final sessionId = TermSessionManager.statusSessionId(id);
    final spi = _ref.read(serversProvider).servers[id];
    if (spi == null) {
      TermSessionManager.remove(sessionId);
      Loggers.app.warning('Server with id $id not found');
      return;
    }

    _ref.read(serverProvider(id).notifier).closeConnection();
    _ref.read(serversProvider.notifier).markManualDisconnected(id);
    TermSessionManager.remove(sessionId);
  }
}

final serverConnectionsProvider = Provider<ServerConnections>((ref) {
  final connections = ServerConnections(ref);
  final unregister = ref
      .read(serverLifecycleProvider)
      .onRefresh(connections.refresh);
  ref.onDispose(() {
    unregister();
    connections.stopAutoRefresh();
  });
  return connections;
});
