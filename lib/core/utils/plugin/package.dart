import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:server_box/data/model/plugin/l10n.dart';

/// A `.sbp`, read and checked. PLUGINS.md section 2.
///
/// A zip carrying `manifest.json`, `plugin.js`, `l10n/<locale>.json` and
/// `icon.png`. Everything here is about a file that came from somewhere else:
/// a repository, a share sheet, a chat message. So it is read into memory and
/// checked before anything reaches the filesystem — nothing in this class
/// writes.
class PluginPackage {
  const PluginPackage({
    required this.manifestJson,
    required this.source,
    required this.l10n,
    this.icon,
  });

  /// The manifest verbatim, so `plugin_read_manifest` is the one parser.
  final String manifestJson;

  /// `plugin.js`.
  final String source;

  /// Locale to its strings, from `l10n/<locale>.json`.
  final Map<String, Map<String, String>> l10n;

  final Uint8List? icon;

  static const manifestName = 'manifest.json';
  static const sourceName = 'plugin.js';
  static const l10nDir = 'l10n/';
  static const iconName = 'icon.png';

  /// The whole package, unpacked.
  ///
  /// A cap rather than a courtesy: this is an untrusted archive, and a zip
  /// bomb is a few kilobytes that decompresses to whatever the reader will
  /// hold. What a plugin actually is — a manifest, a script and some
  /// translations — is orders of magnitude under this.
  static const maxTotalBytes = 8 * 1024 * 1024;

  /// The longest single entry.
  static const maxEntryBytes = 4 * 1024 * 1024;

  /// Reads and checks [bytes], or throws [PluginPackageError].
  factory PluginPackage.read(List<int> bytes) {
    final Archive archive;
    try {
      archive = ZipDecoder().decodeBytes(bytes);
    } catch (e) {
      throw const PluginPackageError('not a readable .sbp');
    }

    String? manifest;
    String? source;
    Uint8List? icon;
    final l10n = <String, Map<String, String>>{};
    var total = 0;

    for (final file in archive) {
      if (!file.isFile) continue;
      final name = _safeName(file.name);
      // A name that escapes the directory it is unpacked into. The classic
      // archive attack, and the reason nothing is written before this loop
      // has finished.
      if (name == null) {
        throw PluginPackageError('unsafe path in the package: ${file.name}');
      }
      if (file.size > maxEntryBytes) {
        throw PluginPackageError('$name is larger than $maxEntryBytes bytes');
      }
      total += file.size;
      if (total > maxTotalBytes) {
        throw const PluginPackageError('the package unpacks to too much');
      }

      final content = file.content;
      switch (name) {
        case manifestName:
          manifest = _utf8(content, name);
        case sourceName:
          source = _utf8(content, name);
        case iconName:
          icon = content;
        default:
          if (!name.startsWith(l10nDir) || !name.endsWith('.json')) continue;
          final locale = name.substring(
            l10nDir.length,
            name.length - '.json'.length,
          );
          if (locale.isEmpty) continue;
          // A translation file that will not parse costs that locale, not the
          // install: the plugin then shows its keys there and works in `en`.
          l10n[locale] = PluginL10n.parse(_utf8(content, name));
      }
    }

    if (manifest == null) {
      throw const PluginPackageError('the package has no $manifestName');
    }
    if (source == null) {
      throw const PluginPackageError('the package has no $sourceName');
    }
    return PluginPackage(
      manifestJson: manifest,
      source: source,
      l10n: l10n,
      icon: icon,
    );
  }

  /// The strings for [locale], and `en` behind them.
  PluginL10n l10nFor(String locale) => PluginL10n(
    // `zh_Hant` before `zh`, because a locale is more specific than its
    // language and a package may ship both.
    active: l10n[locale] ?? l10n[locale.split(RegExp('[-_]')).first] ?? const {},
    fallback: l10n['en'] ?? const {},
  );

  /// The entry name, or null when it is one nothing may be written under.
  ///
  /// Refused: an absolute path, a Windows drive letter, and any `..` step.
  /// Backslashes are normalised first, because a zip written on Windows uses
  /// them and a check that only looked for `/` would let `..\..\x` through.
  static String? _safeName(String raw) {
    final name = raw.replaceAll('\\', '/');
    if (name.isEmpty) return null;
    if (name.startsWith('/')) return null;
    if (RegExp('^[A-Za-z]:').hasMatch(name)) return null;
    for (final part in name.split('/')) {
      if (part == '..') return null;
    }
    return name;
  }

  static String _utf8(List<int> bytes, String name) {
    try {
      return utf8.decode(bytes);
    } catch (_) {
      throw PluginPackageError('$name is not UTF-8');
    }
  }
}

/// Why a package could not be read.
///
/// A message rather than a code: every one of these is shown to somebody who
/// is about to install something, and what they need is the reason.
class PluginPackageError implements Exception {
  const PluginPackageError(this.message);
  final String message;

  @override
  String toString() => message;
}
