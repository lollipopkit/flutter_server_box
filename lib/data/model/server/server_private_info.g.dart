// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'server_private_info.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_Spi _$SpiFromJson(Map<String, dynamic> json) => _Spi(
  name: json['name'] as String,
  ssh: json['ssh'] == null
      ? null
      : SshCredential.fromJson(json['ssh'] as Map<String, dynamic>),
  monitorHttp: json['monitorHttp'] == null
      ? null
      : MonitorHttpCredential.fromJson(
          json['monitorHttp'] as Map<String, dynamic>,
        ),
  tags: (json['tags'] as List<dynamic>?)?.map((e) => e as String).toList(),
  autoConnect: json['autoConnect'] as bool? ?? true,
  custom: json['custom'] == null
      ? null
      : ServerCustom.fromJson(json['custom'] as Map<String, dynamic>),
  wolCfg: json['wolCfg'] == null
      ? null
      : WakeOnLanCfg.fromJson(json['wolCfg'] as Map<String, dynamic>),
  envs: (json['envs'] as Map<String, dynamic>?)?.map(
    (k, e) => MapEntry(k, e as String),
  ),
  id: json['id'] == null ? '' : Spi.parseId(json['id']),
  customSystemType: $enumDecodeNullable(
    _$SystemTypeEnumMap,
    json['customSystemType'],
  ),
  disabledCmdTypes: (json['disabledCmdTypes'] as List<dynamic>?)
      ?.map((e) => e as String)
      .toList(),
);

Map<String, dynamic> _$SpiToJson(_Spi instance) => <String, dynamic>{
  'name': instance.name,
  'ssh': ?instance.ssh,
  'monitorHttp': ?instance.monitorHttp,
  'tags': ?instance.tags,
  'autoConnect': instance.autoConnect,
  'custom': ?instance.custom,
  'wolCfg': ?instance.wolCfg,
  'envs': ?instance.envs,
  'id': instance.id,
  'customSystemType': ?_$SystemTypeEnumMap[instance.customSystemType],
  'disabledCmdTypes': ?instance.disabledCmdTypes,
};

const _$SystemTypeEnumMap = {
  SystemType.linux: 'linux',
  SystemType.bsd: 'bsd',
  SystemType.windows: 'windows',
};
