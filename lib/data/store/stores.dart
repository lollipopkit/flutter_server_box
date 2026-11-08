import 'package:fl_lib/fl_lib.dart';
import 'package:fl_pi_llm_ui/fl_pi_llm_ui.dart' show LlmStores;
import 'package:get_it/get_it.dart';
import 'package:server_box/data/store/benchmark.dart';
import 'package:server_box/data/store/bmc_credential.dart';
import 'package:server_box/data/store/connection_stats.dart';
import 'package:server_box/data/store/container.dart';
import 'package:server_box/data/store/entity_store.dart';
import 'package:server_box/data/store/history.dart';
import 'package:server_box/data/store/migrations/m003_hive_to_sqlite.dart';
import 'package:server_box/data/store/port_forward.dart';
import 'package:server_box/data/store/private_key.dart';
import 'package:server_box/data/store/pve.dart';
import 'package:server_box/data/store/remote_desktop.dart';
import 'package:server_box/data/store/schema.dart';
import 'package:server_box/data/store/secret.dart';
import 'package:server_box/data/store/self_addr.dart';
import 'package:server_box/data/store/server.dart';
import 'package:server_box/data/store/server_dist.dart';
import 'package:server_box/data/store/setting.dart';
import 'package:server_box/data/store/snippet.dart';
import 'package:server_box/data/store/sync_recorder.dart';
import 'package:server_box/data/store/tables.dart';

final GetIt getIt = GetIt.instance;

extension SyncSqlitePropWrite<T extends Object> on StoreProp<T> {
  /// Performs a checked synchronous write, so a surrounding SQLite
  /// transaction can roll back when persistence fails.
  void putSync(T value) {
    final sqlite = store;
    if (sqlite is! SqliteStore ||
        !sqlite.set(
          key,
          value,
          toObj: toObj,
          updateLastUpdateTsOnSet: updateLastUpdateTsOnSet,
        )) {
      throw StateError('failed to persist "$key"');
    }
  }
}

abstract final class Stores {
  static SettingStore get setting => getIt<SettingStore>();
  static ServerStore get server => getIt<ServerStore>();
  static ContainerStore get container => getIt<ContainerStore>();

  /// Each server's PVE configuration — a child of `server`, see [PveStore].
  static PveStore get pve => getIt<PveStore>();
  static PrivateKeyStore get key => getIt<PrivateKeyStore>();
  static BmcCredentialStore get bmcCredential => getIt<BmcCredentialStore>();
  static SnippetStore get snippet => getIt<SnippetStore>();
  static HistoryStore get history => getIt<HistoryStore>();
  static ConnectionStatsStore get connectionStats =>
      getIt<ConnectionStatsStore>();
  static PortForwardStore get portForward => getIt<PortForwardStore>();
  static RemoteDesktopStore get remoteDesktop => getIt<RemoteDesktopStore>();

  /// What each server said its own address is.
  ///
  /// The only thing about the globe that is remembered. There was a second
  /// store beside it holding where each *host* was, and it went with the
  /// per-lookup network requests it existed for — see [IpGeo.shared.locate]. This one
  /// stays because it is not a cache of a computation: only the machine knows
  /// which public address is assigned to one of its interfaces, so nothing
  /// here can work it out again.
  static SelfAddrStore get selfAddr => getIt<SelfAddrStore>();
  static BenchmarkStore get benchmark => getIt<BenchmarkStore>();

  /// Saved sudo passwords, key passphrases and where the backup syncs to:
  /// the secrets this app keeps beside the data they open.
  static SudoPasswordStore get sudoPassword => SudoPasswordStore.instance;
  static KeyPassphraseStore get keyPassphrase => KeyPassphraseStore.instance;
  static SyncRemoteStore get syncRemote => SyncRemoteStore.instance;

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
  /// `container` and `pve` are absent because their rows are children of
  /// `server`: changing one stamps the server that owns it.
  static List<EntityStore> get _entityStores => [
    server,
    key,
    bmcCredential,
    snippet,
    portForward,
    remoteDesktop,
  ];

  /// The sync roots' tables: what `SyncRecorder` stamps as records.
  static List<String> get syncedTables => [for (final store in _entityStores) store.table];

  /// The stores of [syncedTables], by table.
  static Map<String, EntityStore> get syncedEntities => {for (final store in _entityStores) store.table: store};

  static Future<void> init() async {
    getIt.registerLazySingleton<SettingStore>(() => SettingStore.instance);
    getIt.registerLazySingleton<ServerStore>(() => ServerStore.instance);
    getIt.registerLazySingleton<ContainerStore>(() => ContainerStore.instance);
    getIt.registerLazySingleton<PveStore>(() => PveStore.instance);
    getIt.registerLazySingleton<PrivateKeyStore>(
      () => PrivateKeyStore.instance,
    );
    getIt.registerLazySingleton<BmcCredentialStore>(
      () => BmcCredentialStore.instance,
    );
    getIt.registerLazySingleton<SnippetStore>(() => SnippetStore.instance);
    getIt.registerLazySingleton<HistoryStore>(() => HistoryStore.instance);
    getIt.registerLazySingleton<ServerDistStore>(
      () => ServerDistStore.instance,
    );
    getIt.registerLazySingleton<ConnectionStatsStore>(
      () => ConnectionStatsStore.instance,
    );
    getIt.registerLazySingleton<PortForwardStore>(
      () => PortForwardStore.instance,
    );
    getIt.registerLazySingleton<RemoteDesktopStore>(
      () => RemoteDesktopStore.instance,
    );
    getIt.registerLazySingleton<SelfAddrStore>(() => SelfAddrStore.instance);
    getIt.registerLazySingleton<BenchmarkStore>(() => BenchmarkStore.instance);

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
    // And the dist cache, for the same reason. It is not an `EntityStore` and
    // so not in that list, but it is the same singleton holding the same kind
    // of copy — and its `put` short-circuits on what the cache says, so a
    // stale one would also stop the correct reading ever being written.
    serverDist.dropCache();

    await Future.wait([
      ..._kvStores.map((store) => store.init()),
      // Not in `_kvStores`, and that is the point: a server answering where it
      // is is not something the user did, so it must not move the clock sync
      // reads.
      selfAddr.init(),
      // The Agent's: its chats, providers, tool switches and memory. Not in
      // `_kvStores`: a conversation is a record of what was said, not an
      // edit, and stays on this device; the rest syncs as
      // `SyncRecorder.syncedStores` says.
      ...LlmStores.all.map((store) => store.init()),
      // The secrets, a sync category of their own.
      LlmStores.mcpSecret.init(),
      LlmStores.credential.init(),
      sudoPassword.init(),
      keyPassphrase.init(),
      syncRemote.init(),
    ]);

    // Refused here, once, before anything below writes: the stored version is
    // read out of the settings store, so this is the first point it can be,
    // and every write after it (the sweep, the Hive import, the retired keys)
    // would otherwise touch a database a newer build wrote — and the rescue
    // screen's "nothing has been changed" would be untrue. `main` catches it.
    final stored = setting.schemaVersion.fetch();
    if (stored > SchemaVersion.current) {
      throw SchemaTooNewException(stored: stored, supported: SchemaVersion.current);
    }

    connectionStats.init();

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
    for (final store in {..._kvStores, ...SyncRecorder.syncedStores.values}) {
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
