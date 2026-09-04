import 'package:fl_lib/fl_lib.dart';
import 'package:server_box/data/store/schema.dart';

/// Drops the rows the retired geo cache left in `kv`.
///
/// `GeoStore` held where each *host* was, keyed by the host string, and it
/// existed because a lookup used to be a network request for one shard per /8.
/// It is gone: the whole dataset is downloaded once and a lookup is a handful
/// of reads from a file this device already holds open, so a row read and a
/// JSON decode in front of it cost more than the answer they stood in for.
///
/// **The rows have to go rather than being left to rot.** Nothing reads them
/// once `Stores.geo` is gone, so they are invisible — and they are the only
/// place this app kept a *derived* record of where a user's servers are. An
/// install that has been placing servers for months carries one row per host,
/// which is a list of the addresses that install connects to, sitting in the
/// database for no reason at all. It is also the shape of thing a backup
/// carries without anyone deciding it should.
///
/// A `DELETE` and nothing else. There is no table to drop — `setting` and
/// `history` share `kv` and are still there — and no data to carry forward,
/// since every value in these rows is recomputed on the next lookup from the
/// installed month's data, which is where the answer should have been coming
/// from all along.
///
/// Idempotent by construction: a second run deletes nothing.
class DropGeoCacheMigration implements SchemaMigration {
  const DropGeoCacheMigration();

  @override
  int get from => 19;

  @override
  Future<void> apply() async {
    SqliteDb.instance.execute("DELETE FROM kv WHERE store = 'geo';");
  }
}
