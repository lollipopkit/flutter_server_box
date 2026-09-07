/// Where an installed plugin's record, its per-server configuration and its
/// own data live. PLUGINS.md section 7.
///
/// The migration group is the part that cannot be checked anywhere else:
/// `tables_schema_test.dart` only ever sees a schema Drift created, and an
/// install already at v22 never reaches that code — so the hand-written DDL
/// and the Drift one have to be compared against each other here.
library;

import 'package:fl_lib/fl_lib.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/data/model/plugin/install.dart';
import 'package:server_box/data/res/store.dart';
import 'package:server_box/data/store/migrations/all.dart';
import 'package:server_box/data/store/migrations/m022_plugin_tables.dart';
import 'package:server_box/data/store/plugin.dart';
import 'package:server_box/data/store/schema.dart';
import 'package:server_box/data/store/server.dart';
import 'package:server_box/data/store/tables.dart';

import 'helpers/test_db.dart';

const _pluginTables = [
  'plugin_install',
  'server_plugin_cfg',
  'plugin_kv',
  'server_plugin_kv',
];

({List<String> columns, String sql}) _schemaOf(String table) {
  final db = SqliteDb.instance;
  final sql =
      db
              .select('SELECT sql FROM sqlite_master WHERE name = ?;', [table])
              .singleOrNull?['sql']
          as String? ??
      '';
  final columns = [
    for (final row in db.select('PRAGMA table_info($table);'))
      row['name'] as String,
  ];
  return (columns: columns, sql: sql);
}

