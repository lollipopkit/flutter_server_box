// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'block_device.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

BlockDevice _$BlockDeviceFromJson(Map<String, dynamic> json) => BlockDevice(
  name: json['name'] as String,
  path: json['path'] as String? ?? '',
  kind: json['kind'] as String,
  model: json['model'] as String?,
  size: (json['size'] as num?)?.toInt() ?? 0,
  tran: json['tran'] as String?,
  fsType: json['fs_type'] as String?,
  mount: json['mount'] as String?,
  children:
      (json['children'] as List<dynamic>?)
          ?.map((e) => BlockDevice.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const [],
);

Map<String, dynamic> _$BlockDeviceToJson(BlockDevice instance) =>
    <String, dynamic>{
      'name': instance.name,
      'path': instance.path,
      'kind': instance.kind,
      'model': instance.model,
      'size': instance.size,
      'tran': instance.tran,
      'fs_type': instance.fsType,
      'mount': instance.mount,
      'children': instance.children,
    };
