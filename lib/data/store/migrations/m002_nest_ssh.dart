import 'package:fl_lib/fl_lib.dart';
import 'package:server_box/data/model/server/server_private_info.dart';
import 'package:server_box/data/store/schema.dart';
import 'package:server_box/data/store/server.dart';
import 'package:server_box/hive/spi_legacy_adapter.dart';

/// v2 -> v3: rewrites every stored server so its SSH fields live under
/// `Spi.ssh` instead of flat on the record.
///
/// The read half is [SpiLegacyAdapter], registered on the old typeId; this
/// step only has to put each record back, which the generated adapter then
/// writes under the current typeId in the current shape.
///
/// Safe to re-run: a record already in the new shape is decoded by the current
/// adapter and written back unchanged. The version is only recorded once the
/// whole pass completes, so a crash part-way means the next launch repeats it.
class SpiNestSshMigration implements SchemaMigration {
  const SpiNestSshMigration();

  @override
  int get from => 2;

  @override
  Future<void> apply() async {
    final store = ServerStore.instance;
    final migrated = <String, Spi>{};

    for (final key in store.box.keys) {
      if (key is! String) continue;
      try {
        // Untyped: a v2 record decodes to LegacySpiV2, a v3 one to Spi
        final raw = store.box.get(key);
        final spi = switch (raw) {
          final LegacySpiV2 legacy => legacy.toSpi(),
          final Spi spi => spi,
          _ => null,
        };
        if (spi != null) migrated[key] = spi;
      } catch (e, s) {
        // One unreadable record must not block the rest: leaving the whole
        // store on v2 would mean every launch retries and fails the same way
        Loggers.app.warning('Skipping unreadable server record "$key"', e, s);
      }
    }

    for (final entry in migrated.entries) {
      // Keyed by the original key, not `spi.id`: records written before 1155
      // are stored under `user@ip:port`, and `ServerStore.migrateIds` rekeys
      // them afterwards
      store.set(entry.key, entry.value);
    }

    Loggers.app.info('Nested SSH credentials for ${migrated.length} servers');
  }
}
