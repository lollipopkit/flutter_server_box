import 'dart:async';
import 'dart:convert';

import 'package:fl_lib/fl_lib.dart';
import 'package:sqlite3/sqlite3.dart';

/// Raised when a write would collide with a `UNIQUE` column.
///
/// Names are unique in the schema rather than in the two pages that can create
/// a record, so this is where a duplicate is found. The pages turn it into a
/// message; without it the failure is a raw `SqliteException` on the way out of
/// a button handler.
class DuplicateNameException implements Exception {
  const DuplicateNameException(this.name);

  final String name;

  @override
  String toString() => 'DuplicateNameException: $name';
}

/// One table that carries `updated_at` and `rev`, and the writes that keep
/// them true.
///
/// Separate from [EntityStore] because a store is not always one table: the
/// container settings are two, keyed differently, and both have to be stamped
/// and tombstoned the same way.
class SyncedTable {
  const SyncedTable(this.table, {this.idColumn = 'id'});

  /// One of `Tables.syncRoots`.
  final String table;

  /// The column a row is addressed by, and what a tombstone records.
  final String idColumn;

  Database get db => SqliteDb.instance;

  /// Writes one row, leaving columns it does not name alone.
  ///
  /// Not `INSERT OR REPLACE`: that deletes the row and inserts a new one, so
  /// every column absent from the statement goes back to its default. Here
  /// that silently reset `rev` to 0 on every write, which is the one thing
  /// `rev` exists to prevent — two edits in the same millisecond became
  /// indistinguishable again. It would also fire every `ON DELETE CASCADE`
  /// pointing at the row, taking the children with it.
  void upsert(
    List<String> columns,
    List<Object?> values, {
    List<String>? keyColumns,
    String? into,
  }) {
    final keys = keyColumns ?? [idColumn];
    final placeholders = List.filled(columns.length, '?').join(', ');
    final assignments = [
      for (final c in columns)
        if (!keys.contains(c)) '$c = excluded.$c',
    ].join(', ');
    db.execute(
      'INSERT INTO ${into ?? table} (${columns.join(', ')}) '
      'VALUES ($placeholders) '
      'ON CONFLICT (${keys.join(', ')}) DO UPDATE SET $assignments;',
      values,
    );
  }

  /// Marks the record changed, for the incremental sync to select on.
  ///
  /// `rev` moves too: two edits inside one millisecond are indistinguishable
  /// by the clock alone.
  void stamp(String id, {int? at}) {
    db.execute(
      'UPDATE $table SET updated_at = ?, rev = rev + 1 WHERE $idColumn = ?;',
      [at ?? DateTimeX.timestamp, id],
    );
    db.execute('DELETE FROM tombstone WHERE tbl = ? AND row_id = ?;', [
      table,
      id,
    ]);
  }

  /// Records that this record existed and no longer does.
  ///
  /// A peer that still holds the row would otherwise read its absence as an
  /// addition and put it back on the next sync.
  void tombstone(String id, {int? at}) {
    db.execute(
      'INSERT OR REPLACE INTO tombstone (tbl, row_id, deleted_at) '
      'VALUES (?, ?, ?);',
      [table, id, at ?? DateTimeX.timestamp],
    );
  }

  /// The newest change this table holds, including deletions.
  ///
  /// What `SqliteStore.lastUpdateTs` was for a K-V store, and read for the same
  /// reason: sync compares it against the backup's to decide which side wins. A
  /// delete counts — otherwise a device whose only change was removing a server
  /// looks unchanged and gets the server pushed back to it.
  int get lastModTime {
    final rows = db.select(
      'SELECT MAX(t) AS t FROM ('
      '  SELECT MAX(updated_at) AS t FROM $table'
      '  UNION ALL'
      '  SELECT MAX(deleted_at) FROM tombstone WHERE tbl = ?'
      ');',
      [table],
    );
    return (rows.singleOrNull?['t'] as int?) ?? 0;
  }
}

/// A store whose records are rows in a table of their own.
///
/// Not a [KvStore]: there is no key-addressed `get`/`set` here, because the
/// point of the move was that these records have columns, relations and
/// constraints. What it keeps is the shape the app already talks to —
/// [fetch], [fetchOneRaw], [put], [delete] — so a caller passing a model
/// around never learns which of the two backs it.
///
/// Change notification replaces what `box.watch()` and `SqliteStore.watch()`
/// gave: SQLite has no change feed, so writes announce themselves.
abstract class EntityStore<T extends Object> {
  /// The table this store owns, one of `Tables.syncRoots`.
  ///
  /// A getter rather than a constructor argument: the name is fixed by the
  /// schema Drift owns, so there is nothing for a caller to choose.
  String get table;

  /// The column a row is addressed by.
  String get idColumn => 'id';

