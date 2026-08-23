// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'bmc_credential.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

BmcCredential _$BmcCredentialFromJson(Map<String, dynamic> json) =>
    BmcCredential(
      id: json['id'] as String,
      name: json['name'] as String,
      user: json['user'] as String,
      pwd: json['pwd'] as String?,
    );

Map<String, dynamic> _$BmcCredentialToJson(BmcCredential instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'user': instance.user,
      'pwd': instance.pwd,
    };
