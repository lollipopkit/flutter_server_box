import 'dart:async';
import 'dart:convert';

import 'package:fl_lib/fl_lib.dart';
import 'package:server_box/data/res/store.dart';
import 'package:server_box/data/store/entity_store.dart';
import 'package:server_box/data/store/sync_recorder.dart';
import 'package:sqlite3/sqlite3.dart';

/// A synced record as an op carries it (`docs/dev/sync-log.md`): read from the
/// stores to send, and written back when another device's op wins.
///
/// A record is `(c, id)` as [SyncRecorder] stamps it: a sync root's table and
/// the row's id, or `kv:<store>` and the key. A server carries its children
/// that are not records of their own: its container hosts and PVE settings.
abstract final class SyncRecords {
  static const _kvPrefix = 'kv:';

  /// [c]/[id] as it is now, JSON; null when it is not here (deleted).
  static Object? read(String c, String id) => reader()(c, id);

  /// [read] for many records: the stores and the servers' children are
  /// read once.
  static Object? Function(String c, String id) reader() {
    final entities = Stores.syncedEntities;
    Map<String, Object?>? containers;
    Map<String, Object?>? pves;
    return (c, id) {
      if (c.startsWith(_kvPrefix)) {
        final store = _kvStore(c);
        if (store == null || !_syncedKey(store, id)) return null;
        return store.get<Object>(id);
      }
      final store = entities[c];
      final item = store?.fetchOneRaw(id);
      if (store == null || item == null) return null;
      final json = _plain(store.toJson(item));
      if (c != Stores.server.table) return json;
      return {
        'spi': json,
        'container': (containers ??= Stores.container.getAllMap())[id] ?? const <String, Object?>{},
        'pve': (pves ??= Stores.pve.getAllMap())[id],
      };
    };
  }

  /// Writes [ops] (each `(c, id, h, d)`, already decided to win) as other
  /// devices' changes: each record stamped with its op's [h]. One
  /// transaction; a record this device cannot take (a name another record
  /// here holds) is left as it is and logged. Answers the collections
  /// written, for the caller to announce.
  static Set<String> write(List<({String c, String id, String h, Object? d})> ops) {
    final kv = <({SqliteStore store, String key, String h, Object? d})>[];
    final touched = <EntityStore>{};
    final entities = Stores.syncedEntities;
    SqliteStore.transact(() {
      final linked = <(EntityStore, Object, String)>[];
      for (final op in ops) {
        if (op.c.startsWith(_kvPrefix)) {
          final store = _kvStore(op.c);
          if (store != null && _syncedKey(store, op.id)) kv.add((store: store, key: op.id, h: op.h, d: op.d));
          continue;
        }
        final store = entities[op.c];
        if (store == null) continue;
        touched.add(store);
        SyncRecorder.receiving(op.h, () {
          final item = _entity(store, op);
          if (item != null) linked.add((store, item, op.h));
        });
      }
      // Once every row exists, so a reference to one written later in the
      // same ops still lands (a jump server).
      for (final (store, item, h) in linked) {
        SyncRecorder.receiving(h, () => store.writeLinks(item));
      }
      for (final op in kv) {
        SyncRecorder.receiving(op.h, () {
          final written = op.d == null
              ? op.store.remove(op.key, updateLastUpdateTsOnRemove: false)
              : op.store.set(op.key, op.d!, updateLastUpdateTsOnSet: false);
          if (!written) throw StateError('failed to write ${op.store.name}/${op.key}');
          SyncRecorder.record('kv:${op.store.name}', op.key);
        });
      }
    });
    // The snapshot sync's stamps, at each op's time, so it agrees with what
    // was written.
    for (final op in kv) {
      unawaited(op.store.updateLastUpdateTs(ts: SyncRecorder.msOf(op.h), key: op.key));
    }
    return {for (final store in touched) store.table, for (final op in kv) 'kv:${op.store.name}'};
  }

  /// Writes one entity op; the item to link once all are written, if any.
  static Object? _entity(EntityStore store, ({String c, String id, String h, Object? d}) op) {
    final isServer = store == Stores.server;
    final d = op.d;
    // The record this device holds the op's under ([_aliasOf]).
    final id = _aliasOf(op.c, op.id) ?? op.id;
    if (d == null) {
      store.db.execute('DELETE FROM ${store.table} WHERE ${store.idColumn} = ?;', [id]);
      store.synced.tombstone(id);
      if (id != op.id) SyncRecorder.record(op.c, op.id);
      return null;
    }
    if (d is! Map) return null;
    final json = isServer ? d['spi'] : d;
    if (json is! Map) return null;
    final map = Map<String, dynamic>.from(_plain(json) as Map);
    map['id'] = id;
    // Not [EntityStore.reconcile]: it matches by name alone, for backups
    // written before ids existed. An op names its record by id; another
    // record of the same name is another record unless it is the same in
    // every field ([_yieldName]).
    final yielded = _yieldName(store, op.c, id, op.h, map);
    if (yielded == null) {
      // The same record as one here under another id: that id is this one's.
      SyncRecorder.record(op.c, op.id);
      return null;
    }
    final item = store.fromJson(map);
    if (item == null) return null;
    try {
      SqliteStore.transact(() {
        yielded();
        store.write(item);
        store.synced.stamp(id);
        if (id != op.id) SyncRecorder.record(op.c, op.id);
        if (isServer) {
          // The container store asks the server store, whose cache predates
          // this row.
          store.dropCache();
          Stores.container.restoreOne(id, d['container'] ?? const <String, Object?>{}, notify: false);
          Stores.pve.restoreOne(id, d['pve'], notify: false);
        }
      });
    } on SqliteException catch (e) {
      Loggers.app.warning('Sync skipped ${op.c}/${op.id}', e);
      return null;
    }
    return item;
  }

