/// Helpers for tmux's escaped, tab-separated format output.
library;

import 'dart:convert';

/// Splits a formatted tmux line on unescaped tabs.
List<String> splitTmuxFields(String line) {
  final fields = <String>[];
  final current = StringBuffer();
  for (var i = 0; i < line.length; i++) {
    final char = line[i];
    if (char == r'\' && i + 1 < line.length) {
      current
        ..write(char)
        ..write(line[++i]);
      continue;
    }
    if (char == '\t') {
      fields.add(current.toString());
      current.clear();
      continue;
    }
    current.write(char);
  }
  fields.add(current.toString());
  return fields;
}

/// Reverses the `q:` format modifier enough for values shown by the app.
String unescapeTmuxField(String value) {
  if (value.length < 2) return value;
  final out = StringBuffer();
  List<int>? utf8Bytes;

  void flushBytes() {
    final bytes = utf8Bytes;
    if (bytes == null || bytes.isEmpty) return;
    out.write(utf8.decode(bytes, allowMalformed: true));
    utf8Bytes = null;
  }

  for (var i = 0; i < value.length; i++) {
    if (value[i] != r'\' || i + 1 >= value.length) {
      flushBytes();
      out.write(value[i]);
      continue;
    }

    final next = value[++i];
    if (i + 2 < value.length) {
      final octal = value.substring(i, i + 3);
      final byte = int.tryParse(octal, radix: 8);
      if (byte != null && byte <= 0xff) {
        final bytes = utf8Bytes ??= <int>[];
        bytes.add(byte);
        i += 2;
        continue;
      }
    }
    flushBytes();
    out.write(next);
  }
  flushBytes();
  return out.toString();
}
