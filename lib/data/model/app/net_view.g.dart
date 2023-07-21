// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'net_view.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class NetViewTypeAdapter extends TypeAdapter<NetViewType> {
  @override
  final int typeId = 5;

  @override
  NetViewType read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return NetViewType.conn;
      case 1:
        return NetViewType.speed;
      case 2:
        return NetViewType.traffic;
      default:
        return NetViewType.conn;
    }
  }

  @override
  void write(BinaryWriter writer, NetViewType obj) {
    switch (obj) {
      case NetViewType.conn:
        writer.writeByte(0);
        break;
      case NetViewType.speed:
        writer.writeByte(1);
        break;
      case NetViewType.traffic:
        writer.writeByte(2);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NetViewTypeAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
