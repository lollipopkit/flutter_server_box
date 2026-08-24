import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/material.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/data/res/store.dart';
import 'package:xterm/core.dart';

/// How many virtual keys go in one row.
///
/// Fixed rather than measured: a key is as wide as the row divided by this, so
/// the same key is in the same place on every phone and the row does not
/// reflow when the window does. It is also what the settings page counts rows
/// with, which is why it is here rather than beside the terminal that draws
/// them.
const kVirtKeysPerRow = 7;

/// The three kinds of virtual key, which is what the walkthrough steps
/// through. See [VirtKeyX.group].
enum VirtKeyGroup { modifiers, navigation, shortcuts }

enum VirtualKeyFunc {
  toggleIME,
  backspace,
  clipboard,
  snippet,
  file,
  sudoPassword,
  tmuxSwitch,
}

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
  sudo,
  tmux,
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
    if (this == VirtKey.tmux) return 'tmux';

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
    VirtKey.sudo,
    VirtKey.ime,
    VirtKey.shift,
    VirtKey.tmux,
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
    VirtKey.sudo => Icons.password,
    VirtKey.tmux => Icons.window,
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
    VirtKey.sudo => VirtualKeyFunc.sudoPassword,
    VirtKey.tmux => VirtualKeyFunc.tmuxSwitch,
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
    VirtKey.sudo => l10n.trySudo,
    VirtKey.ime => l10n.virtKeyHelpIME,
    VirtKey.snippet => l10n.virtKeyHelpSnippet,
    VirtKey.tmux => l10n.virtKeyHelpTmux,
    _ => null,
  };

  /// What kind of key this is, for the walkthrough that runs once over the
  /// row.
  ///
  /// Three kinds and not seventeen keys: a tour with a step per key is a
  /// punishment, and what a newcomer needs is which of these *type* something,
  /// which move the cursor, and which open a page instead. Punctuation and the
  /// function keys belong to none — they are what they say.
  VirtKeyGroup? get group => switch (this) {
    VirtKey.esc ||
    VirtKey.tab ||
    VirtKey.ctrl ||
    VirtKey.alt ||
    VirtKey.shift => VirtKeyGroup.modifiers,
    VirtKey.up ||
    VirtKey.down ||
    VirtKey.left ||
    VirtKey.right ||
    VirtKey.home ||
    VirtKey.end ||
    VirtKey.pgup ||
    VirtKey.pgdn => VirtKeyGroup.navigation,
    // Defined by what it does rather than by a second list to keep in step:
    // a key with a [func] leaves the terminal, which is the whole of what
    // sets these apart.
    _ => func == null ? null : VirtKeyGroup.shortcuts,
  };

  /// The user's order, with anything this build cannot name left out.
  ///
  /// An index outside the enum is a key added by a newer build — a restored
  /// backup, or a downgrade — and there is nothing here to draw for it. It used
  /// to reset the whole order to the default, so one unknown entry threw away
  /// an arrangement that was otherwise entirely readable; and the settings page
  /// indexed the same list without the guard, so it threw while building.
  ///
  /// Only what was dropped is written back, and only when something was: the
  /// unknown key is then gone for good, which is the price of not carrying an
  /// index nothing can render. An empty result is a stored value that says
  /// nothing at all, and falls back to the default without being saved over.
  /// [persistRepairs] off reads without writing, for a caller that only wants
  /// to know what is stored.
  static List<VirtKey> loadFromStore({bool persistRepairs = true}) {
    try {
      final ints = Stores.setting.sshVirtKeys.fetch();
      final keys = [
        for (final e in ints)
          if (e >= 0 && e < VirtKey.values.length) VirtKey.values[e],
      ];
      if (keys.isEmpty) return defaultOrder;
      if (persistRepairs && keys.length != ints.length) {
        Stores.setting.sshVirtKeys.put(keys.map((e) => e.index).toList());
      }
      return keys;
    } catch (e, s) {
      Loggers.app.warning('Failed to load sshVirtKeys', e, s);
    }
    return defaultOrder;
  }
}
