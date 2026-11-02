import 'dart:convert';

import 'package:fl_lib/fl_lib.dart';
import 'package:server_box/data/model/app/bak/backup.dart';
import 'package:server_box/data/model/app/bak/backup2.dart';
import 'package:server_box/data/store/schema.dart';

abstract final class MergeableUtils {
  /// Full backups and encrypted envelopes use the restore flow, including keys.
  static bool isBackup(String text) {
    if (AgeCryptor.isEncryptedText(text)) return true;
    final value = jsonDecode(text);
    return (value is Map &&
            value.containsKey('version') &&
            value.containsKey('spis')) ||
        (value is List && value.isNotEmpty && value.every((e) => e is int));
  }

  /// Picks a reader for [plain] (`BackupV2.unlock`'s) by trying the current
  /// format first and falling back to v1.
  ///
  /// A file from a *newer* build is not a fallback case: the v1 reader would
  /// happily decode part of it and drop the rest. That signal is rethrown so
  /// callers can report it instead of restoring a mangled copy.
  static (Mergeable, String) fromBytes(List<int> plain) {
    try {
      final bak = BackupV2.fromPlainBytes(plain);
      return (bak, DateTime.fromMillisecondsSinceEpoch(bak.date).hms());
    } on SchemaTooNewException {
      rethrow;
    } catch (_) {
      // Only legacy array-based backups belong to the v1 reader, and those
      // are text. Preserve validation errors from current backups.
      final json = _text(plain);
      if (json == null) rethrow;
      final value = jsonDecode(json);
      final Backup bak;
      if (value is Map<String, dynamic> &&
          value['spis'] is List &&
          value['version'] is num &&
          (value['version'] as num) < BackupV2.formatVer) {
        bak = Backup.fromJson(value);
      } else if (value is List && value.every((e) => e is int)) {
        bak = Backup.fromJsonString(json);
      } else {
        rethrow;
      }
      return (bak, bak.date);
    }
  }

  /// [fromBytes] for text that is not encrypted.
  static (Mergeable, String) fromJsonString(String json) =>
      fromBytes(utf8.encode(json));

  static String? _text(List<int> bytes) {
    try {
      return utf8.decode(bytes);
    } on FormatException {
      return null;
    }
  }
}
