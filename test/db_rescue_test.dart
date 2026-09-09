/// Getting data off a database this build cannot read.
///
/// The case is a downgrade: a newer build wrote the store, `SchemaVersion`
/// refuses it, and the app has no UI to offer. What makes this hard is that the
/// data worth rescuing is precisely the data this build has no classes for — so
/// most of what follows is about a table the reader has never heard of.
///
/// Against a **real `SqliteDb` file**, not an in-memory one, and that is
/// load-bearing twice over. The copy runs on its own isolate with its own
/// connection, so it has to open what `SqliteDb.open` wrote — including
/// whichever cipher that is, a constant `DbRescue` deliberately does not
/// restate. And `SqliteDb.path` is null for an in-memory database, so the whole
/// path is unreachable from one.
library;

import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:fl_lib/fl_lib.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/core/utils/db_rescue.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqlite3/sqlite3.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tmp;

  setUpAll(() async {
    tmp = await Directory.systemTemp.createTemp('db-rescue-');
    Paths.doc = tmp.path;

    final rng = Random(7);
    FlutterSecureStorage.setMockInitialValues({
      'hivePwd': base64UrlEncode(
        Uint8List.fromList(List<int>.generate(32, (_) => rng.nextInt(256))),
      ),
    });
    SharedPreferences.setMockInitialValues({});
    await PrefStore.shared.init();
  });

  tearDownAll(() {
    if (tmp.existsSync()) tmp.deleteSync(recursive: true);
  });

  late Directory dbDir;

  setUp(() async {
    // A directory per test: `SqliteDb` keeps one handle for the process, so the
    // file has to be new rather than merely reopened between them.
    dbDir = tmp.createTempSync('db-');
    await SqliteDb.open(dbDir.path);
  });

  tearDown(SqliteDb.close);

  /// Rows a newer build would have written: a table with no counterpart in this
  /// one, an index on it, and a blob — the shapes a model-driven backup drops.
  void seedFutureSchema() {
    final db = SqliteDb.instance;
    db.execute('CREATE TABLE plugin_install('
        'id TEXT PRIMARY KEY, name TEXT NOT NULL, payload BLOB);');
    db.execute(
      r"""INSERT INTO plugin_install VALUES ('p1', 'from the future', x'0011ff'), ('p2', 'second', NULL);""",
    );
    db.execute('CREATE UNIQUE INDEX idx_plugin_name ON plugin_install(name);');
  }

  /// A child table that `sqlite_master` lists *before* its parent, with rows in
  /// both.
  ///
  /// Not a contrivance: a create-copy-drop-rename migration moves the table it
  /// rebuilds to the end of `sqlite_master`, and `server` — the parent of six
  /// cascade tables — was rebuilt by m017. A real v23 database on a real iPad
  /// failed exactly here, with `no such table: rescue_out.server`, while every
  /// test then passing had either no foreign keys or no rows.
  void seedChildBeforeParent() {
    final db = SqliteDb.instance;
    db.execute('CREATE TABLE child_thing('
        'id TEXT PRIMARY KEY, '
        'parent TEXT NOT NULL REFERENCES parent_thing(id) ON DELETE CASCADE);');
    db.execute('CREATE TABLE parent_thing(id TEXT PRIMARY KEY);');
    db.execute("INSERT INTO parent_thing VALUES ('p');");
    db.execute("INSERT INTO child_thing VALUES ('c', 'p');");
  }

  String out(String name) => '${dbDir.path}/$name';

  test('the isolate can open what SqliteDb wrote', () async {
    // The whole reason these run against a file. The copy opens the store on a
    // second connection and nothing in `DbRescue` names the cipher — so this
    // fails the moment that stops being something sqlite3mc works out itself.
    seedFutureSchema();

    await DbRescue.exportTo(out('opened.db'));

    final copy = sqlite3.open(out('opened.db'));
    addTearDown(copy.close);
    expect(copy.select('SELECT id FROM plugin_install;').length, 2);
  });

  test('a plain export opens with no key at all', () async {
    seedFutureSchema();

    await DbRescue.exportTo(out('plain.db'));

    final copy = sqlite3.open(out('plain.db'));
    addTearDown(copy.close);
    final rows = copy.select('SELECT id, name FROM plugin_install ORDER BY id;');
    expect(rows.map((r) => r['id']), ['p1', 'p2']);
    expect(rows.first['name'], 'from the future');
  });

  test('including the blobs and the nulls', () async {
    seedFutureSchema();

    await DbRescue.exportTo(out('blob.db'));

    final copy = sqlite3.open(out('blob.db'));
    addTearDown(copy.close);
    final rows = copy.select('SELECT payload FROM plugin_install ORDER BY id;');
    expect(rows.first['payload'], [0x00, 0x11, 0xff]);
    expect(rows.last['payload'], isNull);
  });

  test('and the indexes, so the copy is a database and not a dump', () async {
    seedFutureSchema();

    await DbRescue.exportTo(out('idx.db'));

    final copy = sqlite3.open(out('idx.db'));
    addTearDown(copy.close);
    // Still unique, which a `CREATE INDEX` losing its `UNIQUE` would not be.
    expect(
      () => copy.execute(
        "INSERT INTO plugin_install VALUES ('p3', 'from the future', NULL);",
      ),
      throwsA(isA<SqliteException>()),
    );
  });

  test('the tables this build does know come too', () async {
    SqliteDb.instance.execute(
      r"""INSERT INTO kv (store, key, value, updated_at) VALUES ('setting', 'timeOut', '5', 1);""",
    );

    await DbRescue.exportTo(out('known.db'));

    final copy = sqlite3.open(out('known.db'));
    addTearDown(copy.close);
    expect(
      copy.select("SELECT value FROM kv WHERE key = 'timeOut';").single['value'],
      '5',
    );
  });

  test('rows still only in the WAL are in the copy', () async {
    // The second connection reads the file. `SqliteDb` opens WAL, so without a
    // checkpoint first the newest writes would sit in a log the copy never
    // looked at — a backup missing exactly what the user did last.
    seedFutureSchema();
    SqliteDb.instance.execute(
      "INSERT INTO plugin_install VALUES ('p3', 'written last', NULL);",
    );

    await DbRescue.exportTo(out('wal.db'));

    final copy = sqlite3.open(out('wal.db'));
    addTearDown(copy.close);
    expect(
      copy.select("SELECT name FROM plugin_install WHERE id = 'p3';").length,
      1,
    );
  });

  test('a child listed before its parent still copies', () async {
    seedChildBeforeParent();

    await DbRescue.exportTo(out('fk.db'));

    final copy = sqlite3.open(out('fk.db'));
    addTearDown(copy.close);
    expect(copy.select('SELECT id FROM child_thing;').single['id'], 'c');
    expect(copy.select('SELECT id FROM parent_thing;').single['id'], 'p');
  });

  test('and the copy still declares the foreign key', () async {
    // Off during the copy, not removed from the schema: the DDL comes over
    // verbatim, so the copy enforces what the original did.
    seedChildBeforeParent();

    await DbRescue.exportTo(out('fk2.db'));

    final copy = sqlite3.open(out('fk2.db'));
    addTearDown(copy.close);
    copy.execute('PRAGMA foreign_keys = ON;');
    expect(
      () => copy.execute("INSERT INTO child_thing VALUES ('c2', 'nobody');"),
      throwsA(isA<SqliteException>()),
    );
  });

  test("the app's own connection keeps its foreign keys", () async {
    // The pragma is turned off on the *copy's* connection, which belongs to the
    // isolate and dies with it. Were that ever to move back onto this one,
    // leaving it off would disarm every cascade for the rest of the app's life.
    seedChildBeforeParent();

    await DbRescue.exportTo(out('fk3.db'));

    expect(
      SqliteDb.instance.select('PRAGMA foreign_keys;').single.values.first,
      1,
    );
  });

  test('an index whose name contains "unique" is not made unique', () async {
    // The modifier came from `sql.contains('UNIQUE')`, so `idx_unique_name`
    // read as one — and the copy died on the first duplicate.
    final db = SqliteDb.instance;
    db.execute('CREATE TABLE dupes(name TEXT);');
    db.execute("INSERT INTO dupes VALUES ('same'), ('same');");
    db.execute('CREATE INDEX idx_unique_name ON dupes(name);');

    await DbRescue.exportTo(out('dupes.db'));

    final copy = sqlite3.open(out('dupes.db'));
    addTearDown(copy.close);
    expect(copy.select('SELECT name FROM dupes;').length, 2);
  });

  test('neither kind of generated column takes the export down', () async {
    // `SELECT *` yields both and `INSERT` refuses both, so they have to be left
    // out of the column list — and the copy recreates them from the DDL, so the
    // values come back on their own.
    //
    // Both kinds, because `table_xinfo`'s `hidden` is 2 for VIRTUAL and 3 for
    // STORED, and a first version had those the wrong way round: it excluded
    // STORED, which is what this test used, and let VIRTUAL through. The export
    // died on any table with one.
    final db = SqliteDb.instance;
    db.execute('CREATE TABLE gen('
        'a INTEGER, '
        'v INTEGER GENERATED ALWAYS AS (a * 2) VIRTUAL, '
        's INTEGER GENERATED ALWAYS AS (a * 3) STORED);');
    db.execute('INSERT INTO gen(a) VALUES (7);');

    await DbRescue.exportTo(out('gen.db'));

    final copy = sqlite3.open(out('gen.db'));
    addTearDown(copy.close);
    final row = copy.select('SELECT a, v, s FROM gen;').single;
    expect(row['a'], 7);
    expect(row['v'], 14);
    expect(row['s'], 21);
  });

  test('an object it cannot rewrite is named, not run against the source',
      () async {
    // An unmatched `CREATE` used to fall through unchanged — and the
    // connection's default schema is `main`, so it executed against the
    // database being rescued.
    final db = SqliteDb.instance;
    db.execute('CREATE TABLE src(body TEXT);');
    db.execute("INSERT INTO src VALUES ('x');");
    try {
      db.execute('CREATE VIRTUAL TABLE vt USING fts5(body);');
    } catch (_) {
      return; // fts5 not in this build; the guard is still the point.
    }

    await expectLater(
      DbRescue.exportTo(out('virt.db')),
      throwsA(isA<UnsupportedError>()),
    );
    // And the source is untouched: one virtual table, not two.
    expect(
      db
          .select("SELECT count(*) c FROM sqlite_master WHERE name = 'vt';")
          .single['c'],
      1,
    );
  });

  group('an encrypted export', () {
    test('needs its password, and refuses another', () async {
      seedFutureSchema();

      await DbRescue.exportTo(out('keyed.db'), password: 'correct horse');

      final right = sqlite3.open(out('keyed.db'));
      right.execute("PRAGMA key = 'correct horse';");
      expect(right.select('SELECT id FROM plugin_install;').length, 2);
      right.close();

      final wrong = sqlite3.open(out('keyed.db'));
      wrong.execute("PRAGMA key = 'battery staple';");
      expect(
        () => wrong.select('SELECT id FROM plugin_install;'),
        throwsA(isA<SqliteException>()),
      );
      wrong.close();
    });

    test('and is not readable without one', () async {
      seedFutureSchema();

      await DbRescue.exportTo(out('keyed2.db'), password: 'correct horse');

      final plain = sqlite3.open(out('keyed2.db'));
      addTearDown(plain.close);
      expect(
        () => plain.select('SELECT id FROM plugin_install;'),
        throwsA(isA<SqliteException>()),
      );
    });
  });

  test('exporting twice over the same path does not double the rows', () async {
    // The attach appends into whatever is already there, so a leftover from an
    // interrupted attempt would come back as a second copy of every table.
    seedFutureSchema();

    await DbRescue.exportTo(out('twice.db'));
    await DbRescue.exportTo(out('twice.db'));

    final copy = sqlite3.open(out('twice.db'));
    addTearDown(copy.close);
    expect(copy.select('SELECT id FROM plugin_install;').length, 2);
  });

  test('a failed export leaves nothing behind, and the next one works', () async {
    seedFutureSchema();

    await expectLater(
      DbRescue.exportTo('${dbDir.path}/nope/deep.db'),
      throwsA(anything),
    );

    await DbRescue.exportTo(out('after.db'));
    final copy = sqlite3.open(out('after.db'));
    addTearDown(copy.close);
    expect(copy.select('SELECT id FROM plugin_install;').length, 2);
  });

  test('wiping takes the database and its sidecars', () async {
    seedFutureSchema();
    final path = SqliteDb.path!;
    expect(File(path).existsSync(), isTrue);

    await DbRescue.wipe();

    for (final suffix in const ['', '-wal', '-shm', '-journal']) {
      expect(File('$path$suffix').existsSync(), isFalse, reason: suffix);
    }
  });

  test('and the Hive boxes, which would otherwise be imported straight back',
      () async {
    // `HiveImport` decides whether to run from a marker in `setting` — inside
    // the database. Deleting the database alone *arms* it: no marker, boxes
    // full of servers and keys, and the next launch copies them all back in.
    final box = File(Paths.doc.joinPath('server.hive'))
      ..writeAsStringSync('not really a box, but it is what the import looks '
          'for');
    final lock = File(Paths.doc.joinPath('server.lock'))..writeAsStringSync('');

    await DbRescue.wipe();

    expect(box.existsSync(), isFalse);
    expect(lock.existsSync(), isFalse);
  });
}
