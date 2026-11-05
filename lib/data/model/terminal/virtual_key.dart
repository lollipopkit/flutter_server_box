import 'package:fl_lib/fl_lib.dart';
import 'package:material_ui/material_ui.dart';
import 'package:server_box/core/extension/context/locale.dart';
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
/// through. See [VirtualKeyX.group].
enum VirtualKeyGroup { modifiers, navigation, shortcuts }

enum VirtualKeyFunc {
  toggleIME,
  backspace,
  snippet,
  file,
  sudoPassword,
  tmuxSwitch,
}

enum VirtualKey {
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

extension VirtualKeyX on VirtualKey {
  /// Used for input to terminal
  String? get inputRaw => switch (this) {
    VirtualKey.slash => '/',
    VirtualKey.backSlash => '\\',
    VirtualKey.underscore => '_',
    VirtualKey.plus => '+',
    VirtualKey.equal => '=',
    VirtualKey.minus => '-',
    VirtualKey.parenLeft => '(',
    VirtualKey.parenRight => ')',
    VirtualKey.bracketLeft => '[',
    VirtualKey.bracketRight => ']',
    VirtualKey.braceLeft => '{',
    VirtualKey.braceRight => '}',
    VirtualKey.chevronLeft => '<',
    VirtualKey.chevronRight => '>',
    VirtualKey.colon => ':',
    VirtualKey.semicolon => ';',
    _ => null,
  };

  /// Used for displaying on UI
  String get text {
    final t = inputRaw;
    if (t != null) return t;

    if (this == VirtualKey.pgdn) return 'PgDn';
    if (this == VirtualKey.pgup) return 'PgUp';
    if (this == VirtualKey.tmux) return 'tmux';

    if (name.length > 1) {
      return name.substring(0, 1).toUpperCase() + name.substring(1);
    }
    return name;
  }

  /// What a screen reader says for this key: the key's name where [text] is
  /// an abbreviation or the key is drawn as an icon.
  String get semanticLabel => switch (this) {
    VirtualKey.esc => l10n.keyEscape,
    VirtualKey.ctrl => l10n.keyControl,
    VirtualKey.up => l10n.keyArrowUp,
    VirtualKey.down => l10n.keyArrowDown,
    VirtualKey.left => l10n.keyArrowLeft,
    VirtualKey.right => l10n.keyArrowRight,
    VirtualKey.pgup => l10n.keyPageUp,
    VirtualKey.pgdn => l10n.keyPageDown,
    VirtualKey.sftp => 'SFTP',
    VirtualKey.snippet => libL10n.snippet,
    VirtualKey.sudo => l10n.trySudo,
    VirtualKey.ime => l10n.virtKeyHelpIME,
    _ => text,
  };

  /// Default order of virtual keys
  static const defaultOrder = [
    // Two full rows, each key of a pair over the other: ↑ over ↓, PgUp over
    // PgDn. The file browser, the sudo password and tmux are off until turned
    // on in the settings.
    VirtualKey.esc,
    VirtualKey.alt,
    VirtualKey.home,
    VirtualKey.up,
    VirtualKey.end,
    VirtualKey.pgup,
    VirtualKey.tab,
    VirtualKey.shift,
    VirtualKey.ctrl,
    VirtualKey.left,
    VirtualKey.down,
    VirtualKey.right,
    VirtualKey.pgdn,
    VirtualKey.ime,
  ];

  /// Corresponding [TerminalKey]
  TerminalKey? get key => switch (this) {
    VirtualKey.esc => TerminalKey.escape,
    VirtualKey.alt => TerminalKey.alt,
    VirtualKey.home => TerminalKey.home,
    VirtualKey.up => TerminalKey.arrowUp,
    VirtualKey.end => TerminalKey.end,
    VirtualKey.tab => TerminalKey.tab,
    VirtualKey.ctrl => TerminalKey.control,
    VirtualKey.left => TerminalKey.arrowLeft,
    VirtualKey.down => TerminalKey.arrowDown,
    VirtualKey.right => TerminalKey.arrowRight,
    VirtualKey.shift => TerminalKey.shift,
    VirtualKey.pgup => TerminalKey.pageUp,
    VirtualKey.pgdn => TerminalKey.pageDown,
    VirtualKey.f1 => TerminalKey.f1,
    VirtualKey.f2 => TerminalKey.f2,
    VirtualKey.f3 => TerminalKey.f3,
    VirtualKey.f4 => TerminalKey.f4,
    VirtualKey.f5 => TerminalKey.f5,
    VirtualKey.f6 => TerminalKey.f6,
    VirtualKey.f7 => TerminalKey.f7,
    VirtualKey.f8 => TerminalKey.f8,
    VirtualKey.f9 => TerminalKey.f9,
    VirtualKey.f10 => TerminalKey.f10,
    VirtualKey.f11 => TerminalKey.f11,
    VirtualKey.f12 => TerminalKey.f12,
    _ => null,
  };

