// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'connection_stat.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class ConnectionStatAdapter extends TypeAdapter<ConnectionStat> {
  @override
  final typeId = 100;

  @override
  ConnectionStat read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ConnectionStat(
      serverId: fields[0] as String,
      serverName: fields[1] as String,
      timestamp: fields[2] as DateTime,
      result: fields[3] as ConnectionResult,
      errorMessage: fields[4] == null ? '' : fields[4] as String,
      durationMs: (fields[5] as num).toInt(),
    );
  }

  @override
  void write(BinaryWriter writer, ConnectionStat obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.serverId)
      ..writeByte(1)
      ..write(obj.serverName)
      ..writeByte(2)
      ..write(obj.timestamp)
      ..writeByte(3)
      ..write(obj.result)
      ..writeByte(4)
      ..write(obj.errorMessage)
      ..writeByte(5)
      ..write(obj.durationMs);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ConnectionStatAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class ServerConnectionStatsAdapter extends TypeAdapter<ServerConnectionStats> {
  @override
  final typeId = 101;

  @override
  ServerConnectionStats read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ServerConnectionStats(
      serverId: fields[0] as String,
      serverName: fields[1] as String,
      totalAttempts: (fields[2] as num).toInt(),
      successCount: (fields[3] as num).toInt(),
      failureCount: (fields[4] as num).toInt(),
      lastSuccessTime: fields[5] == null ? null : fields[5] as DateTime?,
      lastFailureTime: fields[6] == null ? null : fields[6] as DateTime?,
      recentConnections: fields[7] == null
          ? []
          : (fields[7] as List).cast<ConnectionStat>(),
      successRate: (fields[8] as num).toDouble(),
    );
  }

  @override
  void write(BinaryWriter writer, ServerConnectionStats obj) {
    writer
      ..writeByte(9)
      ..writeByte(0)
      ..write(obj.serverId)
      ..writeByte(1)
      ..write(obj.serverName)
      ..writeByte(2)
      ..write(obj.totalAttempts)
      ..writeByte(3)
      ..write(obj.successCount)
      ..writeByte(4)
      ..write(obj.failureCount)
      ..writeByte(5)
      ..write(obj.lastSuccessTime)
      ..writeByte(6)
      ..write(obj.lastFailureTime)
      ..writeByte(7)
      ..write(obj.recentConnections)
      ..writeByte(8)
      ..write(obj.successRate);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ServerConnectionStatsAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class ConnectionResultAdapter extends TypeAdapter<ConnectionResult> {
  @override
  final typeId = 102;

  @override
  ConnectionResult read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return ConnectionResult.success;
      case 1:
        return ConnectionResult.timeout;
      case 2:
        return ConnectionResult.authFailed;
      case 3:
        return ConnectionResult.networkError;
      case 4:
        return ConnectionResult.unknownError;
      default:
        return ConnectionResult.success;
    }
  }

  @override
  void write(BinaryWriter writer, ConnectionResult obj) {
    switch (obj) {
      case ConnectionResult.success:
        writer.writeByte(0);
      case ConnectionResult.timeout:
        writer.writeByte(1);
      case ConnectionResult.authFailed:
        writer.writeByte(2);
      case ConnectionResult.networkError:
        writer.writeByte(3);
      case ConnectionResult.unknownError:
        writer.writeByte(4);
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ConnectionResultAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

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
