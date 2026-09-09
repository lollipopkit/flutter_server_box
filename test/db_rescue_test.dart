/// Getting data off a database this build cannot read.
///
/// The case is a downgrade: a newer build wrote the store, `SchemaVersion`
/// refuses it, and the app has no UI to offer. What makes this hard is that the
/// data worth rescuing is precisely the data this build has no classes for — so
/// every assertion below is about a table the reader has never heard of.
library;

import 'dart:io';

import 'package:fl_lib/fl_lib.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/core/utils/db_rescue.dart';
import 'package:sqlite3/sqlite3.dart';

import 'helpers/test_db.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tmp;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('db-rescue-');
    await openTestDb();
  });

  tearDown(() async {
    await closeTestDb();
    if (tmp.existsSync()) tmp.deleteSync(recursive: true);
  });

  /// Rows a newer build would have written: a table with no counterpart in this
  /// one, an index on it, and a blob — the shapes a model-driven backup drops.
  void seedFutureSchema() {
    final db = SqliteDb.instance;
    db.execute('CREATE TABLE plugin_install('
        'id TEXT PRIMARY KEY, name TEXT NOT NULL, payload BLOB);');
    db.execute(r"""INSERT INTO plugin_install VALUES ('p1', 'from the future', x'0011ff'), ('p2', 'second', NULL);""");
    db.execute('CREATE UNIQUE INDEX idx_plugin_name ON plugin_install(name);');
  }

  /// A child table that `sqlite_master` lists *before* its parent, with rows in
  /// both.
  ///
  /// Which is not a contrivance: a create-copy-drop-rename migration moves the
  /// table it rebuilds to the end of `sqlite_master`, and `server` — the parent
  /// of six cascade tables — was rebuilt by m017. A real v23 database on a real
  /// iPad failed exactly here, with `no such table: rescue_out.server`, while
  /// every test above passed: the invented tables had no foreign keys, and the
  /// real ones had no rows.
  void seedChildBeforeParent() {
    final db = SqliteDb.instance;
    db.execute('CREATE TABLE child_thing('
        'id TEXT PRIMARY KEY, '
        'parent TEXT NOT NULL REFERENCES parent_thing(id) ON DELETE CASCADE);');
    db.execute('CREATE TABLE parent_thing(id TEXT PRIMARY KEY);');
    db.execute("INSERT INTO parent_thing VALUES ('p');");
    db.execute("INSERT INTO child_thing VALUES ('c', 'p');");
  }

  String out(String name) => '${tmp.path}/$name';

  test('a child listed before its parent still copies', () {
    seedChildBeforeParent();
    final path = out('fk.db');

    expect(() => DbRescue.exportTo(path), returnsNormally);

    final copy = sqlite3.open(path);
    addTearDown(copy.close);
    expect(copy.select('SELECT id FROM child_thing;').single['id'], 'c');
    expect(copy.select('SELECT id FROM parent_thing;').single['id'], 'p');
  });

  test('and the copy still declares the foreign key', () {
    // Off during the copy, not removed from the schema: the DDL comes over
    // verbatim, so the copy enforces what the original did.
    seedChildBeforeParent();
    final path = out('fk2.db');

    DbRescue.exportTo(path);

    final copy = sqlite3.open(path);
    addTearDown(copy.close);
    copy.execute('PRAGMA foreign_keys = ON;');
    expect(
      () => copy.execute("INSERT INTO child_thing VALUES ('c2', 'nobody');"),
      throwsA(isA<SqliteException>()),
    );
  });

  test('foreign keys are back on afterwards', () {
    // Left off, every cascade on this connection is disarmed for the rest of
    // its life — and this connection is the app's.
    seedChildBeforeParent();
    DbRescue.exportTo(out('fk3.db'));

    expect(
      SqliteDb.instance.select('PRAGMA foreign_keys;').single.values.first,
      1,
    );
  });

  test('and back on even when the copy fails', () {
    seedChildBeforeParent();
    try {
      DbRescue.exportTo('${tmp.path}/nope/deep.db');
    } catch (_) {}

    expect(
      SqliteDb.instance.select('PRAGMA foreign_keys;').single.values.first,
      1,
    );
  });

  test('a plain export opens with no key at all', () {
    seedFutureSchema();
    final path = out('plain.db');

    DbRescue.exportTo(path);

    final copy = sqlite3.open(path);
    addTearDown(copy.close);
    final rows = copy.select('SELECT id, name FROM plugin_install ORDER BY id;');
    expect(rows.map((r) => r['id']), ['p1', 'p2']);
    expect(rows.first['name'], 'from the future');
  });

  test('including the blobs and the nulls', () {
    seedFutureSchema();
    final path = out('plain2.db');

    DbRescue.exportTo(path);

    final copy = sqlite3.open(path);
    addTearDown(copy.close);
    final rows = copy.select('SELECT payload FROM plugin_install ORDER BY id;');
    expect(rows.first['payload'], [0x00, 0x11, 0xff]);
    expect(rows.last['payload'], isNull);
  });

  test('and the indexes, so the copy is a database and not a dump', () {
    seedFutureSchema();
    final path = out('idx.db');

    DbRescue.exportTo(path);

    final copy = sqlite3.open(path);
    addTearDown(copy.close);
    expect(
      copy
          .select("SELECT name FROM sqlite_master WHERE type = 'index' "
              "AND name = 'idx_plugin_name';")
          .length,
      1,
    );
    // Still unique, which a `CREATE INDEX` losing its `UNIQUE` would not be.
    expect(
      () => copy.execute(
        "INSERT INTO plugin_install VALUES ('p3', 'from the future', NULL);",
      ),
      throwsA(isA<SqliteException>()),
    );
  });

  test('the tables this build does know come too', () {
    // `openTestDb` created the real schema, so this is the ordinary half.
    final path = out('known.db');
    SqliteDb.instance.execute(
      r"""INSERT INTO kv (store, key, value, updated_at) VALUES ('setting', 'timeOut', '5', 1);""",
    );

    DbRescue.exportTo(path);

    final copy = sqlite3.open(path);
    addTearDown(copy.close);
    expect(
      copy.select("SELECT value FROM kv WHERE key = 'timeOut';").single['value'],
      '5',
    );
  });

  group('an encrypted export', () {
    test('needs its password, and refuses another', () {
      seedFutureSchema();
      final path = out('keyed.db');

      DbRescue.exportTo(path, password: 'correct horse');

      final right = sqlite3.open(path);
      right.execute("PRAGMA key = 'correct horse';");
      expect(
        right.select('SELECT id FROM plugin_install;').length,
        2,
      );
      right.close();

      final wrong = sqlite3.open(path);
      wrong.execute("PRAGMA key = 'battery staple';");
      expect(
        () => wrong.select('SELECT id FROM plugin_install;'),
        throwsA(isA<SqliteException>()),
      );
      wrong.close();
    });

    test('and is not readable without one', () {
      seedFutureSchema();
      final path = out('keyed2.db');

      DbRescue.exportTo(path, password: 'correct horse');

      final plain = sqlite3.open(path);
      addTearDown(plain.close);
      expect(
        () => plain.select('SELECT id FROM plugin_install;'),
        throwsA(isA<SqliteException>()),
      );
    });
  });

  test('exporting twice over the same path does not double the rows', () {
    // The attach appends into whatever is already there, so a leftover from an
    // interrupted attempt would come back as a second copy of every table.
    seedFutureSchema();
    final path = out('twice.db');

    DbRescue.exportTo(path);
    DbRescue.exportTo(path);

    final copy = sqlite3.open(path);
    addTearDown(copy.close);
    expect(copy.select('SELECT id FROM plugin_install;').length, 2);
  });

  test('a failed export still detaches', () {
    // Otherwise the alias stays taken and every later attempt fails with
    // something that says nothing about the first failure.
    seedFutureSchema();
    // A directory that does not exist: the attach itself is fine, the copy is
    // not reached, and what matters is that the next call works.
    try {
      DbRescue.exportTo('${tmp.path}/nope/deep.db');
    } catch (_) {}

    final path = out('after.db');
    expect(() => DbRescue.exportTo(path), returnsNormally);
    final copy = sqlite3.open(path);
    addTearDown(copy.close);
    expect(copy.select('SELECT id FROM plugin_install;').length, 2);
  });
}
