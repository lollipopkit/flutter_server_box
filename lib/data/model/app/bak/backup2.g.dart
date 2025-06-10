// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'backup2.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_BackupV2 _$BackupV2FromJson(Map<String, dynamic> json) => _BackupV2(
  version: (json['version'] as num).toInt(),
  date: (json['date'] as num).toInt(),
  spis: json['spis'] as Map<String, dynamic>,
  snippets: json['snippets'] as Map<String, dynamic>,
  keys: json['keys'] as Map<String, dynamic>,
  container: json['container'] as Map<String, dynamic>,
  history: json['history'] as Map<String, dynamic>,
  settings: json['settings'] as Map<String, dynamic>,
);

Map<String, dynamic> _$BackupV2ToJson(_BackupV2 instance) => <String, dynamic>{
  'version': instance.version,
  'date': instance.date,
  'spis': instance.spis,
  'snippets': instance.snippets,
  'keys': instance.keys,
  'container': instance.container,
  'history': instance.history,
  'settings': instance.settings,
};
