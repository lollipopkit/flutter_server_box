import 'package:fl_lib/fl_lib.dart';
import 'package:server_box/data/model/app/bak/backup.dart';
import 'package:server_box/data/model/app/bak/backup2.dart';
import 'package:server_box/data/store/schema.dart';

abstract final class MergeableUtils {
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
    } catch (e) {
      final bak = Backup.fromJsonString(json);
      return (bak, bak.date);
    }
  }
}
