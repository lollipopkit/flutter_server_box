import 'package:fl_lib/fl_lib.dart';
import 'package:server_box/data/store/schema.dart';

/// What an update replaced, so it can be put back.
///
/// Installing used to delete the directory and move the new one into place: a
/// version that turned out to be broken was gone, and getting the old one back
/// meant finding a `.sbp` for it. The files of the previous version are now
/// kept beside the installed ones, and this column is the record that went
/// with them.
///
/// **The record, not just the version string.** `granted` is what the user
/// agreed that code may do, and it cannot be recovered from the old
/// directory — re-deriving it from that manifest would grant whatever the
/// version asked for rather than what was consented to.
///
/// An `ALTER TABLE ... ADD COLUMN` rather than a create-copy-drop-rename:
/// `plugin_install` is nobody's parent, the column is nullable, and adding one
/// is the one shape SQLite's `ALTER` does correctly.
class PluginPreviousMigration implements SchemaMigration {
  const PluginPreviousMigration();

  /// The version this migrates **from**; `SchemaVersion.current` is one
  /// higher. See the note in `PluginReposMigration` about the gap.
  static const appliedAt = 25;

  @override
  int get from => appliedAt;

  @override
  Future<void> apply() async {
    final db = SqliteDb.instance;
    // Checked rather than assumed: a fresh install gets the column from
    // `createTables`, and this migration then runs over a table that already
    // has it. `ADD COLUMN` on an existing name is an error, not a no-op.
    final columns = db.select('PRAGMA table_info(plugin_install);');
    final has = columns.any((row) => row['name'] == 'previous');
    if (has) return;
    db.execute('ALTER TABLE plugin_install ADD COLUMN previous TEXT;');
  }
}
