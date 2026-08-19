import 'package:fl_lib/fl_lib.dart';
import 'package:server_box/data/store/tables.dart';

/// Opens a fresh in-memory database with the entity schema on it.
///
/// What `Stores.init` does for the app, minus everything that needs a
/// Flutter binding. A test that writes through a store needs the tables, the
/// foreign keys — which are per connection, so a pragma set anywhere else
/// would not apply here — and no file on disk: a real file write started in a
/// `testWidgets` fake-async zone completes on a callback that zone never
/// pumps, which is how one such test hung a whole run.
Future<void> openTestDb() async {
  // The previous test closed its handle directly, so the cached `AppDb` from
  // that connection has to go with it.
  resetTables();
  SqliteDb.openInMemory();
  SqliteDb.instance.execute('PRAGMA foreign_keys = ON;');
  await createTables(SqliteDb.instance);
}
