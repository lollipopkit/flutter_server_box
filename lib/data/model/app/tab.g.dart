// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'tab.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class AppTabAdapter extends TypeAdapter<AppTab> {
  @override
  final typeId = 103;

  @override
  AppTab read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return AppTab.server;
      case 1:
        return AppTab.ssh;
      case 2:
        return AppTab.file;
      case 3:
        return AppTab.snippet;
      default:
        return AppTab.server;
    }
  }

  @override
  void write(BinaryWriter writer, AppTab obj) {
    switch (obj) {
      case AppTab.server:
        writer.writeByte(0);
      case AppTab.ssh:
        writer.writeByte(1);
      case AppTab.file:
        writer.writeByte(2);
      case AppTab.snippet:
        writer.writeByte(3);
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppTabAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
