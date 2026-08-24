import 'dart:async';

import 'package:fl_lib/fl_lib.dart';
import 'package:meta/meta.dart';
import 'package:server_box/data/model/server/dist.dart';
import 'package:sqlite3/sqlite3.dart';

/// What each server was last seen running.
///
/// A distribution is a fact about the far end, observed rather than
/// configured, so nothing in a `Spi` says it and a server that has never
/// connected has none. Remembering the last reading is what lets a row draw
/// the right mark without holding a live status — which the pickers, the
/// known-hosts page and the order page all lack.
///
/// Read synchronously and cached in memory, like the rest of the stores here:
/// the UI reads this while building.
class ServerDistStore {
  ServerDistStore._(this._table);

  static final instance = ServerDistStore._('server_dist');

  /// A distinct table name would need distinct DDL, so a test shares the real
  /// one on an in-memory database instead. Present for symmetry with the
  /// other stores' `forTest`, and to make the sharing explicit at the call
  /// site rather than implicit in the singleton.
  @visibleForTesting
  ServerDistStore.forTest() : _table = 'server_dist';

  final String _table;

  Database get _db => SqliteDb.instance;

  /// Every reading, by server id.
  ///
  /// Cached whole rather than queried per row: the callers are list builders
  /// drawing one row per server, and a query each would be one statement per
  /// frame per row. Dropped by [_invalidate] on every write.
  Map<String, Dist> get _cache => _cached ??= _readAll();
  Map<String, Dist>? _cached;

  Map<String, Dist> _readAll() {
    final out = <String, Dist>{};
    for (final row in _db.select('SELECT server_id, dist FROM $_table;')) {
      final name = row['dist'] as String?;
      if (name == null) continue;
      // By name, so a value written by a build that knew a case this one does
      // not simply reads back as absent rather than throwing.
      final dist = Dist.values.firstWhereOrNull((e) => e.name == name);
      if (dist != null) out[row['server_id'] as String] = dist;
    }
    return out;
  }

  void _invalidate() {
    _cached = null;
    if (!_changes.isClosed) _changes.add(null);
  }

  final _changes = StreamController<void>.broadcast();

  /// Fires after any write, for a widget that has to redraw when a server it
  /// is showing reports its distribution for the first time.
  Stream<void> get changes => _changes.stream;

  /// The last reading for [serverId], or null if it has never reported one.
  Dist? get(String serverId) => _cache[serverId];

  /// Records [dist] for [serverId].
  ///
  /// A no-op when it has not changed, so a status poll every few seconds does
  /// not write a row and invalidate every list on every tick.
  void put(String serverId, Dist dist) {
    if (_cache[serverId] == dist) return;
    _db.execute(
      'INSERT INTO $_table (server_id, dist, updated_at) VALUES (?, ?, ?) '
      'ON CONFLICT (server_id) DO UPDATE SET '
      'dist = excluded.dist, updated_at = excluded.updated_at;',
      [serverId, dist.name, DateTimeX.timestamp],
    );
    _invalidate();
  }

  /// Forgets one server's reading.
  ///
  /// Deleting the server does this on its own — the foreign key cascades — so
  /// this is for a server that is still there and whose reading is known to be
  /// wrong.
  void remove(String serverId) {
    _db.execute('DELETE FROM $_table WHERE server_id = ?;', [serverId]);
    _invalidate();
  }

  /// Every reading, for a caller drawing a whole list at once.
  Map<String, Dist> all() => Map.unmodifiable(_cache);

  /// Drops the in-memory copy without announcing anything, for a reader that
  /// wants to re-read after something else wrote — a restore, say.
  void dropCache() => _cached = null;
}
