import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/material.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/data/res/store.dart';
import 'package:xterm/core.dart';

enum VirtualKeyFunc { toggleIME, backspace, clipboard, snippet, file }

enum VirtKey {
  esc,
  alt,
  home,
  up,
  end,
  sftp,
  snippet,
  tab,
  ctrl,
  left,
  down,
  right,
  clipboard,
  ime,
  shift,
  pgup,
  pgdn,
  slash,
  backSlash,
  underscore,
  plus,
  equal,
  minus,
  parenLeft,
  parenRight,
  bracketLeft,
  bracketRight,
  braceLeft,
  braceRight,
  chevronLeft,
  chevronRight,
  colon,
  semicolon,
  f1,
  f2,
  f3,
  f4,
  f5,
  f6,
  f7,
  f8,
  f9,
  f10,
  f11,
  f12,
}

extension VirtKeyX on VirtKey {
  /// Used for input to terminal
  String? get inputRaw => switch (this) {
    VirtKey.slash => '/',
    VirtKey.backSlash => '\\',
    VirtKey.underscore => '_',
    VirtKey.plus => '+',
    VirtKey.equal => '=',
    VirtKey.minus => '-',
    VirtKey.parenLeft => '(',
    VirtKey.parenRight => ')',
    VirtKey.bracketLeft => '[',
    VirtKey.bracketRight => ']',
    VirtKey.braceLeft => '{',
    VirtKey.braceRight => '}',
    VirtKey.chevronLeft => '<',
    VirtKey.chevronRight => '>',
    VirtKey.colon => ':',
    VirtKey.semicolon => ';',
    _ => null,
  };

  /// Used for displaying on UI
  String get text {
    final t = inputRaw;
    if (t != null) return t;

    if (this == VirtKey.pgdn) return 'PgDn';
    if (this == VirtKey.pgup) return 'PgUp';

    if (name.length > 1) {
      return name.substring(0, 1).toUpperCase() + name.substring(1);
    }
    return name;
  }

  /// Default order of virtual keys
  static const defaultOrder = [
    VirtKey.esc,
    VirtKey.alt,
    VirtKey.home,
    VirtKey.up,
    VirtKey.end,
    VirtKey.sftp,
    VirtKey.snippet,
    VirtKey.tab,
    VirtKey.ctrl,
    VirtKey.left,
    VirtKey.down,
    VirtKey.right,
    VirtKey.clipboard,
    VirtKey.ime,
    VirtKey.shift,
  ];

  /// Corresponding [TerminalKey]
  TerminalKey? get key => switch (this) {
    VirtKey.esc => TerminalKey.escape,
    VirtKey.alt => TerminalKey.alt,
    VirtKey.home => TerminalKey.home,
    VirtKey.up => TerminalKey.arrowUp,
    VirtKey.end => TerminalKey.end,
    VirtKey.tab => TerminalKey.tab,
    VirtKey.ctrl => TerminalKey.control,
    VirtKey.left => TerminalKey.arrowLeft,
    VirtKey.down => TerminalKey.arrowDown,
    VirtKey.right => TerminalKey.arrowRight,
    VirtKey.shift => TerminalKey.shift,
    VirtKey.pgup => TerminalKey.pageUp,
    VirtKey.pgdn => TerminalKey.pageDown,
    VirtKey.f1 => TerminalKey.f1,
    VirtKey.f2 => TerminalKey.f2,
    VirtKey.f3 => TerminalKey.f3,
    VirtKey.f4 => TerminalKey.f4,
    VirtKey.f5 => TerminalKey.f5,
    VirtKey.f6 => TerminalKey.f6,
    VirtKey.f7 => TerminalKey.f7,
    VirtKey.f8 => TerminalKey.f8,
    VirtKey.f9 => TerminalKey.f9,
    VirtKey.f10 => TerminalKey.f10,
    VirtKey.f11 => TerminalKey.f11,
    VirtKey.f12 => TerminalKey.f12,
    _ => null,
  };

  /// Icons for virtual keys
  IconData? get icon => switch (this) {
    VirtKey.up => Icons.arrow_upward,
    VirtKey.left => Icons.arrow_back,
    VirtKey.down => Icons.arrow_downward,
    VirtKey.right => Icons.arrow_forward,
    VirtKey.sftp => Icons.file_open,
    VirtKey.snippet => Icons.code,
    VirtKey.clipboard => Icons.paste,
    VirtKey.ime => Icons.keyboard,
    _ => null,
  };

  // Use [VirtualKeyFunc] instead of [VirtKey]
  // This can help linter to enum all [VirtualKeyFunc]
  // and make sure all [VirtualKeyFunc] are handled
  VirtualKeyFunc? get func => switch (this) {
    VirtKey.sftp => VirtualKeyFunc.file,
    VirtKey.snippet => VirtualKeyFunc.snippet,
    VirtKey.clipboard => VirtualKeyFunc.clipboard,
    VirtKey.ime => VirtualKeyFunc.toggleIME,
    _ => null,
  };

  bool get toggleable => switch (this) {
    VirtKey.alt || VirtKey.ctrl || VirtKey.shift => true,
    _ => false,
  };

  bool get canLongPress => switch (this) {
    VirtKey.up || VirtKey.left || VirtKey.down || VirtKey.right => true,
    _ => false,
  };

  String? get help => switch (this) {
    VirtKey.sftp => l10n.virtKeyHelpSFTP,
    VirtKey.clipboard => l10n.virtKeyHelpClipboard,
    VirtKey.ime => l10n.virtKeyHelpIME,
    _ => null,
  };

  /// - [saveDefaultIfErr] if the stored raw values is invalid, save default order to store
  static List<VirtKey> loadFromStore({bool saveDefaultIfErr = true}) {
    try {
      final ints = Stores.setting.sshVirtKeys.fetch();
      return ints.map((e) => VirtKey.values[e]).toList();
    } on RangeError {
      final ints = defaultOrder.map((e) => e.index).toList();
      Stores.setting.sshVirtKeys.put(ints);
    } catch (e, s) {
      Loggers.app.warning('Failed to load sshVirtKeys', e, s);
    }
    return defaultOrder;
  }
}
