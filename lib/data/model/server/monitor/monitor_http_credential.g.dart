// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'monitor_http_credential.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

MonitorHttpCredential _$MonitorHttpCredentialFromJson(
  Map<String, dynamic> json,
) => MonitorHttpCredential(
  addr: json['addr'] as String,
  pwd: json['pwd'] as String?,
  legacyUser: json['user'] as String?,
  certSha256: json['certSha256'] as String?,
  allowInsecure: json['allowInsecure'] as bool? ?? false,
);

Map<String, dynamic> _$MonitorHttpCredentialToJson(
  MonitorHttpCredential instance,
) => <String, dynamic>{
  'addr': instance.addr,
  'pwd': ?instance.pwd,
  'user': ?instance.legacyUser,
  'certSha256': ?instance.certSha256,
  'allowInsecure': instance.allowInsecure,
};
