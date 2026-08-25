import 'package:fl_lib/fl_lib.dart';
import 'package:server_box/data/store/schema.dart';
import 'package:server_box/data/store/setting.dart';
import 'package:sqlite3/sqlite3.dart';

/// Puts the trusted host keys back where the app reads them.
///
/// [KvToTablesMigration] moved `sshKnownHostFingerprints` into the `known_host`
/// table and deleted the setting. Nothing outside that migration ever read the
/// table — `persistHostKeyFingerprint`, `forgetHostKey` and the known-hosts
/// page all go through the setting — so on the installs that ran it, every host
/// key the user had accepted disappeared and every server asked to be verified
/// again. That step no longer moves them; this one recovers the installs it
/// already moved.
///
/// Merged rather than overwritten: a device that has been running since then
/// has re-accepted some of those hosts, and what it holds now is what the user
/// answered most recently. Only a `serverId::keyType` the setting has nothing
/// for is filled in.
///
/// Idempotent, and cheap on the installs with nothing to do — the table is
/// empty on a fresh install and on one that migrated after the step stopped
/// filling it.
///
/// TODO: delete this step and the `known_host` table together, once no install
/// can still be carrying rows in it.
class KnownHostsToSettingsMigration implements SchemaMigration {
  const KnownHostsToSettingsMigration({SettingStore? store}) : _store = store;

  /// Which store to convert. Null is the app's own; a test hands in a
  /// `forTest` one, since the singleton is bound to the real store name and an
  /// in-memory database has no rows under it.
  final SettingStore? _store;

  static const appliedAt = 12;

  @override
  int get from => appliedAt;

  static const key = 'sshKnownHostFingerprints';

  Database get _db => SqliteDb.instance;

  @override
  Future<void> apply() async {
    final store = _store ?? SettingStore.instance;

    final rows = _db.select(
      'SELECT server_id, key_type, fingerprint FROM known_host;',
    );
    if (rows.isEmpty) return;

    final known = Map<String, String>.from(store.sshKnownHostFingerprints.get());
    var added = 0;
    for (final row in rows) {
      final storageKey =
          '${row['server_id'] as String}::${row['key_type'] as String}';
      if (known.containsKey(storageKey)) continue;
      known[storageKey] = row['fingerprint'] as String;
      added++;
    }
    if (added == 0) return;

    // `updateLastUpdateTsOnSet: false`: recovering what this device already
    // trusted is not an edit the user made, and counting it as one would have
    // every upgrading install claim the newer copy of every setting.
    //
    // `set` answers false rather than throwing, and this step has no return
    // value — a quiet failure would let `SchemaVersion.migrate` record the
    // version and never come back, leaving the fingerprints in the table.
    final ok = store.set(key, known, updateLastUpdateTsOnSet: false);
    if (!ok) throw StateError('m012: writing "$key" failed');
    Loggers.app.info('m012: recovered $added trusted host keys');
  }
}
