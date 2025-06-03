// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'snippet.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$SnippetImpl _$$SnippetImplFromJson(Map<String, dynamic> json) =>
    _$SnippetImpl(
      name: json['name'] as String,
      script: json['script'] as String,
      tags: (json['tags'] as List<dynamic>?)?.map((e) => e as String).toList(),
      note: json['note'] as String?,
      autoRunOn: (json['autoRunOn'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList(),
    );

Map<String, dynamic> _$$SnippetImplToJson(_$SnippetImpl instance) =>
    <String, dynamic>{
      'name': instance.name,
      'script': instance.script,
      'tags': instance.tags,
      'note': instance.note,
      'autoRunOn': instance.autoRunOn,
    };
