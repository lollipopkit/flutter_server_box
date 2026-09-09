/// Building a `.sbp` the way one arrives.
///
/// One copy, because three tests were writing the same archive by hand and the
/// entry names are the contract — `PluginPackage.read` looks for exactly these
/// and ignores anything else, so a name typed differently in one test is a
/// package that installs with no translations and nothing saying why.
library;

import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:server_box/core/utils/plugin/package.dart';

/// A package holding [manifest] and [source].
///
/// [extra] is for entries a real package would not have — a path that escapes,
/// something oversized — which is what the reader's checks are about.
List<int> buildSbp({
  required String manifest,
  String source = 'export function statusCmd() { return { cmd: "true" }; }',
  Map<String, Object?> l10n = const {
    'en': {'title': 'Title'},
  },
  List<int>? icon,
  Map<String, List<int>> extra = const {},
}) {
  final archive = Archive();
  void add(String name, List<int> bytes) =>
      archive.add(ArchiveFile.bytes(name, bytes));

  add(PluginPackage.manifestName, utf8.encode(manifest));
  add(PluginPackage.sourceName, utf8.encode(source));
  for (final e in l10n.entries) {
    add('${PluginPackage.l10nDir}${e.key}.json', utf8.encode(jsonEncode(e.value)));
  }
  if (icon != null) add(PluginPackage.iconName, icon);
  for (final e in extra.entries) {
    add(e.key, e.value);
  }
  return ZipEncoder().encode(archive);
}

/// A manifest with the fields every one needs and nothing else.
String pluginManifest({
  String id = 'app.serverbox.test',
  String version = '1.0.0',
  int abi = 1,
  String name = 'Test',
  List<String> permissions = const ['server.exec'],
  Map<String, Object?>? contributes,
  Map<String, Object?> extra = const {},
}) => jsonEncode({
  'id': id,
  'version': version,
  'abi': abi,
  'name': name,
  'permissions': {for (final p in permissions) p: true},
  'contributes': ?contributes,
  ...extra,
});
