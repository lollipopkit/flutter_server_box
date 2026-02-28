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

  Future<List<ConnectionStat>> getConnectionHistory(String serverId) async {
    final query = _db.select(_db.connectionStatsRecords)
      ..where((tbl) => tbl.serverId.equals(serverId))
      ..orderBy([(tbl) => d.OrderingTerm.desc(tbl.timestampMs)]);

    final rows = await query.get();
    return rows.map(_fromRow).toList(growable: false);
  }

  Future<List<ServerConnectionStats>> getAllServerStats() async {
    final rows = await _db.select(_db.connectionStatsRecords).get();
    final groupedStats = <String, List<ConnectionStat>>{};
    final serverNames = <String, String>{};

    for (final row in rows) {
      final stat = _fromRow(row);
      groupedStats.putIfAbsent(stat.serverId, () => []).add(stat);
      serverNames[stat.serverId] ??= stat.serverName;
    }

    final allStats = <ServerConnectionStats>[];
    for (final entry in groupedStats.entries) {
      final serverId = entry.key;
      final serverName = serverNames[serverId] ?? serverId;
      final stats = entry.value;
      stats.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      allStats.add(
        _buildServerStats(
          serverId: serverId,
          serverName: serverName,
          sortedStats: stats,
        ),
      );
    }

    allStats.sort((a, b) {
      final aTs = a.recentConnections.isEmpty
          ? DateTime.fromMillisecondsSinceEpoch(0)
          : a.recentConnections.first.timestamp;
      final bTs = b.recentConnections.isEmpty
          ? DateTime.fromMillisecondsSinceEpoch(0)
          : b.recentConnections.first.timestamp;
      return bTs.compareTo(aTs);
    });

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
