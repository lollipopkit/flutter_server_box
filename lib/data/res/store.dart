import 'package:get_it/get_it.dart';
import 'package:server_box/data/db/app_db.dart';
import 'package:server_box/data/store/connection_stats.dart';
import 'package:server_box/data/store/container.dart';
import 'package:server_box/data/store/history.dart';
import 'package:server_box/data/store/private_key.dart';
import 'package:server_box/data/store/server.dart';
import 'package:server_box/data/store/setting.dart';
import 'package:server_box/data/store/snippet.dart';

final GetIt getIt = GetIt.instance;

abstract final class Stores {
  static const List<String> _timestampedTables = <String>[
    'servers',
    'server_customs',
    'server_wol_cfgs',
    'snippets',
    'private_keys',
    'container_hosts',
    'connection_stats_records',
  ];

  static SettingStore get setting => getIt<SettingStore>();
  static ServerStore get server => getIt<ServerStore>();
  static ContainerStore get container => getIt<ContainerStore>();
  static PrivateKeyStore get key => getIt<PrivateKeyStore>();
  static SnippetStore get snippet => getIt<SnippetStore>();
  static HistoryStore get history => getIt<HistoryStore>();
  static ConnectionStatsStore get connectionStats =>
      getIt<ConnectionStatsStore>();

  static Future<void> init() async {
    if (!getIt.isRegistered<SettingStore>()) {
      getIt.registerLazySingleton<SettingStore>(() => SettingStore.instance);
      getIt.registerLazySingleton<ServerStore>(() => ServerStore.instance);
      getIt.registerLazySingleton<ContainerStore>(
        () => ContainerStore.instance,
      );
      getIt.registerLazySingleton<PrivateKeyStore>(
        () => PrivateKeyStore.instance,
      );
      getIt.registerLazySingleton<SnippetStore>(() => SnippetStore.instance);
      getIt.registerLazySingleton<HistoryStore>(() => HistoryStore.instance);
      getIt.registerLazySingleton<ConnectionStatsStore>(
        () => ConnectionStatsStore.instance,
      );
    }

    // Warm up app database.
    await AppDb.instance.customSelect('SELECT 1').getSingleOrNull();

    await setting.init();
    await history.init();
    await container.init();
  }

  static Future<int> lastModTime() async {
    var last = 0;

    void mergeMap(Map<String, int>? map) {
      if (map == null) return;
      for (final ts in map.values) {
        if (ts > last) last = ts;
      }
    }

    Future<void> mergeTable(String tableName) async {
      final row = await AppDb.instance
          .customSelect('SELECT MAX(updated_at) AS max_ts FROM $tableName')
          .getSingleOrNull();
      final rawTs = row?.data['max_ts'];
      final ts = switch (rawTs) {
        final int v => v,
        final num v => v.toInt(),
        _ => 0,
      };
      if (ts > last) {
        last = ts;
      }
    }

    mergeMap(setting.lastUpdateTs);
    mergeMap(history.lastUpdateTs);
    mergeMap(container.lastUpdateTs);

    for (final table in _timestampedTables) {
      await mergeTable(table);
    }

    return last;
  }
}
