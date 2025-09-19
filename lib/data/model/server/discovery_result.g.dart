// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'discovery_result.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_SshDiscoveryResult _$SshDiscoveryResultFromJson(Map<String, dynamic> json) =>
    _SshDiscoveryResult(
      ip: json['ip'] as String,
      port: (json['port'] as num).toInt(),
      banner: json['banner'] as String?,
      isSelected: json['isSelected'] as bool? ?? false,
    );

Map<String, dynamic> _$SshDiscoveryResultToJson(_SshDiscoveryResult instance) =>
    <String, dynamic>{
      'ip': instance.ip,
      'port': instance.port,
      'banner': instance.banner,
      'isSelected': instance.isSelected,
    };

_SshDiscoveryReport _$SshDiscoveryReportFromJson(Map<String, dynamic> json) =>
    _SshDiscoveryReport(
      generatedAt: json['generatedAt'] as String,
      durationMs: (json['durationMs'] as num).toInt(),
      count: (json['count'] as num).toInt(),
      items: (json['items'] as List<dynamic>)
          .map((e) => SshDiscoveryResult.fromJson(e as Map<String, dynamic>))
          .toList(),
    );

Map<String, dynamic> _$SshDiscoveryReportToJson(_SshDiscoveryReport instance) =>
    <String, dynamic>{
      'generatedAt': instance.generatedAt,
      'durationMs': instance.durationMs,
      'count': instance.count,
      'items': instance.items,
    };
