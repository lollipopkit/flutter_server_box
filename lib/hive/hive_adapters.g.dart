// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'hive_adapters.dart';

// **************************************************************************
// AdaptersGenerator
// **************************************************************************

class PrivateKeyInfoAdapter extends TypeAdapter<PrivateKeyInfo> {
  @override
  final typeId = 1;

  @override
  PrivateKeyInfo read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return PrivateKeyInfo(id: fields[0] as String, key: fields[1] as String);
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

class SnippetAdapter extends TypeAdapter<Snippet> {
  @override
  final typeId = 2;

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

class SpiAdapter extends TypeAdapter<Spi> {
  @override
  final typeId = 3;

  @override
  Spi read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Spi(
      name: fields[0] as String,
      ip: fields[1] as String,
      port: (fields[2] as num).toInt(),
      user: fields[3] as String,
      pwd: fields[4] as String?,
      keyId: fields[5] as String?,
      tags: (fields[6] as List?)?.cast<String>(),
      alterUrl: fields[7] as String?,
      autoConnect: fields[8] == null ? true : fields[8] as bool,
      jumpId: fields[9] as String?,
      custom: fields[10] as ServerCustom?,
      wolCfg: fields[11] as WakeOnLanCfg?,
      envs: (fields[12] as Map?)?.cast<String, String>(),
      id: fields[13] == null ? '' : fields[13] as String,
      customSystemType: fields[14] as SystemType?,
      disabledCmdTypes: (fields[15] as List?)?.cast<String>(),
    );
  }

  @override
  void write(BinaryWriter writer, Spi obj) {
    writer
      ..writeByte(16)
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
      ..write(obj.jumpId)
      ..writeByte(10)
      ..write(obj.custom)
      ..writeByte(11)
      ..write(obj.wolCfg)
      ..writeByte(12)
      ..write(obj.envs)
      ..writeByte(13)
      ..write(obj.id)
      ..writeByte(14)
      ..write(obj.customSystemType)
      ..writeByte(15)
      ..write(obj.disabledCmdTypes);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SpiAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class VirtKeyAdapter extends TypeAdapter<VirtKey> {
  @override
  final typeId = 4;

  @override
  VirtKey read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return VirtKey.esc;
      case 1:
        return VirtKey.alt;
      case 2:
        return VirtKey.home;
      case 3:
        return VirtKey.up;
      case 4:
        return VirtKey.end;
      case 5:
        return VirtKey.sftp;
      case 6:
        return VirtKey.snippet;
      case 7:
        return VirtKey.tab;
      case 8:
        return VirtKey.ctrl;
      case 9:
        return VirtKey.left;
      case 10:
        return VirtKey.down;
      case 11:
        return VirtKey.right;
      case 12:
        return VirtKey.clipboard;
      case 13:
        return VirtKey.ime;
      case 14:
        return VirtKey.pgup;
      case 15:
        return VirtKey.pgdn;
      case 16:
        return VirtKey.slash;
      case 17:
        return VirtKey.backSlash;
      case 18:
        return VirtKey.underscore;
      case 19:
        return VirtKey.plus;
      case 20:
        return VirtKey.equal;
      case 21:
        return VirtKey.minus;
      case 22:
        return VirtKey.parenLeft;
      case 23:
        return VirtKey.parenRight;
      case 24:
        return VirtKey.bracketLeft;
      case 25:
        return VirtKey.bracketRight;
      case 26:
        return VirtKey.braceLeft;
      case 27:
        return VirtKey.braceRight;
      case 28:
        return VirtKey.chevronLeft;
      case 29:
        return VirtKey.chevronRight;
      case 30:
        return VirtKey.colon;
      case 31:
        return VirtKey.semicolon;
      case 32:
        return VirtKey.f1;
      case 33:
        return VirtKey.f2;
      case 34:
        return VirtKey.f3;
      case 35:
        return VirtKey.f4;
      case 36:
        return VirtKey.f5;
      case 37:
        return VirtKey.f6;
      case 38:
        return VirtKey.f7;
      case 39:
        return VirtKey.f8;
      case 40:
        return VirtKey.f9;
      case 41:
        return VirtKey.f10;
      case 42:
        return VirtKey.f11;
      case 43:
        return VirtKey.f12;
      case 44:
        return VirtKey.shift;
      default:
        return VirtKey.esc;
    }
  }

