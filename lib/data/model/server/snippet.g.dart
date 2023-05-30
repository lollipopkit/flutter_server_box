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
      fields[0] as String,
      fields[1] as String,
      tags: (fields[2] as List?)?.cast<String>(),
    );
  }

  @override
  void write(BinaryWriter writer, Snippet obj) {
    writer
      ..writeByte(3)
      ..writeByte(0)
      ..write(obj.name)
      ..writeByte(1)
      ..write(obj.script)
      ..writeByte(2)
      ..write(obj.tags);
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
