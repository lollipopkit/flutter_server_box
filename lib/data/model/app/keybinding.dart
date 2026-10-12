import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// Where a command answers: [global] wherever the app is, the rest only on
/// their own page. Two commands of different scopes may share a chord.
enum KbScope { global, workspace, settings, serverTab }

/// The two keyboards a chord is written for. Apple's has Command, and holds
/// it where every other holds Control; an iPad with a keyboard is one too.
enum KbPlatform {
  pc,
  mac;

  /// The machine the app runs on, as the rest of the app asks it — not
  /// `defaultTargetPlatform`, which a test overrides while the keyboard
  /// stays the host's.
  static KbPlatform get current => isMacOS || isIOS ? mac : pc;
}

/// Something the keyboard can do, and the chords it does it with by default.
///
/// A chord is a string — `Ctrl+Alt+\` — because that is what is stored, shown
/// and compared; [KbChord] turns one into something Flutter can match.
enum KbCommand {
  wsSplitRight('ws.splitRight', KbScope.workspace, r'Ctrl+Alt+\', r'Ctrl+Meta+\'),
  wsSplitDown('ws.splitDown', KbScope.workspace, 'Ctrl+Alt+-', 'Ctrl+Meta+-'),
  wsFocusLeft('ws.focusLeft', KbScope.workspace, 'Ctrl+Alt+←', 'Ctrl+Meta+←'),
  wsFocusRight('ws.focusRight', KbScope.workspace, 'Ctrl+Alt+→', 'Ctrl+Meta+→'),
  wsFocusUp('ws.focusUp', KbScope.workspace, 'Ctrl+Alt+↑', 'Ctrl+Meta+↑'),
  wsFocusDown('ws.focusDown', KbScope.workspace, 'Ctrl+Alt+↓', 'Ctrl+Meta+↓'),
  wsNewTab('ws.newTab', KbScope.workspace, 'Ctrl+Alt+N', 'Ctrl+Meta+N'),
  wsCloseTab('ws.closeTab', KbScope.workspace, 'Ctrl+Alt+W', 'Ctrl+Meta+W'),
  wsNextTab('ws.nextTab', KbScope.workspace, 'Ctrl+Alt+]', 'Ctrl+Meta+]'),
  wsPrevTab('ws.prevTab', KbScope.workspace, 'Ctrl+Alt+[', 'Ctrl+Meta+['),
  wsTabs('ws.tabs', KbScope.workspace, 'Ctrl+Alt+O', 'Ctrl+Meta+O'),
  wsReopenTab(
    'ws.reopenTab',
    KbScope.workspace,
    'Ctrl+Alt+Shift+T',
    'Ctrl+Meta+Shift+T',
  ),
  wsMaximize('ws.maximize', KbScope.workspace, 'Ctrl+Alt+M', 'Ctrl+Meta+M'),
  wsSync('ws.sync', KbScope.workspace, 'Ctrl+Alt+I', 'Ctrl+Meta+I'),
  wsQuickOpen('ws.quickOpen', KbScope.workspace, 'Ctrl+Alt+P', 'Ctrl+Meta+P'),
  wsSwitcher('ws.switcher', KbScope.workspace, 'Ctrl+Alt+S', 'Ctrl+Meta+S'),

  /// Not a chord but nine, and not changeable: which digit is which tab is
  /// the whole of what it means. Listed so the page names every key the app
  /// takes.
  homeTab('home.tab', KbScope.global, 'Ctrl+1…9', 'Meta+1…9', fixed: true),
  appSettings('app.settings', KbScope.global, 'Ctrl+,', 'Meta+,'),
  settingsSearch('settings.search', KbScope.settings, 'Ctrl+F', 'Meta+F'),
  serverPrev('server.prev', KbScope.serverTab, 'Ctrl+[', 'Meta+['),
  serverNext('server.next', KbScope.serverTab, 'Ctrl+]', 'Meta+]'),
  serverList('server.list', KbScope.serverTab, 'Ctrl+K', 'Meta+K'),
  serverClose('server.close', KbScope.serverTab, 'Escape', 'Escape');

  const KbCommand(this.id, this.scope, this.pc, this.mac, {this.fixed = false});

  /// Stable across builds: what an override is stored under.
  final String id;
  final KbScope scope;
  final String pc;
  final String mac;
  final bool fixed;

  String defaultFor(KbPlatform platform) => switch (platform) {
    KbPlatform.pc => pc,
    KbPlatform.mac => mac,
  };

  /// Whether a chord bound to this and one bound to [other] could both be
  /// asked for in the same place.
  bool sharesScopeWith(KbCommand other) =>
      scope == other.scope ||
      scope == KbScope.global ||
      other.scope == KbScope.global;
}

/// [command] asked for from the keyboard, as an [Intent] — so a terminal,
/// which takes every key it is given, can be told which ones are the app's: a
/// binding whose intent finds no action above the terminal falls through to
/// the shell.
///
/// One type per scope, because an [Actions] is found by the intent's type and
/// the nearest one wins whether it is enabled or not: the workspace's actions
/// must not be what a global chord finds on its way up to the home page's.
sealed class KbIntent extends Intent {
  const KbIntent(this.command);

