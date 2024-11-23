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
      case VirtKey.slash:
        writer.writeByte(16);
        break;
      case VirtKey.backSlash:
        writer.writeByte(17);
        break;
      case VirtKey.underscore:
        writer.writeByte(18);
        break;
      case VirtKey.plus:
        writer.writeByte(19);
        break;
      case VirtKey.equal:
        writer.writeByte(20);
        break;
      case VirtKey.minus:
        writer.writeByte(21);
        break;
      case VirtKey.parenLeft:
        writer.writeByte(22);
        break;
      case VirtKey.parenRight:
        writer.writeByte(23);
        break;
      case VirtKey.bracketLeft:
        writer.writeByte(24);
        break;
      case VirtKey.bracketRight:
        writer.writeByte(25);
        break;
      case VirtKey.braceLeft:
        writer.writeByte(26);
        break;
      case VirtKey.braceRight:
        writer.writeByte(27);
        break;
      case VirtKey.chevronLeft:
        writer.writeByte(28);
        break;
      case VirtKey.chevronRight:
        writer.writeByte(29);
        break;
      case VirtKey.colon:
        writer.writeByte(30);
        break;
      case VirtKey.semicolon:
        writer.writeByte(31);
        break;
      case VirtKey.f1:
        writer.writeByte(32);
        break;
      case VirtKey.f2:
        writer.writeByte(33);
        break;
      case VirtKey.f3:
        writer.writeByte(34);
        break;
      case VirtKey.f4:
        writer.writeByte(35);
        break;
      case VirtKey.f5:
        writer.writeByte(36);
        break;
      case VirtKey.f6:
        writer.writeByte(37);
        break;
      case VirtKey.f7:
        writer.writeByte(38);
        break;
      case VirtKey.f8:
        writer.writeByte(39);
        break;
      case VirtKey.f9:
        writer.writeByte(40);
        break;
      case VirtKey.f10:
        writer.writeByte(41);
        break;
      case VirtKey.f11:
        writer.writeByte(42);
        break;
      case VirtKey.f12:
        writer.writeByte(43);
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
