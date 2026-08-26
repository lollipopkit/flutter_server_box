import 'dart:async';

import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/foundation.dart' show listEquals;
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:server_box/core/service/scoped_token.dart';
import 'package:server_box/core/service/watch_sync.dart';
import 'package:server_box/core/service/widget_sync.dart';
import 'package:server_box/core/sync.dart';
import 'package:server_box/core/utils/refresh_interval.dart';
import 'package:server_box/core/utils/server.dart';
import 'package:server_box/core/utils/sudo_password.dart';
import 'package:server_box/data/model/app/error.dart';
import 'package:server_box/data/model/server/server.dart';
import 'package:server_box/data/model/server/server_private_info.dart';
import 'package:server_box/data/model/server/try_limiter.dart';
import 'package:server_box/data/provider/port_forward_provider.dart';
import 'package:server_box/data/provider/server/selection.dart';
import 'package:server_box/data/provider/server/single.dart';
import 'package:server_box/data/res/store.dart';
import 'package:server_box/data/ssh/session_manager.dart';
import 'package:server_box/data/store/entity_store.dart';

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
  static const _maxConcurrentRefreshes = 4;
  int _autoRefreshGeneration = 0;
  Future<void> _mutationTail = Future.value();

  Future<T> _mutate<T>(Future<T> Function() action) async {
    final previous = _mutationTail;
    final release = Completer<void>();
    _mutationTail = release.future;
    try {
      await previous.catchError((_) {});
      return await action();
    } finally {
      release.complete();
    }
  }

  @override
  ServersState build() {
    return _load();
  }

  Future<void> reload({bool refreshConnections = true}) async {
    Stores.server.dropCache();
    final newState = _load();
    final selectedId = ref.read(serverSelectionProvider);
    if (selectedId != null && !newState.servers.containsKey(selectedId)) {
      ref.read(serverSelectionProvider.notifier).select(null);
    }
    if (newState == state) return;
    final previousServers = state.servers;
    state = newState;
    for (final entry in previousServers.entries) {
      if (newState.servers.containsKey(entry.key)) continue;
      final provider = serverProvider(entry.key);
      if (ref.exists(provider)) ref.invalidate(provider);
    }
    for (final entry in newState.servers.entries) {
      if (previousServers[entry.key] == entry.value) continue;
      final provider = serverProvider(entry.key);
      if (ref.exists(provider)) {
        ref.read(provider.notifier).updateSpi(entry.value);
      }
    }
    if (refreshConnections) await refresh();
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

    return stateOrNull?.copyWith(
          servers: newServers,
          serverOrder: newServerOrder,
          tags: newTags,
        ) ??
        ServersState(
          servers: newServers,
          serverOrder: newServerOrder,
          tags: newTags,
        );
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

  Future<void> _clearSudoPasswordOverrideBestEffort(String id) async {
    try {
      await SudoPassword.clearOverride(id);
    } catch (e, s) {
      Loggers.app.warning(
        'Failed to clear sudo password override for server $id',
        e,
        s,
      );
    }
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

  /// if [spi] is specificed then only refresh this server
  /// [onlyFailed] only refresh failed servers
  Future<void> refresh({Spi? spi, bool onlyFailed = false}) async {
    if (spi != null) {
      final newManualDisconnected = Set<String>.from(
        state.manualDisconnectedIds,
      )..remove(spi.id);
      state = state.copyWith(manualDisconnectedIds: newManualDisconnected);
      final serverNotifier = ref.read(serverProvider(spi.id).notifier);
      await serverNotifier.refresh(interactive: true);
      return;
    }

    final serversToRefresh = <MapEntry<String, Spi>>[];
    final idsToResetLimiter = <String>[];

    for (final entry in state.servers.entries) {
      final serverId = entry.key;
      final spi = entry.value;

      if (state.manualDisconnectedIds.contains(serverId)) continue;

      final serverState = ref.read(serverProvider(serverId));

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

      if (serverState.conn == ServerConn.disconnected && !spi.autoConnect) {
        continue;
      }

      serversToRefresh.add(entry);
    }

    for (final id in idsToResetLimiter) {
      TryLimiter.reset(id);
    }

    await _refreshEach(serversToRefresh.map((e) => e.key).toList());
  }

  /// Connects every server, the ones taken down by hand included.
  ///
  /// [refresh] passes over those on purpose — a poll on a timer is not allowed
  /// to undo a disconnect the user asked for — and it also passes over a
  /// server whose `autoConnect` is off. Asking for all of them is the one case
  /// where both of those are the point, so this forgets what was closed by
  /// hand and connects the lot.
  ///
  /// Non-interactive, like the timer's refresh and unlike opening one server:
  /// a keyboard-interactive prompt per machine would be a stack of dialogs
  /// nobody asked for. Those servers keep the lock on their card, which is
  /// where answering one at a time belongs.
  Future<void> connectAll() async {
    final ids = state.servers.keys.toList();
    if (ids.isEmpty) return;
    state = state.copyWith(manualDisconnectedIds: const <String>{});
    for (final id in ids) {
      TryLimiter.reset(id);
    }
    await _refreshEach(ids);
  }

  /// Refreshes [ids], a few at a time.
  ///
  /// The cap is what keeps a list of thirty machines from opening thirty
  /// connections at once; the workers share one cursor rather than a slice
  /// each, so a slow server holds up nothing but itself.
  Future<void> _refreshEach(List<String> ids) async {
    var next = 0;
    Future<void> worker() async {
      while (next < ids.length) {
        final serverNotifier = ref.read(serverProvider(ids[next++]).notifier);
        await serverNotifier.refresh();
      }
    }

    await Future.wait(
      List.generate(
        ids.length.clamp(0, _maxConcurrentRefreshes).toInt(),
        (_) => worker(),
      ),
    );
  }

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
      final timer = Timer(Duration(seconds: duration), () async {
        try {
          await refresh();
        } catch (e, s) {
          Loggers.app.warning('Auto refresh failed', e, s);
        } finally {
          if (generation == _autoRefreshGeneration) schedule();
        }
      });
      state = state.copyWith(autoRefreshTimer: timer);
    }

    schedule();
  }

  void stopAutoRefresh() {
    _autoRefreshGeneration++;
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
      TermSessionManager.updateStatus(
        sessionId,
        TermSessionStatus.disconnected,
      );
    }
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

    final newManualDisconnected = Set<String>.from(state.manualDisconnectedIds)
      ..add(id);
    state = state.copyWith(manualDisconnectedIds: newManualDisconnected);

    // Remove SSH session when server is manually closed
    final sessionId = 'ssh_$id';
    TermSessionManager.remove(sessionId);
  }

  Future<void> addServer(Spi spi) => _mutate(() => _addServer(spi));

  Future<void> _addServer(Spi spi) async {
    spi.validateOrThrow();

    final exists = state.servers.containsKey(spi.id);
    final newServers = Map<String, Spi>.from(state.servers);
    newServers[spi.id] = spi;

    final newOrder = List<String>.from(state.serverOrder);
    if (!exists) {
      newOrder.add(spi.id);
    } else {
      Loggers.app.warning(
        'addServer: id ${spi.id} already exists, updating in place',
      );
    }
    final newTags = _calculateTags(newServers);
    final newManualDisconnected = Set<String>.from(state.manualDisconnectedIds)
      ..remove(spi.id);

    Stores.server.put(spi);
    Stores.setting.serverOrder.put(newOrder);
    state = state.copyWith(
      servers: newServers,
      serverOrder: newOrder,
      tags: newTags,
      manualDisconnectedIds: newManualDisconnected,
    );
    // If the server already had a live notifier, refresh its Spi rather than
    // leaving it stale with the old credentials.
    if (exists) {
      try {
        ref.read(serverProvider(spi.id).notifier).updateSpi(spi);
      } catch (_) {
        // Provider may not have been created yet (keepAlive not yet built)
        ref.invalidate(serverProvider(spi.id));
      }
    }
    unawaited(refresh(spi: spi));
    bakSync.sync(milliDelay: 1000);
  }

  Future<void> delServer(String id) => _mutate(() => _delServer(id));

  Future<void> _delServer(String id) async {
    final deleting = state.servers[id];
    if (deleting == null) return;
    // Started here, because revoking is an authenticated call to the agent
    // and the credential is on the record. Neither publishes — see
    // `revokeServer`: a rebuild from a store that still holds this server
    // would mint a replacement token for the one being deleted.
    //
    // Not waited for, for the reason the edit path does not either: an agent
    // that has gone away costs ten seconds per call to establish that, and a
    // delete that hangs on it is a delete that looks ignored. `deleting` is a
    // value already in hand, so the request carries the old credential
    // whatever the store does next, and a rebuild after the row is gone has
    // nothing to mint for.
    unawaited(WatchSync.instance.revokeServer(deleting));
    unawaited(WidgetSync.instance.revokeServer(deleting));
    await _clearServerData(id);
    final newServers = Map<String, Spi>.from(state.servers);
    newServers.remove(id);

    final newOrder = List<String>.from(state.serverOrder)..remove(id);
    final newTags = _calculateTags(newServers);
    final newManualDisconnected = Set<String>.from(state.manualDisconnectedIds)
      ..remove(id);

    Stores.setting.serverOrder.put(newOrder);
    Stores.server.deleteById(id);
    // The row goes with the server — the foreign key cascades — but the whole
    // map this store keeps in memory does not, so a list drawn afterwards read
    // a mark for a server that no longer exists.
    Stores.serverDist.remove(id);
    state = state.copyWith(
      servers: newServers,
      serverOrder: newOrder,
      tags: newTags,
      manualDisconnectedIds: newManualDisconnected,
    );
    await _clearSudoPasswordOverrideBestEffort(id);

    // Now that the row is gone, so the rebuilt lists cannot contain it.
    await WatchSync.instance.push();
    await WidgetSync.instance.push();

    // Deselect if the deleted server was selected, and invalidate its provider
    // so the keepAlive notifier (PersistentShell, Pve socket) is disposed.
    if (ref.read(serverSelectionProvider) == id) {
      ref.read(serverSelectionProvider.notifier).select(null);
    }
    ref.invalidate(serverProvider(id));
    forgetHostKeyFingerprints(id);

    // Remove SSH session when server is deleted
    final sessionId = 'ssh_$id';
    TermSessionManager.remove(sessionId);

    bakSync.sync(milliDelay: 1000);
  }

  Future<void> deleteAll() => _mutate(_deleteAll);

  Future<void> _deleteAll() async {
    final serverIds = state.servers.keys.toList();

    // Remove all SSH sessions before clearing servers
    for (final id in serverIds) {
      final sessionId = 'ssh_$id';
      TermSessionManager.remove(sessionId);
    }

    // Revoke every one first, while the records are still there to
    // authenticate with; the single push comes after the store is empty.
    for (final spi in state.servers.values) {
      await WatchSync.instance.revokeServer(spi);
      await WidgetSync.instance.revokeServer(spi);
    }
    for (final id in serverIds) {
      await _clearServerData(id);
    }
    final bool cleared;
    try {
      cleared = await Stores.server.clear();
    } catch (e, s) {
      Loggers.app.warning('Failed to clear servers', e, s);
      return;
    }
    if (!cleared) {
      Loggers.app.warning('Failed to clear servers');
      return;
    }
    Stores.setting.serverOrder.put([]);
    state = const ServersState();
    // One push, once the store is empty. Pushing per server inside the loop
    // above would rebuild from a store that still held the rest and re-issue
    // tokens for servers on their way out.
    await WatchSync.instance.push();
    await WidgetSync.instance.push();
    await Future.wait(serverIds.map(_clearSudoPasswordOverrideBestEffort));
    for (final id in serverIds) {
      ref.invalidate(serverProvider(id));
      forgetHostKeyFingerprints(id);
      // The rows went with the servers — the foreign key cascades — but the
      // map this store keeps in memory did not, so a list drawn afterwards
      // read a mark for a server that no longer exists. `delServer` does the
      // same for the one it deletes.
      Stores.serverDist.remove(id);
    }
    ref.read(serverSelectionProvider.notifier).select(null);
    bakSync.sync(milliDelay: 1000);
  }

  Future<void> _clearServerData(String id) async {
    await ref.read(portForwardProvider(id).notifier).clear();
    Stores.agentConversation.clearServer(id);
    await Stores.connectionStats.clearServerStats(id);
  }

  Future<void> updateServerOrder(List<String> order) =>
      _mutate(() => _updateServerOrder(order));

  Future<void> _updateServerOrder(List<String> order) async {
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

    Stores.setting.serverOrder.put(newOrder);
    state = state.copyWith(serverOrder: newOrder);
    bakSync.sync(milliDelay: 1000);
  }

  bool _isSameOrder(List<String> a, List<String> b) {
    if (identical(a, b)) return true;
    return listEquals(a, b);
  }

  Future<void> updateServer(Spi old, Spi newSpi) =>
      _mutate(() => _updateServer(old, newSpi));

  Future<void> _updateServer(Spi old, Spi newSpi) async {
    newSpi.validateOrThrow();

    if (state.servers[old.id] != old) {
      throw StateError('${libL10n.server}: ${libL10n.retry}');
    }

    if (old != newSpi) {
      if (newSpi.id != old.id) {
        // `EntityStore.update` explicitly rejects id changes; renaming must
        // move dependent rows and handle sync metadata itself.
        if (state.servers.containsKey(newSpi.id)) {
          throw DuplicateNameException(newSpi.name);
        }
        Stores.server.rename(old, newSpi);
      } else {
        Stores.server.update(old, newSpi);
      }

      final newServers = Map<String, Spi>.from(state.servers);
      final newOrder = List<String>.from(state.serverOrder);
      final newManualDisconnected = Set<String>.from(
        state.manualDisconnectedIds,
      );

      if (newSpi.id != old.id) {
        newServers[newSpi.id] = newSpi;
        newServers.remove(old.id);
        newOrder.update(old.id, newSpi.id);
        if (newManualDisconnected.remove(old.id)) {
          newManualDisconnected.add(newSpi.id);
        }
        Stores.setting.serverOrder.put(newOrder);
        Stores.history.renameSshServer(old.id, newSpi.id);
      } else {
        newServers[old.id] = newSpi;
      }

      final newTags = _calculateTags(newServers);
      state = state.copyWith(
        servers: newServers,
        serverOrder: newOrder,
        tags: newTags,
        manualDisconnectedIds: newManualDisconnected,
      );

      if (newSpi.id != old.id) {
        // Publish the replacement before selection or async cleanup can make
        // consumers rebuild against the deleted id.
        if (ref.read(serverSelectionProvider) == old.id) {
          ref.read(serverSelectionProvider.notifier).select(newSpi.id);
        }
        ref.invalidate(serverProvider(old.id));

        final oldSessionId = 'ssh_${old.id}';
        TermSessionManager.remove(oldSessionId);
        await _clearSudoPasswordOverrideBestEffort(old.id);
      } else {
        final serverNotifier = ref.read(serverProvider(old.id).notifier);
        serverNotifier.updateSpi(newSpi);
      }

      // While the *old* credential is still known. A scoped token is revoked
      // by an authenticated call to the agent that issued it, so this is the
      // last moment anything can: after this the old address and login are
      // gone, and a rebuild of the token set can only stop handing the
      // credential out, never take it back.
      //
      // Started here and not waited for. The old address is the one being
      // moved away from, and the commonest reason to move away from an
      // address is that it stopped answering — so this is a request that
      // routinely runs into `MonitorHttpClient`'s ten-second connect timeout,
      // twice, on the one code path between the Save button and the editor
      // closing. `_mutate` serialises every mutation, so a second tap queued
      // behind the first instead of doing anything: the save appeared to be
      // ignored for as long as the old agent took to not answer.
      //
      // Nothing below depends on the result, `old` is a value this closure
      // holds rather than something re-read from the store, and the call
      // already swallows its own failures — see its own doc comment for why
      // a token that outlives the edit is the accepted worst case.
      unawaited(revokeScopedTokensLeftBehind(old, newSpi));

      // Only reconnect if neccessary
      if (newSpi.shouldReconnect(old)) {
        // Use [newSpi.id] instead of [old.id] because [old.id] may be changed
        TryLimiter.reset(newSpi.id);
        unawaited(refresh(spi: newSpi));
      }
    }
    bakSync.sync(milliDelay: 1000);
  }
}
