// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'private_key_info.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

PrivateKeyInfo _$PrivateKeyInfoFromJson(Map<String, dynamic> json) =>
    PrivateKeyInfo(
      id: json['id'] as String,
      name: json['name'] as String,
      key: json['private_key'] as String,
      comment: json['comment'] as String?,
    );

Map<String, dynamic> _$PrivateKeyInfoToJson(PrivateKeyInfo instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'private_key': instance.key,
      'comment': instance.comment,
    };
