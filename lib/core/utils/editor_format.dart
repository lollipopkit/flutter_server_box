import 'dart:convert';
import 'dart:math' as math;

import 'package:fl_lib/fl_lib.dart';

const _jsonIndent = JsonEncoder.withIndent('  ');

final _jsonlSuffix = RegExp(r'\.(jsonl|ndjson)$', caseSensitive: false);

/// Pretty-print [text] for whatever the editor opened.
///
/// JSON / JSON Lines / XML are re-encoded. INI-shaped files get `Key=value`.
/// Brace languages are re-indented. Indent-sensitive languages (Python,
/// YAML, Makefiles, …) only lose trailing whitespace, so their meaning
/// does not change.
///
/// Throws [FormatException] when a JSON file is not valid JSON.
String formatEditorText(
  String text, {
  ProgLang? lang,
  String? path,
}) {
  if (text.isEmpty) return text;
  final kind = _kindFor(lang, path, text);
  final formatted = switch (kind) {
    _FormatKind.json => _formatJson(text),
    _FormatKind.jsonl => _formatJsonl(text),
    _FormatKind.xml => _formatXml(text),
    _FormatKind.ini => _formatIni(text),
    _FormatKind.apache => _formatApache(text),
    _FormatKind.braces => _formatBraces(text, comments: _commentsFor(lang)),
    _FormatKind.tidy => _tidy(
        text,
        keepTabs: lang == ProgLang.makefile || lang == ProgLang.python,
      ),
  };
  return _sameTrailingNewline(text, formatted);
}

enum _FormatKind { json, jsonl, xml, ini, apache, braces, tidy }

enum _Comments { cLike, hash, sql, none }

_FormatKind _kindFor(ProgLang? lang, String? path, String text) {
  if (path != null && _jsonlSuffix.hasMatch(path)) return _FormatKind.jsonl;
  switch (lang) {
    case ProgLang.json:
      return _FormatKind.json;
    case ProgLang.xml:
      return _FormatKind.xml;
    case ProgLang.ini:
    case ProgLang.properties:
      return _FormatKind.ini;
    case ProgLang.apache:
      return _FormatKind.apache;
    case ProgLang.yaml:
    case ProgLang.python:
    case ProgLang.makefile:
    case ProgLang.haskell:
    case ProgLang.nim:
    case ProgLang.diff:
    case ProgLang.markdown:
    case ProgLang.plaintext:
    case ProgLang.excel:
    case ProgLang.wasm:
    case ProgLang.dockerfile:
    case ProgLang.latex:
    case ProgLang.bnf:
    case ProgLang.ebnf:
    case ProgLang.fortran:
    case ProgLang.llvm:
      return _FormatKind.tidy;
    case null:
      return _sniff(text);
    default:
      return _FormatKind.braces;
  }
}

_FormatKind _sniff(String text) {
  final t = text.trimLeft();
  if (t.startsWith('{') || t.startsWith('[')) {
    try {
      jsonDecode(text);
      return _FormatKind.json;
    } on FormatException {
      return _FormatKind.braces;
    }
  }
  if (t.startsWith('<?xml') ||
      t.startsWith('<!') ||
      (t.startsWith('<') && t.contains('>'))) {
    return _FormatKind.xml;
  }
  if (RegExp(r'^\s*\[[^\]]+\]', multiLine: true).hasMatch(text) &&
      text.contains('=')) {
    return _FormatKind.ini;
  }
  if (t.contains('{') && t.contains('}')) return _FormatKind.braces;
  return _FormatKind.tidy;
}

