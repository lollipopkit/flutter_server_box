import 'package:fl_lib/fl_lib.dart';
import 'package:server_box/data/store/schema.dart';

/// Deletes the terminal and file tabs' saved sessions.
///
/// Both tabs reopened what was open when the app last went away; a cold
/// start now begins with none, so nothing reads `sshTabs` or `fileTabs`.
///
/// Idempotent by construction: a second run deletes nothing.
class DropTabSessionsMigration implements SchemaMigration {
  const DropTabSessionsMigration();

  @override
  int get from => 37;

  @override
  Future<void> apply() async {
    SqliteDb.instance.execute(
      "DELETE FROM kv WHERE store = 'history' "
      "AND key IN ('sshTabs', 'fileTabs');",
    );
  }
}
