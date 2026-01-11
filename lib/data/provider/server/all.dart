import 'dart:async';

import 'package:fl_lib/fl_lib.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:server_box/core/sync.dart';
import 'package:server_box/data/model/server/server.dart';
import 'package:server_box/data/model/server/server_private_info.dart';
import 'package:server_box/data/model/server/try_limiter.dart';
import 'package:server_box/data/provider/server/single.dart';
import 'package:server_box/data/res/store.dart';
import 'package:server_box/data/ssh/session_manager.dart';

part 'all.freezed.dart';
part 'all.g.dart';

@freezed
abstract class ServersState with _$ServersState {
  const factory ServersState({
    @Default({}) Map<String, Spi> servers,
    @Default([]) List<String> serverOrder,
    @Default(<String>{}) Set<String> tags,
    @Default(<String>{}) Set<String> manualDisconnectedIds,
    Timer? autoRefreshTimer,
  }) = _ServersState;
}

@Riverpod(keepAlive: true)
class ServersNotifier extends _$ServersNotifier {
  @override
  ServersState build() {
    return _load();
  }

  Future<void> reload() async {
    final newState = _load();
    if (newState == state) return;
    state = newState;
    await refresh();
  }

  ServersState _load() {
    final spis = Stores.server.fetch();
    final newServers = <String, Spi>{};
    final newServerOrder = <String>[];

    for (final spi in spis) {
      newServers[spi.id] = spi;
    }

    final serverOrder_ = Stores.setting.serverOrder.fetch();
    if (serverOrder_.isNotEmpty) {
      spis.reorder(order: serverOrder_, finder: (n, id) => n.id == id);
      newServerOrder.addAll(spis.map((e) => e.id));
    } else {
      newServerOrder.addAll(newServers.keys);
    }

    // Must use [equals] to compare [Order] here.
    if (!newServerOrder.equals(serverOrder_)) {
      Stores.setting.serverOrder.put(newServerOrder);
    }

    final newTags = _calculateTags(newServers);

    return stateOrNull?.copyWith(servers: newServers, serverOrder: newServerOrder, tags: newTags) ??
        ServersState(servers: newServers, serverOrder: newServerOrder, tags: newTags);
  }

  Set<String> _calculateTags(Map<String, Spi> servers) {
    final tags = <String>{};
    for (final spi in servers.values) {
      final spiTags = spi.tags;
      if (spiTags == null) continue;
      for (final t in spiTags) {
        tags.add(t);
      }
    }
    return tags;
  }

  /// Get a [Spi] by [spi] or [id].
  ///
  /// Priority: [spi] > [id]
  Spi? pick({Spi? spi, String? id}) {
    if (spi != null) {
      return state.servers[spi.id];
    }
    if (id != null) {
      return state.servers[id];
    }
    return null;
  }

  Future<void>? _refreshCompleter;

  /// if [spi] is specificed then only refresh this server
  /// [onlyFailed] only refresh failed servers
  Future<void> refresh({Spi? spi, bool onlyFailed = false}) async {
    if (spi != null) {
      final newManualDisconnected = Set<String>.from(state.manualDisconnectedIds)..remove(spi.id);
      state = state.copyWith(manualDisconnectedIds: newManualDisconnected);
      final serverNotifier = ref.read(serverProvider(spi.id).notifier);
      await serverNotifier.refresh();
      return;
    }

    if (_refreshCompleter != null) return;

    final completer = Completer<void>();
    _refreshCompleter = completer.future;
    try {
      final refreshFutures = <Future<void>>[];
      for (final entry in state.servers.entries) {
        final serverId = entry.key;
        final spi = entry.value;

        if (onlyFailed) {
          final serverState = ref.read(serverProvider(serverId));
          if (serverState.conn != ServerConn.failed) continue;
          TryLimiter.reset(serverId);
        }

        if (state.manualDisconnectedIds.contains(serverId)) continue;

        final serverState = ref.read(serverProvider(serverId));
        if (serverState.conn == ServerConn.disconnected && !spi.autoConnect) continue;

        final serverNotifier = ref.read(serverProvider(serverId).notifier);
        refreshFutures.add(serverNotifier.refresh());
      }

      await Future.wait(refreshFutures);
    } finally {
      _refreshCompleter = null;
      completer.complete();
    }
  }

  Future<void> startAutoRefresh() async {
    var duration = Stores.setting.serverStatusUpdateInterval.fetch();
    stopAutoRefresh();
    if (duration == 0) return;
    if (duration < 0 || duration > 10) {
      duration = 3;
      Loggers.app.warning('Invalid duration: $duration, use default 3');
    }
    final timer = Timer.periodic(Duration(seconds: duration), (_) async {
      await refresh();
    });
    state = state.copyWith(autoRefreshTimer: timer);
  }

  void stopAutoRefresh() {
    final timer = state.autoRefreshTimer;
    if (timer != null) {
      timer.cancel();
    }
    state = state.copyWith(autoRefreshTimer: null);
  }

