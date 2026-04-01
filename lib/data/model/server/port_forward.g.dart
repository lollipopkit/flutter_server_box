// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'port_forward.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_PortForwardConfig _$PortForwardConfigFromJson(Map<String, dynamic> json) =>
    _PortForwardConfig(
      id: json['id'] as String,
      serverId: json['serverId'] as String,
      name: json['name'] as String,
      type: $enumDecode(_$PortForwardTypeEnumMap, json['type']),
      localHost: json['localHost'] as String?,
      localPort: (json['localPort'] as num?)?.toInt() ?? 0,
      remoteHost: json['remoteHost'] as String?,
      remotePort: (json['remotePort'] as num?)?.toInt(),
    );

Map<String, dynamic> _$PortForwardConfigToJson(_PortForwardConfig instance) =>
    <String, dynamic>{
      'id': instance.id,
      'serverId': instance.serverId,
      'name': instance.name,
      'type': _$PortForwardTypeEnumMap[instance.type]!,
      'localHost': instance.localHost,
      'localPort': instance.localPort,
      'remoteHost': instance.remoteHost,
      'remotePort': instance.remotePort,
    };

const _$PortForwardTypeEnumMap = {
  PortForwardType.local: 'local',
  PortForwardType.remote: 'remote',
  PortForwardType.dynamic: 'dynamic',
};