  late final SyncedTable synced = SyncedTable(table, idColumn: idColumn);

  Database get db => SqliteDb.instance;

  final _changes = StreamController<void>.broadcast();
  List<T>? _cache;

  /// Fires after any write through this store.
  Stream<void> watch() => _changes.stream;

  /// The id of [item], which is never something the user typed.
  String idOf(T item);

  /// The user-typed name of [item], used only to describe a collision.
  String? nameOf(T item) => null;

  /// [item] as a backup carries it.
  Map<String, dynamic> toJson(T item);

  /// Rebuilds one record from what a backup carried.
  ///
  /// Returns null for anything unreadable — a restore skips that record rather
  /// than failing over it.
  T? fromJson(Map<String, dynamic> json);

  /// The incoming record, given the id it should be written under.
  ///
  /// The default is the id it arrived with. A store whose records were keyed by
  /// name before ids existed overrides this: a backup from then carries no id,
  /// `fromJson` generates a fresh one on every decode, and without matching the
  /// name to what is already here, restoring the same file twice would try to
  /// insert the record again — which the unique name refuses.
  T reconcile(T incoming) => incoming;

  /// Reads every record. Implementations do this in as few statements as they
  /// can: a query per row is what the key-value layout forced and this exists
  /// to stop.
  List<T> readAll();

  /// Every record, cached until the next write.
  ///
  /// A copy, so a caller sorting or filtering the result cannot reorder the
  /// cache everyone else reads. The cache is dropped by the write methods
  /// rather than by watching the database, because nothing can reach these
  /// tables except through here.
  List<T> fetch() => List<T>.from(_cache ??= readAll());

  T? fetchOneRaw(String id) {
    for (final item in _cache ??= readAll()) {
      if (idOf(item) == id) return item;
    }
    return null;
  }

  bool have(T item) => fetchOneRaw(idOf(item)) != null;

  List<String> keys() => (_cache ??= readAll()).map(idOf).toList();

  /// Writes [item], as one transaction with its child rows.
  void put(T item) {
    try {
      SqliteStore.transact(() {
        write(item);
        writeLinks(item);
        synced.stamp(idOf(item));
      });
    } on SqliteException catch (e) {
      if (e.extendedResultCode == _uniqueViolation) {
        throw DuplicateNameException(nameOf(item) ?? idOf(item));
      }
      rethrow;
    }
    invalidate();
  }

  static const _uniqueViolation = 2067; // SQLITE_CONSTRAINT_UNIQUE

  /// Inserts or replaces the row and its children. Called inside a
  /// transaction, with the timestamp applied afterwards.
  void write(T item);

  /// Links [item] to other records of the same table.
  ///
  /// A second pass, because a foreign key pointing into this table cannot be
  /// satisfied while the batch is still being written: a jump host is a
  /// server, and the row it names may come later in the same restore. Writing
  /// it inline dropped every forward reference.
  void writeLinks(T item) {}

  void upsert(
    List<String> columns,
    List<Object?> values, {
    List<String>? keyColumns,
    String? into,
  }) => synced.upsert(columns, values, keyColumns: keyColumns, into: into);

  void update(T old, T neu) {
    if (idOf(old) != idOf(neu)) {
      // An id is not something the user edits, so this is a bug rather than a
      // rename. Renaming what the user *did* type is an ordinary column write.
      throw ArgumentError('cannot change the id of a $T');
    }
    put(neu);
  }

  void delete(T item) => deleteById(idOf(item));

  void deleteById(String id) {
    SqliteStore.transact(() {
      // Children go with it: every child table declares ON DELETE CASCADE, so
      // this is one statement rather than the six the old code hand-wrote —
      // and the four it forgot.
      db.execute('DELETE FROM $table WHERE $idColumn = ?;', [id]);
      synced.tombstone(id);
    });
    invalidate();
  }

  /// `Future<bool>` to match `SqliteStore.clear`, which callers guard on: a
  /// store is a store at the call site, whichever shape backs it. Failure is a
  /// throw, so this only ever answers true.
  Future<bool> clear() async {
    SqliteStore.transact(() {
      for (final id in keys()) {
        synced.tombstone(id);
      }
      db.execute('DELETE FROM $table;');
    });
    invalidate();
    return true;
  }

  /// Bumps the parent after a child row changed, so an edit to a tag or an env
  /// is a change to the server that owns it.
  void touch(String id) {
    SqliteStore.transact(() => synced.stamp(id));
    invalidate();
  }

  int get lastModTime => synced.lastModTime;

