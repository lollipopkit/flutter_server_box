import 'package:fl_lib/fl_lib.dart';
import 'package:server_box/data/model/server/connection_stat.dart';

class ConnectionStatsStore extends HiveStore {
  ConnectionStatsStore._() : super('connection_stats');
  
  static final instance = ConnectionStatsStore._();
  
  // Record a connection attempt
  void recordConnection(ConnectionStat stat) {
    final key = '${stat.serverId}_${ShortId.generate()}';
    set(key, stat);
    _cleanOldRecords(stat.serverId);
  }
  
  // Clean records older than 30 days for a specific server
  void _cleanOldRecords(String serverId) {
    final cutoffTime = DateTime.now().subtract(const Duration(days: 30));
    final allKeys = keys().toList();
    final keysToDelete = <String>[];
    
    for (final key in allKeys) {
      if (key.startsWith(serverId)) {
        final parts = key.split('_');
        if (parts.length >= 2) {
          final timestamp = int.tryParse(parts.last);
          if (timestamp != null) {
            final recordTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
            if (recordTime.isBefore(cutoffTime)) {
              keysToDelete.add(key);
            }
          }
        }
      }
    }
    
    for (final key in keysToDelete) {
      remove(key);
    }
  }
  
  // Get connection stats for a specific server
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
    
    final totalAttempts = allStats.length;
    final successCount = allStats.where((s) => s.result.isSuccess).length;
    final failureCount = totalAttempts - successCount;
    final successRate = totalAttempts > 0 ? (successCount / totalAttempts) : 0.0;
    
    final successTimes = allStats
        .where((s) => s.result.isSuccess)
        .map((s) => s.timestamp)
        .toList();
    final failureTimes = allStats
        .where((s) => !s.result.isSuccess)
        .map((s) => s.timestamp)
        .toList();
    
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
    final recentConnections = allStats.take(20).toList();
    
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
    final allKeys = keys().where((key) => key.startsWith(serverId)).toList();
    final stats = <ConnectionStat>[];
    
    for (final key in allKeys) {
      final stat = get<ConnectionStat>(
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
    final serverIds = <String>{};
    final serverNames = <String, String>{};
    
    // Get all unique server IDs
    for (final key in keys()) {
      final parts = key.split('_');
      if (parts.length >= 2) {
        final serverId = parts[0];
        serverIds.add(serverId);
        
        // Try to get server name from the stored stat
        final stat = get<ConnectionStat>(
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
        if (stat != null) {
          serverNames[serverId] = stat.serverName;
        }
      }
    }
    
    final allStats = <ServerConnectionStats>[];
    for (final serverId in serverIds) {
      final serverName = serverNames[serverId] ?? serverId;
      final stats = getServerStats(serverId, serverName);
      allStats.add(stats);
    }
    
    return allStats;
  }
  
  // Clear all connection stats
  void clearAll() {
    box.clear();
  }
  
  // Clear stats for a specific server
  void clearServerStats(String serverId) {
    final keysToDelete = keys().where((key) {
      if (key == serverId) return true;
      return key.startsWith('${serverId}_');
    }).toList();
    for (final key in keysToDelete) {
      remove(key);
    }
  }

  Future<void> compact() async {
    Loggers.app.info('Start compacting connection_stats database...');
    try {
      await box.compact();
      Loggers.app.info('Finished compacting connection_stats database');
    } catch (e, st) {
      Loggers.app.warning('Failed compacting connection_stats database', e, st);
      rethrow;
    }
  }
}