  /// Icons for virtual keys
  IconData? get icon => switch (this) {
    VirtualKey.up => Icons.arrow_upward,
    VirtualKey.left => Icons.arrow_back,
    VirtualKey.down => Icons.arrow_downward,
    VirtualKey.right => Icons.arrow_forward,
    VirtualKey.sftp => Icons.file_open,
    VirtualKey.snippet => Icons.code,
    VirtualKey.sudo => Icons.password,
    VirtualKey.tmux => Icons.window,
    VirtualKey.ime => Icons.keyboard,
    _ => null,
  };

  // Use [VirtualKeyFunc] instead of [VirtualKey]
  // This can help linter to enum all [VirtualKeyFunc]
  // and make sure all [VirtualKeyFunc] are handled
  VirtualKeyFunc? get func => switch (this) {
    VirtualKey.sftp => VirtualKeyFunc.file,
    VirtualKey.snippet => VirtualKeyFunc.snippet,
    VirtualKey.sudo => VirtualKeyFunc.sudoPassword,
    VirtualKey.tmux => VirtualKeyFunc.tmuxSwitch,
    VirtualKey.ime => VirtualKeyFunc.toggleIME,
    _ => null,
  };

  bool get toggleable => switch (this) {
    VirtualKey.alt || VirtualKey.ctrl || VirtualKey.shift => true,
    _ => false,
  };

  bool get canLongPress => switch (this) {
    VirtualKey.up || VirtualKey.left || VirtualKey.down || VirtualKey.right => true,
    _ => false,
  };

  String? get help => switch (this) {
    VirtualKey.sftp => l10n.virtKeyHelpSFTP,
    VirtualKey.sudo => l10n.trySudo,
    VirtualKey.ime => l10n.virtKeyHelpIME,
    VirtualKey.snippet => l10n.virtKeyHelpSnippet,
    VirtualKey.tmux => l10n.virtKeyHelpTmux,
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
  VirtualKeyGroup? get group => switch (this) {
    VirtualKey.ctrl || VirtualKey.alt || VirtualKey.shift => VirtualKeyGroup.modifiers,
    VirtualKey.up ||
    VirtualKey.down ||
    VirtualKey.left ||
    VirtualKey.right ||
    VirtualKey.home ||
    VirtualKey.end ||
    VirtualKey.pgup ||
    VirtualKey.pgdn => VirtualKeyGroup.navigation,
    // Defined by what it does rather than by a second list to keep in step:
    // a key with a [func] leaves the terminal, which is the whole of what
    // sets these apart.
    _ => func == null ? null : VirtualKeyGroup.shortcuts,
  };

  /// The key of that name, or null for one this build has no case for.
  static VirtualKey? byName(String name) =>
      VirtualKey.values.firstWhereOrNull((key) => key.name == name);

  /// The keys [names] names, in that order: a name this build has no key for
  /// is left out, and a repeat is dropped, keeping the first. Empty when none
  /// of them is a key here.
  ///
  /// A name outside the enum is a key added by a newer build — a restored
  /// backup, or a downgrade — and there is nothing here to draw for it. It used
  /// to reset the whole order to the default, so one unknown entry threw away
  /// an arrangement that was otherwise entirely readable; and the settings page
  /// indexed the same list without the guard, so it threw while building.
  ///
  /// A key can only be in one place, so a stored order naming one twice drew
  /// two copies of it — each with the same `ValueKey`, and each toggling the
  /// same modifier — and the settings page offered two rows for the one key.
  /// Reachable from a merged backup and from a reorder interrupted midway,
  /// neither of which a reader can tell apart from a list that was always
  /// right.
  static List<VirtualKey> fromNames(List<String> names) {
    final seen = <VirtualKey>{};
    return [
      for (final name in names)
        if (byName(name) case final key?)
          if (seen.add(key)) key,
    ];
  }
}
