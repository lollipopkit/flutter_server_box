// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'snippet.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_Snippet _$SnippetFromJson(Map<String, dynamic> json) => _Snippet(
  name: json['name'] as String,
  script: json['script'] as String,
  tags: (json['tags'] as List<dynamic>?)?.map((e) => e as String).toList(),
  note: json['note'] as String?,
  autoRunOn: (json['autoRunOn'] as List<dynamic>?)
      ?.map((e) => e as String)
      .toList(),
);

Map<String, dynamic> _$SnippetToJson(_Snippet instance) => <String, dynamic>{
  'name': instance.name,
  'script': instance.script,
  'tags': instance.tags,
  'note': instance.note,
  'autoRunOn': instance.autoRunOn,
};
