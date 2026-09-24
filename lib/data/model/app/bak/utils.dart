import 'dart:convert';

import 'package:fl_lib/fl_lib.dart';
import 'package:server_box/data/model/app/bak/backup.dart';
import 'package:server_box/data/model/app/bak/backup2.dart';
import 'package:server_box/data/store/schema.dart';

abstract final class MergeableUtils {
  /// Full backups and encrypted envelopes use the restore flow, including keys.
  static bool isBackup(String text) {
    if (Cryptor.isEncrypted(text)) return true;
    final value = jsonDecode(text);
    return (value is Map &&
            value.containsKey('version') &&
            value.containsKey('spis')) ||
        (value is List && value.isNotEmpty && value.every((e) => e is int));
  }

  /// Picks a reader by trying the current format first and falling back to v1.
  ///
  /// A file from a *newer* build is not a fallback case: the v1 reader would
  /// happily decode part of it and drop the rest. That signal is rethrown so
  /// callers can report it instead of restoring a mangled copy.
  static (Mergeable, String) fromJsonString(String json, [String? password]) {
    try {
      final bak = BackupV2.fromJsonString(json, password);
      return (bak, DateTime.fromMillisecondsSinceEpoch(bak.date).hms());
    } on SchemaTooNewException {
      rethrow;
    } catch (_) {
      // Only legacy array-based backups belong to the v1 reader. Preserve
      // decryption and validation errors from current backups.
      if (Cryptor.isEncrypted(json)) rethrow;
      final value = jsonDecode(json);
      final Backup bak;
      if (value is Map<String, dynamic> && value['spis'] is List) {
        bak = Backup.fromJson(value);
      } else if (value is List && value.every((e) => e is int)) {
        bak = Backup.fromJsonString(json);
      } else {
        rethrow;
      }
      return (bak, bak.date);
    }
  }
}
