import 'package:fl_lib/fl_lib.dart';
import 'package:server_box/data/db/app_db.dart' as adb;
import 'package:server_box/data/model/container/type.dart';
import 'package:server_box/data/res/store.dart';

const _keyConfig = 'providerConfig';

class ContainerStore {
  ContainerStore._();

  static final instance = ContainerStore._();

  adb.AppDb get _db => adb.AppDb.instance;

  final PrefStore _cfg = PrefStore(
    name: 'container_cfg',
    prefix: 'container_cfg',
  );

  Map<String, int>? get lastUpdateTs => _cfg.lastUpdateTs;

  Future<void> init() async {
    await _cfg.init();
  }

  Future<String?> fetch(String? id) async {
    if (id == null) return null;
    final row = await (_db.select(
      _db.containerHosts,
    )..where((tbl) => tbl.serverId.equals(id))).getSingleOrNull();
    return row?.host;
  }

  Future<void> put(String id, String host) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await _db
        .into(_db.containerHosts)
        .insertOnConflictUpdate(
          adb.ContainerHostsCompanion.insert(
            serverId: id,
            host: host,
            updatedAt: now,
          ),
        );
  }

  Future<void> set(String id, String host) => put(id, host);

  Future<void> remove(String id) async {
    await (_db.delete(
      _db.containerHosts,
    )..where((tbl) => tbl.serverId.equals(id))).go();
  }

  ContainerType getType([String id = '']) {
    final cfg = _cfg.get<String>('$_keyConfig$id');
    if (cfg != null) {
      final type = ContainerType.values.firstWhereOrNull(
        (e) => e.toString() == cfg,
      );
      if (type != null) return type;
    }

    return defaultType;
  }

  ContainerType get defaultType {
    if (Stores.setting.usePodman.fetch()) return ContainerType.podman;
    return ContainerType.docker;
  }

  Future<void> setType(ContainerType type, [String id = '']) async {
    if (type == defaultType) {
      await _cfg.remove('$_keyConfig$id');
    } else {
      await _cfg.set('$_keyConfig$id', type.toString());
    }
  }

  Future<Map<String, Object?>> getAllMap({
    bool includeInternalKeys = StoreDefaults.defaultIncludeInternalKeys,
  }) async {
    final map = <String, Object?>{};

    final hosts = await _db.select(_db.containerHosts).get();
    for (final row in hosts) {
      map[row.serverId] = row.host;
    }

    final cfgKeys = _cfg.keys(includeInternalKeys: includeInternalKeys);
    for (final key in cfgKeys) {
      map[key] = _cfg.get(key);
    }

    return map;
  }

  Future<void> clear() async {
    await _db.delete(_db.containerHosts).go();
    await _cfg.clear();
  }
}
