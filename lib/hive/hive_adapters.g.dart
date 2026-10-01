// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'hive_adapters.dart';

// **************************************************************************
// AdaptersGenerator
// **************************************************************************

class NetViewTypeAdapter extends TypeAdapter<NetViewType> {
  @override
  final typeId = 5;

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
      case NetViewType.speed:
        writer.writeByte(1);
      case NetViewType.traffic:
        writer.writeByte(2);
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

class ServerFuncBtnAdapter extends TypeAdapter<ServerFuncBtn> {
  @override
  final typeId = 6;

  @override
  ServerFuncBtn read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return ServerFuncBtn.terminal;
      case 1:
        return ServerFuncBtn.files;
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
      case 9:
        return ServerFuncBtn.portForward;
      case 10:
        return ServerFuncBtn.power;
      case 12:
        return ServerFuncBtn.users;
      case 13:
        return ServerFuncBtn.scheduledTasks;
      case 14:
        return ServerFuncBtn.remoteDesktop;
      case 15:
        return ServerFuncBtn.firewall;
      default:
        return ServerFuncBtn.terminal;
    }
  }

  @override
  void write(BinaryWriter writer, ServerFuncBtn obj) {
    switch (obj) {
      case ServerFuncBtn.terminal:
        writer.writeByte(0);
      case ServerFuncBtn.files:
        writer.writeByte(1);
      case ServerFuncBtn.container:
        writer.writeByte(2);
      case ServerFuncBtn.process:
        writer.writeByte(3);
      case ServerFuncBtn.snippet:
        writer.writeByte(5);
      case ServerFuncBtn.iperf:
        writer.writeByte(6);
      case ServerFuncBtn.systemd:
        writer.writeByte(8);
      case ServerFuncBtn.portForward:
        writer.writeByte(9);
      case ServerFuncBtn.power:
        writer.writeByte(10);
      case ServerFuncBtn.users:
        writer.writeByte(12);
      case ServerFuncBtn.scheduledTasks:
        writer.writeByte(13);
      case ServerFuncBtn.remoteDesktop:
        writer.writeByte(14);
      case ServerFuncBtn.firewall:
        writer.writeByte(15);
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

class WakeOnLanCfgAdapter extends TypeAdapter<WakeOnLanCfg> {
  @override
  final typeId = 8;

  @override
  WakeOnLanCfg read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return WakeOnLanCfg(
      mac: fields[0] as String,
      ip: fields[1] as String,
      pwd: fields[2] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, WakeOnLanCfg obj) {
    writer
      ..writeByte(3)
      ..writeByte(0)
      ..write(obj.mac)
      ..writeByte(1)
      ..write(obj.ip)
      ..writeByte(2)
      ..write(obj.pwd);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WakeOnLanCfgAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class SystemTypeAdapter extends TypeAdapter<SystemType> {
  @override
  final typeId = 9;

  @override
  SystemType read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return SystemType.linux;
      case 1:
        return SystemType.bsd;
      case 2:
        return SystemType.windows;
      default:
        return SystemType.linux;
    }
  }

  @override
  void write(BinaryWriter writer, SystemType obj) {
    switch (obj) {
      case SystemType.linux:
        writer.writeByte(0);
      case SystemType.bsd:
        writer.writeByte(1);
      case SystemType.windows:
        writer.writeByte(2);
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SystemTypeAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class PortForwardConfigAdapter extends TypeAdapter<PortForwardConfig> {
  @override
  final typeId = 10;

  @override
  PortForwardConfig read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return PortForwardConfig(
      id: fields[0] as String,
      serverId: fields[7] as String,
      name: fields[1] as String,
      type: fields[8] as PortForwardType,
      localHost: fields[2] as String?,
      localPort: fields[3] == null ? 0 : (fields[3] as num).toInt(),
      remoteHost: fields[4] as String?,
      remotePort: (fields[5] as num?)?.toInt(),
    );
  }

  @override
  void write(BinaryWriter writer, PortForwardConfig obj) {
    writer
      ..writeByte(8)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.localHost)
      ..writeByte(3)
      ..write(obj.localPort)
      ..writeByte(4)
      ..write(obj.remoteHost)
      ..writeByte(5)
      ..write(obj.remotePort)
      ..writeByte(7)
      ..write(obj.serverId)
      ..writeByte(8)
      ..write(obj.type);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PortForwardConfigAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class PortForwardTypeAdapter extends TypeAdapter<PortForwardType> {
  @override
  final typeId = 12;

  @override
  PortForwardType read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return PortForwardType.local;
      case 1:
        return PortForwardType.remote;
      case 2:
        return PortForwardType.dynamic;
      default:
        return PortForwardType.local;
    }
  }

  @override
  void write(BinaryWriter writer, PortForwardType obj) {
    switch (obj) {
      case PortForwardType.local:
        writer.writeByte(0);
      case PortForwardType.remote:
        writer.writeByte(1);
      case PortForwardType.dynamic:
        writer.writeByte(2);
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PortForwardTypeAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