  /// When each record last changed, deletions included.
  ///
  /// A tombstone's id is in here with the time it was deleted and *not* in
  /// [getAllMap], which is what tells a merging peer the record was removed
  /// rather than never seen.
  Map<String, int> get timestamps => {
    for (final row in db.select(
      'SELECT $idColumn AS id, updated_at FROM $table;',
    ))
      row['id'] as String: row['updated_at'] as int? ?? 0,
    for (final row in db.select(
      'SELECT row_id, deleted_at FROM tombstone WHERE tbl = ?;',
      [table],
    ))
      row['row_id'] as String: row['deleted_at'] as int? ?? 0,
  };

  /// Everything this store holds, in the shape a backup carries.
  ///
  /// The timestamps ride along under the same key a K-V store uses, so one
  /// envelope describes both kinds of store and [merge] can be the same
  /// last-write-wins rule on either side.
  Map<String, Object?> getAllMap() => {
    for (final item in fetch()) idOf(item): toJson(item),
    lastModKey: timestamps,
  };

  /// Matches `KvStore.lastUpdateTsKey`, and starts with the internal prefix so
  /// nothing mistakes it for a record.
  static const lastModKey = StoreDefaults.defaultLastUpdateTsKey;

  /// Folds a backup's records into this store, newest write winning per record.
  ///
  /// [force] takes the backup's version of every record regardless of when
  /// either side changed. Otherwise a record moves only if the backup's
  /// timestamp is the later one — which is also how a delete travels: the id is
  /// in the backup's timestamps and not among its records.
  ///
  /// Returns whether anything changed, which is what tells a provider to
  /// reload.
  bool merge(Map<String, Object?> backupData, {required bool force}) {
    final incoming = _timestampsOf(backupData[lastModKey]);
    final current = timestamps;
    final records = backupData.keys
        .where((k) => !k.startsWith(StoreDefaults.prefixKey))
        .toSet();

    var changed = false;
    SqliteStore.transact(() {
      final written = <T>[];
      for (final id in {...records, ...current.keys}) {
        final bakTs = incoming[id];
        if (!force && (bakTs ?? 0) <= (current[id] ?? 0)) continue;
        // A backup with no timestamp for this record — an older envelope, or
        // one written before the store carried them — is stamped as now.
        // Stamping 0 would leave the record looking older than anything, and
        // the next sync would take it straight back out.
        final at = bakTs ?? DateTimeX.timestamp;

        if (!records.contains(id)) {
          if (!current.containsKey(id)) continue;
          db.execute('DELETE FROM $table WHERE $idColumn = ?;', [id]);
          synced.tombstone(id, at: at);
          changed = true;
          continue;
        }

        final raw = backupData[id];
        if (raw is! Map) continue;
        final item = fromJson(Map<String, dynamic>.from(raw));
        if (item == null) continue;
        try {
          final resolved = reconcile(item);
          write(resolved);
          written.add(resolved);
          synced.stamp(idOf(resolved), at: at);
          changed = true;
        } on SqliteException catch (e) {
          // One record that cannot be written must not fail the restore: a
          // backup can name a server this device deleted, and refusing the
          // whole file over it would leave the user with neither copy.
          Loggers.app.warning('Restore skipped $table/$id', e);
        }
      }
      // Once every row exists, so a reference to one written later still lands.
      for (final item in written) {
        writeLinks(item);
      }
    });
    if (changed) invalidate();
    return changed;
  }

  /// Replaces everything with [items], for the v1 backup format, which carries
  /// no per-record timestamps and so can only be taken or left whole.
  bool replaceAll(Iterable<T> items) {
    SqliteStore.transact(() {
      for (final id in keys()) {
        synced.tombstone(id);
      }
      db.execute('DELETE FROM $table;');
      final written = <T>[];
      for (final item in items) {
        try {
          final resolved = reconcile(item);
          write(resolved);
          written.add(resolved);
          synced.stamp(idOf(resolved));
        } on SqliteException catch (e) {
          Loggers.app.warning('Restore skipped a $T', e);
        }
      }
      // Once every row exists — see [writeLinks].
      for (final item in written) {
        writeLinks(item);
      }
    });
    invalidate();
    return true;
  }

  static Map<String, int> _timestampsOf(Object? raw) {
    final decoded = raw is String ? _tryDecode(raw) : raw;
    if (decoded is! Map) return const {};
    return {
      for (final entry in decoded.entries)
        if (entry.value is int) '${entry.key}': entry.value as int,
    };
  }

  static Object? _tryDecode(String raw) {
    try {
      return json.decode(raw);
    } catch (_) {
      return null;
    }
  }

  /// Drops the cache without announcing anything.
  ///
  /// For a reader that wants to re-read — a provider reloading after a
  /// restore. [invalidate] is for a writer, and telling every listener to
  /// re-read because one of them chose to would be a loop.
  void dropCache() => _cache = null;

  void invalidate() {
    _cache = null;
    if (!_changes.isClosed) _changes.add(null);
  }
}
