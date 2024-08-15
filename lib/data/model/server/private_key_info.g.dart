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
      id: fields[0] as String,
      key: fields[1] as String,
    );
  }

  @override
  void write(BinaryWriter writer, PrivateKeyInfo obj) {
    writer
      ..writeByte(2)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.key);
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

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

PrivateKeyInfo _$PrivateKeyInfoFromJson(Map<String, dynamic> json) =>
    PrivateKeyInfo(
      id: json['id'] as String,
      key: json['private_key'] as String,
    );

Map<String, dynamic> _$PrivateKeyInfoToJson(PrivateKeyInfo instance) =>
    <String, dynamic>{
      'id': instance.id,
      'private_key': instance.key,
    };
