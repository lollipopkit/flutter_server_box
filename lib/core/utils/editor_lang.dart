import 'package:fl_lib/fl_lib.dart';

/// JSON-shaped files that are not named `.json`.
const _jsonLikeSuffixes = {
  'json',
  'jsonc',
  'json5',
  'jsonl',
  'ndjson',
  'geojson',
  'webmanifest',
  'har',
};

/// systemd unit types from `systemd.unit(5)`. The files are INI
/// (`[Unit]`, `[Service]`, `Key=value`).
const _systemdUnitSuffixes = {
  'service',
  'socket',
  'device',
  'mount',
  'automount',
  'swap',
  'target',
  'path',
  'timer',
  'slice',
  'scope',
};

/// The highlighter for a path opened in the file editor.
///
/// [ProgLang.parseFileName] matches suffixes as they are spelled in the
/// enum, so `package.JSON` is not `json`. A second look lowercases the
/// extension, and JSON-shaped names that are not `.json` still use the JSON
/// highlighter. systemd units such as `.service` use the INI highlighter.
ProgLang? editorLangFor(String? path) {
  if (path == null || path.isEmpty) return null;
  final name = path.split(RegExp(r'[/\\]')).last;
  final byName = ProgLang.parseFileName(name);
  if (byName != null) return byName;
  final dot = name.lastIndexOf('.');
  if (dot <= 0 || dot == name.length - 1) return null;
  final ext = name.substring(dot + 1).toLowerCase();
  if (_jsonLikeSuffixes.contains(ext)) return ProgLang.json;
  if (_systemdUnitSuffixes.contains(ext)) return ProgLang.ini;
  return ProgLang.parseFileName('file.$ext');
}
