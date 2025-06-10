// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'server_private_info.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_Spi _$SpiFromJson(Map<String, dynamic> json) => _Spi(
  name: json['name'] as String,
  ip: json['ip'] as String,
  port: (json['port'] as num).toInt(),
  user: json['user'] as String,
  pwd: json['pwd'] as String?,
  keyId: json['pubKeyId'] as String?,
  tags: (json['tags'] as List<dynamic>?)?.map((e) => e as String).toList(),
  alterUrl: json['alterUrl'] as String?,
  autoConnect: json['autoConnect'] as bool? ?? true,
  jumpId: json['jumpId'] as String?,
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
);

Map<String, dynamic> _$SpiToJson(_Spi instance) => <String, dynamic>{
  'name': instance.name,
  'ip': instance.ip,
  'port': instance.port,
  'user': instance.user,
  if (instance.pwd case final value?) 'pwd': value,
  if (instance.keyId case final value?) 'pubKeyId': value,
  if (instance.tags case final value?) 'tags': value,
  if (instance.alterUrl case final value?) 'alterUrl': value,
  'autoConnect': instance.autoConnect,
  if (instance.jumpId case final value?) 'jumpId': value,
  if (instance.custom case final value?) 'custom': value,
  if (instance.wolCfg case final value?) 'wolCfg': value,
  if (instance.envs case final value?) 'envs': value,
  'id': instance.id,
};
