// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'custom.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class ServerCustomAdapter extends TypeAdapter<ServerCustom> {
  @override
  final int typeId = 7;

  @override
  ServerCustom read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ServerCustom(
      pveAddr: fields[1] as String?,
      pveIgnoreCert: fields[2] == null ? false : fields[2] as bool,
      cmds: (fields[3] as Map?)?.cast<String, String>(),
    );
  }

  @override
  void write(BinaryWriter writer, ServerCustom obj) {
    writer
      ..writeByte(3)
      ..writeByte(1)
      ..write(obj.pveAddr)
      ..writeByte(2)
      ..write(obj.pveIgnoreCert)
      ..writeByte(3)
      ..write(obj.cmds);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ServerCustomAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
