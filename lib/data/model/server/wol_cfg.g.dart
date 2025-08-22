// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'wol_cfg.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

WakeOnLanCfg _$WakeOnLanCfgFromJson(Map<String, dynamic> json) => WakeOnLanCfg(
  mac: json['mac'] as String,
  ip: json['ip'] as String,
  pwd: json['pwd'] as String?,
);

Map<String, dynamic> _$WakeOnLanCfgToJson(WakeOnLanCfg instance) =>
    <String, dynamic>{
      'mac': instance.mac,
      'ip': instance.ip,
      if (instance.pwd case final value?) 'pwd': value,
    };
