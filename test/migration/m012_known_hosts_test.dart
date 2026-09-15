/// The trusted host keys, put back where the app reads them.
///
/// `KvToTablesMigration` used to move them into the `known_host` table and
/// delete the setting — and nothing outside that migration ever read the table,
/// so every install that ran it lost every host key it had accepted and was
/// asked to verify each server again. That step keeps them a setting now; this
/// one recovers the installs it already moved.
library;

import 'package:fl_lib/fl_lib.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/data/store/migrations/m012_known_hosts_to_settings.dart';
import 'package:server_box/data/store/schema.dart';
import 'package:server_box/data/store/setting.dart';
import 'package:server_box/data/store/tables.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SettingStore store;
  late KnownHostsToSettingsMigration migration;

  setUp(() async {
    SqliteDb.openInMemory();
    // `known_host` hangs off `server`, so the whole schema has to exist and
    // the foreign key has to be on for the insert below to be rejected the way
    // the real one would be.
    SqliteDb.instance.execute('PRAGMA foreign_keys = ON;');
    await createTables(SqliteDb.instance);
    store = SettingStore('setting_test');
    migration = KnownHostsToSettingsMigration(store: store);
  });

  tearDown(SqliteDb.close);

  void seedServer(String id) => SqliteDb.instance.execute(
    'INSERT INTO server (id, name, ssh_ip, ssh_port, ssh_user, ssh_pwd, '
    "updated_at, rev) VALUES (?, ?, '10.0.0.1', 22, 'root', 'x', 0, 0);",
    [id, id],
  );

  void seedRow(String serverId, String keyType, String fingerprint) =>
      SqliteDb.instance.execute('INSERT INTO known_host VALUES (?, ?, ?);', [
        serverId,
        keyType,
        fingerprint,
      ]);

  test('it is the step that follows the one before it', () {
    expect(migration.from, 12);
    expect(SchemaVersion.current, greaterThan(migration.from));
  });

  test('a row with nothing for it in the setting is recovered', () async {
    seedServer('srv-1');
    seedRow('srv-1', 'ssh-ed25519', 'SHA256:AAAA');

    await migration.apply();

    expect(store.sshKnownHostFingerprints.get(), {
      'srv-1::ssh-ed25519': 'SHA256:AAAA',
    });
  });

  test('what the user has since answered is not overwritten', () async {
    // The device has been running on the version that lost them, so the host
    // was re-verified and this is the answer that was given most recently.
    seedServer('srv-1');
    seedRow('srv-1', 'ssh-ed25519', 'SHA256:OLD');
    store.sshKnownHostFingerprints.put({'srv-1::ssh-ed25519': 'SHA256:NEW'});

    await migration.apply();

    expect(store.sshKnownHostFingerprints.get(), {
      'srv-1::ssh-ed25519': 'SHA256:NEW',
    });
  });

  test('an empty table leaves the setting exactly as it was', () async {
    store.sshKnownHostFingerprints.put({'srv-1::ssh-rsa': 'SHA256:BBBB'});
    final before = store.lastUpdateTs;

    await migration.apply();

    expect(store.sshKnownHostFingerprints.get(), {
      'srv-1::ssh-rsa': 'SHA256:BBBB',
    });
    expect(store.lastUpdateTs, before, reason: 'nothing was written');
  });

  /// A second pass is what a process stopped between `apply` and the version
  /// being recorded comes back to.
  test('running it again changes nothing', () async {
    seedServer('srv-1');
    seedRow('srv-1', 'ssh-ed25519', 'SHA256:AAAA');
    await migration.apply();
    final after = store.sshKnownHostFingerprints.get();

    await migration.apply();

    expect(store.sshKnownHostFingerprints.get(), after);
  });

  test('recovering is not counted as an edit the user made', () async {
    // Otherwise every upgrading install claims the newer copy of every
    // setting at the next sync.
    seedServer('srv-1');
    seedRow('srv-1', 'ssh-ed25519', 'SHA256:AAAA');
    final before = store.lastUpdateTs;

    await migration.apply();

    expect(store.lastUpdateTs, before);
  });
}
