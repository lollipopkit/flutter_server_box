import 'dart:convert';

import 'package:fl_lib/fl_lib.dart';
import 'package:flutter_gbk2utf8/flutter_gbk2utf8.dart';

/// Utility class for decoding SSH command output with encoding fallback
class SSHDecoder {
  /// Decodes bytes to string with multiple encoding fallback strategies
  ///
  /// Tries in order:
  /// 1. UTF-8 (with allowMalformed for lenient parsing)
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

    // Try UTF-8 first with allowMalformed
    try {
      final result = utf8.decode(bytes, allowMalformed: true);
      // Check if there are replacement characters indicating decode failure
      // For non-Windows systems, always use UTF-8 result
      if (!result.contains('�') || !isWindows) {
        return result;
      }
      // For Windows with replacement chars, log and try GBK fallback
      if (isWindows && result.contains('�')) {
        final contextInfo = context != null ? ' [$context]' : '';
        Loggers.app.info('UTF-8 decode has replacement chars$contextInfo, trying GBK fallback');
      }
    } catch (e) {
      final contextInfo = context != null ? ' [$context]' : '';
      Loggers.app.warning('UTF-8 decode failed$contextInfo: $e');
    }

    // For Windows or when UTF-8 has replacement chars, try GBK
    try {
      return gbk.decode(bytes);
    } catch (e) {
      final contextInfo = context != null ? ' [$context]' : '';
      Loggers.app.warning('GBK decode failed$contextInfo: $e');
      // Return empty string if all decoding attempts fail
      return '';
    }
  }

  /// Encodes string to bytes for SSH command input
  ///
  /// Uses GBK for Windows, UTF-8 for others
  static List<int> encode(String text, {bool isWindows = false}) {
    if (isWindows) {
      try {
        return gbk.encode(text);
      } catch (e) {
        Loggers.app.warning('GBK encode failed: $e, falling back to UTF-8');
        return utf8.encode(text);
      }
    }
    return utf8.encode(text);
  }
}
