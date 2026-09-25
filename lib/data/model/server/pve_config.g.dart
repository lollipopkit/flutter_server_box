// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'pve_config.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_PveConfig _$PveConfigFromJson(Map<String, dynamic> json) => _PveConfig(
  addr: json['addr'] as String,
  auth:
      $enumDecodeNullable(
        _$PveAuthEnumMap,
        json['auth'],
        unknownValue: PveAuth.password,
      ) ??
      PveAuth.password,
  pwd: json['pwd'] as String?,
  tokenId: json['tokenId'] as String?,
  tokenSecret: json['tokenSecret'] as String?,
  certSha256: json['certSha256'] as String?,
);

Map<String, dynamic> _$PveConfigToJson(_PveConfig instance) =>
    <String, dynamic>{
      'addr': instance.addr,
      'auth': _$PveAuthEnumMap[instance.auth]!,
      'pwd': instance.pwd,
      'tokenId': instance.tokenId,
      'tokenSecret': instance.tokenSecret,
      'certSha256': instance.certSha256,
    };

const _$PveAuthEnumMap = {PveAuth.password: 'password', PveAuth.token: 'token'};
