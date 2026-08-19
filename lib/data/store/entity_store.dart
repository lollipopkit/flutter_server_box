import 'dart:async';

import 'package:fl_lib/fl_lib.dart';
import 'package:sqlite3/sqlite3.dart';

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
  EntityStore(this.table);

  /// The table this store owns. Its [syncRoots] entry, so it has
  /// `updated_at` and `rev`.
  final String table;

  Database get db => SqliteDb.instance;

  final _changes = StreamController<void>.broadcast();
  List<T>? _cache;

  /// Fires after any write through this store.
  Stream<void> watch() => _changes.stream;

  /// The id of [item], which is never something the user typed.
  String idOf(T item);

  /// Reads every record. Implementations do this in as few statements as they
  /// can: a query per row is what the key-value layout forced and this exists
  /// to stop.
  List<T> readAll();

  /// Every record, cached until the next write.
  ///
  /// The cache is dropped by the write methods rather than by watching the
  /// database, because nothing can reach these tables except through here.
  List<T> fetch() => _cache ??= readAll();

  T? fetchOneRaw(String id) {
    for (final item in fetch()) {
      if (idOf(item) == id) return item;
    }
    return null;
  }

  List<String> keys() => fetch().map(idOf).toList();

  /// Writes [item], as one transaction with its child rows.
  void put(T item) {
    SqliteStore.transact(() {
      write(item);
      _stamp(idOf(item));
    });
    invalidate();
  }

  /// Inserts or replaces the row and its children. Called inside a
  /// transaction, with the timestamp applied afterwards.
  void write(T item);

  /// Writes one row, leaving columns it does not name alone.
  ///
  /// Not `INSERT OR REPLACE`: that deletes the row and inserts a new one, so
  /// every column absent from the statement goes back to its default. Here
  /// that silently reset `rev` to 0 on every write, which is the one thing
  /// `rev` exists to prevent — two edits in the same millisecond became
  /// indistinguishable again.
  void upsert(String table, List<String> columns, List<Object?> values, {
    List<String> keyColumns = const ['id'],
  }) {
    final placeholders = List.filled(columns.length, '?').join(', ');
    final assignments = [
      for (final c in columns)
        if (!keyColumns.contains(c)) '$c = excluded.$c',
    ].join(', ');
    db.execute(
      'INSERT INTO $table (${columns.join(', ')}) VALUES ($placeholders) '
      'ON CONFLICT (${keyColumns.join(', ')}) DO UPDATE SET $assignments;',
      values,
    );
  }

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
      _tombstone(id);
    });
    invalidate();
  }

  void clear() {
    SqliteStore.transact(() {
      for (final id in keys()) {
        _tombstone(id);
      }
      db.execute('DELETE FROM $table;');
    });
    invalidate();
  }

  /// The column [deleteById] and [_stamp] match on.
  String get idColumn => 'id';

  /// Records that this record existed and no longer does.
  ///
  /// A peer that still holds the row would otherwise read its absence as an
  /// addition and put it back on the next sync.
  void _tombstone(String id) {
    db.execute(
      'INSERT OR REPLACE INTO tombstone (tbl, row_id, deleted_at) '
      'VALUES (?, ?, ?);',
      [table, id, DateTimeX.timestamp],
    );
  }

  /// Marks the record changed, for the incremental sync to select on.
  ///
  /// `rev` moves too: two edits inside one millisecond are indistinguishable
  /// by the clock alone.
  void _stamp(String id) {
    db.execute(
      'UPDATE $table SET updated_at = ?, rev = rev + 1 '
      'WHERE $idColumn = ?;',
      [DateTimeX.timestamp, id],
    );
    db.execute('DELETE FROM tombstone WHERE tbl = ? AND row_id = ?;', [
      table,
      id,
    ]);
  }

  /// Bumps the parent after a child row changed, so an edit to a tag or an env
  /// is a change to the server that owns it.
  void touch(String id) {
    SqliteStore.transact(() => _stamp(id));
    invalidate();
  }

  void invalidate() {
    _cache = null;
    if (!_changes.isClosed) _changes.add(null);
  }

  /// Kept for [Backup], which serialises whatever a store holds.
  Map<String, Object?> getAllMap();
}
