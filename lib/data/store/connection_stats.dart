import 'package:fl_lib/fl_lib.dart';
import 'package:server_box/data/model/server/connection_stat.dart';

class ConnectionStatsStore extends SqliteStore {
  ConnectionStatsStore._() : super('connection_stats');

  static final instance = ConnectionStatsStore._();

  static const _maxRecordsPerServer = 100;

  /// Per-server lists of record keys, so a server's history can be read without
  /// scanning every record.
  ///
  /// Its own store rather than a prefix in this one, so `keys()` here stays
  /// "the records" and the pruning below does not have to filter itself out.
  ///
  /// It used to be a separate Hive box, and — unlike every other box — an
  /// unencrypted one: `Hive.openBox` was called without a cipher, so 114 KB of
  /// `<serverId>_<millis>` sat in plaintext next to the encrypted records they
  /// point at. Sharing the database puts it behind the same key as everything
  /// else.
  ///
  /// TODO: delete along with the hand-rolled pruning below, once the records
  /// are a table with an index on (server_id, timestamp).
  final _index = SqliteStore('conn_stats_index');

  @override
  Future<void> init({String? dir}) async {
    await super.init(dir: dir);
    await _index.init(dir: dir);
  }

  Future<void> rebuildIndexAndCompact() async {
    _rebuildIndexCore();
    await _compactIfNeeded();
  }

  void _rebuildIndexCore() {
    final cutoffTime = DateTime.now().subtract(const Duration(days: 30));
    final serverIdToKeys = <String, List<String>>{};

    for (final key in keys().toList()) {
      final stat = _statOf(key);
      if (stat == null) continue;

      if (stat.timestamp.isBefore(cutoffTime)) {
        remove(key);
        continue;
      }

      serverIdToKeys.putIfAbsent(stat.serverId, () => []).add(key);
    }

    for (final k in _index.keys().toList()) {
      if (k.startsWith('idx_')) _index.remove(k);
    }

    for (final entry in serverIdToKeys.entries) {
      final keys = entry.value;
      if (keys.length > _maxRecordsPerServer) {
        final keyStatPairs = <(String, ConnectionStat)>[];
        for (final key in keys) {
          final stat = _statOf(key);
          if (stat != null) keyStatPairs.add((key, stat));
        }
        keyStatPairs.sort((a, b) => b.$2.timestamp.compareTo(a.$2.timestamp));
        final toKeep = keyStatPairs
            .take(_maxRecordsPerServer)
            .map((p) => p.$1)
            .toList()
            .reversed
            .toList();
        for (final pair in keyStatPairs.skip(_maxRecordsPerServer)) {
          remove(pair.$1);
        }
        _index.set('idx_${entry.key}', toKeep);
      } else {
        _index.set('idx_${entry.key}', keys);
      }
    }
  }

  Future<void> _compactIfNeeded() async {
    try {
      SqliteDb.vacuum();
    } catch (e, st) {
      Loggers.app.warning('Auto compact failed during init', e, st);
    }
  }

  void _updateIndex(String serverId, String recordKey) {
    final indexKey = 'idx_$serverId';
    final keys = _indexKeys(serverId);

    if (keys.contains(recordKey)) return;
    keys.add(recordKey);
    if (keys.length > _maxRecordsPerServer) {
      _pruneExcessRecords(keys);
    }
    _index.set(indexKey, keys);
  }

  void _pruneExcessRecords(List<String> keys) {
    if (keys.length <= _maxRecordsPerServer) return;

    final keyStatPairs = <(String, ConnectionStat)>[];
    for (final key in keys) {
      final stat = _statOf(key);
      if (stat != null) keyStatPairs.add((key, stat));
    }

    keyStatPairs.sort((a, b) => b.$2.timestamp.compareTo(a.$2.timestamp));

    for (final pair in keyStatPairs.skip(_maxRecordsPerServer)) {
      remove(pair.$1);
      keys.remove(pair.$1);
    }
  }

  Future<void> recordConnection(ConnectionStat stat) async {
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
    var successCount = 0;
    DateTime? lastSuccessTime;
    DateTime? lastFailureTime;
    final recentConnections = <ConnectionStat>[];

    for (final stat in allStats) {
      final isSuccess = stat.result.isSuccess;
      if (isSuccess) {
        successCount += 1;
        lastSuccessTime ??= stat.timestamp;
      } else {
        lastFailureTime ??= stat.timestamp;
      }
      if (recentConnections.length < 20) {
        recentConnections.add(stat);
      }
    }

    final failureCount = totalAttempts - successCount;
    final successRate = totalAttempts > 0
        ? (successCount / totalAttempts)
        : 0.0;

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
    final stats = <ConnectionStat>[];
    for (final key in _indexKeys(serverId).reversed) {
      final stat = _statOf(key);
      if (stat != null) stats.add(stat);
    }
    return stats;
  }

  List<ServerConnectionStats> getAllServerStats() {
    final allStats = <ServerConnectionStats>[];
    for (final indexKey in indexKeys) {
      final serverId = indexKey.substring(4);
      final keys = _indexKeys(serverId);
      if (keys.isEmpty) continue;

      String? serverName;
      for (final key in keys.reversed) {
        final stat = _statOf(key);
        if (stat != null) {
          serverName = stat.serverName;
          break;
        }
      }

      if (serverName == null) continue;

      allStats.add(getServerStats(serverId, serverName));
    }

    return allStats;
  }

  Future<void> clearAll() async {
    clear();
    _index.clear();
  }

  Future<void> clearServerStats(String serverId) async {
    for (final key in _indexKeys(serverId)) {
      remove(key);
    }
    _index.remove('idx_$serverId');
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

  Iterable<String> get indexKeys =>
      _index.keys().where((k) => k.startsWith('idx_'));

  List<String> _indexKeys(String serverId) =>
      _index.get<List>('idx_$serverId')?.cast<String>().toList() ?? <String>[];

  ConnectionStat? _statOf(String key) {
    final raw = get<Map>(key);
    if (raw == null) return null;
    try {
      return ConnectionStat.fromJson(Map<String, dynamic>.from(raw));
    } catch (e) {
      dprint('Parsing ConnectionStat from JSON', e);
      return null;
    }
  }

  /// Size of the whole store database, not of this store's rows.
  ///
  /// Every store shares one file, so there is no per-store number to report and
  /// the compaction this feeds is `VACUUM` on that file.
  Future<int> dbSizeAsync() => SqliteDb.size();
}
