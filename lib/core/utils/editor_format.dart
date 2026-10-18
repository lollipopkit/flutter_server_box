import 'dart:convert';

import 'package:fl_lib/fl_lib.dart';

const _jsonIndent = JsonEncoder.withIndent('  ');

final _jsonlSuffix = RegExp(r'\.(jsonl|ndjson)$', caseSensitive: false);

/// Pretty-print [text] for the editor, or `null` when this language has
/// no formatter.
///
/// JSON is re-encoded with two-space indent. JSON Lines (`jsonl` / `ndjson`)
/// stay one value per line. XML-shaped files are indented by tag depth.
/// Throws [FormatException] when the text is not valid for that formatter.
String? formatEditorText(
  String text, {
  ProgLang? lang,
  String? path,
}) {
  final kind = _kindFor(lang, path, text);
  if (kind == null) return null;
  final hadTrailingNewline = text.endsWith('\n');
  final formatted = switch (kind) {
    _FormatKind.json => _formatJson(text),
    _FormatKind.jsonl => _formatJsonl(text),
    _FormatKind.xml => _formatXml(text),
  };
  if (hadTrailingNewline && !formatted.endsWith('\n')) return '$formatted\n';
  if (!hadTrailingNewline && formatted.endsWith('\n')) {
    return formatted.substring(0, formatted.length - 1);
  }
  return formatted;
}

enum _FormatKind { json, jsonl, xml }

_FormatKind? _kindFor(ProgLang? lang, String? path, String text) {
  if (path != null && _jsonlSuffix.hasMatch(path)) return _FormatKind.jsonl;
  if (lang == ProgLang.json) return _FormatKind.json;
  if (lang == ProgLang.xml) return _FormatKind.xml;
  final trimmed = text.trimLeft();
  if (trimmed.startsWith('{') || trimmed.startsWith('[')) {
    return _FormatKind.json;
  }
  if (trimmed.startsWith('<?xml') ||
      trimmed.startsWith('<!') ||
      (trimmed.startsWith('<') && trimmed.contains('>'))) {
    return _FormatKind.xml;
  }
  return null;
}

String _formatJson(String text) {
  final decoded = jsonDecode(text);
  return _jsonIndent.convert(decoded);
}

String _formatJsonl(String text) {
  final lines = const LineSplitter().convert(text);
  return lines
      .map((line) => line.trim().isEmpty ? line : jsonEncode(jsonDecode(line)))
      .join('\n');
}

/// Indent XML/HTML by tag depth. Mixed content on one line is left as it
/// was; this is for config files (`plist`, unit XML), not a full HTML
/// pretty-printer.
String _formatXml(String text) {
  final matches = RegExp(r'<[^>]+>|[^<]+').allMatches(text);
  final out = StringBuffer();
  var depth = 0;
  for (final match in matches) {
    final raw = match.group(0)!;
    final part = raw.trim();
    if (part.isEmpty) continue;
    if (part.startsWith('</')) {
      depth = depth > 0 ? depth - 1 : 0;
      out.writeln('${'  ' * depth}$part');
    } else if (part.startsWith('<?') ||
        part.startsWith('<!') ||
        part.endsWith('/>')) {
      out.writeln('${'  ' * depth}$part');
    } else if (part.startsWith('<')) {
      out.writeln('${'  ' * depth}$part');
      if (!_selfCloses(part)) depth++;
    } else {
      out.writeln('${'  ' * depth}$part');
    }
  }
  return out.toString();
}

bool _selfCloses(String tag) {
  if (tag.endsWith('/>')) return true;
  final name = RegExp(r'^</?([A-Za-z_][\w:.-]*)').firstMatch(tag)?.group(1);
  if (name == null) return false;
  const voidHtml = {
    'area',
    'base',
    'br',
    'col',
    'embed',
    'hr',
    'img',
    'input',
    'link',
    'meta',
    'param',
    'source',
    'track',
    'wbr',
  };
  return voidHtml.contains(name.toLowerCase());
}
