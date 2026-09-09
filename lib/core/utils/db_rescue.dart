import 'dart:io';

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
  /// Writes a copy of the live database to [outPath].
  ///
  /// [password] null gives a plain SQLite file that any tool opens, and any
  /// tool can therefore read the private keys and server passwords in it.
  /// Non-null encrypts the copy, so it takes that password and an sqlite3mc
  /// build to read — and losing the password loses the backup.
  ///
  /// The copy is a *file*, not a `BackupV2` document: this build cannot
  /// serialize records whose shape it does not understand, and a rescue that
  /// silently drops the newer build's data is not a rescue.
  static void exportTo(String outPath, {String? password}) {
    final db = SqliteDb.instance;
    // A leftover from an interrupted attempt would be attached and appended
    // to, leaving a file holding two copies of every table.
    final out = File(outPath);
    if (out.existsSync()) out.deleteSync();

    // `KEY ''` means no encryption in sqlite3mc, which is what makes the plain
    // export plain. No cipher pragma either way: the keyed file records what it
    // was written with, so `PRAGMA key` alone reopens it — which also keeps
    // this from having to know the constant `SqliteDb` keeps to itself.
    db.execute(
      'ATTACH DATABASE ? AS $_alias KEY ?;',
      [outPath, password ?? ''],
    );
    try {
      _copySchemaAndRows(db);
    } finally {
      // Detached even when the copy failed, or the next attempt finds the
      // alias taken and the file locked.
      db.execute('DETACH DATABASE $_alias;');
    }
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
