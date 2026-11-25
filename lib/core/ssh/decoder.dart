import 'dart:convert';

import 'package:fl_lib/fl_lib.dart';
import 'package:flutter_gbk2utf8/flutter_gbk2utf8.dart';

/// Decodes SSH output with a Windows-specific GBK fallback.
class SSHDecoder {
  /// Decodes [bytes] as UTF-8, then tries GBK for malformed Windows output.
  ///
  /// Tries in order:
  /// 1. UTF-8 with malformed sequences replaced.
  ///    - Windows PowerShell scripts now set UTF-8 output encoding by default
  /// 2. GBK (for Windows Chinese systems)
  ///    - In some cases, Windows will still revert to GBK.
  ///    - Only attempted if UTF-8 produces replacement characters (�)
  static String decode(
    List<int> bytes, {
    bool isWindows = false,
    String? context,
  }) {
    if (bytes.isEmpty) return '';

    try {
      final result = utf8.decode(bytes, allowMalformed: true);
      // Non-Windows output remains UTF-8 even when it contains replacement
      // characters; GBK is only a plausible fallback on Windows.
      if (!result.contains('�') || !isWindows) {
        return result;
      }
      if (isWindows && result.contains('�')) {
        final contextInfo = context != null ? ' [$context]' : '';
        Loggers.app.info(
          'UTF-8 decode has replacement chars$contextInfo, trying GBK fallback',
        );
      }
    } catch (e) {
      final contextInfo = context != null ? ' [$context]' : '';
      Loggers.app.warning('UTF-8 decode failed$contextInfo: $e');
    }

    try {
      return gbk.decode(bytes);
    } catch (e) {
      final contextInfo = context != null ? ' [$context]' : '';
      Loggers.app.warning('GBK decode failed$contextInfo: $e');
      return '';
    }
  }
}

/// Stateful chunked decoder for a single Windows SSH output stream.
///
/// Buffers incomplete trailing UTF-8 or GBK multibyte sequences across chunk
/// boundaries so streaming callbacks (`onStdout`/`onStderr`) do not emit
/// split-sequence replacement characters. Falls back to GBK once a complete
/// chunk prefix fails strict UTF-8 decoding.
final class WindowsStreamDecoder {
  WindowsStreamDecoder({this.context});

  final String? context;
  final List<int> _pending = <int>[];
  bool _useGbk = false;

  /// Feeds [chunk] and returns any complete decoded text ready to emit.
  String add(List<int> chunk) {
    if (chunk.isEmpty) return '';
    final bytes = _pending.isEmpty ? chunk : [..._pending, ...chunk];
    _pending.clear();

    if (!_useGbk) {
      final split = _utf8CompletePrefixLength(bytes);
      final prefix = split == bytes.length ? bytes : bytes.sublist(0, split);
      final tail = split == bytes.length ? const <int>[] : bytes.sublist(split);
      try {
        final decoded = prefix.isEmpty
            ? ''
            : utf8.decode(prefix, allowMalformed: false);
        _pending.addAll(tail);
        return decoded;
      } on FormatException {
        _useGbk = true;
        final contextInfo = context != null ? ' [$context]' : '';
        Loggers.app.info(
          'UTF-8 stream decode failed$contextInfo, switching to GBK fallback',
        );
      }
    }

    return _decodeGbkPrefix(bytes);
  }

  /// Flushes any trailing bytes buffered at end-of-stream.
  String flush() {
    if (_pending.isEmpty) return '';
    final tail = List<int>.of(_pending);
    _pending.clear();
    if (_useGbk) {
      // `flutter_gbk2utf8` unconditionally reads two bytes for any byte > 0x80
      // and throws a RangeError on an unpaired trailing byte.
      if (tail.length == 1 && tail[0] > 0x80) return '\uFFFD';
      try {
        return gbk.decode(tail);
      } catch (e) {
        final contextInfo = context != null ? ' [$context]' : '';
        Loggers.app.warning('GBK stream flush failed$contextInfo: $e');
        return '';
      }
    }
    return SSHDecoder.decode(tail, isWindows: true, context: context);
  }

  String _decodeGbkPrefix(List<int> bytes) {
    final split = _gbkCompletePrefixLength(bytes);
    if (split < bytes.length) {
      _pending.addAll(bytes.sublist(split));
    }
    if (split == 0) return '';
    final prefix = split == bytes.length ? bytes : bytes.sublist(0, split);
    try {
      return gbk.decode(prefix);
    } catch (e) {
      final contextInfo = context != null ? ' [$context]' : '';
      Loggers.app.warning('GBK stream decode failed$contextInfo: $e');
      return '';
    }
  }

  /// Returns the length of [bytes] excluding any valid-so-far incomplete UTF-8
  /// sequence at the end.
  static int _utf8CompletePrefixLength(List<int> bytes) {
    if (bytes.isEmpty) return 0;
    final last = bytes.last;
    if (last < 0x80) return bytes.length;

    // Walk back past at most 3 continuation bytes to locate the lead byte.
    var leadIdx = bytes.length - 1;
    final minIdx = bytes.length > 4 ? bytes.length - 4 : 0;
    while (leadIdx > minIdx && (bytes[leadIdx] & 0xC0) == 0x80) {
      leadIdx--;
    }

    final lead = bytes[leadIdx];
    final have = bytes.length - leadIdx;
    final int expected;
    if (lead >= 0xC2 && lead <= 0xDF) {
      expected = 2;
    } else if (lead >= 0xE0 && lead <= 0xEF) {
      expected = 3;
    } else if (lead >= 0xF0 && lead <= 0xF4) {
      expected = 4;
    } else {
      // Not a valid UTF-8 lead byte; let strict decoding reject it now.
      return bytes.length;
    }

    if (have >= expected) return bytes.length;

    // Verify any continuation bytes already received are legal for this lead.
    if (have >= 2) {
      final b1 = bytes[leadIdx + 1];
      if ((b1 & 0xC0) != 0x80) return bytes.length;
      if (lead == 0xE0 && b1 < 0xA0) return bytes.length;
      if (lead == 0xED && b1 > 0x9F) return bytes.length;
      if (lead == 0xF0 && b1 < 0x90) return bytes.length;
      if (lead == 0xF4 && b1 > 0x8F) return bytes.length;
    }
    if (have >= 3 && (bytes[leadIdx + 2] & 0xC0) != 0x80) {
      return bytes.length;
    }
    return leadIdx;
  }

  /// Returns the length of [bytes] excluding a trailing unpaired GBK lead byte.
  ///
  /// Matches `flutter_gbk2utf8`'s `ch > 0x80` two-byte stride so trailing
  /// `0xFF` bytes do not cause a RangeError that drops preceding valid text.
  static int _gbkCompletePrefixLength(List<int> bytes) {
    var i = 0;
    while (i < bytes.length) {
      if (bytes[i] > 0x80) {
        if (i + 1 >= bytes.length) return i;
        i += 2;
      } else {
        i += 1;
      }
    }
    return bytes.length;
  }
}
