// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'bmc_cfg.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

BmcCfg _$BmcCfgFromJson(Map<String, dynamic> json) => BmcCfg(
  addr: json['addr'] as String,
  credId: json['credId'] as String?,
  certSha256: json['certSha256'] as String?,
);

Map<String, dynamic> _$BmcCfgToJson(BmcCfg instance) => <String, dynamic>{
  'addr': instance.addr,
  'credId': ?instance.credId,
  'certSha256': ?instance.certSha256,
};
