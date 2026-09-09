import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:fl_lib/fl_lib.dart';
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
    // to, leaving a file holding two copies of every table.
    final out = File(outPath);
    if (out.existsSync()) out.deleteSync();

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
      if (out.existsSync()) out.deleteSync();
      rethrow;
    }
  }

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

      // `CREATE TABLE x (...)` -> `CREATE TABLE rescue_out.x (...)`. Only the
      // leading keyword is touched; the body, including any `IF NOT EXISTS`
      // that followed it, is the newer build's and is copied verbatim.
      final qualified = sql.replaceFirst(
        RegExp(
          r'^\s*CREATE\s+(TEMP\s+|TEMPORARY\s+)?(UNIQUE\s+)?'
          r'(TABLE|INDEX|VIEW|TRIGGER)\s+(IF\s+NOT\s+EXISTS\s+)?',
          caseSensitive: false,
        ),
        'CREATE ${type == 'index' && sql.toUpperCase().contains('UNIQUE') ? 'UNIQUE ' : ''}'
            '${type.toUpperCase()} $_alias.',
      );
      db.execute(qualified);

      if (type == 'table') {
        db.execute(
          'INSERT INTO $_alias."$name" SELECT * FROM main."$name";',
        );
      }
    }
  }

  /// Deletes the database file, so the next launch starts empty.
  ///
  /// The file only. The encryption key stays in the keychain — it is per
  /// install, not per database, and a new file is keyed with it just the same —
  /// and so do the logs, which are the only record of why this was needed.
  ///
  /// The connection is closed first: unlinking a file out from under a live
  /// handle is undefined at best, and on Windows the delete fails outright.
  /// Every sidecar goes too, or SQLite reopens a `-wal` holding pages for a
  /// database that is no longer there.
  static Future<void> wipe() async {
    final path = SqliteDb.path;
    await closeTables();
    await SqliteDb.close();
    if (path == null) return;
    for (final suffix in const ['', '-wal', '-shm', '-journal']) {
      final f = File('$path$suffix');
      if (f.existsSync()) f.deleteSync();
    }
  }
}
