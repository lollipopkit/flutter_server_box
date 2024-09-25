// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'backup.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Backup _$BackupFromJson(Map<String, dynamic> json) => Backup(
      version: (json['version'] as num).toInt(),
      date: json['date'] as String,
      spis: (json['spis'] as List<dynamic>)
          .map((e) => Spi.fromJson(e as Map<String, dynamic>))
          .toList(),
      snippets: (json['snippets'] as List<dynamic>)
          .map((e) => Snippet.fromJson(e as Map<String, dynamic>))
          .toList(),
      keys: (json['keys'] as List<dynamic>)
          .map((e) => PrivateKeyInfo.fromJson(e as Map<String, dynamic>))
          .toList(),
      container: json['container'] as Map<String, dynamic>,
      history: json['history'] as Map<String, dynamic>,
      settings: json['settings'] as Map<String, dynamic>?,
      lastModTime: (json['lastModTime'] as num?)?.toInt(),
    );

Map<String, dynamic> _$BackupToJson(Backup instance) => <String, dynamic>{
      'version': instance.version,
      'date': instance.date,
      'spis': instance.spis,
      'snippets': instance.snippets,
      'keys': instance.keys,
      'container': instance.container,
      'history': instance.history,
      'lastModTime': instance.lastModTime,
      'settings': instance.settings,
    };
