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
  ServerRefreshHandler? _refreshHandler;

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

  Future<void> beforeDelete(String serverId) async {
    for (final hook in List<ServerLifecycleHook>.of(_beforeDelete)) {
      await hook(serverId);
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
