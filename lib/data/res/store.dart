import 'package:fl_lib/fl_lib.dart';
import 'package:get_it/get_it.dart';
import 'package:server_box/data/store/agent_conversation.dart';
import 'package:server_box/data/store/connection_stats.dart';
import 'package:server_box/data/store/container.dart';
import 'package:server_box/data/store/history.dart';
import 'package:server_box/data/store/migrations/m003_hive_to_sqlite.dart';
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
  static ConnectionStatsStore get connectionStats =>
      getIt<ConnectionStatsStore>();
  static PortForwardStore get portForward => getIt<PortForwardStore>();

  /// The stores whose contents count as something the user changed.
  ///
  /// [lastModTime] is read off these, and sync uses that number to decide which
  /// side wins — so what belongs here is what a user edits, not what the app
  /// records. `connectionStats` used to be in this list and is not: connecting
  /// to a server is not an edit, and every attempt was marking the device as
  /// holding the newer copy of everything.
  static List<SqliteStore> get _kvStores => [
    setting,
    server,
    container,
    key,
    snippet,
    history,
    portForward,
  ];

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

    // First and on its own. `connectionStats` and `agentConversation` create
    // their tables, which means reaching the database synchronously — and a
    // `Future.wait` invokes every element before awaiting any of them, so
    // batching them with the stores that are still opening the file would have
    // them reach a database that is still null. It did, on every cold launch.
    await SqliteStore.openDatabase();

    await Future.wait([
      ..._kvStores.map((store) => store.init()),
      // Their own tables rather than rows in `kv`, so they create those.
      connectionStats.init(),
      agentConversation.init(),
    ]);

    // Before every fixup below. Each of them writes a flag meaning "this device
    // has been dealt with", and running them against the empty stores would set
    // those flags over data that has not been copied across yet — so the
    // records that need converting would arrive after the only pass that would
    // have converted them.
    await HiveImport.runIfNeeded();

    await setting.removeRetiredKeys();

    // Migrate sshConnectionMode from old int values to bool
    setting.migrateSshConnectionMode();
    await setting.migrateHomeTabsAgent();
  }

  static int get lastModTime {
    var lastModTime = 0;
    for (final store in _kvStores) {
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
