import 'package:fl_lib/fl_lib.dart';
import 'package:server_box/data/model/container/type.dart';
import 'package:server_box/data/res/store.dart';
import 'package:sqlite3/sqlite3.dart';

/// Per-server container settings: the runtime the user picked, and the host to
/// reach it on.
///
/// Not an [EntityStore]: both are children of `server`, so neither carries its
/// own `updated_at` and there is nothing here to tombstone. A change is a
/// change to the server, which is what [ServerStore.touch] records — and what
/// makes the row travel with the server it belongs to instead of arriving
/// before it.
///
/// The keys these replaced were `containerHost<type><serverId>` and
/// `providerConfig<serverId>` in one K-V store, so nothing stopped a host
/// belonging to a server that had been deleted, and a serverId beginning with
/// `docker` would have been read as a runtime name.
class ContainerStore {
  ContainerStore();

  static final instance = ContainerStore();

  Database get _db => SqliteDb.instance;

  /// The host for [id] under [type], or null to use the runtime's own default.
  String? fetch(String? id, ContainerType type) {
    if (id == null) return null;
    final rows = _db.select(
      'SELECT host FROM container_host WHERE server_id = ? AND type = ?;',
      [id, type.name],
    );
    return rows.singleOrNull?['host'] as String?;
  }

  void put(String id, ContainerType type, String host) {
    SqliteStore.transact(() {
      _db.execute(
        'INSERT INTO container_host (server_id, type, host) VALUES (?, ?, ?) '
        'ON CONFLICT (server_id, type) DO UPDATE SET host = excluded.host;',
        [id, type.name, host],
      );
      Stores.server.synced.stamp(id);
    });
    Stores.server.invalidate();
  }

  void removeHost(String id, ContainerType type) {
    SqliteStore.transact(() {
      _db.execute(
        'DELETE FROM container_host WHERE server_id = ? AND type = ?;',
        [id, type.name],
      );
      Stores.server.synced.stamp(id);
    });
    Stores.server.invalidate();
  }

  /// The runtime chosen for [id], falling back to the global default.
  ContainerType getType(String id) {
    final rows = _db.select(
      'SELECT type FROM container_runtime WHERE server_id = ?;',
      [id],
    );
    final name = rows.singleOrNull?['type'] as String?;
    return ContainerType.values.firstWhereOrNull((e) => e.name == name) ??
        defaultType;
  }

  ContainerType get defaultType => Stores.setting.usePodman.get()
      ? ContainerType.podman
      : ContainerType.docker;

  /// Records [type] for [id], or drops the row when it matches the default —
  /// so a later change to the global setting still reaches servers the user
  /// never chose one for.
  void setType(ContainerType type, String id) {
    SqliteStore.transact(() {
      if (type == defaultType) {
        _db.execute('DELETE FROM container_runtime WHERE server_id = ?;', [id]);
      } else {
        _db.execute(
          'INSERT INTO container_runtime (server_id, type) VALUES (?, ?) '
          'ON CONFLICT (server_id) DO UPDATE SET type = excluded.type;',
          [id, type.name],
        );
      }
      Stores.server.synced.stamp(id);
    });
    Stores.server.invalidate();
  }

  /// Everything this store holds, keyed the way a backup carries it.
  ///
  /// One entry per server, so a restore writes both tables from one object
  /// rather than reconstructing the old flattened key names.
  Map<String, Object?> getAllMap() {
    final out = <String, Map<String, Object?>>{};
    for (final row in _db.select(
      'SELECT server_id, type, host FROM container_host;',
    )) {
      (out[row['server_id'] as String] ??= {})['host_${row['type']}'] =
          row['host'] as String;
    }
    for (final row in _db.select(
      'SELECT server_id, type FROM container_runtime;',
    )) {
      (out[row['server_id'] as String] ??= {})['runtime'] =
          row['type'] as String;
    }
    return out;
  }

  /// Restores the flattened map the v1 backup format carries.
  ///
  /// That format holds this store's old K-V keys verbatim:
  /// `containerHost<type><serverId>`, `providerConfig<serverId>`, and a bare
  /// `<serverId>` for the Docker host from before there was a runtime to name.
  void restoreLegacyMap(Map<String, Object?> flat) {
    const hostPrefix = 'containerHost';
    const typePrefix = 'providerConfig';

    flat.forEach((key, value) {
      if (value is! String || value.isEmpty) return;
      if (key.startsWith(hostPrefix)) {
        final rest = key.substring(hostPrefix.length);
        final type = ContainerType.values.firstWhereOrNull(
          (e) => rest.startsWith(e.name),
        );
        if (type == null) return;
        _restoreHost(rest.substring(type.name.length), type, value);
        return;
      }
      if (key.startsWith(typePrefix)) {
        final serverId = key.substring(typePrefix.length);
        final type = ContainerType.values.firstWhereOrNull(
          (e) => value.endsWith(e.name),
        );
        if (type == null || !_known(serverId)) return;
        setType(type, serverId);
        return;
      }
      _restoreHost(key, ContainerType.docker, value);
    });
  }

  void _restoreHost(String serverId, ContainerType type, String host) {
    if (!_known(serverId)) return;
    put(serverId, type, host);
  }

  /// Both tables have a foreign key, and a backup can name a server this device
  /// deleted.
  bool _known(String serverId) => Stores.server.fetchOneRaw(serverId) != null;

  /// Writes one entry of [getAllMap] back. Skips a server that is not here:
  /// both tables have a foreign key, and a backup can name a server this
  /// device deleted.
  bool restoreOne(String serverId, Object? value, {bool notify = true}) {
    if (value is! Map || !_known(serverId)) return false;

    SqliteStore.transact(() {
      // One backup entry is the complete state for this server. Rows absent
      // from it were removed on the source device and must not survive here.
      _db.execute('DELETE FROM container_host WHERE server_id = ?;', [
        serverId,
      ]);
      _db.execute('DELETE FROM container_runtime WHERE server_id = ?;', [
        serverId,
      ]);

      for (final type in ContainerType.values) {
        final host = value['host_${type.name}'];
        if (host is! String || host.isEmpty) continue;
        _db.execute(
          'INSERT INTO container_host (server_id, type, host) VALUES (?, ?, ?);',
          [serverId, type.name, host],
        );
      }

      final runtime = ContainerType.values.firstWhereOrNull(
        (type) => type.name == value['runtime'],
      );
      if (runtime != null) {
        // Presence in the backup means it was explicit on the source device,
        // even when it happens to equal this device's current global default.
        _db.execute(
          'INSERT INTO container_runtime (server_id, type) VALUES (?, ?);',
          [serverId, runtime.name],
        );
      }
      Stores.server.synced.stamp(serverId);
    });
    if (notify) Stores.server.invalidate();
    return true;
  }
}
