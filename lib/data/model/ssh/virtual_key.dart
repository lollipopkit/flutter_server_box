import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/material.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/data/model/server/server_private_info.dart';
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

  /// Whether a terminal on [spi] can do what this key does — null for a shell
  /// on this device, including the Linux systems installed in it.
  ///
  /// Four of these keys act on a *server*, and on a shell that is not on one
  /// they returned without a word: the strip drew them, they took a tap, and
  /// nothing happened. Answered here beside the rest of what a key is, rather
  /// than in the page that draws them, so the toolbar and the strip cannot
  /// come to different conclusions about the same button.
  bool worksOn(Spi? spi) => switch (this) {
    // Opens the files of the server this shell is on. This device has its own
    // browser, in the files tab.
    VirtKey.sftp => spi != null,
    // Inserts the password stored for this server. There is none for a shell
    // that is not on one, none worth inserting for a session already root, and
    // none at all on a server reached only through its monitor agent — `Spi.ssh`
    // is where the password lives, and a monitor server carries no
    // `SshCredential`. `isRoot` alone answered false for those, so the key was
    // drawn on a terminal where tapping it could only show an empty result.
    VirtKey.sudo => spi?.ssh != null && !spi!.isRoot,
    // Needs a channel that does not echo what is written into it, which only
    // an SSH exec channel is: a shell on this device runs in a pseudo-terminal,
    // and a monitor agent carries no exec channel at all.
    VirtKey.tmux => spi?.ssh != null,
    // Everything else is the terminal's own — keys, modifiers, the clipboard,
    // the IME, and snippets, which are a script typed into whatever is there.
    _ => true,
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
  ///
  /// Esc and Tab belong to none either, and used to be counted as modifiers.
  /// The step's text tells the reader to tap one to arm it and then tap a
  /// letter, which is true of exactly the three keys [toggleable] answers yes
  /// to; Esc and Tab send a character and are done. Highlighted under that
  /// sentence they taught something that is not so.
  VirtKeyGroup? get group => switch (this) {
    VirtKey.ctrl || VirtKey.alt || VirtKey.shift => VirtKeyGroup.modifiers,
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

  /// The key of that name, or null for one this build has no case for.
  static VirtKey? byName(String name) =>
      VirtKey.values.firstWhereOrNull((key) => key.name == name);

  /// The user's order, with anything this build cannot name left out.
  ///
  /// A name outside the enum is a key added by a newer build — a restored
  /// backup, or a downgrade — and there is nothing here to draw for it. It used
  /// to reset the whole order to the default, so one unknown entry threw away
  /// an arrangement that was otherwise entirely readable; and the settings page
  /// indexed the same list without the guard, so it threw while building.
  ///
  /// A repeat is dropped too, keeping the first. A key can only be in one
  /// place, so a stored order naming one twice drew two copies of it — each
  /// with the same `ValueKey`, and each toggling the same modifier — and the
  /// settings page offered two rows for the one key. Reachable from a merged
  /// backup and from a reorder interrupted midway, neither of which the reader
  /// can tell apart from a list that was always right.
  ///
  /// Only what was dropped is written back, and only when something was: the
  /// unknown key is then gone for good, which is the price of not carrying a
  /// name nothing can render. An empty result is a stored value that says
  /// nothing at all, and falls back to the default without being saved over.
  /// [persistRepairs] off reads without writing, for a caller that only wants
  /// to know what is stored.
  static List<VirtKey> loadFromStore({bool persistRepairs = true}) {
    try {
      final names = Stores.setting.sshVirtKeys.fetch();
      final seen = <VirtKey>{};
      final keys = [
        for (final name in names)
          if (byName(name) case final key?)
            if (seen.add(key)) key,
      ];
      if (keys.isEmpty) return defaultOrder;
      if (persistRepairs && keys.length != names.length) {
        Stores.setting.sshVirtKeys.put(keys.map((e) => e.name).toList());
      }
      return keys;
    } catch (e, s) {
      Loggers.app.warning('Failed to load sshVirtKeys', e, s);
    }
    return defaultOrder;
  }
}
