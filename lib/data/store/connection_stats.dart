// Policy exception: ConnectionStatsStore uses Drift instead of Hive.
//
// Rationale: Connection stats require complex SQL queries (aggregation,
// window functions, grouping) that are impractical to implement efficiently
// with Hive key-value storage. The data is non-sensitive telemetry (success
// rates, timestamps, error messages) and does not require encryption.
//
// Migration to Hive would require significant refactoring of query logic
// and may impact performance for stats aggregation.
//
// See: fix(restore): harden backup parsing and stats store safety
//
import 'package:drift/drift.dart' as d;
import 'package:fl_lib/fl_lib.dart';
import 'package:server_box/data/db/app_db.dart' as adb;
import 'package:server_box/data/model/server/connection_stat.dart';

class ConnectionStatsStore {
  ConnectionStatsStore._();

  static final instance = ConnectionStatsStore._();

  static const _retention = Duration(days: 30);
  static const _cleanupInsertThreshold = 50;
  static const _cleanupMinInterval = Duration(minutes: 5);
  static const _connectionStatsTable = 'connection_stats_records';
  static const _recentHistoryLimit = 20;

  adb.AppDb get _db => adb.AppDb.instance;
  int _pendingSinceCleanup = 0;
  DateTime? _lastCleanupAt;
  Future<void>? _cleanupFuture;

  Future<void> recordConnection(ConnectionStat stat) async {
    await _db
        .into(_db.connectionStatsRecords)
        .insert(
          adb.ConnectionStatsRecordsCompanion.insert(
            serverId: stat.serverId,
            serverName: stat.serverName,
            timestampMs: stat.timestamp.millisecondsSinceEpoch,
            result: stat.result.name,
            errorMessage: stat.errorMessage,
            durationMs: stat.durationMs,
            updatedAt: DateTimeX.timestamp,
          ),
        );
    _pendingSinceCleanup++;
    final now = DateTime.now();
    final shouldCleanupByCount =
        _pendingSinceCleanup >= _cleanupInsertThreshold;
    final shouldCleanupByInterval =
        _lastCleanupAt == null ||
        now.difference(_lastCleanupAt!) >= _cleanupMinInterval;
    if (shouldCleanupByCount || shouldCleanupByInterval) {
      final inFlight = _cleanupFuture;
      if (inFlight != null) {
        await inFlight;
        return;
      }

      final cleanupFuture = () async {
        try {
          await _cleanOldRecords();
          _pendingSinceCleanup = 0;
          _lastCleanupAt = now;
        } catch (e, s) {
          Loggers.app.warning('Cleanup old connection stats failed', e, s);
        }
      }();
      _cleanupFuture = cleanupFuture;
      try {
        await cleanupFuture;
      } finally {
        if (identical(_cleanupFuture, cleanupFuture)) {
          _cleanupFuture = null;
        }
      }
    }
  }

  Future<void> _cleanOldRecords() async {
    final cutoff = DateTime.now().subtract(_retention).millisecondsSinceEpoch;
    await (_db.delete(
      _db.connectionStatsRecords,
    )..where((tbl) => tbl.timestampMs.isSmallerThanValue(cutoff))).go();
  }

