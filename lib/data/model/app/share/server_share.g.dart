// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'server_share.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_ServerShare _$ServerShareFromJson(Map<String, dynamic> json) => _ServerShare(
  version: (json['version'] as num).toInt(),
  spi: Spi.fromJson(json['spi'] as Map<String, dynamic>),
  keys:
      (json['keys'] as List<dynamic>?)
          ?.map((e) => PrivateKeyInfo.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const <PrivateKeyInfo>[],
  expiresAt: (json['expiresAt'] as num?)?.toInt(),
);

Map<String, dynamic> _$ServerShareToJson(_ServerShare instance) =>
    <String, dynamic>{
      'version': instance.version,
      'spi': instance.spi,
      'keys': instance.keys,
      'expiresAt': instance.expiresAt,
    };
