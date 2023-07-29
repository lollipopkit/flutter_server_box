// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'virtual_key.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class VirtKeyAdapter extends TypeAdapter<VirtKey> {
  @override
  final int typeId = 4;

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
      default:
        return VirtKey.esc;
    }
  }

  @override
  void write(BinaryWriter writer, VirtKey obj) {
    switch (obj) {
      case VirtKey.esc:
        writer.writeByte(0);
        break;
      case VirtKey.alt:
        writer.writeByte(1);
        break;
      case VirtKey.home:
        writer.writeByte(2);
        break;
      case VirtKey.up:
        writer.writeByte(3);
        break;
      case VirtKey.end:
        writer.writeByte(4);
        break;
      case VirtKey.sftp:
        writer.writeByte(5);
        break;
      case VirtKey.snippet:
        writer.writeByte(6);
        break;
      case VirtKey.tab:
        writer.writeByte(7);
        break;
      case VirtKey.ctrl:
        writer.writeByte(8);
        break;
      case VirtKey.left:
        writer.writeByte(9);
        break;
      case VirtKey.down:
        writer.writeByte(10);
        break;
      case VirtKey.right:
        writer.writeByte(11);
        break;
      case VirtKey.clipboard:
        writer.writeByte(12);
        break;
      case VirtKey.ime:
        writer.writeByte(13);
        break;
      case VirtKey.pgup:
        writer.writeByte(14);
        break;
      case VirtKey.pgdn:
        writer.writeByte(15);
        break;
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
