// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'snippet.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class SnippetAdapter extends TypeAdapter<Snippet> {
  @override
  final int typeId = 2;

  @override
  Snippet read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Snippet(
      name: fields[0] as String,
      script: fields[1] as String,
      tags: (fields[2] as List?)?.cast<String>(),
      note: fields[3] as String?,
      autoRunOn: (fields[4] as List?)?.cast<String>(),
    );
  }

  @override
  void write(BinaryWriter writer, Snippet obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.name)
      ..writeByte(1)
      ..write(obj.script)
      ..writeByte(2)
      ..write(obj.tags)
      ..writeByte(3)
      ..write(obj.note)
      ..writeByte(4)
      ..write(obj.autoRunOn);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SnippetAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Snippet _$SnippetFromJson(Map<String, dynamic> json) => Snippet(
      name: json['name'] as String,
      script: json['script'] as String,
      tags: (json['tags'] as List<dynamic>?)?.map((e) => e as String).toList(),
      note: json['note'] as String?,
      autoRunOn: (json['autoRunOn'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList(),
    );

Map<String, dynamic> _$SnippetToJson(Snippet instance) => <String, dynamic>{
      'name': instance.name,
      'script': instance.script,
      'tags': instance.tags,
      'note': instance.note,
      'autoRunOn': instance.autoRunOn,
    };