  final KbCommand command;

  factory KbIntent.of(KbCommand command) => switch (command.scope) {
    KbScope.global => GlobalKbIntent(command),
    KbScope.workspace => WorkspaceKbIntent(command),
    KbScope.settings => SettingsKbIntent(command),
    KbScope.serverTab => ServerTabKbIntent(command),
  };
}

final class GlobalKbIntent extends KbIntent {
  const GlobalKbIntent(super.command);
}

final class WorkspaceKbIntent extends KbIntent {
  const WorkspaceKbIntent(super.command);
}

final class SettingsKbIntent extends KbIntent {
  const SettingsKbIntent(super.command);
}

final class ServerTabKbIntent extends KbIntent {
  const ServerTabKbIntent(super.command);
}

/// A chord string, read.
///
/// `Ctrl`, `Meta`, `Alt` and `Shift` in any order, then one key. Keys are
/// letters and digits as themselves, punctuation as the character, arrows as
/// `←→↑↓`, and the named keys by their names (`Escape`, `F5`).
abstract final class KbChord {
  static const _modifiers = ['Ctrl', 'Meta', 'Alt', 'Shift'];

  static final Map<String, LogicalKeyboardKey> _keys = {
    for (var c = 0; c < 26; c++)
      String.fromCharCode(0x41 + c): LogicalKeyboardKey(
        LogicalKeyboardKey.keyA.keyId + c,
      ),
    for (var d = 0; d < 10; d++)
      '$d': LogicalKeyboardKey(LogicalKeyboardKey.digit0.keyId + d),
    r'\': LogicalKeyboardKey.backslash,
    '-': LogicalKeyboardKey.minus,
    '=': LogicalKeyboardKey.equal,
    '[': LogicalKeyboardKey.bracketLeft,
    ']': LogicalKeyboardKey.bracketRight,
    ',': LogicalKeyboardKey.comma,
    '.': LogicalKeyboardKey.period,
    '/': LogicalKeyboardKey.slash,
    ';': LogicalKeyboardKey.semicolon,
    "'": LogicalKeyboardKey.quote,
    '`': LogicalKeyboardKey.backquote,
    '←': LogicalKeyboardKey.arrowLeft,
    '→': LogicalKeyboardKey.arrowRight,
    '↑': LogicalKeyboardKey.arrowUp,
    '↓': LogicalKeyboardKey.arrowDown,
    'Space': LogicalKeyboardKey.space,
    'Tab': LogicalKeyboardKey.tab,
    'Escape': LogicalKeyboardKey.escape,
    'Enter': LogicalKeyboardKey.enter,
    'Backspace': LogicalKeyboardKey.backspace,
    'Delete': LogicalKeyboardKey.delete,
    'PageUp': LogicalKeyboardKey.pageUp,
    'PageDown': LogicalKeyboardKey.pageDown,
    'Home': LogicalKeyboardKey.home,
    'End': LogicalKeyboardKey.end,
    for (var f = 1; f <= 12; f++)
      'F$f': LogicalKeyboardKey(LogicalKeyboardKey.f1.keyId + f - 1),
  };

