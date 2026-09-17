import 'package:drift/native.dart';
import 'package:server_box/data/store/db.dart';
import 'package:sqlite3/sqlite3.dart';

/// Creates the entity schema on [db] by opening a Drift database over it.
///
/// The DDL lives in Drift, but a migration and a test both need the tables to
/// exist on a raw handle before any Drift object has been built over it. This
/// is that seam: open, let `onCreate` run, and hand the connection back.
Future<void> createTables(Database db) async {
  if (!identical(_over, db)) {
    // One live `AppDb` at a time. Two over the same connection is what Drift
    // warns about, and a test suite that opens a database per test would
    // otherwise leave one behind for each.
    //
    await closeTables();
    // `closeUnderlyingOnClose: false`: the handle belongs to `SqliteDb`, which
    // opened it, applied the cipher pragmas and will close it.
    _appDb = AppDb(NativeDatabase.opened(db, closeUnderlyingOnClose: false));
    _over = db;
  }
  // Nothing exists until the executor opens, and opening is what runs
  // `onCreate`. Idempotent after that: Drift records its own version in
  // `user_version` and `createAll` is `IF NOT EXISTS` regardless.
  await _appDb!.customStatement('SELECT 1;');
}

/// Closes the Drift wrapper without closing the raw SQLite handle it borrows.
///
/// This must run before `SqliteDb.close()`: the wrapper was created with
/// `closeUnderlyingOnClose: false`, so each layer remains responsible for its
/// own resource and Drift can finish its pending work before the handle goes.
Future<void> closeTables() async {
  final appDb = _appDb;
  _appDb = null;
  _over = null;
  await appDb?.close();
}

AppDb? _appDb;
Database? _over;
