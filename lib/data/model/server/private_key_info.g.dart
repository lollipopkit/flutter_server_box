// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'private_key_info.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class PrivateKeyInfoAdapter extends TypeAdapter<PrivateKeyInfo> {
  @override
  final int typeId = 1;

  @override
  PrivateKeyInfo read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return PrivateKeyInfo(
      fields[0] as String,
      fields[1] as String,
      fields[2] as String,
    );
  }

  @override
  void write(BinaryWriter writer, PrivateKeyInfo obj) {
    writer
      ..writeByte(3)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.privateKey)
      ..writeByte(2)
      ..write(obj.password);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PrivateKeyInfoAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
