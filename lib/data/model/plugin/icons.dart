import 'package:flutter/material.dart';

/// The icons a plugin may name, and the one thing that resolves a name to one.
///
/// **A fixed table, not a lookup into the font's codepoints.** A plugin naming
/// an arbitrary glyph would be a plugin whose icon changes meaning when the
/// icon set does, and there is no way to review that at install time. It also
/// keeps `--tree-shake-icons` working: every entry here is a const reference
/// the compiler can see, which a codepoint built at runtime is not.
///
/// Read from two places and they must agree — the `icon` node inside a
/// plugin's own interface (`PluginRender`), and the icon on the button or tab
/// a contribution puts in the app's own chrome (`InstalledPlugin`). A
/// contribution that names one and a widget that names the same one should not
/// be able to draw different glyphs.
abstract final class PluginIcons {
  /// Null for a name this build has none for.
  ///
  /// Null rather than a placeholder, so each caller decides: a widget says so
  /// out loud because the plugin asked for something specific, while a
  /// contribution falls back to [fallback] — a newer plugin naming an icon
  /// this build lacks should still have a button.
  static IconData? resolve(String? name) => name == null ? null : _table[name];

  /// What a contribution gets when it names nothing, or names something this
  /// build has no glyph for.
  static const fallback = Icons.extension_outlined;

  /// [resolve], with [fallback] for anything it does not know.
  static IconData of(String? name) => resolve(name) ?? fallback;

  /// Every name a manifest or a node may use.
  static Iterable<String> get names => _table.keys;

  static const _table = <String, IconData>{
    // --- state
    'info': Icons.info_outline,
    'warning': Icons.warning_amber_outlined,
    'error': Icons.error_outline,
    'check': Icons.check_circle_outline,

    // --- actions
    'power': Icons.power_settings_new,
    'refresh': Icons.refresh,
    'settings': Icons.settings_outlined,
    'play': Icons.play_arrow,
    'stop': Icons.stop,
    'edit': Icons.edit_outlined,
    'delete': Icons.delete_outline,
    'add': Icons.add,
    'up': Icons.arrow_upward,

    // --- things on a machine
    'server': Icons.dns_outlined,
    'disk': Icons.storage_outlined,
    'folder': Icons.folder_outlined,
    'file': Icons.description_outlined,
    'network': Icons.lan_outlined,
    'port': Icons.settings_ethernet,
    'cpu': Icons.memory,
    'temperature': Icons.thermostat_outlined,
    'clock': Icons.schedule,
    'calendar': Icons.event_outlined,
    'lock': Icons.lock_outline,
    'terminal': Icons.terminal,
    'process': Icons.list_alt_outlined,
    'package': Icons.inventory_2_outlined,
    'chart': Icons.pie_chart_outline,
    'globe': Icons.public,
  };
}
