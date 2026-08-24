import 'package:fl_lib/fl_lib.dart';
import 'package:server_box/data/store/schema.dart';

/// Adds `private_key.comment`: the OpenSSH comment shown at the end of the
/// public key line.
///
/// A column rather than a rewrite of the key. Every key file carries its own
/// comment, inside the part that gets encrypted, so editing that one means
/// opening the key — a passphrase prompt and a rewrite of key material, to
/// change a label. Null here means "whatever the key itself says", which is
/// what every existing row keeps saying without being touched.
///
/// Written by hand rather than left to Drift, which owns the DDL but only for
/// a database being *created*: an install already at v7 has a `private_key`
/// table Drift will not revisit, and `createTables` is `IF NOT EXISTS`
/// throughout. The two must agree — `m007_private_key_comment_test.dart` is
/// what checks it, since `tables_schema_test.dart` only ever sees a freshly
/// created schema and never runs this step.
class PrivateKeyCommentMigration implements SchemaMigration {
  const PrivateKeyCommentMigration();

  @override
  int get from => 7;

  @override
  Future<void> apply() async {
    final db = SqliteDb.instance;
    final columns = db
        .select('PRAGMA table_info(private_key);')
        .map((row) => row['name'] as String)
        .toSet();
    // Guarded, so the step is safe to run again after a process stops partway:
    // the version is recorded only once every statement has run.
    if (columns.contains('comment')) return;
    db.execute('ALTER TABLE private_key ADD COLUMN comment TEXT;');
  }
}
