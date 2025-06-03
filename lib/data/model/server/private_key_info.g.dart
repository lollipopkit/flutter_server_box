// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'private_key_info.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

PrivateKeyInfo _$PrivateKeyInfoFromJson(Map<String, dynamic> json) =>
    PrivateKeyInfo(
      id: json['id'] as String,
      key: json['private_key'] as String,
    );

Map<String, dynamic> _$PrivateKeyInfoToJson(PrivateKeyInfo instance) =>
    <String, dynamic>{'id': instance.id, 'private_key': instance.key};
