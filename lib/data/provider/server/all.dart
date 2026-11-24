import 'dart:async';

import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/foundation.dart' show listEquals;
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:server_box/core/service/scoped_token.dart';
import 'package:server_box/core/service/watch_sync.dart';
import 'package:server_box/core/service/widget_sync.dart';
import 'package:server_box/core/ssh/host_keys.dart';
import 'package:server_box/core/sync/sync.dart';
import 'package:server_box/core/utils/sudo_password.dart';
import 'package:server_box/data/model/server/server_private_info.dart';
import 'package:server_box/data/model/server/try_limiter.dart';
import 'package:server_box/data/provider/ai/agent_scope.dart';
import 'package:server_box/data/provider/bmc/targets.dart';
import 'package:server_box/data/provider/server/lifecycle.dart';
import 'package:server_box/data/provider/server/selection.dart';
import 'package:server_box/data/provider/workspace.dart';
import 'package:server_box/data/store/entity_store.dart';
import 'package:server_box/data/store/stores.dart';
import 'package:server_box/data/terminal/session_manager.dart';

part 'all.freezed.dart';
part 'all.g.dart';

@freezed
abstract class ServersState with _$ServersState {
  const factory ServersState({
    @Default({}) Map<String, Spi> servers,
    @Default([]) List<String> serverOrder,
    @Default(<String>{}) Set<String> tags,
    @Default(<String>{}) Set<String> manualDisconnectedIds,
    // TODO: remove unused field next time freezed codegen is run on all.dart.
    Timer? autoRefreshTimer,
  }) = _ServersState;
}

/// The server was changed elsewhere since the caller read it.
class ServerChangedConcurrently implements Exception {
  const ServerChangedConcurrently();

  @override
  String toString() => '${libL10n.server}: ${libL10n.retry}';
}

@Riverpod(keepAlive: true)
class ServersNotifier extends _$ServersNotifier {
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
    state = newState;
    if (refreshConnections) {
      await ref.read(serverLifecycleProvider).requestRefresh();
    }
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
    SudoPassword.forget(id);
    try {
      SudoPassword.unsave(id);
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

  void markManualDisconnected(String id) {
    if (state.manualDisconnectedIds.contains(id)) return;
    state = state.copyWith(
      manualDisconnectedIds: {...state.manualDisconnectedIds, id},
    );
  }

  void clearManualDisconnected(String id) {
    if (!state.manualDisconnectedIds.contains(id)) return;
    final next = Set<String>.from(state.manualDisconnectedIds)..remove(id);
    state = state.copyWith(manualDisconnectedIds: next);
  }

  void clearAllManualDisconnected() {
    if (state.manualDisconnectedIds.isEmpty) return;
    state = state.copyWith(manualDisconnectedIds: const <String>{});
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
    unawaited(ref.read(serverLifecycleProvider).requestRefresh(spi: spi));
    bakSync.syncSoon();
  }

  Future<void> delServer(String id) => _mutate(() => _delServer(id));

  Future<void> _delServer(String id) async {
    final deleting = state.servers[id];
    if (deleting == null) return;
    // Keep both surfaces from minting while local cleanup still needs the row.
    unawaited(WatchSync.instance.revokeServer(deleting));
    final lifecycle = ref.read(serverLifecycleProvider);
    final finishLifecycleDeletion = lifecycle.beginDelete(id);
    final finishWidgetDeletion = WidgetSync.instance.beginServerDeletion(deleting);
    final List<String> newOrder;
    try {
      await lifecycle.beforeDelete(id);
      ref.read(workspacesProvider.notifier).removeServer(id);
      await _clearServerData(id);
      newOrder = List<String>.from(state.serverOrder)..remove(id);
      Stores.setting.serverOrder.put(newOrder);
      Stores.server.deleteById(id);
      ref.read(bmcTargetsProvider.notifier).reload();
    } finally {
      finishLifecycleDeletion();
      finishWidgetDeletion();
      WatchSync.instance.finishServerDeletion(id);
    }
    final newServers = Map<String, Spi>.from(state.servers);
    newServers.remove(id);

    final newTags = _calculateTags(newServers);
    final newManualDisconnected = Set<String>.from(state.manualDisconnectedIds)
      ..remove(id);

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
    // Not waited for: on iOS/Android `push` talks to remaining monitor agents
    // and WatchConnectivity, which can stall for tens of seconds and leave the
    // edit page open after the confirmation sheet closes.
    unawaited(WatchSync.instance.push());
    unawaited(WidgetSync.instance.push());

    // Deselect if the deleted server was selected; live `serverProvider(id)`
    // notifiers dispose themselves via their `serversProvider` listener.
    if (ref.read(serverSelectionProvider) == id) {
      ref.read(serverSelectionProvider.notifier).select(null);
    }
    await forgetHostKeyFingerprints(id);

    TermSessionManager.remove(TermSessionManager.statusSessionId(id));

    bakSync.syncSoon();
  }

  Future<void> _clearServerData(String id) async {
    Stores.portForward.clearServer(id);
    await AgentChats.clearScope(AgentScope.terminal(id));
    Stores.connectionStats.clearServerStats(id);
    Stores.selfAddr.forget(id);
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
    bakSync.syncSoon();
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
      throw const ServerChangedConcurrently();
    }

    if (old != newSpi) {
      if (newSpi.id != old.id) {
        await ref.read(serverLifecycleProvider).beforeRename(old.id, newSpi.id);
        // `EntityStore.update` explicitly rejects id changes; renaming must
        // move dependent rows and handle sync metadata itself.
        if (state.servers.containsKey(newSpi.id)) {
          throw DuplicateNameException(newSpi.name);
        }
        Stores.server.rename(old, newSpi);
        ref.read(bmcTargetsProvider.notifier).reload();
      } else {
        Stores.server.update(old, newSpi);
      }
      // Both surfaces revoke in the background with the old credential
      // snapshot, ahead of their next mint for this server.
      revokeScopedTokensLeftBehind(
        old,
        newSpi,
        queueWatchRevoke: WatchSync.instance.revokeEditedServer,
        queueWidgetRevoke: WidgetSync.instance.revokeEditedServer,
      );

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
        ref.read(workspacesProvider.notifier).renameServer(old.id, newSpi.id);
        // Device-local derived state follows the same stable server identity.
        // Keeping the old key would retain an orphan and make the renamed
        // server wait for another extended poll before it can be placed.
        if (!Stores.selfAddr.rename(old.id, newSpi.id)) {
          Loggers.app.warning(
            'Failed to move the self-reported address from ${old.id} '
            'to ${newSpi.id}',
          );
        }
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

        TermSessionManager.remove(TermSessionManager.statusSessionId(old.id));
        await _clearSudoPasswordOverrideBestEffort(old.id);
      } else {
        // The login may be another account now, whose sudo password the one
        // typed this session is not.
        SudoPassword.forget(old.id);
      }

      // Only reconnect if neccessary
      if (newSpi.shouldReconnect(old)) {
        // Use [newSpi.id] instead of [old.id] because [old.id] may be changed
        TryLimiter.reset(newSpi.id);
        unawaited(
          ref.read(serverLifecycleProvider).requestRefresh(spi: newSpi),
        );
      }
    }
    bakSync.syncSoon();
  }
}
