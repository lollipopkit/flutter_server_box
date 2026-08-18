import 'package:fl_lib/fl_lib.dart';
import 'package:server_box/data/model/server/connection_stat.dart';
import 'package:sqlite3/sqlite3.dart';

/// Connection attempts, one row each.
///
/// A table rather than a K-V store because every question asked of it is a
/// range over one server's history, and answering those out of a K-V store took
/// a second store holding per-server lists of keys, plus the code to keep those
/// lists in step: rebuild, update-on-insert, prune-to-100 and expire-after-30-
/// days were four hand-written passes over the records. They are two `DELETE`
/// statements and an index here.
///
/// That second store was also the one thing in the app that was never
/// encrypted, because it was a Hive box opened without a cipher. Being a table
/// in the shared database, this is behind the same key as everything else.
class ConnectionStatsStore {
  ConnectionStatsStore._();

  static final instance = ConnectionStatsStore._();

  /// Kept per server, oldest dropped first.
  static const _maxRecordsPerServer = 100;

  /// Dropped regardless of the per-server count.
  static const _retention = Duration(days: 30);

  Database get _db => SqliteDb.instance;

  Future<void> init() async {
    _db.execute('''
CREATE TABLE IF NOT EXISTS conn_stat (
  id            TEXT    NOT NULL PRIMARY KEY,
  server_id     TEXT    NOT NULL,
  server_name   TEXT    NOT NULL,
  timestamp     INTEGER NOT NULL,
  result        TEXT    NOT NULL,
  error_message TEXT    NOT NULL DEFAULT '',
  duration_ms   INTEGER NOT NULL
) WITHOUT ROWID;
''');
    // Every read is "this server, newest first", and the per-server cap below
    // is the same order with a LIMIT.
    _db.execute(
      'CREATE INDEX IF NOT EXISTS idx_conn_stat_server_ts '
      'ON conn_stat(server_id, timestamp DESC);',
    );
    // The age sweep asks about `timestamp` alone, which the index above cannot
    // serve — its leading column is `server_id`.
    _db.execute(
      'CREATE INDEX IF NOT EXISTS idx_conn_stat_ts ON conn_stat(timestamp);',
    );

    _expire();
  }

  Future<void> recordConnection(ConnectionStat stat) async {
    _insert(_idOf(stat), stat);
    _prune(stat.serverId);
  }

  List<ConnectionStat> getConnectionHistory(String serverId) {
    final rows = _db.select(
      'SELECT * FROM conn_stat WHERE server_id = ? ORDER BY timestamp DESC;',
      [serverId],
    );
    return rows.map(_fromRow).toList();
  }

  ServerConnectionStats getServerStats(String serverId, String serverName) {
    final allStats = getConnectionHistory(serverId);

    if (allStats.isEmpty) {
      return ServerConnectionStats(
        serverId: serverId,
        serverName: serverName,
        totalAttempts: 0,
        successCount: 0,
        failureCount: 0,
        recentConnections: [],
        successRate: 0.0,
      );
    }

    var successCount = 0;
    DateTime? lastSuccessTime;
    DateTime? lastFailureTime;
    final recentConnections = <ConnectionStat>[];

    for (final stat in allStats) {
      if (stat.result.isSuccess) {
        successCount += 1;
        lastSuccessTime ??= stat.timestamp;
      } else {
        lastFailureTime ??= stat.timestamp;
      }
      if (recentConnections.length < 20) recentConnections.add(stat);
    }

    final totalAttempts = allStats.length;
    return ServerConnectionStats(
      serverId: serverId,
      serverName: serverName,
      totalAttempts: totalAttempts,
      successCount: successCount,
      failureCount: totalAttempts - successCount,
      lastSuccessTime: lastSuccessTime,
      lastFailureTime: lastFailureTime,
      recentConnections: recentConnections,
      successRate: successCount / totalAttempts,
    );
  }

