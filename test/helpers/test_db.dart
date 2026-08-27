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
  await closeTables();
  SqliteDb.openInMemory();
  SqliteDb.instance.execute('PRAGMA foreign_keys = ON;');
  await createTables(SqliteDb.instance);
}

Future<void> closeTestDb() async {
  // SqliteStore writes its per-key timestamp through a serialized microtask
  // queue. Let that queue drain before closing the shared handle; otherwise a
  // teardown immediately after several synchronous writes can make the last
  // timestamp update run against the next test's database, or against none.
  await Future<void>.delayed(Duration.zero);
  await closeTables();
  await SqliteDb.close();
}
