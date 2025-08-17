// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'custom.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ServerCustom _$ServerCustomFromJson(Map<String, dynamic> json) => ServerCustom(
  pveAddr: json['pveAddr'] as String?,
  pveIgnoreCert: json['pveIgnoreCert'] as bool? ?? false,
  cmds: (json['cmds'] as Map<String, dynamic>?)?.map(
    (k, e) => MapEntry(k, e as String),
  ),
  preferTempDev: json['preferTempDev'] as String?,
  logoUrl: json['logoUrl'] as String?,
  netDev: json['netDev'] as String?,
  scriptDir: json['scriptDir'] as String?,
);

Map<String, dynamic> _$ServerCustomToJson(ServerCustom instance) =>
    <String, dynamic>{
      'pveAddr': ?instance.pveAddr,
      'pveIgnoreCert': instance.pveIgnoreCert,
      'cmds': ?instance.cmds,
      'preferTempDev': ?instance.preferTempDev,
      'logoUrl': ?instance.logoUrl,
      'netDev': ?instance.netDev,
      'scriptDir': ?instance.scriptDir,
    };