  /// The names a table holds once (per `scope` column, its JSON field).
  static const _uniqueNames = <String, ({String scope, String scopeJson})?>{
    'private_key': null,
    'bmc_credential': null,
    'snippet': null,
    'remote_desktop_profile': (scope: 'server_id', scopeJson: 'serverId'),
  };

  /// Two devices naming two records alike: the one stamped later keeps the
  /// name, the other is given `<name> (<its id's start>)`. Derived from the
  /// stamps alone and written unstamped, so every device comes to the same
  /// names and none sends a rename that could race another's.
  ///
  /// The rename of the record here, if any, to run with the write (nothing
  /// to do: a no-op); null when the one here is the same record in every
  /// field but the id, as two devices that each restored a backup written
  /// before ids existed hold one: the op's id then names it from now on.
  static void Function()? _yieldName(EntityStore store, String c, String id, String h, Map<String, dynamic> map) {
    void none() {}
    if (!_uniqueNames.containsKey(store.table)) return none;
    final name = map['name'];
    if (name is! String) return none;
    final scope = _uniqueNames[store.table];
    final rows = store.db.select(
      'SELECT id FROM ${store.table} WHERE name = ? AND id != ?${scope == null ? '' : ' AND ${scope.scope} = ?'};',
      [name, id, if (scope != null) map[scope.scopeJson]],
    );
    if (rows.isEmpty) return none;
    final holder = rows.first['id'] as String;
    if (store.db.select('SELECT 1 FROM ${store.table} WHERE id = ?;', [id]).isEmpty && _sameBut(store, holder, map)) {
      _alias(c, id, holder);
      return null;
    }
    final held = SyncRecorder.stampsOf([(c, holder)])[(c, holder)] ?? '';
    if (h.compareTo(held) > 0) {
      final renamed = _suffixed(store, name, holder, scope, map);
      return () => store.db.execute('UPDATE ${store.table} SET name = ? WHERE id = ?;', [renamed, holder]);
    }
    map['name'] = _suffixed(store, name, id, scope, map);
    return none;
  }

  /// Whether [holder] is [map] in every field but the id.
  static bool _sameBut(EntityStore store, String holder, Map<String, dynamic> map) {
    final item = store.fetchOneRaw(holder);
    final incoming = store.fromJson({...map, 'id': holder});
    if (item == null || incoming == null) return false;
    return jsonEncode(store.toJson(item)) == jsonEncode(store.toJson(incoming));
  }

  /// The id this device holds another device's record [id] under, the same
  /// record made under two ids ([_yieldName]).
  static String? _aliasOf(String c, String id) =>
      SqliteDb.instance.select('SELECT v FROM sync_state WHERE k = ?;', ['alias:$c:$id']).firstOrNull?['v'] as String?;

  static void _alias(String c, String id, String local) => SqliteDb.instance.execute(
    'INSERT INTO sync_state (k, v) VALUES (?, ?) ON CONFLICT (k) DO UPDATE SET v = excluded.v;',
    ['alias:$c:$id', local],
  );

  static String _suffixed(EntityStore store, String name, String id, ({String scope, String scopeJson})? scope, Map<String, dynamic> map) {
    for (final len in [6, id.length]) {
      final candidate = '$name (${id.substring(0, len.clamp(0, id.length))})';
      final taken = store.db.select(
        'SELECT 1 FROM ${store.table} WHERE name = ? AND id != ?${scope == null ? '' : ' AND ${scope.scope} = ?'};',
        [candidate, id, if (scope != null) map[scope.scopeJson]],
      );
      if (taken.isEmpty) return candidate;
    }
    return '$name ($id)';
  }

  static SqliteStore? _kvStore(String c) {
    final name = c.substring(_kvPrefix.length);
    if (!SyncRecorder.syncedStores.contains(name)) return null;
    return name == Stores.setting.name ? Stores.setting : null;
  }

  static bool _syncedKey(SqliteStore store, String key) => !store.isInternalKey(key) && !store.isDeviceLocalKey(key);

  /// [value] as plain JSON (maps, lists, primitives), as another device
  /// decodes it.
  static Object? _plain(Object? value) => json.decode(json.encode(value));
}
