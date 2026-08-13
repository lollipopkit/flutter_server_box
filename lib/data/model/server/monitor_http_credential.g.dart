// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'monitor_http_credential.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

MonitorHttpCredential _$MonitorHttpCredentialFromJson(
  Map<String, dynamic> json,
) => MonitorHttpCredential(
  addr: json['addr'] as String,
  user: json['user'] as String?,
  pwd: json['pwd'] as String?,
  ignoreCert: json['ignoreCert'] as bool? ?? false,
  fullAccess: json['fullAccess'] as bool? ?? false,
);

Map<String, dynamic> _$MonitorHttpCredentialToJson(
  MonitorHttpCredential instance,
) => <String, dynamic>{
  'addr': instance.addr,
  'user': ?instance.user,
  'pwd': ?instance.pwd,
  'ignoreCert': instance.ignoreCert,
  'fullAccess': instance.fullAccess,
};
