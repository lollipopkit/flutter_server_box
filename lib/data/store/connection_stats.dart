import 'package:fl_lib/fl_lib.dart';
import 'package:server_box/data/model/server/connection_stat.dart';

class ConnectionStatsStore extends SqliteStore {
  ConnectionStatsStore._() : super('connection_stats');

  static final instance = ConnectionStatsStore._();

  static const _keySep = '_';
  static const _retention = Duration(days: 30);

  // Record a connection attempt
  void recordConnection(ConnectionStat stat) {
    final key = '${stat.serverId}_${ShortId.generate()}';
    set(key, stat, toObj: (val) => val?.toJson());
    _cleanOldRecords(stat.serverId);
  }

  // Clean records older than 30 days for a specific server
  void _cleanOldRecords(String serverId) {
    final cutoffTime = DateTime.now().subtract(_retention);
    final allKeys = keys().toList();
    final keysToDelete = <String>[];

    for (final key in allKeys) {
      if (!_isServerRecordKey(key, serverId)) continue;
      final recordTime = _extractRecordTimeFromKey(key);
      if (recordTime != null && recordTime.isBefore(cutoffTime)) {
        keysToDelete.add(key);
      }
    }

    for (final key in keysToDelete) {
      remove(key);
    }
  }

  // Get connection stats for a specific server
  ServerConnectionStats getServerStats(String serverId, String serverName) {
    final sortedStats = getConnectionHistory(serverId);
    if (sortedStats.isEmpty) {
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

    return _buildServerStats(serverId: serverId, serverName: serverName, sortedStats: sortedStats);
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

    final successTimes = sortedStats.where((s) => s.result.isSuccess).map((s) => s.timestamp).toList();
    final failureTimes = sortedStats.where((s) => !s.result.isSuccess).map((s) => s.timestamp).toList();

    DateTime? lastSuccessTime;
    DateTime? lastFailureTime;

    if (successTimes.isNotEmpty) {
      successTimes.sort((a, b) => b.compareTo(a));
      lastSuccessTime = successTimes.first;
    }

    if (failureTimes.isNotEmpty) {
      failureTimes.sort((a, b) => b.compareTo(a));
      lastFailureTime = failureTimes.first;
    }

    // Get recent connections (last 20)
    final recentConnections = sortedStats.take(20).toList();

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

  // Get connection history for a specific server
  List<ConnectionStat> getConnectionHistory(String serverId) {
    final allKeys = keys().where((key) => _isServerRecordKey(key, serverId)).toList();
    final stats = <ConnectionStat>[];

    for (final key in allKeys) {
      final stat = _readStat(key);
      if (stat != null) {
        stats.add(stat);
      }
    }

    // Sort by timestamp, newest first
    stats.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return stats;
  }

  // Get all servers' stats
  List<ServerConnectionStats> getAllServerStats() {
    final groupedStats = <String, List<ConnectionStat>>{};
    final serverNames = <String, String>{};

    for (final key in keys()) {
      final parsed = _parseRecordKey(key);
      if (parsed == null) continue;

      final serverId = parsed.$1;
      final stat = _readStat(key);
      if (stat == null) continue;

      groupedStats.putIfAbsent(serverId, () => []).add(stat);
      serverNames[serverId] ??= stat.serverName;
    }

    final allStats = <ServerConnectionStats>[];
    for (final entry in groupedStats.entries) {
      final serverId = entry.key;
      final serverName = serverNames[serverId] ?? serverId;
      final stats = entry.value;
      stats.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      allStats.add(_buildServerStats(serverId: serverId, serverName: serverName, sortedStats: stats));
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

  // Clear all connection stats
  void clearAll() {
    clear();
  }

  // Clear stats for a specific server
  void clearServerStats(String serverId) {
    final keysToDelete = keys().where((key) {
      return _isServerRecordKey(key, serverId);
    }).toList();
    for (final key in keysToDelete) {
      remove(key);
    }
  }

  Future<void> compact() async {
    Loggers.app.info('Start compacting connection_stats database...');
    try {
      await vacuum();
      Loggers.app.info('Finished compacting connection_stats database');
    } catch (e, st) {
      Loggers.app.warning('Failed compacting connection_stats database', e, st);
      rethrow;
    }
  }

  ConnectionStat? _readStat(String key) {
    return get<ConnectionStat>(
      key,
      fromObj: (val) {
        if (val is ConnectionStat) return val;
        if (val is Map<dynamic, dynamic>) {
          final map = val.toStrDynMap;
          if (map == null) return null;
          try {
            return ConnectionStat.fromJson(map as Map<String, dynamic>);
          } catch (e) {
            dprint('Parsing ConnectionStat from JSON', e);
          }
        }
        return null;
      },
    );
  }

  bool _isServerRecordKey(String key, String serverId) {
    final parsed = _parseRecordKey(key);
    return parsed != null && parsed.$1 == serverId;
  }

  (String, String)? _parseRecordKey(String key) {
    final idx = key.lastIndexOf(_keySep);
    if (idx <= 0 || idx >= key.length - 1) return null;
    return (key.substring(0, idx), key.substring(idx + 1));
  }

  DateTime? _extractRecordTimeFromKey(String key) {
    final parsed = _parseRecordKey(key);
    if (parsed == null) return null;

    // Backward compatibility for potential old decimal timestamp suffix.
    final raw = parsed.$2;
    final legacyTs = int.tryParse(raw);
    if (legacyTs != null) {
      return DateTime.fromMillisecondsSinceEpoch(legacyTs);
    }

    final decoded = ShortId.decode(raw);
    return decoded?.$1;
  }
}
