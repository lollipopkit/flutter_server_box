// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'bmc_cfg.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

BmcCfg _$BmcCfgFromJson(Map<String, dynamic> json) => BmcCfg(
  addr: json['addr'] as String,
  user: json['user'] as String,
  pwd: json['pwd'] as String?,
  certSha256: json['certSha256'] as String?,
);

Map<String, dynamic> _$BmcCfgToJson(BmcCfg instance) => <String, dynamic>{
  'addr': instance.addr,
  'user': instance.user,
  'pwd': ?instance.pwd,
  'certSha256': ?instance.certSha256,
};
