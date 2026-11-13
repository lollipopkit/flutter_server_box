// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'swap_area.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

SwapArea _$SwapAreaFromJson(Map<String, dynamic> json) => SwapArea(
  path: json['path'] as String,
  kind: json['kind'] as String? ?? '',
  size: (json['size'] as num?)?.toInt() ?? 0,
  used: (json['used'] as num?)?.toInt() ?? 0,
  priority: (json['priority'] as num?)?.toInt() ?? 0,
);

Map<String, dynamic> _$SwapAreaToJson(SwapArea instance) => <String, dynamic>{
  'path': instance.path,
  'kind': instance.kind,
  'size': instance.size,
  'used': instance.used,
  'priority': instance.priority,
};
