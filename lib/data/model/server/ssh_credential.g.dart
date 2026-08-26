// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'ssh_credential.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

SshCredential _$SshCredentialFromJson(Map<String, dynamic> json) =>
    SshCredential(
      ip: json['ip'] as String,
      port: (json['port'] as num?)?.toInt() ?? 22,
      user: json['user'] as String? ?? 'root',
      pwd: json['pwd'] as String?,
      keyId: json['pubKeyId'] as String?,
      keyPath: json['keyPath'] as String?,
      identityFiles: (json['identityFiles'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList(),
      alterUrl: json['alterUrl'] as String?,
      jumpId: json['jumpId'] as String?,
      jumpIds: (json['jumpIds'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList(),
      proxyCommand: json['proxyCommand'] as String?,
    );

Map<String, dynamic> _$SshCredentialToJson(SshCredential instance) =>
    <String, dynamic>{
      'ip': instance.ip,
      'port': instance.port,
      'user': instance.user,
      'pwd': ?instance.pwd,
      'pubKeyId': ?instance.keyId,
      'keyPath': ?instance.keyPath,
      'identityFiles': ?instance.identityFiles,
      'alterUrl': ?instance.alterUrl,
      'jumpId': ?instance.jumpId,
      'jumpIds': ?instance.jumpIds,
      'proxyCommand': ?instance.proxyCommand,
    };
