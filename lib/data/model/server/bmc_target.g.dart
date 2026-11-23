// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'bmc_target.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_BmcTarget _$BmcTargetFromJson(Map<String, dynamic> json) => _BmcTarget(
  id: json['id'] as String,
  name: json['name'] as String,
  addr: json['addr'] as String,
  credId: json['credId'] as String?,
  certSha256: json['certSha256'] as String?,
  serverId: json['serverId'] as String?,
  tags: (json['tags'] as List<dynamic>?)?.map((e) => e as String).toList(),
);

Map<String, dynamic> _$BmcTargetToJson(_BmcTarget instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'addr': instance.addr,
      'credId': ?instance.credId,
      'certSha256': ?instance.certSha256,
      'serverId': ?instance.serverId,
      'tags': ?instance.tags,
    };
