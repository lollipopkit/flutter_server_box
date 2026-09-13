import 'package:flutter/services.dart';
import 'package:server_box/data/model/server/remote_desktop.dart';

class RemoteDesktopKey {
  const RemoteDesktopKey(this.code, {this.extended = false});

  final int code;
  final bool extended;

  @override
  bool operator ==(Object other) =>
      other is RemoteDesktopKey &&
      other.code == code &&
      other.extended == extended;

  @override
  int get hashCode => Object.hash(code, extended);
}

/// Converts Flutter key events into RDP scan codes or X11 keysyms.
RemoteDesktopKey? remoteDesktopKeyFor(
  KeyEvent event,
  RemoteDesktopProtocol protocol,
) => switch (protocol) {
  RemoteDesktopProtocol.rdp => _rdpKey(event.physicalKey),
  RemoteDesktopProtocol.vnc => _vncKey(event.logicalKey),
};

RemoteDesktopKey? _rdpKey(PhysicalKeyboardKey key) {
  final simple = <PhysicalKeyboardKey, int>{
    PhysicalKeyboardKey.escape: 0x01,
    PhysicalKeyboardKey.digit1: 0x02,
    PhysicalKeyboardKey.digit2: 0x03,
    PhysicalKeyboardKey.digit3: 0x04,
    PhysicalKeyboardKey.digit4: 0x05,
    PhysicalKeyboardKey.digit5: 0x06,
    PhysicalKeyboardKey.digit6: 0x07,
    PhysicalKeyboardKey.digit7: 0x08,
    PhysicalKeyboardKey.digit8: 0x09,
    PhysicalKeyboardKey.digit9: 0x0a,
    PhysicalKeyboardKey.digit0: 0x0b,
    PhysicalKeyboardKey.minus: 0x0c,
    PhysicalKeyboardKey.equal: 0x0d,
    PhysicalKeyboardKey.backspace: 0x0e,
    PhysicalKeyboardKey.tab: 0x0f,
    PhysicalKeyboardKey.keyQ: 0x10,
    PhysicalKeyboardKey.keyW: 0x11,
    PhysicalKeyboardKey.keyE: 0x12,
    PhysicalKeyboardKey.keyR: 0x13,
    PhysicalKeyboardKey.keyT: 0x14,
    PhysicalKeyboardKey.keyY: 0x15,
    PhysicalKeyboardKey.keyU: 0x16,
    PhysicalKeyboardKey.keyI: 0x17,
    PhysicalKeyboardKey.keyO: 0x18,
    PhysicalKeyboardKey.keyP: 0x19,
    PhysicalKeyboardKey.bracketLeft: 0x1a,
    PhysicalKeyboardKey.bracketRight: 0x1b,
    PhysicalKeyboardKey.enter: 0x1c,
    PhysicalKeyboardKey.controlLeft: 0x1d,
    PhysicalKeyboardKey.keyA: 0x1e,
    PhysicalKeyboardKey.keyS: 0x1f,
    PhysicalKeyboardKey.keyD: 0x20,
    PhysicalKeyboardKey.keyF: 0x21,
    PhysicalKeyboardKey.keyG: 0x22,
    PhysicalKeyboardKey.keyH: 0x23,
    PhysicalKeyboardKey.keyJ: 0x24,
    PhysicalKeyboardKey.keyK: 0x25,
    PhysicalKeyboardKey.keyL: 0x26,
    PhysicalKeyboardKey.semicolon: 0x27,
    PhysicalKeyboardKey.quote: 0x28,
    PhysicalKeyboardKey.backquote: 0x29,
    PhysicalKeyboardKey.shiftLeft: 0x2a,
    PhysicalKeyboardKey.backslash: 0x2b,
    PhysicalKeyboardKey.keyZ: 0x2c,
    PhysicalKeyboardKey.keyX: 0x2d,
    PhysicalKeyboardKey.keyC: 0x2e,
    PhysicalKeyboardKey.keyV: 0x2f,
    PhysicalKeyboardKey.keyB: 0x30,
    PhysicalKeyboardKey.keyN: 0x31,
    PhysicalKeyboardKey.keyM: 0x32,
    PhysicalKeyboardKey.comma: 0x33,
    PhysicalKeyboardKey.period: 0x34,
    PhysicalKeyboardKey.slash: 0x35,
    PhysicalKeyboardKey.shiftRight: 0x36,
    PhysicalKeyboardKey.altLeft: 0x38,
    PhysicalKeyboardKey.space: 0x39,
    PhysicalKeyboardKey.capsLock: 0x3a,
    PhysicalKeyboardKey.f1: 0x3b,
    PhysicalKeyboardKey.f2: 0x3c,
    PhysicalKeyboardKey.f3: 0x3d,
    PhysicalKeyboardKey.f4: 0x3e,
    PhysicalKeyboardKey.f5: 0x3f,
    PhysicalKeyboardKey.f6: 0x40,
    PhysicalKeyboardKey.f7: 0x41,
    PhysicalKeyboardKey.f8: 0x42,
    PhysicalKeyboardKey.f9: 0x43,
    PhysicalKeyboardKey.f10: 0x44,
    PhysicalKeyboardKey.f11: 0x57,
    PhysicalKeyboardKey.f12: 0x58,
  };
  final code = simple[key];
  if (code != null) return RemoteDesktopKey(code);
  final extended = <PhysicalKeyboardKey, int>{
    PhysicalKeyboardKey.controlRight: 0x1d,
    PhysicalKeyboardKey.altRight: 0x38,
    PhysicalKeyboardKey.arrowUp: 0x48,
    PhysicalKeyboardKey.arrowLeft: 0x4b,
    PhysicalKeyboardKey.arrowRight: 0x4d,
    PhysicalKeyboardKey.arrowDown: 0x50,
    PhysicalKeyboardKey.insert: 0x52,
    PhysicalKeyboardKey.delete: 0x53,
    PhysicalKeyboardKey.home: 0x47,
    PhysicalKeyboardKey.end: 0x4f,
    PhysicalKeyboardKey.pageUp: 0x49,
    PhysicalKeyboardKey.pageDown: 0x51,
    PhysicalKeyboardKey.metaLeft: 0x5b,
    PhysicalKeyboardKey.metaRight: 0x5c,
  };
  final extendedCode = extended[key];
  return extendedCode == null
      ? null
      : RemoteDesktopKey(extendedCode, extended: true);
}

