import 'dart:io';

import 'package:fl_lib/fl_lib.dart';
import 'package:hive_ce/hive.dart';
import 'package:server_box/data/model/server/connection_stat.dart';

class ConnectionStatsStore extends HiveStore {
  ConnectionStatsStore._() : super('connection_stats');

  static final instance = ConnectionStatsStore._();

  static const _indexBoxName = 'conn_stats_index';
  static const _maxRecordsPerServer = 100;

  late final Box<dynamic> _indexBox;

  @override
  Future<void> init() async {
    await super.init();
    _indexBox = await Hive.openBox(
      _indexBoxName,
      path: box.path?.substring(0, box.path!.lastIndexOf(Pfs.seperator)),
    );
    await _cleanAllOldAndRebuildIndex();
  }

  Future<void> _cleanAllOldAndRebuildIndex() async {
    final cutoffTime = DateTime.now().subtract(const Duration(days: 30));
    final serverIdToKeys = <String, List<String>>{};

    for (final key in keys()) {
      final stat = get<ConnectionStat>(key);
      if (stat == null) continue;

      if (stat.timestamp.isBefore(cutoffTime)) {
        remove(key);
        continue;
      }

      final serverId = stat.serverId;
      serverIdToKeys.putIfAbsent(serverId, () => []).add(key);
    }

    for (final entry in serverIdToKeys.entries) {
      _indexBox.put('idx_${entry.key}', entry.value);
    }

    await _compactIfNeeded();
  }

  Future<void> _compactIfNeeded() async {
    try {
      await box.compact();
      await _indexBox.compact();
    } catch (e, st) {
      Loggers.app.warning('Auto compact failed during init', e, st);
    }
  }

  void _updateIndex(String serverId, String recordKey) {
    final indexKey = 'idx_$serverId';
    final keys = (_indexBox.get(indexKey) as List?)?.cast<String>() ?? [];

    if (!keys.contains(recordKey)) {
      keys.add(recordKey);
      if (keys.length > _maxRecordsPerServer) {
        _pruneExcessRecords(serverId, keys);
      }
      _indexBox.put(indexKey, keys);
    }
  }

  void _pruneExcessRecords(String serverId, List<String> keys) {
    if (keys.length <= _maxRecordsPerServer) return;

    final records = <ConnectionStat>[];
    for (final key in keys) {
      final stat = get<ConnectionStat>(key);
      if (stat != null) {
        records.add(stat);
      }
    }

    records.sort((a, b) => b.timestamp.compareTo(a.timestamp));

    final toRemove = records.skip(_maxRecordsPerServer).toList();
    for (final stat in toRemove) {
      final key = '${stat.serverId}_${stat.timestamp.millisecondsSinceEpoch}';
      remove(key);
      keys.remove(key);
    }
  }

  void recordConnection(ConnectionStat stat) {
    final key = '${stat.serverId}_${stat.timestamp.millisecondsSinceEpoch}';
    set(key, stat);
    _updateIndex(stat.serverId, key);
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

  List<ConnectionStat> getConnectionHistory(String serverId) {
    final indexKey = 'idx_$serverId';
    final keys = (_indexBox.get(indexKey) as List?)?.cast<String>() ?? [];

    final stats = <ConnectionStat>[];
    for (final key in keys) {
      final stat = get<ConnectionStat>(key);
      if (stat != null) {
        stats.add(stat);
      }
    }

    stats.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return stats;
  }

  List<ServerConnectionStats> getAllServerStats() {
    final indexKeys = _indexBox.keys
        .where((k) => k is String && k.startsWith('idx_'))
        .cast<String>()
        .toList();

    final allStats = <ServerConnectionStats>[];
    for (final indexKey in indexKeys) {
      final serverId = indexKey.substring(4);
      final keys = (_indexBox.get(indexKey) as List?)?.cast<String>() ?? [];

      if (keys.isEmpty) continue;

      String? serverName;
      for (final key in keys) {
        final stat = get<ConnectionStat>(key);
        if (stat != null) {
          serverName = stat.serverName;
          break;
        }
      }

      if (serverName == null) continue;

      final stats = getServerStats(serverId, serverName);
      allStats.add(stats);
    }

    return allStats;
  }

  void clearAll() {
    box.clear();
    _indexBox.clear();
  }

  void clearServerStats(String serverId) {
    final indexKey = 'idx_$serverId';
    final keys = (_indexBox.get(indexKey) as List?)?.cast<String>() ?? [];

    for (final key in keys) {
      remove(key);
    }
    _indexBox.delete(indexKey);
  }

  Future<void> compact() async {
    Loggers.app.info('Start compacting connection_stats database...');
    try {
      await box.compact();
      await _indexBox.compact();
      Loggers.app.info('Finished compacting connection_stats database');
    } catch (e, st) {
      Loggers.app.warning('Failed compacting connection_stats database', e, st);
      rethrow;
    }
  }

  String? get dbPath => box.path;

  String? get indexDbPath => _indexBox.path;

  int get dbSize {
    final path = dbPath;
    if (path == null) return 0;
    final file = File(path);
    return file.existsSync() ? file.lengthSync() : 0;
  }

  int get indexDbSize {
    final path = indexDbPath;
    if (path == null) return 0;
    final file = File(path);
    return file.existsSync() ? file.lengthSync() : 0;
  }
}