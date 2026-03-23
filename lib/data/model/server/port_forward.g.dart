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
      localHost: json['localHost'] as String? ?? 'localhost',
      localPort: (json['localPort'] as num).toInt(),
      remoteHost: json['remoteHost'] as String,
      remotePort: (json['remotePort'] as num).toInt(),
      description: json['description'] as String?,
    );

Map<String, dynamic> _$PortForwardConfigToJson(_PortForwardConfig instance) =>
    <String, dynamic>{
      'id': instance.id,
      'serverId': instance.serverId,
      'name': instance.name,
      'localHost': instance.localHost,
      'localPort': instance.localPort,
      'remoteHost': instance.remoteHost,
      'remotePort': instance.remotePort,
      'description': instance.description,
    };