  @override
  void write(BinaryWriter writer, VirtKey obj) {
    switch (obj) {
      case VirtKey.esc:
        writer.writeByte(0);
      case VirtKey.alt:
        writer.writeByte(1);
      case VirtKey.home:
        writer.writeByte(2);
      case VirtKey.up:
        writer.writeByte(3);
      case VirtKey.end:
        writer.writeByte(4);
      case VirtKey.sftp:
        writer.writeByte(5);
      case VirtKey.snippet:
        writer.writeByte(6);
      case VirtKey.tab:
        writer.writeByte(7);
      case VirtKey.ctrl:
        writer.writeByte(8);
      case VirtKey.left:
        writer.writeByte(9);
      case VirtKey.down:
        writer.writeByte(10);
      case VirtKey.right:
        writer.writeByte(11);
      case VirtKey.clipboard:
        writer.writeByte(12);
      case VirtKey.ime:
        writer.writeByte(13);
      case VirtKey.pgup:
        writer.writeByte(14);
      case VirtKey.pgdn:
        writer.writeByte(15);
      case VirtKey.slash:
        writer.writeByte(16);
      case VirtKey.backSlash:
        writer.writeByte(17);
      case VirtKey.underscore:
        writer.writeByte(18);
      case VirtKey.plus:
        writer.writeByte(19);
      case VirtKey.equal:
        writer.writeByte(20);
      case VirtKey.minus:
        writer.writeByte(21);
      case VirtKey.parenLeft:
        writer.writeByte(22);
      case VirtKey.parenRight:
        writer.writeByte(23);
      case VirtKey.bracketLeft:
        writer.writeByte(24);
      case VirtKey.bracketRight:
        writer.writeByte(25);
      case VirtKey.braceLeft:
        writer.writeByte(26);
      case VirtKey.braceRight:
        writer.writeByte(27);
      case VirtKey.chevronLeft:
        writer.writeByte(28);
      case VirtKey.chevronRight:
        writer.writeByte(29);
      case VirtKey.colon:
        writer.writeByte(30);
      case VirtKey.semicolon:
        writer.writeByte(31);
      case VirtKey.f1:
        writer.writeByte(32);
      case VirtKey.f2:
        writer.writeByte(33);
      case VirtKey.f3:
        writer.writeByte(34);
      case VirtKey.f4:
        writer.writeByte(35);
      case VirtKey.f5:
        writer.writeByte(36);
      case VirtKey.f6:
        writer.writeByte(37);
      case VirtKey.f7:
        writer.writeByte(38);
      case VirtKey.f8:
        writer.writeByte(39);
      case VirtKey.f9:
        writer.writeByte(40);
      case VirtKey.f10:
        writer.writeByte(41);
      case VirtKey.f11:
        writer.writeByte(42);
      case VirtKey.f12:
        writer.writeByte(43);
      case VirtKey.shift:
        writer.writeByte(44);
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is VirtKeyAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

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
      case ServerFuncBtn.sftp:
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

class ServerCustomAdapter extends TypeAdapter<ServerCustom> {
  @override
  final typeId = 7;

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
      preferTempDev: fields[4] as String?,
      logoUrl: fields[5] as String?,
      netDev: fields[6] as String?,
      scriptDir: fields[7] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, ServerCustom obj) {
    writer
      ..writeByte(7)
      ..writeByte(1)
      ..write(obj.pveAddr)
      ..writeByte(2)
      ..write(obj.pveIgnoreCert)
      ..writeByte(3)
      ..write(obj.cmds)
      ..writeByte(4)
      ..write(obj.preferTempDev)
      ..writeByte(5)
      ..write(obj.logoUrl)
      ..writeByte(6)
      ..write(obj.netDev)
      ..writeByte(7)
      ..write(obj.scriptDir);
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