void main() {
  group('the schema step', () {
    setUp(() => SqliteDb.openInMemory());
    tearDown(() async {
      await closeTables();
      await SqliteDb.close();
    });

    // The three edits a schema step is, asserted separately, because two of
    // them are invisible in the step's own test: missing the version bump
    // leaves every install on the old version with a green suite, and missing
    // the registration throws `Missing schema migration from vN` at launch on
    // a user's device.
    test('is registered, and the version was bumped past it', () {
      expect(const PluginTablesMigration().from, 22);
      expect(
        kSchemaMigrations.map((m) => m.from),
        contains(22),
        reason: 'an unregistered step throws at launch, not here',
      );
      expect(SchemaVersion.current, greaterThan(22));
    });

    test('creates tables Drift would have created identically', () async {
      await createTables(SqliteDb.instance);
      final fromDrift = {
        for (final t in _pluginTables) t: _schemaOf(t),
      };
      for (final t in _pluginTables) {
        expect(fromDrift[t]!.columns, isNotEmpty, reason: 'Drift has to make $t');
      }

      for (final t in _pluginTables) {
        SqliteDb.instance.execute('DROP TABLE $t;');
      }
      await const PluginTablesMigration().apply();

      for (final t in _pluginTables) {
        expect(
          _schemaOf(t).columns,
          fromDrift[t]!.columns,
          reason: '$t: the two definitions disagree',
        );
      }
    });

    /// A process stopped between two of the statements comes back to this.
    test('and running it again on the tables it made changes nothing', () async {
      await const PluginTablesMigration().apply();
      final before = {for (final t in _pluginTables) t: _schemaOf(t).sql};

      await const PluginTablesMigration().apply();

      expect({for (final t in _pluginTables) t: _schemaOf(t).sql}, before);
    });

    test('the tables are known but none of them is synced', () async {
      expect(Tables.names, containsAll(_pluginTables));
      // Installing puts files on *this* device. A row arriving on another one
      // would name a plugin that is not there, and `granted` would be consent
      // given on a different device to code this one has never seen.
      for (final t in _pluginTables) {
        expect(Tables.syncRoots, isNot(contains(t)));
      }
    });
  });

  group('the install record', () {
    late PluginInstallStore store;

    setUp(() async {
      await openTestDb();
      store = PluginInstallStore();
    });
    tearDown(closeTestDb);

    PluginInstall zfs({
      String version = '1.0.0',
      String? repo,
      bool enabled = true,
      Set<String> granted = const {'server.exec'},
    }) => PluginInstall(
      id: 'app.serverbox.zfs',
      version: version,
      repo: repo,
      enabled: enabled,
      granted: granted,
      installedAt: DateTime.fromMillisecondsSinceEpoch(1700000000000),
    );

    test('reads back whole', () {
      store.put(zfs(repo: 'official'));

      expect(store.fetch('app.serverbox.zfs'), zfs(repo: 'official'));
      expect(store.readAll(), [zfs(repo: 'official')]);
      expect(store.fetch('nothing'), isNull);
    });

    test('a bundled plugin has no repository, and says so', () {
      store.put(zfs());

      final read = store.fetch('app.serverbox.zfs')!;
      expect(read.repo, isNull);
      expect(read.bundled, isTrue);
      expect(read.isDev, isFalse);
      expect(zfs(repo: PluginInstall.devRepo).isDev, isTrue);
    });

    /// `INSERT OR REPLACE` would have reset every column the statement does
    /// not name; an update names them.
    test('an update replaces the row rather than adding one', () {
      store.put(zfs(version: '1.0.0'));
      store.put(zfs(version: '2.0.0', granted: {'server.exec', 'net.http'}));

      expect(store.readAll(), hasLength(1));
      final read = store.fetch('app.serverbox.zfs')!;
      expect(read.version, '2.0.0');
      expect(read.granted, {'server.exec', 'net.http'});
    });

    // Being switched off is not the same as not being there: it keeps the
    // configuration, the data, and the place the user arranged it in.
    test('turning it off leaves everything else alone', () {
      store.put(zfs());
      PluginKvStore.instance.put('app.serverbox.zfs', 'k', 'v');

      store.setEnabled('app.serverbox.zfs', false);

      expect(store.fetch('app.serverbox.zfs')!.enabled, isFalse);
      expect(store.isActive('app.serverbox.zfs'), isFalse);
      expect(PluginKvStore.instance.fetch('app.serverbox.zfs', 'k'), 'v');
    });

    test('a plugin that is not installed is not active either', () {
      expect(store.isActive('nothing'), isFalse);
    });

    test('uninstalling takes the data with it, unless it is kept', () {
      store.put(zfs());
      PluginKvStore.instance.put('app.serverbox.zfs', 'k', 'v');

      store.remove('app.serverbox.zfs');

      expect(store.fetch('app.serverbox.zfs'), isNull);
      expect(PluginKvStore.instance.fetch('app.serverbox.zfs', 'k'), isNull);

      store.put(zfs());
      PluginKvStore.instance.put('app.serverbox.zfs', 'k', 'v');
      store.remove('app.serverbox.zfs', keepData: true);

      expect(PluginKvStore.instance.fetch('app.serverbox.zfs', 'k'), 'v');
    });

    /// A row this build cannot decode is one whose consent it cannot vouch
    /// for, and the safe reading of that is that nothing was consented to.
    test('a granted column it cannot read grants nothing', () {
      store.put(zfs());
      SqliteDb.instance.execute(
        "UPDATE plugin_install SET granted = 'not json' WHERE id = ?;",
        ['app.serverbox.zfs'],
      );

      expect(store.fetch('app.serverbox.zfs')!.granted, isEmpty);
    });

    test('the record survives JSON, for a backup', () {
      final install = zfs(repo: 'official', enabled: false);
      expect(PluginInstall.fromJson(install.toJson()), install);
    });
  });

  group('per-server configuration', () {
    late PluginCfgStore store;

    setUp(() async {
      await openTestDb();
      // A write here stamps the server it belongs to, the way a container host
      // does — so the store that owns that row has to be reachable.
      getIt.registerSingleton<ServerStore>(ServerStore());
      store = PluginCfgStore();
      SqliteDb.instance.execute(
        "INSERT INTO server (id, name, ssh_ip) VALUES ('srv-1', 'one', '10.0.0.1');",
      );
      SqliteDb.instance.execute(
        "INSERT INTO server (id, name, ssh_ip) VALUES ('srv-2', 'two', '10.0.0.2');",
      );
    });
    tearDown(() async {
      await getIt.reset();
      await closeTestDb();
    });

    test('reads back what was typed', () {
      store.put('srv-1', 'bmc', {'addr': 'https://10.0.0.9'}, cfgVer: 1);

      expect(store.fetch('srv-1', 'bmc'), {'addr': 'https://10.0.0.9'});
      expect(store.fetch('srv-2', 'bmc'), isEmpty);
      expect(store.pluginsFor('srv-1'), ['bmc']);
      expect(store.pluginsFor('srv-2'), isEmpty);
    });

    /// What `requires_config` asks. A form saved with every field blank is
    /// still a decision, so it is not the same question as `fetch` being
    /// empty — a card that appeared on every server to say "not configured"
    /// would be noise on the machines that have no BMC, which is most of them.
    test('having been configured is not the same as having values', () {
      store.put('srv-1', 'bmc', const {}, cfgVer: 1);

      expect(store.fetch('srv-1', 'bmc'), isEmpty);
      expect(store.has('srv-1', 'bmc'), isTrue);
      expect(store.has('srv-2', 'bmc'), isFalse);
    });

    test('a row it cannot decode reads as no configuration', () {
      store.put('srv-1', 'bmc', {'addr': 'x'}, cfgVer: 1);
      SqliteDb.instance.execute(
        "UPDATE server_plugin_cfg SET cfg = 'not json' WHERE server_id = 'srv-1';",
      );

      expect(store.fetch('srv-1', 'bmc'), isEmpty);
    });

    test('deleting the server takes its configuration', () {
      store.put('srv-1', 'bmc', {'addr': 'x'}, cfgVer: 1);
      store.put('srv-2', 'bmc', {'addr': 'y'}, cfgVer: 1);

      SqliteDb.instance.execute("DELETE FROM server WHERE id = 'srv-1';");

      expect(store.has('srv-1', 'bmc'), isFalse);
      expect(store.fetch('srv-2', 'bmc'), {'addr': 'y'});
    });

    test('uninstalling takes every server\'s configuration for it', () {
      store.put('srv-1', 'bmc', {'addr': 'x'}, cfgVer: 1);
      store.put('srv-2', 'bmc', {'addr': 'y'}, cfgVer: 1);
      store.put('srv-1', 'zfs', const {}, cfgVer: 1);

      store.removePlugin('bmc');

      expect(store.has('srv-1', 'bmc'), isFalse);
      expect(store.has('srv-2', 'bmc'), isFalse);
      expect(store.has('srv-1', 'zfs'), isTrue);
    });
  });

  group('plugin data', () {
    late PluginKvStore store;

    setUp(() async {
      await openTestDb();
      store = PluginKvStore();
      SqliteDb.instance.execute(
        "INSERT INTO server (id, name, ssh_ip) VALUES ('srv-1', 'one', '10.0.0.1');",
      );
    });
    tearDown(closeTestDb);

    // The two namespaces are separate tables, and the whole point of that is
    // that neither can be mistaken for the other.
    test('a global key and a per-server key of the same name are two things', () {
      store.put('bmc', 'token', 'global');
      store.put('bmc', 'token', 'per-server', serverId: 'srv-1');

      expect(store.fetch('bmc', 'token'), 'global');
      expect(store.fetch('bmc', 'token', serverId: 'srv-1'), 'per-server');
    });

    /// Which a nullable `server_id` in one table could not have promised:
    /// SQLite counts two NULLs as different in a unique index, so the shape
    /// that meant "global" would have been the shape with no uniqueness.
    test('writing a global key twice updates it rather than adding a second', () {
      store.put('bmc', 'token', 'first');
      store.put('bmc', 'token', 'second');

      expect(store.fetch('bmc', 'token'), 'second');
      expect(store.keys('bmc'), ['token']);
    });

    test('keys list one namespace, sorted', () {
      store.put('bmc', 'b', '1');
      store.put('bmc', 'a', '2');
      store.put('bmc', 'z', '3', serverId: 'srv-1');
      store.put('zfs', 'a', '4');

      expect(store.keys('bmc'), ['a', 'b']);
      expect(store.keys('bmc', serverId: 'srv-1'), ['z']);
      expect(store.keys('zfs'), ['a']);
    });

    test('removing one key leaves the other namespace alone', () {
      store.put('bmc', 'token', 'global');
      store.put('bmc', 'token', 'per-server', serverId: 'srv-1');

      store.remove('bmc', 'token');

      expect(store.fetch('bmc', 'token'), isNull);
      expect(store.fetch('bmc', 'token', serverId: 'srv-1'), 'per-server');
    });

    test('deleting the server takes what a plugin kept about it', () {
      store.put('bmc', 'token', 'global');
      store.put('bmc', 'token', 'per-server', serverId: 'srv-1');

      SqliteDb.instance.execute("DELETE FROM server WHERE id = 'srv-1';");

      expect(store.fetch('bmc', 'token', serverId: 'srv-1'), isNull);
      expect(store.fetch('bmc', 'token'), 'global', reason: 'global is not the server\'s');
    });

    test('uninstalling takes both namespaces', () {
      store.put('bmc', 'token', 'global');
      store.put('bmc', 'token', 'per-server', serverId: 'srv-1');
      store.put('zfs', 'k', 'v');

      store.removePlugin('bmc');

      expect(store.keys('bmc'), isEmpty);
      expect(store.keys('bmc', serverId: 'srv-1'), isEmpty);
      expect(store.keys('zfs'), ['k']);
    });
  });
}
