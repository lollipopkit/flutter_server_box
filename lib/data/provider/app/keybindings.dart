import 'package:flutter/widgets.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:server_box/data/model/app/keybinding.dart';
import 'package:server_box/data/res/store.dart';

part 'keybindings.g.dart';

/// The chords in force on this device: the defaults, and what was changed.
final class KbState {
  const KbState({required this.platform, required this.overrides});

  final KbPlatform platform;

  /// This platform's changes only, by command id. An empty chord is a command
  /// whose keys were removed.
  final Map<String, String> overrides;

  bool isModified(KbCommand c) => overrides.containsKey(c.id);

  /// The chord [c] runs on; empty when it has none.
  String chordOf(KbCommand c) => overrides[c.id] ?? c.defaultFor(platform);

  SingleActivator? activatorOf(KbCommand c) => KbChord.activator(chordOf(c));

  /// [c]'s chord as a tooltip says it; empty when it has none.
  String labelOf(KbCommand c) => KbChord.label(chordOf(c), platform);

  /// `name ⌃⌘P`, or the name alone without a chord.
  String tip(String name, KbCommand c) {
    final keys = labelOf(c);
    return keys.isEmpty ? name : '$name $keys';
  }

  /// Every changeable command of [scopes] with a chord, for a [Shortcuts].
  Map<ShortcutActivator, Intent> shortcutsFor(Iterable<KbScope> scopes) => {
    for (final c in KbCommand.values)
      if (!c.fixed && scopes.contains(c.scope))
        ?activatorOf(c): KbIntent.of(c),
  };

  /// The commands that would answer [chord] wherever [command] does.
  List<KbCommand> conflictsOf(KbCommand command, String chord) => [
    for (final c in KbCommand.values)
      if (c != command &&
          !c.fixed &&
          chord.isNotEmpty &&
          chordOf(c) == chord &&
          c.sharesScopeWith(command))
        c,
  ];
}

/// The keyboard shortcuts, as changed on the settings page.
@Riverpod(keepAlive: true)
class Keybindings extends _$Keybindings {
  @override
  KbState build() {
    final platform = KbPlatform.current;
    return KbState(platform: platform, overrides: _read(platform));
  }

  static String _key(KbPlatform p, String id) => '${p.name}:$id';

  static Map<String, String> _read(KbPlatform platform) {
    final prefix = '${platform.name}:';
    return {
      for (final e in Stores.setting.keybindings.fetch().entries)
        // One no chord reads — written by hand, or by a build that took more
        // spellings — leaves its command at the default.
        if (e.key.startsWith(prefix) &&
            (e.value.isEmpty || KbChord.activator(e.value) != null))
          e.key.substring(prefix.length): e.value,
    };
  }

  /// Writes this platform's changes, leaving the other platform's alone.
  void _write(Map<String, String> overrides) {
    final p = state.platform;
    final all = {
      for (final e in Stores.setting.keybindings.fetch().entries)
        if (!e.key.startsWith('${p.name}:')) e.key: e.value,
      for (final e in overrides.entries) _key(p, e.key): e.value,
    };
    Stores.setting.keybindings.put(all);
    state = KbState(platform: p, overrides: overrides);
  }

  /// [command] bound to [chord], taken from any command it conflicts with.
  /// A chord [KbChord.activator] cannot read is refused.
  void bind(KbCommand command, String chord) {
    if (command.fixed) return;
    if (chord.isNotEmpty && KbChord.activator(chord) == null) return;
    final next = {...state.overrides};
    for (final c in state.conflictsOf(command, chord)) {
      next[c.id] = '';
    }
    next[command.id] = chord;
    // Bound back to its default is not a change.
    if (chord == command.defaultFor(state.platform)) next.remove(command.id);
    _write(next);
  }

  /// [command] with no keys at all.
  void unbind(KbCommand command) => bind(command, '');

  void reset(KbCommand command) =>
      _write({...state.overrides}..remove(command.id));

  void resetAll() => _write(const {});
}
