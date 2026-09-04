import 'package:fl_lib/fl_lib.dart';
import 'package:server_box/data/store/schema.dart';

/// Adds the two columns holding the coordinate a user typed for a server.
///
/// Two columns rather than one, because that is what SQLite has to offer; the
/// pair is made whole on the way out, in `ServerStore._customOf`, which
/// answers null unless both are present and in range. No CHECK constraint
/// states that range here on purpose — a restore carrying a value this build
/// would refuse must cost the coordinate, not the server it is attached to.
///
/// An `ALTER TABLE`, unlike `m017`. That step had to rebuild `server` because
/// it changed a table *constraint*, which SQLite cannot replace in place;
/// adding a column touches no constraint and so needs none of it.
///
/// Each statement is guarded, so the step is safe to run again after a process
/// stops partway — the version is recorded only once every statement has run,
/// so a stop between the two means both run again.
class ServerGeoMigration implements SchemaMigration {
  const ServerGeoMigration();

  @override
  int get from => 18;

  @override
  Future<void> apply() async {
    final db = SqliteDb.instance;

    final columns = db
        .select('PRAGMA table_info(server);')
        .map((row) => row['name'] as String)
        .toSet();
    const additions = {'geo_lat': 'REAL', 'geo_lon': 'REAL'};
    for (final MapEntry(key: column, value: type) in additions.entries) {
      if (columns.contains(column)) continue;
      db.execute('ALTER TABLE server ADD COLUMN $column $type;');
    }
  }
}