  Future<ServerConnectionStats> getServerStats(
    String serverId,
    String serverName,
  ) async {
    const successName = 'success';
    final row = await _db
        .customSelect(
          '''
SELECT
  COUNT(*) AS total_attempts,
  SUM(CASE WHEN result = ? THEN 1 ELSE 0 END) AS success_count,
  MAX(CASE WHEN result = ? THEN timestamp_ms ELSE NULL END) AS last_success_ts,
  MAX(CASE WHEN result <> ? THEN timestamp_ms ELSE NULL END) AS last_failure_ts
FROM $_connectionStatsTable
WHERE server_id = ?
      ''',
          variables: [
            d.Variable.withString(successName),
            d.Variable.withString(successName),
            d.Variable.withString(successName),
            d.Variable.withString(serverId),
          ],
        )
        .getSingleOrNull();
    final data = row?.data ?? const <String, Object?>{};
    final totalAttempts = (data['total_attempts'] as num?)?.toInt() ?? 0;
    if (totalAttempts == 0) {
      return ServerConnectionStats(
        serverId: serverId,
        serverName: serverName,
        totalAttempts: 0,
        successCount: 0,
        failureCount: 0,
        recentConnections: const [],
        successRate: 0,
      );
    }
    final successCount = (data['success_count'] as num?)?.toInt() ?? 0;
    final failureCount = totalAttempts - successCount;
    final successRate = successCount / totalAttempts;
    final lastSuccessTs = (data['last_success_ts'] as num?)?.toInt();
    final lastFailureTs = (data['last_failure_ts'] as num?)?.toInt();
    final recentConnections = await getConnectionHistory(
      serverId,
      limit: _recentHistoryLimit,
    );

    return ServerConnectionStats(
      serverId: serverId,
      serverName: serverName,
      totalAttempts: totalAttempts,
      successCount: successCount,
      failureCount: failureCount,
      lastSuccessTime: lastSuccessTs == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(lastSuccessTs),
      lastFailureTime: lastFailureTs == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(lastFailureTs),
      recentConnections: recentConnections,
      successRate: successRate,
    );
  }

  Future<List<ConnectionStat>> getConnectionHistory(
    String serverId, {
    int? limit,
  }) async {
    final query = _db.select(_db.connectionStatsRecords)
      ..where((tbl) => tbl.serverId.equals(serverId))
      ..orderBy([(tbl) => d.OrderingTerm.desc(tbl.timestampMs)]);
    if (limit != null && limit > 0) {
      query.limit(limit);
    }

    final rows = await query.get();
    return rows.map(_fromRow).toList(growable: false);
  }

  Future<List<ServerConnectionStats>> getAllServerStats() async {
    const successName = 'success';
    final rows = await _db
        .customSelect(
          '''
SELECT
  t.server_id,
  (
    SELECT t2.server_name
    FROM $_connectionStatsTable t2
    WHERE t2.server_id = t.server_id
    ORDER BY t2.timestamp_ms DESC, t2.id DESC
    LIMIT 1
  ) AS server_name,
  COUNT(*) AS total_attempts,
  SUM(CASE WHEN t.result = ? THEN 1 ELSE 0 END) AS success_count,
  MAX(CASE WHEN t.result = ? THEN t.timestamp_ms ELSE NULL END) AS last_success_ts,
  MAX(CASE WHEN t.result <> ? THEN t.timestamp_ms ELSE NULL END) AS last_failure_ts,
  MAX(t.timestamp_ms) AS latest_ts
FROM $_connectionStatsTable t
GROUP BY t.server_id
ORDER BY latest_ts DESC
      ''',
          variables: [
            d.Variable.withString(successName),
            d.Variable.withString(successName),
            d.Variable.withString(successName),
          ],
        )
        .get();
    if (rows.isEmpty) return const <ServerConnectionStats>[];

    final serverIds = <String>[];
    for (final row in rows) {
      final id = row.data['server_id'] as String?;
      if (id == null || id.isEmpty) continue;
      serverIds.add(id);
    }
    if (serverIds.isEmpty) return const <ServerConnectionStats>[];

    final placeholders = List<String>.filled(serverIds.length, '?').join(', ');
    final historyRows = await _db
        .customSelect(
          '''
SELECT
  server_id,
  server_name,
  timestamp_ms,
  result,
  error_message,
  duration_ms
FROM (
  SELECT
    server_id,
    server_name,
    timestamp_ms,
    result,
    error_message,
    duration_ms,
    ROW_NUMBER() OVER (
      PARTITION BY server_id
      ORDER BY timestamp_ms DESC
    ) AS rn
  FROM $_connectionStatsTable
  WHERE server_id IN ($placeholders)
)
WHERE rn <= ?
ORDER BY server_id, timestamp_ms DESC
      ''',
          variables: [
            for (final serverId in serverIds) d.Variable.withString(serverId),
            d.Variable.withInt(_recentHistoryLimit),
          ],
        )
        .get();
    final recentConnectionsByServer = <String, List<ConnectionStat>>{};
    for (final row in historyRows) {
      final serverId = row.data['server_id'] as String?;
      if (serverId == null || serverId.isEmpty) continue;
      final list = recentConnectionsByServer.putIfAbsent(
        serverId,
        () => <ConnectionStat>[],
      );
      list.add(_fromDataMap(row.data));
    }

    final allStats = <ServerConnectionStats>[];
    for (final row in rows) {
      final data = row.data;
      final serverId = data['server_id'] as String?;
      if (serverId == null || serverId.isEmpty) continue;
      final serverName = (data['server_name'] as String?) ?? serverId;
      final totalAttempts = (data['total_attempts'] as num?)?.toInt() ?? 0;
      final successCount = (data['success_count'] as num?)?.toInt() ?? 0;
      final failureCount = totalAttempts - successCount;
      final successRate = totalAttempts > 0
          ? (successCount / totalAttempts)
          : 0.0;
      final lastSuccessTs = (data['last_success_ts'] as num?)?.toInt();
      final lastFailureTs = (data['last_failure_ts'] as num?)?.toInt();
      final recentConnections =
          recentConnectionsByServer[serverId] ?? const <ConnectionStat>[];

      allStats.add(
        ServerConnectionStats(
          serverId: serverId,
          serverName: serverName,
          totalAttempts: totalAttempts,
          successCount: successCount,
          failureCount: failureCount,
          lastSuccessTime: lastSuccessTs == null
              ? null
              : DateTime.fromMillisecondsSinceEpoch(lastSuccessTs),
          lastFailureTime: lastFailureTs == null
              ? null
              : DateTime.fromMillisecondsSinceEpoch(lastFailureTs),
          recentConnections: recentConnections,
          successRate: successRate,
        ),
      );
    }
    return allStats;
  }