_Comments _commentsFor(ProgLang? lang) {
  return switch (lang) {
    ProgLang.shell ||
    ProgLang.bash ||
    ProgLang.python ||
    ProgLang.yaml ||
    ProgLang.ruby ||
    ProgLang.perl ||
    ProgLang.awk ||
    ProgLang.nix ||
    ProgLang.r ||
    ProgLang.ini ||
    ProgLang.properties ||
    ProgLang.apache ||
    ProgLang.nginx ||
    ProgLang.powershell ||
    ProgLang.dockerfile ||
    ProgLang.cmake ||
    ProgLang.nim =>
      _Comments.hash,
    ProgLang.lua ||
    ProgLang.sql ||
    ProgLang.pgsql ||
    ProgLang.haskell =>
      _Comments.sql,
    ProgLang.plaintext ||
    ProgLang.markdown ||
    ProgLang.diff ||
    ProgLang.xml ||
    ProgLang.json =>
      _Comments.none,
    _ => _Comments.cLike,
  };
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

String _formatXml(String text) {
  final matches = RegExp(r'<[^>]+>|[^<]+').allMatches(text);
  final out = StringBuffer();
  var depth = 0;
  for (final match in matches) {
    final part = match.group(0)!.trim();
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

String _formatIni(String text) {
  final out = <String>[];
  for (final raw in const LineSplitter().convert(text)) {
    final t = raw.trim();
    if (t.isEmpty) {
      out.add('');
      continue;
    }
    if (t.startsWith('#') || t.startsWith(';') || t.startsWith('export ')) {
      out.add(t);
      continue;
    }
    if (t.startsWith('[') && t.endsWith(']')) {
      out.add(t);
      continue;
    }
    final eq = t.indexOf('=');
    if (eq <= 0) {
      out.add(t);
      continue;
    }
    out.add('${t.substring(0, eq).trim()}=${t.substring(eq + 1).trimLeft()}');
  }
  return out.join('\n');
}

String _formatApache(String text) {
  final out = <String>[];
  var depth = 0;
  for (final raw in const LineSplitter().convert(text)) {
    final t = raw.trim();
    if (t.isEmpty) {
      out.add('');
      continue;
    }
    final lower = t.toLowerCase();
    if (lower.startsWith('</')) {
      depth = depth > 0 ? depth - 1 : 0;
    }
    out.add('${'  ' * depth}${_collapseSpaces(t)}');
    if (lower.startsWith('<') &&
        !lower.startsWith('</') &&
        !lower.startsWith('<!')) {
      depth++;
    }
  }
  return out.join('\n');
}

String _collapseSpaces(String line) {
  final out = StringBuffer();
  var inQuote = 0;
  var escape = false;
  var space = false;
  for (final unit in line.codeUnits) {
    if (escape) {
      out.writeCharCode(unit);
      escape = false;
      continue;
    }
    if (unit == 0x5c && inQuote != 0) {
      out.writeCharCode(unit);
      escape = true;
      continue;
    }
    if (inQuote == 0 && (unit == 0x22 || unit == 0x27)) {
      inQuote = unit;
      space = false;
      out.writeCharCode(unit);
      continue;
    }
    if (inQuote != 0 && unit == inQuote) {
      inQuote = 0;
      out.writeCharCode(unit);
      continue;
    }
    if (inQuote == 0 && (unit == 0x20 || unit == 0x09)) {
      if (!space && out.isNotEmpty) {
        out.write(' ');
        space = true;
      }
      continue;
    }
    space = false;
    out.writeCharCode(unit);
  }
  return out.toString();
}

String _formatBraces(String text, {required _Comments comments}) {
  final state = _ScanState();
  final out = <String>[];
  var depth = 0;
  for (final raw in const LineSplitter().convert(text)) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) {
      _scanLine(raw, state, comments);
      out.add('');
      continue;
    }
    final (leadingCloses, delta) = _braceCounts(trimmed, state, comments);
    final indent = math.max(0, depth - leadingCloses);
    out.add('${'  ' * indent}$trimmed');
    depth = math.max(0, depth + delta);
  }
  return out.join('\n');
}

String _tidy(String text, {required bool keepTabs}) {
  final out = <String>[];
  for (final raw in const LineSplitter().convert(text)) {
    var line = raw.replaceAll(RegExp(r'[ \t]+$'), '');
    if (!keepTabs) {
      line = line.replaceAll('\t', '  ');
    }
    out.add(line);
  }
  return out.join('\n');
}

class _ScanState {
  bool inBlockComment = false;
  int stringQuote = 0;
}

(int, int) _braceCounts(String line, _ScanState state, _Comments comments) {
  var leadingCloses = 0;
  var stillLeading = true;
  var opens = 0;
  var closes = 0;
  _scanLine(line, state, comments, onCode: (unit) {
    if (unit == 0x7b) {
      stillLeading = false;
      opens++;
    } else if (unit == 0x7d) {
      closes++;
      if (stillLeading) leadingCloses++;
    } else if (unit != 0x20 && unit != 0x09) {
      stillLeading = false;
    }
  });
  return (leadingCloses, opens - closes);
}

void _scanLine(
  String line,
  _ScanState state,
  _Comments comments, {
  void Function(int unit)? onCode,
}) {
  var escape = false;
  var i = 0;
  while (i < line.length) {
    final unit = line.codeUnitAt(i);
    if (state.inBlockComment) {
      if (unit == 0x2a && i + 1 < line.length && line.codeUnitAt(i + 1) == 0x2f) {
        state.inBlockComment = false;
        i += 2;
        continue;
      }
      i++;
      continue;
    }
    if (state.stringQuote != 0) {
      if (escape) {
        escape = false;
        i++;
        continue;
      }
      if (unit == 0x5c) {
        escape = true;
        i++;
        continue;
      }
      if (unit == state.stringQuote) state.stringQuote = 0;
      i++;
      continue;
    }
    if (comments == _Comments.cLike &&
        unit == 0x2f &&
        i + 1 < line.length &&
        line.codeUnitAt(i + 1) == 0x2f) {
      break;
    }
    if (comments == _Comments.cLike &&
        unit == 0x2f &&
        i + 1 < line.length &&
        line.codeUnitAt(i + 1) == 0x2a) {
      state.inBlockComment = true;
      i += 2;
      continue;
    }
    if (comments == _Comments.hash && unit == 0x23) break;
    if (comments == _Comments.sql &&
        unit == 0x2d &&
        i + 1 < line.length &&
        line.codeUnitAt(i + 1) == 0x2d) {
      break;
    }
    if (unit == 0x22 || unit == 0x27 || unit == 0x60) {
      state.stringQuote = unit;
      i++;
      continue;
    }
    onCode?.call(unit);
    i++;
  }
}

String _sameTrailingNewline(String original, String formatted) {
  final had = original.endsWith('\n');
  if (had && !formatted.endsWith('\n')) return '$formatted\n';
  if (!had && formatted.endsWith('\n')) {
    return formatted.substring(0, formatted.length - 1);
  }
  return formatted;
}
