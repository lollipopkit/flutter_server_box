import 'package:fl_lib/fl_lib.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/data/store/migrations/m007_private_key_comment.dart';

/// The step that gives `private_key` somewhere to put a label.
///
/// It gets one pass over a user's records and is not repeatable, so the thing
/// worth asserting is that the keys already there come out of it unchanged —
/// a migration that touched the key column would be a migration that could
/// lose a key.
void main() {
  setUp(SqliteDb.openInMemory);
  tearDown(SqliteDb.close);

  /// The v7 shape: no comment column.
  void createV7PrivateKey() {
    SqliteDb.instance.execute(
      'CREATE TABLE private_key ('
      'id TEXT PRIMARY KEY, name TEXT NOT NULL UNIQUE, key TEXT NOT NULL'
      ') WITHOUT ROWID;',
    );
  }

  List<String> columns() => SqliteDb.instance
      .select('PRAGMA table_info(private_key);')
      .map((column) => column['name'] as String)
      .toList();

  test('adds the column and leaves the keys alone', () async {
    createV7PrivateKey();
    SqliteDb.instance.execute(
      "INSERT INTO private_key VALUES ('k-1', 'laptop', '-----BEGIN X-----');",
    );

    await const PrivateKeyCommentMigration().apply();

    expect(columns(), contains('comment'));
    final row = SqliteDb.instance.select('SELECT * FROM private_key;').single;
    expect(row['id'], 'k-1');
    expect(row['name'], 'laptop');
    expect(row['key'], '-----BEGIN X-----');
    // Null, not the name and not an empty string: null is what means "whatever
    // the key itself says", and an empty string would read as "no comment" and
    // strip the label off every key that had one.
    expect(row['comment'], isNull);
  });

  test('runs again without complaining', () async {
    // The version is recorded only once every statement has run, so a process
    // stopped partway means the whole step runs again.
    createV7PrivateKey();
    await const PrivateKeyCommentMigration().apply();
    await const PrivateKeyCommentMigration().apply();
    expect(columns().where((c) => c == 'comment'), hasLength(1));
  });

  test('a table that already has the column is left as it is', () async {
    SqliteDb.instance.execute(
      'CREATE TABLE private_key ('
      'id TEXT PRIMARY KEY, name TEXT NOT NULL UNIQUE, key TEXT NOT NULL, '
      'comment TEXT'
      ') WITHOUT ROWID;',
    );
    SqliteDb.instance.execute(
      "INSERT INTO private_key VALUES ('k-1', 'laptop', 'pem', 'me@host');",
    );

    await const PrivateKeyCommentMigration().apply();

    expect(
      SqliteDb.instance.select('SELECT comment FROM private_key;').single
          ['comment'],
      'me@host',
      reason: 'a comment already stored must survive the step',
    );
  });
}