RemoteDesktopKey? _vncKey(LogicalKeyboardKey key) {
  final special = <LogicalKeyboardKey, int>{
    LogicalKeyboardKey.backspace: 0xff08,
    LogicalKeyboardKey.tab: 0xff09,
    LogicalKeyboardKey.enter: 0xff0d,
    LogicalKeyboardKey.escape: 0xff1b,
    LogicalKeyboardKey.home: 0xff50,
    LogicalKeyboardKey.arrowLeft: 0xff51,
    LogicalKeyboardKey.arrowUp: 0xff52,
    LogicalKeyboardKey.arrowRight: 0xff53,
    LogicalKeyboardKey.arrowDown: 0xff54,
    LogicalKeyboardKey.pageUp: 0xff55,
    LogicalKeyboardKey.pageDown: 0xff56,
    LogicalKeyboardKey.end: 0xff57,
    LogicalKeyboardKey.insert: 0xff63,
    LogicalKeyboardKey.delete: 0xffff,
    LogicalKeyboardKey.f1: 0xffbe,
    LogicalKeyboardKey.f2: 0xffbf,
    LogicalKeyboardKey.f3: 0xffc0,
    LogicalKeyboardKey.f4: 0xffc1,
    LogicalKeyboardKey.f5: 0xffc2,
    LogicalKeyboardKey.f6: 0xffc3,
    LogicalKeyboardKey.f7: 0xffc4,
    LogicalKeyboardKey.f8: 0xffc5,
    LogicalKeyboardKey.f9: 0xffc6,
    LogicalKeyboardKey.f10: 0xffc7,
    LogicalKeyboardKey.f11: 0xffc8,
    LogicalKeyboardKey.f12: 0xffc9,
    LogicalKeyboardKey.shiftLeft: 0xffe1,
    LogicalKeyboardKey.shiftRight: 0xffe2,
    LogicalKeyboardKey.controlLeft: 0xffe3,
    LogicalKeyboardKey.controlRight: 0xffe4,
    LogicalKeyboardKey.capsLock: 0xffe5,
    LogicalKeyboardKey.metaLeft: 0xffeb,
    LogicalKeyboardKey.metaRight: 0xffec,
    LogicalKeyboardKey.altLeft: 0xffe9,
    LogicalKeyboardKey.altRight: 0xffea,
  };
  final code = special[key];
  if (code != null) return RemoteDesktopKey(code);
  final id = key.keyId;
  if (id > 0x10ffff) return null;
  return RemoteDesktopKey(id > 0xff ? id | 0x01000000 : id);
}

class RemoteDesktopInputController {
  RemoteDesktopInputController({
    required this.protocol,
    required this.sendKey,
    required this.sendText,
    required this.releaseRemoteKeys,
  });

  final RemoteDesktopProtocol protocol;
  final void Function(int code, bool down, bool extended) sendKey;
  final void Function(String text) sendText;
  final void Function() releaseRemoteKeys;
  final Set<RemoteDesktopKey> _pressed = {};

  bool handle(KeyEvent event) {
    final key = remoteDesktopKeyFor(event, protocol);
    if (key != null) {
      final down = event is! KeyUpEvent;
      if (down) {
        _pressed.add(key);
      } else {
        _pressed.remove(key);
      }
      sendKey(key.code, down, key.extended);
      return true;
    }
    final character = event.character;
    if (event is KeyDownEvent && character != null && character.isNotEmpty) {
      sendText(character);
      return true;
    }
    return false;
  }

  void releaseAll() {
    _pressed.clear();
    releaseRemoteKeys();
  }
}
