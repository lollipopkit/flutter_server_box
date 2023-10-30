// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'server_private_info.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class ServerPrivateInfoAdapter extends TypeAdapter<ServerPrivateInfo> {
  @override
  final int typeId = 3;

  @override
  ServerPrivateInfo read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ServerPrivateInfo(
      name: fields[0] as String,
      ip: fields[1] as String,
      port: fields[2] as int,
      user: fields[3] as String,
      pwd: fields[4] as String?,
      keyId: fields[5] as String?,
      tags: (fields[6] as List?)?.cast<String>(),
      alterUrl: fields[7] as String?,
      autoConnect: fields[8] as bool?,
      jumpId: fields[9] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, ServerPrivateInfo obj) {
    writer
      ..writeByte(10)
      ..writeByte(0)
      ..write(obj.name)
      ..writeByte(1)
      ..write(obj.ip)
      ..writeByte(2)
      ..write(obj.port)
      ..writeByte(3)
      ..write(obj.user)
      ..writeByte(4)
      ..write(obj.pwd)
      ..writeByte(5)
      ..write(obj.keyId)
      ..writeByte(6)
      ..write(obj.tags)
      ..writeByte(7)
      ..write(obj.alterUrl)
      ..writeByte(8)
      ..write(obj.autoConnect)
      ..writeByte(9)
      ..write(obj.jumpId);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ServerPrivateInfoAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
