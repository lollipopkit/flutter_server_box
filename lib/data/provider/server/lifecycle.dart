import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:server_box/data/model/server/server_private_info.dart';

typedef ServerLifecycleHook = Future<void> Function(String serverId);
typedef ServerRenameHook = Future<void> Function(String oldId, String newId);
typedef ServerRefreshHandler =
    Future<void> Function({Spi? spi, bool onlyFailed});

/// Container-scoped lifecycle hooks for server deletion, rename, and refresh.
///
/// Downstream providers register their teardown or refresh handlers here so
/// `ServersNotifier` stays at the base of the provider dependency DAG without
/// importing feature providers.
final class ServerLifecycle {
  final List<ServerLifecycleHook> _beforeDelete = [];
  final List<ServerRenameHook> _beforeRename = [];
  final Map<String, int> _deletingCounts = {};
  ServerRefreshHandler? _refreshHandler;

  bool isDeleting(String serverId) => (_deletingCounts[serverId] ?? 0) > 0;

  void Function() beginDelete(String serverId) {
    _deletingCounts[serverId] = (_deletingCounts[serverId] ?? 0) + 1;
    var done = false;
    return () {
      if (done) return;
      done = true;
      final remaining = (_deletingCounts[serverId] ?? 0) - 1;
      if (remaining <= 0) {
        _deletingCounts.remove(serverId);
      } else {
        _deletingCounts[serverId] = remaining;
      }
    };
  }

  void Function() onBeforeDelete(ServerLifecycleHook hook) {
    _beforeDelete.add(hook);
    return () => _beforeDelete.remove(hook);
  }

  void Function() onBeforeRename(ServerRenameHook hook) {
    _beforeRename.add(hook);
    return () => _beforeRename.remove(hook);
  }

  void Function() onRefresh(ServerRefreshHandler handler) {
    _refreshHandler = handler;
    return () {
      if (identical(_refreshHandler, handler)) _refreshHandler = null;
    };
  }

  /// Runs every registered deletion hook for [serverId], including any hook
  /// registered while earlier hooks were awaiting.
  Future<void> beforeDelete(String serverId) async {
    final invoked = <ServerLifecycleHook>{};
    while (true) {
      final pending = [
        for (final hook in _beforeDelete)
          if (invoked.add(hook)) hook,
      ];
      if (pending.isEmpty) break;
      for (final hook in pending) {
        if (!_beforeDelete.contains(hook)) continue;
        await hook(serverId);
      }
    }
  }

  Future<void> beforeRename(String oldId, String newId) async {
    for (final hook in List<ServerRenameHook>.of(_beforeRename)) {
      await hook(oldId, newId);
    }
  }

  Future<void> requestRefresh({Spi? spi, bool onlyFailed = false}) async {
    final handler = _refreshHandler;
    if (handler != null) {
      await handler(spi: spi, onlyFailed: onlyFailed);
    }
  }
}

final serverLifecycleProvider = Provider<ServerLifecycle>(
  (ref) => ServerLifecycle(),
);
