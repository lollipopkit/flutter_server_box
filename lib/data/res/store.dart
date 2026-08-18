import 'package:fl_lib/fl_lib.dart';
import 'package:get_it/get_it.dart';
import 'package:server_box/data/store/agent_conversation.dart';
import 'package:server_box/data/store/connection_stats.dart';
import 'package:server_box/data/store/container.dart';
import 'package:server_box/data/store/history.dart';
import 'package:server_box/data/store/port_forward.dart';
import 'package:server_box/data/store/private_key.dart';
import 'package:server_box/data/store/server.dart';
import 'package:server_box/data/store/setting.dart';
import 'package:server_box/data/store/snippet.dart';

final GetIt getIt = GetIt.instance;

abstract final class Stores {
  static SettingStore get setting => getIt<SettingStore>();
  static ServerStore get server => getIt<ServerStore>();
  static ContainerStore get container => getIt<ContainerStore>();
  static PrivateKeyStore get key => getIt<PrivateKeyStore>();
  static SnippetStore get snippet => getIt<SnippetStore>();
  static HistoryStore get history => getIt<HistoryStore>();
  static AgentConversationStore get agentConversation =>
      getIt<AgentConversationStore>();
  // Keep the legacy box registered so existing connection stats DB files remain intact.
  static ConnectionStatsStore get connectionStats =>
      getIt<ConnectionStatsStore>();
  static PortForwardStore get portForward => getIt<PortForwardStore>();

  /// All stores that need backup
  static List<HiveStore> get _allBackup => [
    setting,
    server,
    container,
    key,
    snippet,
    history,
    connectionStats,
    portForward,
  ];

  /// Stores initialized locally. Agent conversations intentionally stay out of
  /// backup and sync because they may contain terminal output and reasoning.
  static List<HiveStore> get _allStores => [..._allBackup, agentConversation];

  static Future<void> init() async {
    getIt.registerLazySingleton<SettingStore>(() => SettingStore.instance);
    getIt.registerLazySingleton<ServerStore>(() => ServerStore.instance);
    getIt.registerLazySingleton<ContainerStore>(() => ContainerStore.instance);
    getIt.registerLazySingleton<PrivateKeyStore>(
      () => PrivateKeyStore.instance,
    );
    getIt.registerLazySingleton<SnippetStore>(() => SnippetStore.instance);
    getIt.registerLazySingleton<HistoryStore>(() => HistoryStore.instance);
    getIt.registerLazySingleton<AgentConversationStore>(
      () => AgentConversationStore.instance,
    );
    getIt.registerLazySingleton<ConnectionStatsStore>(
      () => ConnectionStatsStore.instance,
    );
    getIt.registerLazySingleton<PortForwardStore>(
      () => PortForwardStore.instance,
    );

    await Future.wait(_allStores.map((store) => store.init()));

    await setting.removeRetiredKeys();

    // Migrate sshConnectionMode from old int values to bool
    setting.migrateSshConnectionMode();
    await setting.migrateHomeTabsAgent();

    if (connectionStats.indexDbKeys.isEmpty) {
      await connectionStats.rebuildIndexAndCompact();
    }
  }

  static int get lastModTime {
    var lastModTime = 0;
    for (final store in _allBackup) {
      final last = store.lastUpdateTs;
      if (last == null) {
        continue;
      }
      var lastModTimeTs = 0;
      for (final item in last.entries) {
        final ts = item.value;
        if (ts > lastModTimeTs) {
          lastModTimeTs = ts;
        }
      }
      if (lastModTimeTs > lastModTime) {
        lastModTime = lastModTimeTs;
      }
    }
    return lastModTime;
  }
}
