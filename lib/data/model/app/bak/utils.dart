import 'package:fl_lib/fl_lib.dart';
import 'package:server_box/data/model/app/bak/backup.dart';
import 'package:server_box/data/model/app/bak/backup2.dart';

abstract final class MergeableUtils {
  static (Mergeable, String) fromJsonString(String json, [String? password]) {
    try {
      final bak = BackupV2.fromJsonString(json, password);
      return (bak, DateTime.fromMillisecondsSinceEpoch(bak.date).hms());
    } catch (e) {
      final bak = Backup.fromJsonString(json);
      return (bak, bak.date);
    }
  }
}
