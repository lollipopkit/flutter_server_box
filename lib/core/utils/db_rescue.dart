import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:fl_lib/fl_lib.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:server_box/data/store/tables.dart';
import 'package:sqlite3/sqlite3.dart';

/// Getting a user's data out of, or off, a database this build cannot read.
///
/// The one case that needs this is a downgrade: the data was written by a newer
/// build, `SchemaVersion.migrate` refuses it, and the app stops before it has a
/// UI. See `SchemaTooNewPage`, which is the whole of the audience.
///
/// **Nothing here goes through a model.** `BackupV2.loadFromStore` reads the
/// stores with this build's classes, so a table or a column the newer build
/// added is one it does not ask for — the JSON would come out looking complete
/// and be missing exactly the data the newer build stored. Everything below
/// copies at the SQL level, enumerating `sqlite_master`, so a shape this build
/// has never heard of survives.
abstract final class DbRescue {
  /// Writes a copy of the live database to [outPath], off the UI isolate.
  ///
  /// [password] null gives a plain SQLite file that any tool opens, and any
  /// tool can therefore read the private keys and server passwords in it.
  /// Non-null encrypts the copy, so it takes that password and an sqlite3mc
  /// build to read — and losing the password loses the backup.
  ///
  /// The copy is a *file*, not a `BackupV2` document: this build cannot
  /// serialize records whose shape it does not understand, and a rescue that
  /// silently drops the newer build's data is not a rescue.
  ///
  /// On its own isolate with its own connection, because the copy is one
  /// `INSERT ... SELECT` per table and SQLite runs each to completion — there
  /// is no point inside one at which the UI could be let back in. The
  /// database this is worth running on is the large one: fifty benchmark runs
  /// a server, each carrying a log and a result document, is tens of megabytes
  /// to read, decrypt and write, and doing that on the isolate drawing frames
  /// freezes the screen for as long as it takes.
  static Future<void> exportTo(String outPath, {String? password}) async {
    final dbPath = SqliteDb.path;
    if (dbPath == null) {
      throw StateError('The database is not open');
    }

    // The second connection reads the file, and the newest pages may still be
    // in the write-ahead log. SQLite would let it read them, but only through
    // the `-shm` file and only while this connection keeps that consistent —
    // folding them back first makes the copy depend on the file alone.
    SqliteDb.instance.execute('PRAGMA wal_checkpoint(TRUNCATE);');

    // Read here, not there: it comes from the keychain through a platform
    // channel, and a background isolate has no messenger to ask over.
    final keyB64 = await SecureStoreProps.hivePwd.read();
    if (keyB64 == null) {
      throw StateError('No store encryption key');
    }

    // A leftover from an interrupted attempt would be attached and appended
    // to, leaving a file holding two copies of every table. Sidecars included:
    // the attached database is in rollback-journal mode, so a process killed
    // mid-copy leaves `-journal` behind, and SQLite would replay that hot
    // journal into the unrelated file the next attach creates.
    _deleteWithSidecars(outPath);

    try {
      await Isolate.run(
        () => _exportSync(
          dbPath: dbPath,
          keyB64: keyB64,
          outPath: outPath,
          password: password,
        ),
      );
    } catch (_) {
      // A half-written copy is worse than none: it looks like a backup.
      _deleteWithSidecars(outPath);
      rethrow;
    }
  }

  /// Everything SQLite may have made for the database at [path].
  static void _deleteWithSidecars(String path) {
    for (final suffix in _sidecars) {
      final f = File('$path$suffix');
      if (f.existsSync()) f.deleteSync();
    }
  }

  static const _sidecars = ['', '-wal', '-shm', '-journal'];