  bool get isAutoRefreshOn => state.autoRefreshTimer != null;

  void setDisconnected() {
    for (final serverId in state.servers.keys) {
      final serverNotifier = ref.read(serverProvider(serverId).notifier);
      serverNotifier.updateConnection(ServerConn.disconnected);

      // Update SSH session status to disconnected
      final sessionId = 'ssh_$serverId';
      TermSessionManager.updateStatus(sessionId, TermSessionStatus.disconnected);
    }
    //TryLimiter.clear();
  }

  void closeServer({String? id}) {
    if (id == null) {
      for (final serverId in state.servers.keys) {
        closeOneServer(serverId);
      }
      return;
    }
    closeOneServer(id);
  }

  void closeOneServer(String id) {
    final spi = state.servers[id];
    if (spi == null) {
      Loggers.app.warning('Server with id $id not found');
      return;
    }

    final serverNotifier = ref.read(serverProvider(id).notifier);
    serverNotifier.closeConnection();

    final newManualDisconnected = Set<String>.from(state.manualDisconnectedIds)..add(id);
    state = state.copyWith(manualDisconnectedIds: newManualDisconnected);

    // Remove SSH session when server is manually closed
    final sessionId = 'ssh_$id';
    TermSessionManager.remove(sessionId);
  }

  void addServer(Spi spi) {
    final newServers = Map<String, Spi>.from(state.servers);
    newServers[spi.id] = spi;

    final newOrder = List<String>.from(state.serverOrder)..add(spi.id);
    final newTags = _calculateTags(newServers);

    state = state.copyWith(servers: newServers, serverOrder: newOrder, tags: newTags);

    Stores.server.put(spi);
    Stores.setting.serverOrder.put(newOrder);
    refresh(spi: spi);
    bakSync.sync(milliDelay: 1000);
  }

  void delServer(String id) {
    final newServers = Map<String, Spi>.from(state.servers);
    newServers.remove(id);

    final newOrder = List<String>.from(state.serverOrder)..remove(id);
    final newTags = _calculateTags(newServers);

    state = state.copyWith(servers: newServers, serverOrder: newOrder, tags: newTags);

    Stores.setting.serverOrder.put(newOrder);
    Stores.server.delete(id);

    // Remove SSH session when server is deleted
    final sessionId = 'ssh_$id';
    TermSessionManager.remove(sessionId);

    bakSync.sync(milliDelay: 1000);
  }

  void deleteAll() {
    // Remove all SSH sessions before clearing servers
    for (final id in state.servers.keys) {
      final sessionId = 'ssh_$id';
      TermSessionManager.remove(sessionId);
    }

    state = const ServersState();

    Stores.setting.serverOrder.put([]);
    Stores.server.clear();
    bakSync.sync(milliDelay: 1000);
  }

  void updateServerOrder(List<String> order) {
    final seen = <String>{};
    final newOrder = <String>[];

    for (final id in order) {
      if (!state.servers.containsKey(id)) {
        continue;
      }
      if (!seen.add(id)) {
        continue;
      }
      newOrder.add(id);
    }

    for (final id in state.servers.keys) {
      if (seen.add(id)) {
        newOrder.add(id);
      }
    }

    if (_isSameOrder(newOrder, state.serverOrder)) {
      return;
    }

    state = state.copyWith(serverOrder: newOrder);
    Stores.setting.serverOrder.put(newOrder);
    bakSync.sync(milliDelay: 1000);
  }

  bool _isSameOrder(List<String> a, List<String> b) {
    if (identical(a, b)) {
      return true;
    }
    if (a.length != b.length) {
      return false;
    }
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) {
        return false;
      }
    }
    return true;
  }

  Future<void> updateServer(Spi old, Spi newSpi) async {
    if (old != newSpi) {
      Stores.server.update(old, newSpi);

      final newServers = Map<String, Spi>.from(state.servers);
      final newOrder = List<String>.from(state.serverOrder);

      if (newSpi.id != old.id) {
        newServers[newSpi.id] = newSpi;
        newServers.remove(old.id);
        newOrder.update(old.id, newSpi.id);
        Stores.setting.serverOrder.put(newOrder);

        // Update SSH session ID when server ID changes
        final oldSessionId = 'ssh_${old.id}';
        TermSessionManager.remove(oldSessionId);
        // Session will be re-added when reconnecting if necessary
      } else {
        newServers[old.id] = newSpi;
        // Update SPI in the corresponding IndividualServerNotifier
        final serverNotifier = ref.read(serverProvider(old.id).notifier);
        serverNotifier.updateSpi(newSpi);
      }

      final newTags = _calculateTags(newServers);
      state = state.copyWith(servers: newServers, serverOrder: newOrder, tags: newTags);

      // Only reconnect if neccessary
      if (newSpi.shouldReconnect(old)) {
        // Use [newSpi.id] instead of [old.id] because [old.id] may be changed
        TryLimiter.reset(newSpi.id);
        refresh(spi: newSpi);
      }
    }
    bakSync.sync(milliDelay: 1000);
  }
}
