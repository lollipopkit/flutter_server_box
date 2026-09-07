/// A plugin's data through a backup. PLUGINS.md section 7's `plugins` field.
library;

import 'package:fl_lib/fl_lib.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/data/model/plugin/backup.dart';
import 'package:server_box/data/res/store.dart';
import 'package:server_box/data/store/plugin.dart';
import 'package:server_box/data/store/server.dart';

import 'helpers/test_db.dart';

void main() {
  late PluginCfgStore cfg;
  late PluginKvStore kv;

  void addServer(String id) => SqliteDb.instance.execute(
    "INSERT INTO server (id, name, ssh_ip) VALUES ('$id', '$id', '10.0.0.1');",
  );

  setUp(() async {
    await openTestDb();
    getIt.registerSingleton<ServerStore>(ServerStore());
    cfg = PluginCfgStore();
    kv = PluginKvStore();
    addServer('srv-1');
    addServer('srv-2');
  });

  tearDown(() async {
    await getIt.reset();
    await closeTestDb();
  });

  test('everything a plugin stored comes back', () {
    cfg.put('srv-1', 'bmc', {'addr': 'https://10.0.0.9'}, cfgVer: 1);
    kv.put('bmc', 'acct/a', 'one');
    kv.put('bmc', 'token', 'per-server', serverId: 'srv-1');

    final loaded = PluginBackup.load();
    // Cleared the way a restore onto a fresh device finds it.
    SqliteDb.instance.execute('DELETE FROM server_plugin_cfg;');
    SqliteDb.instance.execute('DELETE FROM plugin_kv;');
    SqliteDb.instance.execute('DELETE FROM server_plugin_kv;');

    expect(PluginBackup.restore(loaded), isTrue);

    expect(cfg.fetch('srv-1', 'bmc'), {'addr': 'https://10.0.0.9'});
    expect(kv.fetch('bmc', 'acct/a'), 'one');
    expect(kv.fetch('bmc', 'token', serverId: 'srv-1'), 'per-server');
  });

  /// The same mapping snippets and port forwards go through: a server matched
  /// by name may already be here under a different id.
  test('a server that was renumbered is followed', () {
    cfg.put('srv-1', 'bmc', {'addr': 'x'}, cfgVer: 1);
    kv.put('bmc', 'k', 'v', serverId: 'srv-1');
    final loaded = PluginBackup.load();
    SqliteDb.instance.execute('DELETE FROM server_plugin_cfg;');
    SqliteDb.instance.execute('DELETE FROM server_plugin_kv;');

    PluginBackup.restore(loaded, serverIds: const {'srv-1': 'srv-2'});

    expect(cfg.fetch('srv-2', 'bmc'), {'addr': 'x'});
    expect(kv.fetch('bmc', 'k', serverId: 'srv-2'), 'v');
    expect(cfg.has('srv-1', 'bmc'), isFalse);
  });

  /// Both tables have a foreign key, and a backup can name a server this
  /// device deleted.
  test('an entry for a server that is not here is skipped', () {
    cfg.put('srv-1', 'bmc', {'addr': 'x'}, cfgVer: 1);
    kv.put('bmc', 'k', 'v', serverId: 'srv-1');
    kv.put('bmc', 'global', 'g');
    final loaded = PluginBackup.load();
    SqliteDb.instance.execute("DELETE FROM server WHERE id = 'srv-1';");

    expect(PluginBackup.restore(loaded), isTrue, reason: 'the global one lands');

    expect(kv.fetch('bmc', 'global'), 'g');
    expect(
      SqliteDb.instance.select('SELECT 1 FROM server_plugin_cfg;'),
      isEmpty,
    );
  });

  /// Unlike `container`, a backup is not the complete state of this: the file
  /// may come from a device with a different set of plugins, and deleting what
  /// it does not mention would make restoring an old backup a way to lose a
  /// newer plugin's data.
  test('what the file does not mention is left alone', () {
    kv.put('zfs', 'kept', 'yes');
    kv.put('bmc', 'k', 'old');

    PluginBackup.restore({
      'bmc': {
        'kv': [
          {'server': null, 'key': 'k', 'value': 'new'},
        ],
      },
    });

    expect(kv.fetch('bmc', 'k'), 'new', reason: 'the file wins where they meet');
    expect(kv.fetch('zfs', 'kept'), 'yes');
  });

  test('a malformed entry costs that entry, not the restore', () {
    final changed = PluginBackup.restore({
      'bmc': {
        'kv': [
          'not an entry',
          {'key': 'no value'},
          {'value': 'no key'},
          {'server': null, 'key': 'ok', 'value': 'v'},
        ],
        'cfg': 'not a list',
      },
      '': {'kv': <Object?>[]},
      'x': 'not a map',
    });

    expect(changed, isTrue);
    expect(kv.fetch('bmc', 'ok'), 'v');
    expect(kv.keys('bmc'), ['ok']);
  });

  test('nothing at all is nothing to do', () {
    expect(PluginBackup.restore(null), isFalse);
    expect(PluginBackup.restore(const <String, Object?>{}), isFalse);
    expect(PluginBackup.load(), isEmpty);
  });
}