  /// The copy itself, on a connection of this isolate's own.
  ///
  /// No `PRAGMA cipher`: sqlite3mc reads which one a file was written with, and
  /// leaving it out is what keeps this from restating a constant `SqliteDb`
  /// keeps private — where a copy that drifted would not fail to compile, it
  /// would fail to open a user's database at the one moment they needed it.
  /// `db_rescue_test.dart` opens a real `SqliteDb` file to hold that.
  static void _exportSync({
    required String dbPath,
    required String keyB64,
    required String outPath,
    required String? password,
  }) {
    final db = sqlite3.open(dbPath);
    try {
      db.execute('PRAGMA key = "x\'${_hex(base64Url.decode(keyB64))}\'";');
      // The first statement that reads a page, and so the first that can fail
      // on a wrong key — same reason `SqliteDb.open` does this.
      db.select('SELECT count(*) FROM sqlite_master;');

      // Off across the whole copy, and this is not optional. `sqlite_master` is
      // in creation order, and a create-copy-drop-rename migration moves the
      // table it rebuilds to the *end* — so `server`, the parent of six
      // `ON DELETE CASCADE` tables, comes after its own children. Inserting
      // `server_tag` before `server` exists then fails the foreign key, which is
      // what a real v23 database did on the first device this ran on. Ordering
      // the copy by dependency would be the alternative, and it would have to
      // parse the newer build's DDL to find the dependencies.
      //
      // Outside a transaction, because the pragma is a no-op inside one — and
      // there is no transaction here for that reason.
      //
      // Nothing is lost by it: the source satisfies its own constraints, so a
      // faithful copy does too. They are still declared in the copy, since the
      // DDL comes over verbatim.
      db.execute('PRAGMA foreign_keys = OFF;');

      // `KEY ''` means no encryption in sqlite3mc, which is what makes the
      // plain export plain.
      //
      // An encrypted one names its cipher, and that is not the same decision as
      // the read above. Reading may leave it out because the file says what it
      // was written with; *writing* without it takes whatever sqlite3mc has as
      // its default that month, so a bump could hand a user a backup readable
      // only by a build nobody can identify from the file. fl_lib pins the
      // store's cipher for the same reason. This is a format choice for the
      // exported file, not a restatement of what `SqliteDb` uses — the two can
      // differ without anything breaking.
      //
      // On the connection, before the attach: `PRAGMA <schema>.cipher` needs
      // the schema to exist, and after the attach the file has already been
      // created with a cipher. `main` is open and keyed by now, so changing the
      // default cannot affect reading it.
      if (password != null) {
        db.execute("PRAGMA cipher = '$_exportCipher';");
      }
      db.execute(
        'ATTACH DATABASE ? AS $_alias KEY ?;',
        [outPath, password ?? ''],
      );
      try {
        _copySchemaAndRows(db);
      } finally {
        db.execute('DETACH DATABASE $_alias;');
      }
    } finally {
      // This connection is this isolate's and goes with it, so the pragma does
      // not have to be put back — but the handle does have to be closed, or the
      // file keeps a lock the app's own connection can trip over.
      db.close();
    }
  }

  static String _hex(Uint8List bytes) {
    const digits = '0123456789abcdef';
    final sb = StringBuffer();
    for (final b in bytes) {
      sb.write(digits[(b >> 4) & 0xf]);
      sb.write(digits[b & 0xf]);
    }
    return sb.toString();
  }

  static const _alias = 'rescue_out';

  /// Recreates every object of `main` in the attached database and fills the
  /// tables.
  ///
  /// Driven by `sqlite_master` rather than by a list of known tables, which is
  /// the entire point: the rows worth rescuing are the ones this build has no
  /// name for.
  static void _copySchemaAndRows(Database db) {
    final objects = db.select(
      'SELECT type, name, sql FROM main.sqlite_master '
      "WHERE sql IS NOT NULL AND name NOT LIKE 'sqlite_%' "
      // Tables first: an index or a trigger cannot be created before the thing
      // it is on, and `sqlite_master` is in creation order, not dependency
      // order, once a table has been dropped and remade — which every
      // create-copy-drop-rename migration does.
      "ORDER BY CASE type WHEN 'table' THEN 0 WHEN 'view' THEN 1 ELSE 2 END;",
    );

    for (final o in objects) {
      final type = o['type'] as String;
      final name = o['name'] as String;
      final sql = o['sql'] as String;

      db.execute(_qualify(sql, type));
      if (type == 'table') _copyRows(db, name);
    }
  }

