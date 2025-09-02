import 'package:fl_lib/fl_lib.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:hive_ce/hive.dart';

part 'connection_stat.freezed.dart';
part 'connection_stat.g.dart';

@freezed
@HiveType(typeId: 100)
abstract class ConnectionStat with _$ConnectionStat {
  const factory ConnectionStat({
    @HiveField(0) required String serverId,
    @HiveField(1) required String serverName,
    @HiveField(2) required DateTime timestamp,
    @HiveField(3) required ConnectionResult result,
    @HiveField(4) @Default('') String errorMessage,
    @HiveField(5) required int durationMs,
  }) = _ConnectionStat;

  factory ConnectionStat.fromJson(Map<String, dynamic> json) =>
      _$ConnectionStatFromJson(json);
}

@freezed
@HiveType(typeId: 101)
abstract class ServerConnectionStats with _$ServerConnectionStats {
  const factory ServerConnectionStats({
    @HiveField(0) required String serverId,
    @HiveField(1) required String serverName,
    @HiveField(2) required int totalAttempts,
    @HiveField(3) required int successCount,
    @HiveField(4) required int failureCount,
    @HiveField(5) @Default(null) DateTime? lastSuccessTime,
    @HiveField(6) @Default(null) DateTime? lastFailureTime,
    @HiveField(7) @Default([]) List<ConnectionStat> recentConnections,
    @HiveField(8) required double successRate,
  }) = _ServerConnectionStats;

  factory ServerConnectionStats.fromJson(Map<String, dynamic> json) =>
      _$ServerConnectionStatsFromJson(json);
}

@HiveType(typeId: 102)
enum ConnectionResult {
  @HiveField(0)
  @JsonValue('success')
  success,
  @HiveField(1)
  @JsonValue('timeout')
  timeout,
  @HiveField(2)
  @JsonValue('auth_failed')
  authFailed,
  @HiveField(3)
  @JsonValue('network_error')
  networkError,
  @HiveField(4)
  @JsonValue('unknown_error')
  unknownError,
}

extension ConnectionResultExtension on ConnectionResult {
  String get displayName {
    switch (this) {
      case ConnectionResult.success:
        return libL10n.success;
      case ConnectionResult.timeout:
        return '${libL10n.error}(timeout)';
      case ConnectionResult.authFailed:
        return '${libL10n.error}(auth)';
      case ConnectionResult.networkError:
        return '${libL10n.error}(${libL10n.network})';
      case ConnectionResult.unknownError:
        return '${libL10n.error}(${libL10n.unknown})';
    }
  }

  bool get isSuccess => this == ConnectionResult.success;
}