  static final Map<LogicalKeyboardKey, String> _names = {
    for (final e in _keys.entries) e.value: e.key,
  };

  static final _modifierKeys = {
    LogicalKeyboardKey.controlLeft,
    LogicalKeyboardKey.controlRight,
    LogicalKeyboardKey.metaLeft,
    LogicalKeyboardKey.metaRight,
    LogicalKeyboardKey.altLeft,
    LogicalKeyboardKey.altRight,
    LogicalKeyboardKey.shiftLeft,
    LogicalKeyboardKey.shiftRight,
    LogicalKeyboardKey.capsLock,
    LogicalKeyboardKey.fn,
  };

  /// [chord] as an activator; null for an empty one, one that names a key
  /// this does not know, or a range such as `Ctrl+1…9`.
  static SingleActivator? activator(String chord) {
    if (chord.isEmpty) return null;
    final parts = chord.split('+');
    final key = _keys[parts.last];
    if (key == null) return null;
    final mods = parts.sublist(0, parts.length - 1);
    if (mods.any((m) => !_modifiers.contains(m))) return null;
    return _KbActivator(
      key,
      control: mods.contains('Ctrl'),
      meta: mods.contains('Meta'),
      alt: mods.contains('Alt'),
      shift: mods.contains('Shift'),
    );
  }

  /// What [event] is as a chord, with the modifiers held; null while only a
  /// modifier is down, or for a key this cannot name.
  static String? fromEvent(KeyEvent event, HardwareKeyboard keyboard) {
    final key = event.logicalKey;
    if (_modifierKeys.contains(key)) return null;
    final name = _names[key];
    if (name == null) return null;
    return [
      if (keyboard.isControlPressed) 'Ctrl',
      if (keyboard.isMetaPressed) 'Meta',
      if (keyboard.isAltPressed) 'Alt',
      if (keyboard.isShiftPressed) 'Shift',
      name,
    ].join('+');
  }

  /// [chord] as the keycaps it is pressed with: `⌃⌘\` on a Mac, `Ctrl`,
  /// `Alt`, `\` elsewhere.
  static List<String> caps(String chord, KbPlatform platform) {
    if (chord.isEmpty) return const [];
    return [
      for (final p in chord.split('+'))
        switch ((platform, p)) {
          (KbPlatform.mac, 'Ctrl') => '⌃',
          (KbPlatform.mac, 'Meta') => '⌘',
          (KbPlatform.mac, 'Alt') => '⌥',
          (KbPlatform.mac, 'Shift') => '⇧',
          (KbPlatform.pc, 'Meta') => 'Win',
          (_, 'Escape') => 'Esc',
          _ => p,
        },
    ];
  }

  /// [chord] on one line, the way a tooltip says it.
  static String label(String chord, KbPlatform platform) =>
      caps(chord, platform).join(platform == KbPlatform.mac ? '' : '+');
}

/// A [SingleActivator] that leaves AltGr alone.
///
/// Windows reports AltGr as Control and the right Alt held together, so on a
/// German or French keyboard `\`, `[` and `]` are typed with exactly the
/// chords the workspace's defaults are — and a terminal that split itself on
/// every backslash would be unusable. A chord with Control and Alt is the
/// app's only through the left Alt, then; the right one types characters.
final class _KbActivator extends SingleActivator {
  const _KbActivator(
    super.trigger, {
    super.control,
    super.meta,
    super.alt,
    super.shift,
  });

  @override
  bool accepts(KeyEvent event, HardwareKeyboard state) {
    if (control &&
        alt &&
        KbPlatform.current == KbPlatform.pc &&
        state.physicalKeysPressed.contains(PhysicalKeyboardKey.altRight)) {
      return false;
    }
    return super.accepts(event, state);
  }
}
