// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'server_func.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class ServerFuncBtnAdapter extends TypeAdapter<ServerFuncBtn> {
  @override
  final int typeId = 6;

  @override
  ServerFuncBtn read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return ServerFuncBtn.terminal;
      case 1:
        return ServerFuncBtn.sftp;
      case 2:
        return ServerFuncBtn.container;
      case 3:
        return ServerFuncBtn.process;
      case 5:
        return ServerFuncBtn.snippet;
      case 6:
        return ServerFuncBtn.iperf;
      case 8:
        return ServerFuncBtn.systemd;
      default:
        return ServerFuncBtn.terminal;
    }
  }

  @override
  void write(BinaryWriter writer, ServerFuncBtn obj) {
    switch (obj) {
      case ServerFuncBtn.terminal:
        writer.writeByte(0);
        break;
      case ServerFuncBtn.sftp:
        writer.writeByte(1);
        break;
      case ServerFuncBtn.container:
        writer.writeByte(2);
        break;
      case ServerFuncBtn.process:
        writer.writeByte(3);
        break;
      case ServerFuncBtn.snippet:
        writer.writeByte(5);
        break;
      case ServerFuncBtn.iperf:
        writer.writeByte(6);
        break;
      case ServerFuncBtn.systemd:
        writer.writeByte(8);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ServerFuncBtnAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
