import 'dart:convert';

/// A plugin's own translations. PLUGINS.md section 5.1.
///
/// A string starting `l10n.` is looked up in `l10n/<locale>.json`, falling
/// back to `en`; everything else is shown as typed. So a plugin that ships no
/// translations works, and one that does needs no API for it — the strings
/// travel as ordinary property values.
class PluginL10n {
  const PluginL10n({this.active = const {}, this.fallback = const {}});

  /// The active locale's strings.
  final Map<String, String> active;

  /// `en`, which a manifest must ship.
  final Map<String, String> fallback;

  static const empty = PluginL10n();

  /// The prefix that marks a value as a key rather than a string.
  static const prefix = 'l10n.';

  /// The separator between a key and its arguments.
  ///
  /// A control character rather than something typeable: an argument is a
  /// machine name or a `ResetType`, and a plugin must not be able to break its
  /// own formatting by containing the separator. The SDK strips it from
  /// arguments as well.
  static const argSep = '\u001F';

  /// Reads one `l10n/<locale>.json`.
  ///
  /// A file that will not parse, or holds anything but strings, contributes
  /// nothing rather than failing the install: the plugin then shows its keys
  /// in that locale and works in `en`.
  static Map<String, String> parse(String json) {
    try {
      final decoded = jsonDecode(json);
      if (decoded is! Map) return const {};
      return {
        for (final e in decoded.entries)
          if (e.key is String && e.value is String)
            e.key as String: e.value as String,
      };
    } catch (_) {
      return const {};
    }
  }

  /// What to show for [raw].
  ///
  /// Anything not starting [prefix] is returned unchanged, which is most
  /// strings — a machine name, a number a plugin formatted itself.
  ///
  /// A key with no translation in either map shows the key. That is the one
  /// answer that says where to look: an empty string would be a card with a
  /// blank row, and the raw `l10n.foo` names the entry that is missing.
  String resolve(String raw) {
    if (!raw.startsWith(prefix)) return raw;
    final parts = raw.split(argSep);
    final key = parts.first.substring(prefix.length);
    if (key.isEmpty) return raw;

    final template = active[key] ?? fallback[key] ?? parts.first;
    if (parts.length == 1) return template;

    // The whole sentence is in the translation file and only the values cross,
    // so there is nothing here to assemble — just the substitution the
    // translator's `{0}` asked for. An index the template does not use is
    // dropped, and one it uses twice is substituted twice.
    var out = template;
    for (var i = 1; i < parts.length; i++) {
      out = out.replaceAll('{${i - 1}}', parts[i]);
    }
    return out;
  }
}
