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
