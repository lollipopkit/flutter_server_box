import 'package:fl_lib/fl_lib.dart';
import 'package:server_box/data/store/schema.dart';

/// Adds `server.monitor_fallback_addr` (`MonitorHttpCredential.fallbackAddr`):
/// null for every existing row, as no build before had one.
///
/// Written by hand: Drift creates tables only for a new database.
/// `m042_monitor_fallback_addr_test.dart` checks the two agree.
class MonitorFallbackAddrMigration extends SchemaMigration {
  const MonitorFallbackAddrMigration();

  @override
  int get from => 42;

  @override
  bool get olderBuildsRead => true;

  @override
  Future<void> apply() async {
    final db = SqliteDb.instance;
    final columns = db
        .select('PRAGMA table_info(server);')
        .map((row) => row['name'] as String)
        .toSet();
    // Guarded: the version is recorded only once every statement has run.
    if (columns.contains('monitor_fallback_addr')) return;
    db.execute('ALTER TABLE server ADD COLUMN monitor_fallback_addr TEXT;');
  }
}
