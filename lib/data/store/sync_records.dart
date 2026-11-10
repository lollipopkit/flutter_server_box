import 'dart:convert';

import 'package:fl_lib/fl_lib.dart';
import 'package:server_box/core/ssh/key_passphrase.dart';
import 'package:server_box/data/store/benchmark.dart';
import 'package:server_box/data/store/entity_store.dart';
import 'package:server_box/data/store/picked_files.dart';
import 'package:server_box/data/store/store_reload.dart';
import 'package:server_box/data/store/stores.dart';
import 'package:server_box/data/store/sync_skills.dart';
import 'package:server_box/data/store/sync_themes.dart';
import 'package:sqlite3/sqlite3.dart';

/// ServerBox's records for fl_lib's [SyncRecords]: the entity tables, and the
/// kinds kept outside the stores (themes, picked files, skills, benchmarks).
abstract final class ServerSyncRecords {
  /// Registers them, and what tells the app of other devices' ops. Before any
  /// sync runs.
  static void install() {
    SyncRecords.tables = EntityRecords.instance;
    SyncRecords.kinds
      ..clear()
      ..addAll({
        // A theme is added only: one removed here says nothing to the others.
        SyncThemes.c: SyncKind.batched(
          reader: () {
            Future<Map<String, Object?>?>? themes;
            return (id) => (themes ??= SyncThemes.read()).then(
              (t) => t == null ? SyncRecords.unread : t[id] ?? SyncRecords.silent,
            );
          },
          stamp: SyncThemes.stamp,
          install: SyncThemes.install,
        ),
        PickedFiles.c: const SyncKind(read: PickedFiles.read, stamp: PickedFiles.stamp, install: PickedFiles.install),
        SyncSkills.c: const SyncKind(read: SyncSkills.read, stamp: SyncSkills.stamp, install: SyncSkills.install),
        BenchmarkStore.c: SyncKind(read: (id) => Stores.benchmark.read(id), install: (ops) => Stores.benchmark.install(ops)),
      });
    SyncRecords.afterRead = (carries) async {
      // Read past: what could not be written then is tried again.
      if (carries(BenchmarkStore.c)) Stores.benchmark.retry();
      if (carries(SyncThemes.c)) await SyncThemes.retry();
    };
    SyncRecords.announce = _announce;
  }

  /// Tells the app what other devices' ops changed, as a backup's merge does.
  static void _announce(List<SyncOp> won, Set<String> written) {
    final keysBefore = EntityRecords.instance._keysBefore;
    EntityRecords.instance._keysBefore = null;
    // The preset may have come before or after its theme.
    if (won.any((op) => op.c == SyncThemes.c) || written.contains('kv:${Stores.setting.name}')) SyncThemes.reselect();
    final servers = written.contains(Stores.server.table);
    if (written.contains(Stores.key.table)) {
      Stores.key.invalidate();
      if (keysBefore != null) KeyPassphrases.forgetGone(keysBefore, Stores.key.fetch().map((e) => e.key));
    }
    if (written.contains(Stores.bmcCredential.table)) Stores.bmcCredential.invalidate();
    if (servers) {
      Stores.server.invalidate();
      // A server's delete cascades these rows.
      Stores.portForward.invalidate();
      Stores.remoteDesktop.invalidate();
      Stores.snippet.invalidate();
      Stores.pve.invalidate();
    }
    if (written.contains(Stores.snippet.table)) Stores.snippet.invalidate();
    if (written.contains(Stores.portForward.table)) Stores.portForward.invalidate();
    if (written.contains(Stores.remoteDesktop.table)) Stores.remoteDesktop.invalidate();
    StoreReload.after({
      if (servers) ...{ReloadedStore.servers, ReloadedStore.containers},
      if (written.contains(Stores.snippet.table)) ReloadedStore.snippets,
      if (written.contains(Stores.key.table)) ReloadedStore.keys,
      if (written.contains(Stores.bmcCredential.table)) ReloadedStore.bmcCredentials,
    });
  }
}

/// The entity tables as records: a sync root's table and the row's id. A
/// server carries its children that are not records of their own: its
/// container hosts and PVE settings.
final class EntityRecords implements SyncTableRecords {
  EntityRecords._();

  static final instance = EntityRecords._();

  /// The private keys before a write that touched them: whose passphrases go
  /// with them ([ServerSyncRecords._announce]).
  List<String>? _keysBefore;

  @override
  bool claims(String c) => Stores.syncedEntities.containsKey(c);

  @override
  Object? Function(String c, String id) reader() {
    final entities = Stores.syncedEntities;
    Map<String, Object?>? containers;
    Map<String, Object?>? pves;
    return (c, id) {
      final store = entities[c];
      final item = store?.fetchOneRaw(id);
      if (store == null || item == null) return null;
      final json = SyncRecords.plain(store.toJson(item));
      if (c != Stores.server.table) return json;
      return {
        'spi': json,
        'container': (containers ??= Stores.container.getAllMap())[id] ?? const <String, Object?>{},
        'pve': (pves ??= Stores.pve.getAllMap())[id],
      };
    };
  }

  /// One record kept by an entity table, for a test.
  static Object? read(String c, String id) => instance.reader()(c, id);

  /// Writes [ops] (each already decided to win) as other devices' changes,
  /// each record stamped with its op's [SyncOp.h], inside the stores'
  /// transaction. A record this device cannot take (a name another record
  /// here holds) is left as it is and logged.
  @override
  Set<String> write(List<SyncOp> ops) {
    final entities = Stores.syncedEntities;
    if (ops.any((op) => op.c == Stores.key.table)) {
      _keysBefore ??= [for (final k in Stores.key.fetch()) k.key];
    }
    final touched = <EntityStore>{};
    final linked = <(EntityStore, Object, String)>[];
    for (final op in ops) {
      final store = entities[op.c];
      if (store == null) continue;
      touched.add(store);
      SyncRecorder.receiving(op.h, () {
        final item = _entity(store, op);
        if (item != null) linked.add((store, item, op.h));
      });
    }
    // Once every row exists, so a reference to one written later in the same
    // ops still lands (a jump server).
    for (final (store, item, h) in linked) {
      SyncRecorder.receiving(h, () => store.writeLinks(item));
    }
    return {for (final store in touched) store.table};
  }

  /// Writes one entity op; the item to link once all are written, if any.
  static Object? _entity(EntityStore store, SyncOp op) {
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
    final map = Map<String, dynamic>.from(SyncRecords.plain(json) as Map);
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
}
