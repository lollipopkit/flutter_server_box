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

  /// How many recent attempts a summary carries. The list card shows three of
  /// them and the detail dialog shows the rest, both off the same object.
  static const _recentPerServer = 20;

  Database get _db => SqliteDb.instance;

  /// The table is created with the rest of the schema, so this is only the
  /// per-launch age sweep.
  Future<void> init() async => _expire();

  /// Records one attempt, or does nothing if the server is gone.
  ///
  /// `server_id` is a foreign key now: a status refresh that lands after the
  /// user deleted the server has nothing to attach the record to, and the row
  /// would only ever have been orphaned statistics.
  Future<void> recordConnection(ConnectionStat stat) async {
    try {
      _insert(ShortId.generate(), stat);
    } on SqliteException catch (e) {
      if (e.extendedResultCode == 787 /* SQLITE_CONSTRAINT_FOREIGNKEY */ ) {
        return;
      }
      rethrow;
    }
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
      if (recentConnections.length < _recentPerServer) {
        recentConnections.add(stat);
      }
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

  /// Every server's summary, in two queries.
  ///
  /// One `GROUP BY` to enumerate servers and then a full history read per
  /// server meant 21 queries and up to 2000 decoded records to draw 20 summary
  /// cards. The counters are an aggregate, and the only rows that reach the UI
  /// are the newest [_recentPerServer] per server — which a window function
  /// bounds in the database rather than after decoding everything.
  List<ServerConnectionStats> getAllServerStats() {
    const success = 'success';
    assert(ConnectionResult.success.name == success);

    final totals = _db.select(
      'SELECT server_id,'
      '  COUNT(*) AS total,'
      "  SUM(CASE WHEN result = '$success' THEN 1 ELSE 0 END) AS successes,"
      "  MAX(CASE WHEN result = '$success' THEN timestamp END) AS last_ok,"
      "  MAX(CASE WHEN result <> '$success' THEN timestamp END) AS last_bad "
      'FROM conn_stat GROUP BY server_id;',
    );
    if (totals.isEmpty) return const [];

    // Newest first within each server, so the first row of a group is also
    // where the current name comes from — a server can be renamed, and the
    // older rows keep whatever it was called at the time.
    final recentRows = _db.select(
      'SELECT * FROM ('
      '  SELECT *, ROW_NUMBER() OVER ('
      '    PARTITION BY server_id ORDER BY timestamp DESC'
      '  ) AS rn FROM conn_stat'
      ') WHERE rn <= ? ORDER BY server_id, timestamp DESC;',
      [_recentPerServer],
    );

    final recent = <String, List<ConnectionStat>>{};
    for (final row in recentRows) {
      (recent[row['server_id'] as String] ??= []).add(_fromRow(row));
    }

    final result = <ServerConnectionStats>[];
    for (final row in totals) {
      final serverId = row['server_id'] as String;
      final recentConnections = recent[serverId] ?? const <ConnectionStat>[];
      if (recentConnections.isEmpty) continue;

      final total = row['total'] as int;
      final successCount = (row['successes'] as num?)?.toInt() ?? 0;
      result.add(
        ServerConnectionStats(
          serverId: serverId,
          serverName: recentConnections.first.serverName,
          totalAttempts: total,
          successCount: successCount,
          failureCount: total - successCount,
          lastSuccessTime: _timeOf(row['last_ok']),
          lastFailureTime: _timeOf(row['last_bad']),
          recentConnections: recentConnections,
          successRate: total > 0 ? successCount / total : 0.0,
        ),
      );
    }
    return result;
  }

  static DateTime? _timeOf(Object? millis) => millis is int
      ? DateTime.fromMillisecondsSinceEpoch(millis)
      : null;

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

  /// The id is generated rather than `<serverId>_<millis>`, which two attempts
  /// in the same millisecond shared — the second overwrote the first, and the
  /// counters are computed from these rows.
  void _insert(String id, ConnectionStat stat) {
    _db.execute(
      'INSERT INTO conn_stat '
      '(id, server_id, server_name, timestamp, result, error_message, duration_ms) '
      'VALUES (?, ?, ?, ?, ?, ?, ?);',
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
