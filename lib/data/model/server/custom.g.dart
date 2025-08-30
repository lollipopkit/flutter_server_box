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
      if (instance.pveAddr case final value?) 'pveAddr': value,
      'pveIgnoreCert': instance.pveIgnoreCert,
      if (instance.cmds case final value?) 'cmds': value,
      if (instance.preferTempDev case final value?) 'preferTempDev': value,
      if (instance.logoUrl case final value?) 'logoUrl': value,
      if (instance.netDev case final value?) 'netDev': value,
      if (instance.scriptDir case final value?) 'scriptDir': value,
    };