  Future<void> clearAll() async {
    await _db.delete(_db.connectionStatsRecords).go();
  }

  Future<void> clearServerStats(String serverId) async {
    await (_db.delete(
      _db.connectionStatsRecords,
    )..where((tbl) => tbl.serverId.equals(serverId))).go();
  }

  Future<void> compact() async {
    Loggers.app.info('Start compacting app database...');
    try {
      await _db.customStatement('VACUUM');
      Loggers.app.info('Finished compacting app database');
    } catch (e, st) {
      Loggers.app.warning('Failed compacting app database', e, st);
      rethrow;
    }
  }

  ConnectionStat _fromRow(adb.ConnectionStatsRecord row) {
    final result = ConnectionResult.values.firstWhere(
      (e) => e.name == row.result,
      orElse: () => ConnectionResult.unknownError,
    );

    return ConnectionStat(
      serverId: row.serverId,
      serverName: row.serverName,
      timestamp: DateTime.fromMillisecondsSinceEpoch(row.timestampMs),
      result: result,
      errorMessage: row.errorMessage,
      durationMs: row.durationMs,
    );
  }

  ConnectionStat _fromDataMap(Map<String, Object?> data) {
    final serverId = data['server_id'] as String? ?? '';
    final resultRaw = data['result'] as String? ?? '';
    final result = ConnectionResult.values.firstWhere(
      (e) => e.name == resultRaw,
      orElse: () => ConnectionResult.unknownError,
    );
    final timestampMs = (data['timestamp_ms'] as num?)?.toInt() ?? 0;
    final durationMs = (data['duration_ms'] as num?)?.toInt() ?? 0;

    return ConnectionStat(
      serverId: serverId,
      serverName: (data['server_name'] as String?) ?? serverId,
      timestamp: DateTime.fromMillisecondsSinceEpoch(timestampMs),
      result: result,
      errorMessage: (data['error_message'] as String?) ?? '',
      durationMs: durationMs,
    );
  }
}
