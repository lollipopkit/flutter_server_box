import 'package:fl_lib/fl_lib.dart';
import 'package:server_box/data/store/schema.dart';

/// Adds the opt-in bit for a monitor credential to use plaintext HTTP.
///
/// The column is nullable because SSH servers have no monitor credential. The
/// check makes the step safe to retry after a process stops between SQLite
/// committing the DDL and [SchemaVersion] recording this migration.
class MonitorInsecureHttpMigration implements SchemaMigration {
  const MonitorInsecureHttpMigration();

  @override
  int get from => 5;

  @override
  Future<void> apply() async {
    final columns = SqliteDb.instance
        .select('PRAGMA table_info(server);')
        .map((row) => row['name'] as String)
        .toSet();
    if (!columns.contains('monitor_allow_insecure')) {
      SqliteDb.instance.execute(
        'ALTER TABLE server ADD COLUMN monitor_allow_insecure INTEGER;',
      );
    }
  }
}
