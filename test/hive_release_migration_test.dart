import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:fl_lib/fl_lib.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:server_box/data/model/container/type.dart';
import 'package:server_box/data/model/server/port_forward.dart';
import 'package:server_box/data/model/server/system.dart';
import 'package:server_box/data/res/store.dart';
import 'package:server_box/data/store/migrations/m004_kv_to_tables.dart';
import 'package:server_box/data/store/schema.dart';
import 'package:server_box/hive/hive_registrar.g.dart';
import 'package:server_box/hive/legacy_adapters.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The upgrade path from every released build, against bytes those builds
/// wrote.
///
/// The SQLite layout has never shipped, so **every** install in the field is
/// on Hive and any released version is a migration source. `hive_adapters.g
/// .dart` is byte-identical across 1466, 1480 and 1491, so the three share one
/// set of assertions — but 1491 also shipped an `agent_conversation` box, so
/// each gets a fixture of its own rather than the later ones being assumed
/// equal to the first.
///
/// Seeding through the *current* adapters would only show that today's code
/// agrees with itself. These fixtures were produced by each release's own
/// generated adapters — see `test/fixtures/hive_v<version>/README.md`.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const versions = ['1466', '1480', '1491'];

  late Directory tempDir;

  // Once for the process: `Paths.doc` is `late final`, so it cannot be set
  // again for the second version. One directory, refilled per test instead.
  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('sbm-hive-releases-');
    Paths.doc = tempDir.path;

    final rng = Random(1);
    FlutterSecureStorage.setMockInitialValues({
      'hivePwd': base64UrlEncode(
        Uint8List.fromList(List<int>.generate(32, (_) => rng.nextInt(256))),
      ),
    });
    SharedPreferences.setMockInitialValues({});
    await PrefStore.shared.init();

    Hive.init(tempDir.path);
    Hive.registerAdapters();
    registerHiveLegacyAdapters();
  });

  tearDownAll(() async {
    await Hive.close();
    await tempDir.delete(recursive: true);
  });

  for (final version in versions) {
    group('v1.0.$version', () {
      final fixtureDir = Directory('test/fixtures/hive_v$version');

      setUp(() async {
        for (final f in tempDir.listSync()) {
          if (f is File) f.deleteSync();
        }
        for (final f in fixtureDir.listSync().whereType<File>()) {
          if (!f.path.endsWith('.hive')) continue;
          f.copySync(tempDir.path.joinPath(f.path.split('/').last));
        }
        SqliteDb.openInMemory();
      });

      tearDown(() async {
        await getIt.reset();
        await SqliteDb.close();
        await Hive.close();
        Hive.init(tempDir.path);
      });

    test('the fixture is present and encrypted', () {
      expect(fixtureDir.existsSync(), isTrue);
      final names = fixtureDir
          .listSync()
          .whereType<File>()
          .map((f) => f.path.split('/').last)
          .where((n) => n.endsWith('.hive'))
          .toList()
        ..sort();
      expect(names, [
        // 1491 shipped one more box than the two before it.
        if (version == '1491') 'agent_conversation_enc.hive',
        'conn_stats_index.hive',
        'connection_stats_enc.hive',
        'docker_enc.hive',
        'history_enc.hive',
        'key_enc.hive',
        'port_forward_enc.hive',
        'server_enc.hive',
        'setting_enc.hive',
        'snippet_enc.hive',
      ]);

      // The one box 1466 wrote without a cipher, and the reason the others are
      // worth keeping encrypted: this one is readable as text.
      final index = File(fixtureDir.path.joinPath('conn_stats_index.hive'));
      expect(index.readAsStringSync(), contains('srv-pwd'));
      // An encrypted box is not.
      final server = File(fixtureDir.path.joinPath('server_enc.hive'));
      expect(
        utf8.decode(server.readAsBytesSync(), allowMalformed: true),
        isNot(contains('password auth')),
        reason: 'the server name must not be readable in the file',
      );
    });

    /// The whole upgrade, not half of it: `HiveImport` leaves the records as
    /// rows in `kv`, and `KvToTablesMigration` is what turns them into the
    /// tables the app reads. Asserting between the two would only prove the
    /// data reached an intermediate shape no build ever ships.
    group('after importing the boxes and migrating', () {
      setUp(() async {
        await Stores.init();
        await SchemaVersion.migrate(const [KvToTablesMigration()]);
      });

      test('every server arrives with its SSH fields nested', () {
        final ids = Stores.server.fetch().map((e) => e.id).toList();
        expect(ids.length, 5);

        final pwd = Stores.server.fetchOneRaw('srv-pwd')!;
        expect(pwd.name, 'password auth');
        // Sorted, because a tag is a row and (server_id, tag) is its key. The
        // order a tag was added in was never meaningful and is not kept.
        expect(pwd.tags, ['db', 'prod']);
        expect(pwd.autoConnect, isTrue);
        expect(pwd.ssh?.ip, '10.0.0.1');
        expect(pwd.ssh?.port, 22);
        expect(pwd.ssh?.user, 'root');
        expect(pwd.ssh?.pwd, 'hunter2');
        expect(pwd.ssh?.keyId, isNull);
        // 1466 had no monitor support, so no record can carry one.
        expect(pwd.monitorHttp, isNull);
      });

      test('the richest record keeps every optional field', () {
        final spi = Stores.server.fetchOneRaw('srv-key')!;
        expect(spi.name, 'key auth + custom');
        expect(spi.autoConnect, isFalse);
        expect(spi.tags, ['staging']);
        expect(spi.envs, {'TERM': 'xterm-256color', 'LANG': 'en_US.UTF-8'});
        expect(spi.customSystemType, SystemType.linux);
        expect(spi.disabledCmdTypes, ['sensors', 'smartctl']);

        expect(spi.ssh?.ip, '10.0.0.2');
        expect(spi.ssh?.port, 2222);
        expect(spi.ssh?.user, 'admin');
        // The key's id is generated now; its name is what the user typed.
        expect(spi.ssh?.keyId, Stores.key.fetchByName('key-ed25519')!.id);
        expect(spi.ssh?.pwd, isNull);
        expect(spi.ssh?.alterUrl, 'admin@alt.example.com:2200');

        final custom = spi.custom!;
        expect(custom.pveAddr, 'https://pve.example.com:8006');
        expect(custom.pveIgnoreCert, isTrue);
        expect(custom.cmds, {'uptime': 'uptime -p', 'who': 'w'});
        expect(custom.preferTempDev, 'coretemp');
        expect(custom.tempIsCelsius, isFalse);
        expect(custom.logoUrl, 'https://example.com/logo.png');
        expect(custom.netDev, 'eth0');
        expect(custom.scriptDir, '/opt/sbm');

        final wol = spi.wolCfg!;
        expect(wol.mac, 'AA:BB:CC:DD:EE:FF');
        expect(wol.ip, '10.0.0.255');
        expect(wol.pwd, 'wolpwd');
      });

      test('jump hosts and proxy command land on the credential', () {
        final jump = Stores.server.fetchOneRaw('srv-jump')!;
        expect(jump.ssh?.jumpId, 'srv-pwd');
        expect(jump.ssh?.jumpIds, ['srv-pwd', 'srv-key']);
        expect(jump.ssh?.proxyCommand, isNull);

        final proxy = Stores.server.fetchOneRaw('srv-proxy')!;
        expect(proxy.ssh?.proxyCommand, 'nc -X 5 -x 127.0.0.1:1080 %h %p');
        expect(proxy.ssh?.jumpIds, isNull);
      });

      test('a record with nothing optional set survives', () {
        // 1466 wrote an empty id for a record predating them, so this one is
        // found by name: an empty primary key is not a thing the table can
        // hold, and the migration is where it is given a real id.
        final bare = Stores.server.fetch().firstWhere((e) => e.name == 'bare');
        expect(bare.ssh?.ip, '10.0.0.9');
        expect(bare.custom, isNull);
        expect(bare.wolCfg, isNull);
        expect(bare.tags, isNull);
        expect(bare.id, isNotEmpty);
      });

      test('the records are columns, and `kv` no longer holds them', () {
        final row = SqliteDb.instance
            .select(
              'SELECT ssh_ip, ssh_port, ssh_user, monitor_addr FROM server '
              'WHERE id = ?;',
              ['srv-key'],
            )
            .single;
        expect(row['ssh_ip'], '10.0.0.2');
        expect(row['ssh_port'], 2222);
        expect(row['ssh_user'], 'admin');
        expect(row['monitor_addr'], isNull);

        for (final store in const ['server', 'key', 'snippet', 'docker']) {
          expect(
            SqliteDb.instance
                .select('SELECT count(*) AS n FROM kv WHERE store = ?;', [store])
                .single['n'],
            0,
            reason: 'a second copy of "$store" that a backup would carry',
          );
        }
      });

      test('private keys and snippets come across whole', () {
        expect(Stores.key.fetchByName('key-ed25519')?.key,
            contains('BEGIN OPENSSH PRIVATE KEY'));
        expect(Stores.key.fetchByName('key-rsa')?.key,
            contains('BEGIN RSA PRIVATE KEY'));

        final deploy = Stores.snippet.fetchByName('deploy')!;
        expect(deploy.script, contains('systemctl restart app'));
        expect(deploy.tags, ['ops', 'risky']);
        expect(deploy.note, 'run on the app hosts only');
        // Sorted, like tags: an auto-run target is a row keyed by the pair.
        expect(deploy.autoRunOn, ['srv-key', 'srv-pwd']);

        // Non-ASCII, quotes, backslashes and newlines through Hive bytes and
        // then through JSON and into a column.
        final unicode = Stores.snippet.fetchByName('日本語 / emoji 🚀')!;
        expect(unicode.note, 'ünïcödé');
        expect(unicode.script, contains(r'引号 "双" \\ 反斜杠'));
        expect(unicode.script.split('\n').length, 2);
      });

      test('settings keep their type, not just their value', () {
        expect(Stores.setting.timeout.get(), 9);
        expect(Stores.setting.textFactor.get(), 1.25);
        expect(Stores.setting.recordHistory.get(), isFalse);
        expect(Stores.setting.useBioAuth.get(), isTrue);
        expect(Stores.setting.locale.get(), 'zh');
        expect(Stores.setting.colorSeed.get(), 4287106639);
        expect(Stores.setting.termFontSize.get(), 13.0);
        expect(Stores.setting.maxRetryCount.get(), 2);

        expect(Stores.setting.homeTabs.get().map((e) => e.name),
            ['server', 'ssh', 'snippet']);
        expect(Stores.setting.sshVirtKeys.get(), [0, 1, 2, 13, 14]);
        expect(Stores.setting.serverOrder.get(),
            ['srv-key', 'srv-pwd', 'srv-jump']);
        expect(Stores.setting.detailCardDisabled.get(), ['temperature']);

        // Stored by name in 1466 and still read by name — an index would have
        // changed meaning silently.
        expect(Stores.setting.netViewType.get().name, 'speed');

        // Not a setting any more: a trusted fingerprint belongs to the server
        // it was trusted for, and cascades with it. The old key is gone.
        expect(Stores.setting.sshKnownHostFingerprints.get(), isEmpty);
        expect(Stores.server.knownHosts('srv-pwd'),
            {'ssh-ed25519': 'SHA256:AAAA'});
        expect(Stores.server.knownHosts('srv-key'), {'ssh-rsa': 'SHA256:BBBB'});
      });

      test('history, container hosts and port forwards come across', () {
        expect(Stores.history.sftpGoPath.all, ['/etc', '/var/log', '/home/ops']);

        // The global entry belonged to no server, and both container tables
        // are children of one now — so it has nowhere to live and is dropped.
        expect(Stores.container.fetch('', ContainerType.docker), isNull);
        expect(Stores.container.fetch('srv-key', ContainerType.docker),
            'tcp://10.0.0.2:2375');
        expect(Stores.container.fetch('srv-jump', ContainerType.podman),
            'unix:///run/podman.sock');

        final forwards = Stores.portForward.fetchForServer('srv-pwd');
        expect(forwards.length, 1);
        expect(forwards.single.name, 'postgres');
        expect(forwards.single.type, PortForwardType.local);
        expect(forwards.single.localPort, 15432);
        expect(forwards.single.remoteHost, '10.0.0.50');
        expect(forwards.single.remotePort, 5432);

        expect(Stores.portForward.fetchForServer('srv-key').single.type,
            PortForwardType.remote);
      });

      test('every connection stat row lands in its table', () {
        // 60 per server, none dropped on the way in. The per-server cap is
        // applied when recording, not when importing.
        final rows = SqliteDb.instance
            .select('SELECT count(*) AS n FROM conn_stat;')
            .single['n'];
        expect(rows, 120);

        final stats = Stores.connectionStats.getServerStats('srv-pwd', 'x');
        expect(stats.totalAttempts, 60);
        // The generator made one in five a success.
        expect(stats.successCount, 12);
        expect(stats.failureCount, 48);
        expect(stats.successRate, closeTo(0.2, 0.001));

        // Every failure kind survives the round trip by name.
        final kinds = SqliteDb.instance
            .select('SELECT DISTINCT result FROM conn_stat ORDER BY result;')
            .map((r) => r['result'] as String)
            .toList();
        expect(kinds, [
          'authFailed',
          'networkError',
          'success',
          'timeout',
          'unknownError',
        ]);

        final one = Stores.connectionStats.getConnectionHistory('srv-key').first;
        expect(one.serverName, 'key auth + custom');
        expect(one.durationMs, greaterThan(0));

        // Every id is generated: the old `<serverId>_<millis>` collided when
        // two attempts landed in the same millisecond.
        final ids = SqliteDb.instance
            .select('SELECT id FROM conn_stat;')
            .map((r) => r['id'] as String);
        expect(ids.every((id) => !id.contains('_')), isTrue);

        // Nothing of the two stats boxes is left in `kv`.
        expect(
          SqliteDb.instance
              .select("SELECT count(*) AS n FROM kv WHERE store LIKE 'conn%';")
              .single['n'],
          0,
        );
      });

      test('the plaintext index is deleted and the rest kept', () {
        expect(
          File(tempDir.path.joinPath('conn_stats_index.hive')).existsSync(),
          isFalse,
        );
        expect(
          File(tempDir.path.joinPath('server_enc.hive')).existsSync(),
          isTrue,
          reason: 'kept so a bad import can be rolled back to',
        );
      });

      test('the schema is up to date, and nothing reads as a local edit', () {
        expect(SchemaVersion.stored, SchemaVersion.current);
        // `Stores.lastModTime` decides which side of a sync wins; a device that
        // has just read its own disk must not claim the newer copy.
        expect(Stores.lastModTime, 0);
      });

      test('a second launch changes nothing', () async {
        Stores.setting.timeout.put(42);
        final before = Stores.server.fetchOneRaw('srv-key')!;
        await getIt.reset();

        await Stores.init();
        await SchemaVersion.migrate(const [KvToTablesMigration()]);

        expect(Stores.setting.timeout.get(), 42, reason: 'no re-import');
        expect(Stores.server.fetchOneRaw('srv-key')!.ssh?.ip, before.ssh?.ip);
        expect(Stores.server.fetch().length, 5, reason: 'no duplicates');

        // The stats are gone, and that is the retention policy rather than a
        // loss: `ConnectionStatsStore.init` sweeps anything past 30 days, and
        // the fixture is stamped in the past for good. On the importing launch
        // they survive only because that sweep runs before `HiveImport`.
        expect(
          SqliteDb.instance
              .select('SELECT count(*) AS n FROM conn_stat;')
              .single['n'],
          0,
        );
      });
    });
      test('the agent conversations come across when the release had them', () async {
        await Stores.init();
        await SchemaVersion.migrate(const [KvToTablesMigration()]);
        final had = version == '1491';
        final convs = Stores.agentConversation.fetchForServer('srv-key');
        expect(convs.length, had ? 1 : 0,
            reason: had
                ? '1491 shipped the box, so its rows must arrive'
                : 'the box does not exist in this release');
        if (had) {
          expect(convs.single.title, '磁盘快满了');
          expect(convs.single.items.length, 2);
          expect(Stores.agentConversation.activeConversationId('srv-key'),
              'conv-1');
        }
      });
    });
  }
}