  /// The leading `CREATE ...` of [sql], pointed at the attached database.
  ///
  /// `CREATE TABLE x (...)` -> `CREATE TABLE rescue_out.x (...)`. Only the
  /// keywords before the name are rewritten; the body, including any
  /// `IF NOT EXISTS`, is the newer build's and is carried verbatim.
  ///
  /// The modifiers come from the match, not from reading the text again. A
  /// first version re-derived `UNIQUE` with `sql.contains('UNIQUE')`, which is
  /// true of `CREATE INDEX idx_unique_name ...` — so a plain index was recreated
  /// as a unique one, and the copy died on the first duplicate.
  static String _qualify(String sql, String type) {
    final match = _createRe.firstMatch(sql);
    if (match == null) {
      // Never fall through to executing [sql] unchanged: the connection's
      // default schema is `main`, so an unrecognised statement would run
      // against the database being rescued. `CREATE VIRTUAL TABLE`, which a
      // newer build may well add, is exactly such a statement.
      throw UnsupportedError('Cannot copy an object declared as: $sql');
    }
    // Everything after the match is the object's own name and body.
    final unique = match.group(2) == null ? '' : 'UNIQUE ';
    return 'CREATE $unique${type.toUpperCase()} $_alias.'
        '${sql.substring(match.end)}';
  }

  static final _createRe = RegExp(
    r'^\s*CREATE\s+(TEMP\s+|TEMPORARY\s+)?(UNIQUE\s+)?'
    r'(TABLE|INDEX|VIEW|TRIGGER)\s+(IF\s+NOT\s+EXISTS\s+)?',
    caseSensitive: false,
  );

  /// Copies one table's rows, naming the columns on both sides.
  ///
  /// `SELECT *` would be shorter and is wrong: a generated column is in `*` and
  /// cannot be inserted into, so a table with one would take the whole export
  /// down. `table_xinfo` reports every column with a `hidden` flag — 0 ordinary,
  /// 1 a hidden virtual-table column, 2 a `VIRTUAL` generated one, 3 `STORED`.
  /// **Only 0 is writable.** Both kinds of generated column refuse an `INSERT`,
  /// and the copy recreates them from the DDL anyway, so their values come back
  /// on their own.
  static void _copyRows(Database db, String table) {
    final cols = db
        .select('SELECT name, hidden FROM pragma_table_xinfo(?);', [table])
        .where((r) => r['hidden'] == 0)
        .map((r) => '"${r['name']}"')
        .join(', ');
    if (cols.isEmpty) return;
    db.execute(
      'INSERT INTO $_alias."$table" ($cols) SELECT $cols FROM main."$table";',
    );
  }

  /// The cipher an encrypted export is written with. See [_exportSync].
  static const _exportCipher = 'chacha20';

  /// Deletes the stored data, so the next launch starts empty.
  ///
  /// The database and the Hive boxes. The boxes matter because `HiveImport`
  /// decides whether to run from a marker kept in `setting` — inside the
  /// database — so deleting the database alone *arms* the import: the next
  /// launch finds no marker and boxes full of servers, keys and snippets, and
  /// copies every one of them back in. For somebody wiping to get data off a
  /// device that is the opposite of what the confirmation promised.
  ///
  /// TODO: drop the box sweep with `HiveImport`.
  ///
  /// The encryption key stays in the keychain — it is per install, not per
  /// database, and a new file is keyed with it just the same — and so do the
  /// logs, which are the only record of why this was needed.
  ///
  /// The connection is closed first: unlinking a file out from under a live
  /// handle is undefined at best, and on Windows the delete fails outright.
  /// Every sidecar goes too, or SQLite reopens a `-wal` holding pages for a
  /// database that is no longer there.
  static Future<void> wipe() async {
    final path = SqliteDb.path;
    await closeTables();
    await SqliteDb.close();
    await Hive.close();
    if (path != null) _deleteWithSidecars(path);

    // Everything Hive keeps, wherever it was told to keep it. Matched by
    // extension rather than by a list of box names: a box this build has no
    // name for is one the import would still read.
    final hiveDir = Directory(Paths.doc);
    if (!hiveDir.existsSync()) return;
    for (final f in hiveDir.listSync().whereType<File>()) {
      if (f.path.endsWith('.hive') || f.path.endsWith('.lock')) {
        f.deleteSync();
      }
    }
  }
}
