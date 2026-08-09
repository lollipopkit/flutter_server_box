import 'package:fl_lib/fl_lib.dart';
import 'package:server_box/data/model/server/server_private_info.dart';
import 'package:server_box/data/store/schema.dart';
import 'package:server_box/data/store/server.dart';

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
    final servers = <Spi>[];

    for (final key in store.box.keys) {
      if (key is! String) continue;
      try {
        final spi = store.get<Spi>(key);
        if (spi != null) servers.add(spi);
      } catch (e, s) {
        // One unreadable record must not block the rest: leaving the whole
        // store on v2 would mean every launch retries and fails the same way
        Loggers.app.warning('Skipping unreadable server record "$key"', e, s);
      }
    }

    for (final spi in servers) {
      store.put(spi);
    }

    Loggers.app.info('Nested SSH credentials for ${servers.length} servers');
  }
}
