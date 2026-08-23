import 'package:fl_lib/fl_lib.dart';
import 'package:server_box/data/store/schema.dart';

/// Adds the columns a server's BMC is stored in.
///
/// All four are nullable and none has a default: a BMC is something a server
/// may have, most do not, and `ServerStore` reads `bmc_addr` being null as
/// "none configured".
///
/// Each column is checked before it is added, so the step is safe to retry
/// after a process stops between SQLite committing one `ALTER TABLE` and
/// [SchemaVersion] recording the migration — the same reason
/// `MonitorInsecureHttpMigration` does it, and more relevant here because
/// there are four statements rather than one and a stop between them is a
/// state the plain form cannot recover from.
class BmcColumnsMigration implements SchemaMigration {
  const BmcColumnsMigration();

  @override
  int get from => 6;

  @override
  Future<void> apply() async {
    final columns = SqliteDb.instance
        .select('PRAGMA table_info(server);')
        .map((row) => row['name'] as String)
        .toSet();
    for (final column in const [
      'bmc_addr',
      'bmc_user',
      'bmc_pwd',
      'bmc_cert_sha256',
    ]) {
      if (columns.contains(column)) continue;
      SqliteDb.instance.execute(
        'ALTER TABLE server ADD COLUMN $column TEXT;',
      );
    }
  }
}
