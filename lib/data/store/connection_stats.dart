import 'package:drift/drift.dart' as d;
import 'package:fl_lib/fl_lib.dart';
import 'package:server_box/data/db/app_db.dart' as adb;
import 'package:server_box/data/model/server/connection_stat.dart';

class ConnectionStatsStore {
  ConnectionStatsStore._();

  static final instance = ConnectionStatsStore._();

  static const _retention = Duration(days: 30);

  adb.AppDb get _db => adb.AppDb.instance;

  Future<void> recordConnection(ConnectionStat stat) async {
    await _db.into(_db.connectionStatsRecords).insert(
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
    await _cleanOldRecords(stat.serverId);
  }

  Future<void> _cleanOldRecords(String serverId) async {
    final cutoff = DateTime.now().subtract(_retention).millisecondsSinceEpoch;
    await (_db.delete(_db.connectionStatsRecords)
          ..where(
            (tbl) =>
                tbl.serverId.equals(serverId) & tbl.timestampMs.isSmallerThanValue(cutoff),
          ))
        .go();
  }

  Future<ServerConnectionStats> getServerStats(
    String serverId,
    String serverName,
  ) async {
    final sortedStats = await getConnectionHistory(serverId);
    if (sortedStats.isEmpty) {
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

    return _buildServerStats(
      serverId: serverId,
      serverName: serverName,
      sortedStats: sortedStats,
    );
  }

  Future<List<ConnectionStat>> getConnectionHistory(
    String serverId, {
    int? limit,
  }) async {
    final query = _db.select(_db.connectionStatsRecords)
      ..where((tbl) => tbl.serverId.equals(serverId))
      ..orderBy([(tbl) => d.OrderingTerm.desc(tbl.timestampMs)]);
    if (limit != null) {
      query.limit(limit);
    }

    final rows = await query.get();
    return rows.map(_fromRow).toList(growable: false);
  }

  Future<List<ServerConnectionStats>> getAllServerStats() async {
    const successName = 'success';
    final rows = await _db.customSelect(
      '''
SELECT
  server_id,
  MAX(server_name) AS server_name,
  COUNT(*) AS total_attempts,
  SUM(CASE WHEN result = ? THEN 1 ELSE 0 END) AS success_count,
  MAX(CASE WHEN result = ? THEN timestamp_ms ELSE NULL END) AS last_success_ts,
  MAX(CASE WHEN result <> ? THEN timestamp_ms ELSE NULL END) AS last_failure_ts,
  MAX(timestamp_ms) AS latest_ts
FROM connection_stats_records
GROUP BY server_id
ORDER BY latest_ts DESC
      ''',
      variables: [
        d.Variable.withString(successName),
        d.Variable.withString(successName),
        d.Variable.withString(successName),
      ],
    ).get();
    if (rows.isEmpty) return const <ServerConnectionStats>[];

    final allStats = <ServerConnectionStats>[];
    for (final row in rows) {
      final data = row.data;
      final serverId = data['server_id'] as String?;
      if (serverId == null || serverId.isEmpty) continue;
      final serverName = (data['server_name'] as String?) ?? serverId;
      final totalAttempts = (data['total_attempts'] as num?)?.toInt() ?? 0;
      final successCount = (data['success_count'] as num?)?.toInt() ?? 0;
      final failureCount = totalAttempts - successCount;
      final successRate = totalAttempts > 0 ? (successCount / totalAttempts) : 0.0;
      final lastSuccessTs = (data['last_success_ts'] as num?)?.toInt();
      final lastFailureTs = (data['last_failure_ts'] as num?)?.toInt();
      final recentConnections = await getConnectionHistory(serverId, limit: 20);

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
    await (_db.delete(_db.connectionStatsRecords)
          ..where((tbl) => tbl.serverId.equals(serverId)))
        .go();
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

  ServerConnectionStats _buildServerStats({
    required String serverId,
    required String serverName,
    required List<ConnectionStat> sortedStats,
  }) {
    final totalAttempts = sortedStats.length;
    final successCount = sortedStats.where((s) => s.result.isSuccess).length;
    final failureCount = totalAttempts - successCount;
    final successRate = totalAttempts > 0 ? (successCount / totalAttempts) : 0.0;

    DateTime? lastSuccessTime;
    DateTime? lastFailureTime;
    for (final stat in sortedStats) {
      if (lastSuccessTime == null && stat.result.isSuccess) {
        lastSuccessTime = stat.timestamp;
      }
      if (lastFailureTime == null && !stat.result.isSuccess) {
        lastFailureTime = stat.timestamp;
      }
      if (lastSuccessTime != null && lastFailureTime != null) {
        break;
      }
    }

    final recentConnections = sortedStats.take(20).toList(growable: false);

    return ServerConnectionStats(
      serverId: serverId,
      serverName: serverName,
      totalAttempts: totalAttempts,
      successCount: successCount,
      failureCount: failureCount,
      lastSuccessTime: lastSuccessTime,
      lastFailureTime: lastFailureTime,
      recentConnections: recentConnections,
      successRate: successRate,
    );
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
}
