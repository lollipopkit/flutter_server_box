// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'connection_stat.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_ConnectionStat _$ConnectionStatFromJson(Map<String, dynamic> json) =>
    _ConnectionStat(
      serverId: json['serverId'] as String,
      serverName: json['serverName'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      result: $enumDecode(_$ConnectionResultEnumMap, json['result']),
      errorMessage: json['errorMessage'] as String? ?? '',
      durationMs: (json['durationMs'] as num).toInt(),
    );

Map<String, dynamic> _$ConnectionStatToJson(_ConnectionStat instance) =>
    <String, dynamic>{
      'serverId': instance.serverId,
      'serverName': instance.serverName,
      'timestamp': instance.timestamp.toIso8601String(),
      'result': _$ConnectionResultEnumMap[instance.result]!,
      'errorMessage': instance.errorMessage,
      'durationMs': instance.durationMs,
    };

const _$ConnectionResultEnumMap = {
  ConnectionResult.success: 'success',
  ConnectionResult.timeout: 'timeout',
  ConnectionResult.authFailed: 'auth_failed',
  ConnectionResult.networkError: 'network_error',
  ConnectionResult.unknownError: 'unknown_error',
};

_ServerConnectionStats _$ServerConnectionStatsFromJson(
  Map<String, dynamic> json,
) => _ServerConnectionStats(
  serverId: json['serverId'] as String,
  serverName: json['serverName'] as String,
  totalAttempts: (json['totalAttempts'] as num).toInt(),
  successCount: (json['successCount'] as num).toInt(),
  failureCount: (json['failureCount'] as num).toInt(),
  lastSuccessTime: json['lastSuccessTime'] == null
      ? null
      : DateTime.parse(json['lastSuccessTime'] as String),
  lastFailureTime: json['lastFailureTime'] == null
      ? null
      : DateTime.parse(json['lastFailureTime'] as String),
  recentConnections:
      (json['recentConnections'] as List<dynamic>?)
          ?.map((e) => ConnectionStat.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const [],
  successRate: (json['successRate'] as num).toDouble(),
);

Map<String, dynamic> _$ServerConnectionStatsToJson(
  _ServerConnectionStats instance,
) => <String, dynamic>{
  'serverId': instance.serverId,
  'serverName': instance.serverName,
  'totalAttempts': instance.totalAttempts,
  'successCount': instance.successCount,
  'failureCount': instance.failureCount,
  'lastSuccessTime': instance.lastSuccessTime?.toIso8601String(),
  'lastFailureTime': instance.lastFailureTime?.toIso8601String(),
  'recentConnections': instance.recentConnections,
  'successRate': instance.successRate,
};