  List<ServerConnectionStats> getAllServerStats() {
    // The name comes from the newest row for each server, since a server can be
    // renamed and the old rows keep the name it had at the time. `server_name`
    // is a bare column beside `MAX`, which SQLite answers from the row the
    // maximum came from.
    final rows = _db.select(
      'SELECT server_id, server_name, MAX(timestamp) AS ts FROM conn_stat '
      'GROUP BY server_id;',
    );
    return [
      for (final row in rows)
        getServerStats(row['server_id'] as String, row['server_name'] as String),
    ];
  }

  Future<void> clearAll() async {
    _db.execute('DELETE FROM conn_stat;');
  }

  Future<void> clearServerStats(String serverId) async {
    _db.execute('DELETE FROM conn_stat WHERE server_id = ?;', [serverId]);
  }

  /// Drops everything past the per-server cap.
  ///
  /// Served by `idx_conn_stat_server_ts`, and bounded by one server's rows.
  /// Cheap enough to run on every insert, which is how the cap stays exact.
  void _prune(String serverId) {
    _db.execute(
      'DELETE FROM conn_stat WHERE server_id = ? AND id NOT IN ('
      '  SELECT id FROM conn_stat WHERE server_id = ? '
      '  ORDER BY timestamp DESC LIMIT ?'
      ');',
      [serverId, serverId, _maxRecordsPerServer],
    );
  }

  /// Drops everything past the age bound.
  ///
  /// At [init], not on every insert. Recording a connection happens on every
  /// attempt against every server — the status page refreshes on a timer — and
  /// the common case is that nothing has expired, so paying for it each time
  /// bought nothing. The bound is about not keeping a month-old record for
  /// ever, which a sweep per launch satisfies.
  void _expire() {
    _db.execute('DELETE FROM conn_stat WHERE timestamp < ?;', [
      DateTime.now().subtract(_retention).millisecondsSinceEpoch,
    ]);
  }

  Future<void> compact() async {
    Loggers.app.info('Start compacting the store database...');
    try {
      SqliteDb.vacuum();
      Loggers.app.info('Finished compacting the store database');
    } catch (e, st) {
      Loggers.app.warning('Failed compacting the store database', e, st);
      rethrow;
    }
  }

  /// Size of the whole store database, not of this table.
  ///
  /// Every store shares one file, so there is no per-table number to report and
  /// the compaction this feeds is `VACUUM` on that file.
  Future<int> dbSizeAsync() => SqliteDb.size();

  /// Takes one row out of the Hive box this table replaced.
  ///
  /// Used only by `HiveImport`. It writes the record under the key it had, so
  /// re-running the import overwrites rather than duplicates.
  bool importRow(String key, Object value) {
    if (value is! Map) return false;
    try {
      _insert(key, ConnectionStat.fromJson(Map<String, dynamic>.from(value)));
      return true;
    } catch (e) {
      dprint('Importing ConnectionStat', e);
      return false;
    }
  }

  void _insert(String id, ConnectionStat stat) {
    _db.execute(
      'INSERT INTO conn_stat '
      '(id, server_id, server_name, timestamp, result, error_message, duration_ms) '
      'VALUES (?, ?, ?, ?, ?, ?, ?) '
      'ON CONFLICT (id) DO UPDATE SET '
      'server_name = excluded.server_name, timestamp = excluded.timestamp, '
      'result = excluded.result, error_message = excluded.error_message, '
      'duration_ms = excluded.duration_ms;',
      [
        id,
        stat.serverId,
        stat.serverName,
        stat.timestamp.millisecondsSinceEpoch,
        stat.result.name,
        stat.errorMessage,
        stat.durationMs,
      ],
    );
  }

  static String _idOf(ConnectionStat stat) =>
      '${stat.serverId}_${stat.timestamp.millisecondsSinceEpoch}';

  static ConnectionStat _fromRow(Row row) => ConnectionStat(
    serverId: row['server_id'] as String,
    serverName: row['server_name'] as String,
    timestamp: DateTime.fromMillisecondsSinceEpoch(row['timestamp'] as int),
    result: ConnectionResult.values.firstWhere(
      (e) => e.name == row['result'],
      orElse: () => ConnectionResult.unknownError,
    ),
    errorMessage: row['error_message'] as String? ?? '',
    durationMs: row['duration_ms'] as int,
  );
}
