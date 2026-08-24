import 'package:fl_lib/fl_lib.dart';
import 'package:get_it/get_it.dart';
import 'package:server_box/data/store/agent_conversation.dart';
import 'package:server_box/data/store/bmc_credential.dart';
import 'package:server_box/data/store/connection_stats.dart';
import 'package:server_box/data/store/container.dart';
import 'package:server_box/data/store/entity_store.dart';
import 'package:server_box/data/store/history.dart';
import 'package:server_box/data/store/migrations/m003_hive_to_sqlite.dart';
import 'package:server_box/data/store/port_forward.dart';
import 'package:server_box/data/store/private_key.dart';
import 'package:server_box/data/store/server.dart';
import 'package:server_box/data/store/server_dist.dart';
import 'package:server_box/data/store/setting.dart';
import 'package:server_box/data/store/snippet.dart';
import 'package:server_box/data/store/tables.dart';

final GetIt getIt = GetIt.instance;

abstract final class Stores {
  static SettingStore get setting => getIt<SettingStore>();
  static ServerStore get server => getIt<ServerStore>();
  static ContainerStore get container => getIt<ContainerStore>();
  static PrivateKeyStore get key => getIt<PrivateKeyStore>();
  static BmcCredentialStore get bmcCredential => getIt<BmcCredentialStore>();
  static SnippetStore get snippet => getIt<SnippetStore>();
  static HistoryStore get history => getIt<HistoryStore>();
  static AgentConversationStore get agentConversation =>
      getIt<AgentConversationStore>();
  static ConnectionStatsStore get connectionStats =>
      getIt<ConnectionStatsStore>();
  static PortForwardStore get portForward => getIt<PortForwardStore>();

  /// What each server was last seen running. A cache of an observation, not a
  /// record anyone edits — see [ServerDistStore].
  static ServerDistStore get serverDist => getIt<ServerDistStore>();

  /// The key-value stores whose contents count as something the user changed.
  ///
  /// [lastModTime] is read off these and off [_entityStores], and sync uses that
  /// number to decide which side wins — so what belongs here is what a user
  /// edits, not what the app records. `connectionStats` used to be in this list
  /// and is not: connecting to a server is not an edit, and every attempt was
  /// marking the device as holding the newer copy of everything.
  static List<SqliteStore> get _kvStores => [setting, history];

  /// The same question asked of the stores that own tables.
  ///
  /// `container` is absent because its rows are children of `server`: changing
  /// a container host stamps the server that owns it.
  static List<EntityStore> get _entityStores =>
      [server, key, bmcCredential, snippet, portForward];

  static Future<void> init() async {
    getIt.registerLazySingleton<SettingStore>(() => SettingStore.instance);
    getIt.registerLazySingleton<ServerStore>(() => ServerStore.instance);
    getIt.registerLazySingleton<ContainerStore>(() => ContainerStore.instance);
    getIt.registerLazySingleton<PrivateKeyStore>(
      () => PrivateKeyStore.instance,
    );
    getIt.registerLazySingleton<BmcCredentialStore>(
      () => BmcCredentialStore.instance,
    );
    getIt.registerLazySingleton<SnippetStore>(() => SnippetStore.instance);
    getIt.registerLazySingleton<HistoryStore>(() => HistoryStore.instance);
    getIt.registerLazySingleton<AgentConversationStore>(
      () => AgentConversationStore.instance,
    );
    getIt.registerLazySingleton<ServerDistStore>(
      () => ServerDistStore.instance,
    );
    getIt.registerLazySingleton<ConnectionStatsStore>(
      () => ConnectionStatsStore.instance,
    );
    getIt.registerLazySingleton<PortForwardStore>(
      () => PortForwardStore.instance,
    );

    // First and on its own: everything below reaches the database, and a
    // `Future.wait` invokes every element before awaiting any of them — so
    // batching them with the call that is still opening the file has them
    // reach a database that is still null. It did, on every cold launch.
    await SqliteStore.openDatabase();

    // Then the entity schema, before anything can read or migrate it. Creating
    // it means opening Drift over this connection, which is why it is awaited
    // here rather than done inside a migration: a migration runs in one
    // synchronous transaction and cannot await anything.
    await createTables(SqliteDb.instance);

    // The entity stores are singletons holding a list cache, and this may not
    // be the database they last read: the sandbox import closes one, restores
    // the previous file and calls back in here. A cache from the old one would
    // outlive it, and nothing else would ever drop it.
    for (final store in _entityStores) {
      store.dropCache();
    }

    await Future.wait([
      ..._kvStores.map((store) => store.init()),
      // Not a table to create — only the per-launch sweep of expired rows.
      connectionStats.init(),
    ]);

    // Before every fixup below. Each of them writes a flag meaning "this device
    // has been dealt with", and running them against the empty stores would set
    // those flags over data that has not been copied across yet — so the
    // records that need converting would arrive after the only pass that would
    // have converted them.
    await HiveImport.runIfNeeded();

    await setting.removeRetiredKeys();
  }

  static int get lastModTime {
    var lastModTime = 0;
    for (final store in _kvStores) {
      final last = store.lastUpdateTs;
      if (last == null) continue;
      for (final ts in last.values) {
        if (ts > lastModTime) lastModTime = ts;
      }
    }
    for (final store in _entityStores) {
      final ts = store.lastModTime;
      if (ts > lastModTime) lastModTime = ts;
    }
    return lastModTime;
  }
}
