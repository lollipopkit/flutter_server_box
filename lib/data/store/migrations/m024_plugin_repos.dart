import 'package:fl_lib/fl_lib.dart';
import 'package:server_box/data/store/schema.dart';

/// Where plugins may be installed from.
///
/// One row per repository, keyed by its `index.json` URL — the URL *is* the
/// identity. A name would be nicer to key on and is exactly wrong: the name
/// comes out of the index, so it is chosen by the thing being identified, and
/// two repositories are free to claim the same one.
///
/// The official repository is not seeded here. A row would be a promise that
/// an address exists, and until one is published the honest state is that this
/// app knows no repositories — see the TODO in `PluginRepoStore`.
class PluginReposMigration implements SchemaMigration {
  const PluginReposMigration();

  /// The version this migrates **from**, which is what `SchemaVersion.migrate`
  /// looks a step up by — `current` is then one higher. Numbering it 25 to
  /// match the new version leaves a gap at 24, and the only place that shows
  /// is `Missing schema migration from v24 to v25` at launch on a device that
  /// already had the app.
  static const appliedAt = 24;

  @override
  int get from => appliedAt;

  @override
  Future<void> apply() async {
    SqliteDb.instance.execute('''
CREATE TABLE IF NOT EXISTS plugin_repo (
  url TEXT NOT NULL PRIMARY KEY,
  name TEXT,
  enabled INTEGER NOT NULL DEFAULT 1,
  added_at INTEGER NOT NULL,
  last_fetched_at INTEGER
) WITHOUT ROWID;
''');
  }
}
