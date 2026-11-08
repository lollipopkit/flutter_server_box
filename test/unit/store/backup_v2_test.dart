import 'dart:convert';
import 'dart:io';

import 'package:fl_lib/fl_lib.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/data/model/app/bak/backup2.dart';
import 'package:server_box/data/model/app/tab.dart';
import 'package:server_box/data/model/container/type.dart';
import 'package:server_box/data/model/server/bmc_cfg.dart';
import 'package:server_box/data/model/server/custom.dart';
import 'package:server_box/data/model/server/port_forward.dart';
import 'package:server_box/data/model/server/private_key_info.dart';
import 'package:server_box/data/model/server/pve_config.dart';
import 'package:server_box/data/model/server/remote_desktop.dart';
import 'package:server_box/data/model/server/server_private_info.dart';
import 'package:server_box/data/model/server/snippet.dart';
import 'package:server_box/data/model/server/ssh_credential.dart';
import 'package:server_box/data/store/migrations/all.dart';
import 'package:server_box/data/store/migrations/m008_settings_fixups.dart';
import 'package:server_box/data/store/migrations/m009_grouped_settings.dart';
import 'package:server_box/data/store/migrations/m021_home_tabs_bar.dart';
import 'package:server_box/data/store/migrations/m022_ai_endpoint_version.dart';
import 'package:server_box/data/store/schema.dart';
import 'package:server_box/data/store/stores.dart';

import '../../helpers/rust_lib_helper.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('BackupV2 JSON encoding', () {
    test('a typed port forward encodes, and comes back the same', () {
      // `PortForwardConfig` is the one freezed model with no `.g.dart`, so its
      // `toJson` is hand-written — and `_toEncodable` did not know the type at
      // all, which threw the moment a backup carried one.
      const forward = PortForwardConfig(
        id: 'pf-1',
        serverId: 'srv-1',
        name: 'postgres',
        type: PortForwardType.remote,
        localHost: '127.0.0.1',
        localPort: 15432,
        remoteHost: '10.0.0.50',
        remotePort: 5432,
      );
      final backup = BackupV2(
        version: BackupV2.formatVer,
        date: 1,
        spis: const {},
        snippets: const {},
        keys: const {},
        portForwards: const {'pf-1': forward},
        container: const {},
        history: const {},
        settings: const {},
      );

      final encoded = backup.toJsonString();
      final decoded = json.decode(encoded) as Map<String, dynamic>;
      final raw = (decoded['portForwards'] as Map)['pf-1'] as Map;
      expect(raw['type'], 'remote', reason: 'the enum by name, not its index');
      expect(raw['remotePort'], 5432);

      // Through the reader the app actually uses, not just `fromJson`.
      final reread = BackupV2.fromJsonString(encoded);
      expect(
        PortForwardConfig.fromJson(
          Map<String, dynamic>.from(reread.portForwards['pf-1'] as Map),
        ),
        forward,
      );
    });

    test('serializes typed store objects as JSON objects', () {
      final backup = BackupV2(
        version: BackupV2.formatVer,
        date: 1,
        spis: {'server': Spix.example},
        snippets: {'snippet': Snippet.example},
        keys: {
          'key': const PrivateKeyInfo(
            id: 'key',
            name: 'key',
            key: '-----BEGIN OPENSSH PRIVATE KEY-----\nkey',
          ),
        },
        container: const {},
        history: const {},
        settings: const {},
      );

      final encoded = backup.toJsonString();
      final decoded = json.decode(encoded) as Map<String, dynamic>;

      expect(decoded['spis']['server'], isA<Map>());
      expect(decoded['spis']['server']['name'], Spix.example.name);
      expect(decoded['snippets']['snippet'], isA<Map>());
      expect(decoded['snippets']['snippet']['script'], Snippet.example.script);
      expect(decoded['keys']['key'], isA<Map>());
      expect(decoded['keys']['key']['private_key'], contains('OPENSSH'));
    });

    test('serializes every object nested on a server', () {
      // `_$SpiToJson` emits these three as the objects themselves, so each one
      // has to be named in `_toEncodable` or the whole backup throws. `bmc`
      // was not, which took out manual export and every auto-sync from the
      // moment one server had a BMC address.
      final backup = BackupV2(
        version: BackupV2.formatVer,
        date: 1,
        spis: {
          'srv-1': const Spi(
            id: 'srv-1',
            name: 'prod',
            ssh: SshCredential(ip: '10.0.0.1', keyId: 'work'),
            bmc: BmcCfg(
              addr: 'https://10.0.0.9',
              credId: 'cred-1',
              certSha256: 'ab12',
            ),
          ),
        },
        snippets: const {},
        keys: const {},
        container: const {},
        history: const {},
        settings: const {},
      );

      final decoded =
          json.decode(backup.toJsonString()) as Map<String, dynamic>;
      final spi = decoded['spis']['srv-1'] as Map<String, dynamic>;

      expect(spi['ssh'], isA<Map>());
      expect(spi['ssh']['ip'], '10.0.0.1');
      expect(spi['bmc'], isA<Map>());
      expect(spi['bmc']['addr'], 'https://10.0.0.9');
      expect(spi['bmc']['credId'], 'cred-1');
      expect(spi['bmc']['certSha256'], 'ab12');

      // Through the reader the app uses, so the round trip is the assertion
      // rather than the shape alone.
      final reread = BackupV2.fromJsonString(backup.toJsonString());
      final restored = Spi.fromJson(
        Map<String, dynamic>.from(reread.spis['srv-1'] as Map),
      );
      expect(
        restored.bmc,
        const BmcCfg(
          addr: 'https://10.0.0.9',
          credId: 'cred-1',
          certSha256: 'ab12',
        ),
      );
    });

    test('serializes enum values by name', () {
      final backup = BackupV2(
        version: BackupV2.formatVer,
        date: 1,
        spis: const {},
        snippets: const {},
        keys: const {},
        container: const {},
        history: const {},
        settings: const {
          'homeTabs': [AppTab.server, AppTab.ssh],
        },
      );

      final decoded =
          json.decode(backup.toJsonString()) as Map<String, dynamic>;

      expect(decoded['settings']['homeTabs'], ['server', 'ssh']);
    });

    test('fails instead of stringifying unknown objects', () {
      final backup = BackupV2(
        version: BackupV2.formatVer,
        date: 1,
        spis: const {},
        snippets: const {},
        keys: const {},
        container: const {},
        history: const {},
        settings: {'bad': _NotJsonEncodable()},
      );

      expect(backup.toJsonString, throwsA(isA<UnsupportedError>()));
    });

    test('preserves failures from supported toJson implementations', () {
      final backup = BackupV2(
        version: BackupV2.formatVer,
        date: 1,
        spis: const {},
        snippets: const {},
        keys: {'bad': const _ThrowingPrivateKeyInfo()},
        container: const {},
        history: const {},
        settings: const {},
      );

      expect(backup.toJsonString, throwsA(isA<StateError>()));
    });

    // #1637: the themes the settings select travel with them.
    test('carries themes, and reads a file from before them', () {
      const entry = {'id': 'example.amethyst', 'name': 'Amethyst'};
      final id = 'a' * 64;
      final backup = BackupV2(
        version: BackupV2.formatVer,
        date: 1,
        spis: const {},
        snippets: const {},
        keys: const {},
        container: const {},
        history: const {},
        settings: const {},
        themes: {id: entry},
      );
      final json = jsonDecode(backup.toJsonString()) as Map<String, dynamic>;
      expect(BackupV2.fromJson(json).themes, {id: entry});

      json.remove('themes');
      expect(BackupV2.fromJson(json).themes, isEmpty);
    });
  });

  group('BackupV2 restore validation', () {
    test('rejects corrupted typed store entries', () {
      final raw = json.encode({
        'version': BackupV2.formatVer,
        'date': 1,
        'spis': {'server': 'Spi<root@example.com:22>'},
        'snippets': {},
        'keys': {},
        'container': {},
        'history': {},
        'settings': {},
      });

      expect(
        () => BackupV2.fromJsonString(raw),
        throwsA(isA<FormatException>()),
      );
    });

    test('allows internal metadata in typed stores', () {
      final raw = json.encode({
        'version': BackupV2.formatVer,
        'date': 1,
        'spis': {'__lkpt_lastUpdateTs': 'legacy timestamp metadata'},
        'snippets': {},
        'keys': {},
        'container': {},
        'history': {},
        'settings': {},
      });

      final backup = BackupV2.fromJsonString(raw);

      expect(backup.spis['__lkpt_lastUpdateTs'], 'legacy timestamp metadata');
    });

    test(
      'rejects a newer numeric version even when JSON decodes it as double',
      () {
        final raw = json.encode({
          'version': 999.0,
          'date': 1,
          'spis': {},
          'snippets': {},
          'keys': {},
          'container': {},
          'history': {},
          'settings': {},
        });

        expect(
          () => BackupV2.fromJsonString(raw),
          throwsA(
            isA<SchemaTooNewException>().having(
              (error) => error.stored,
              'stored version',
              999,
            ),
          ),
        );
      },
    );
  });

  group('BackupV2 store export', () {
    late Directory tempDir;

    setUpAll(() async {
      // Restores forget the passphrases of keys they replace (BLAKE3).
      await initRustLibForTest();
      tempDir = await Directory.systemTemp.createTemp('sbm-backup-v2-');
      Paths.doc = tempDir.path;
    });

    tearDownAll(() async => tempDir.delete(recursive: true));

    setUp(() async {
      SqliteDb.openInMemory();
      await Stores.init();
    });

    tearDown(() async {
      await getIt.reset();
      await SqliteDb.close();
    });

    test('keeps timestamps but excludes device-local markers', () async {
      const importMarker = '${StoreDefaults.prefixKey}hiveImported';
      Stores.setting.set(importMarker, true, updateLastUpdateTsOnSet: false);
      Stores.setting.timeout.put(11);

      final backup = await BackupV2.loadFromStore();

      expect(backup.settings.containsKey(importMarker), isFalse);
      expect(
        backup.settings.containsKey(Stores.setting.schemaVersion.key),
        isFalse,
      );
      expect(
        backup.settings.containsKey(Stores.setting.lastUpdateTsKey),
        isTrue,
      );
      expect(backup.settings['timeOut'], 11);
    });

    test('exports and restores remote desktop profiles', () async {
      const server = Spi(
        id: 'server-1',
        name: 'desktop host',
        ssh: SshCredential(ip: '10.0.0.1'),
      );
      const profile = RemoteDesktopProfile(
        id: 'desktop-1',
        serverId: 'server-1',
        name: 'Windows',
        protocol: RemoteDesktopProtocol.rdp,
        port: 3389,
        username: 'admin',
        password: 'saved-secret',
      );
      Stores.server.put(server);
      Stores.remoteDesktop.put(profile);

      final backup = BackupV2.fromJsonString(
        (await BackupV2.loadFromStore()).toJsonString(),
      );
      Stores.remoteDesktop.delete(profile);
      await backup.merge(force: true);

      expect(Stores.remoteDesktop.fetchForServer(server.id), [profile]);
    });

    /// A file from a build that kept `custom.cmds`: the commands are dropped,
    /// the rest of the server restores as it was.
    test('a server carrying custom.cmds restores without them', () async {
      const server = Spi(
        id: 'cmds-host',
        name: 'cmds host',
        ssh: SshCredential(ip: '10.0.0.4'),
        custom: ServerCustom(netDev: 'eth0', logoUrl: 'https://l/x.png'),
      );
      final serverJson = json.decode(json.encode(server.toJson())) as Map;
      (serverJson['custom'] as Map)['cmds'] = {'up': 'uptime'};
      final raw = json.decode(
        BackupV2(
          version: 36,
          date: 1,
          spis: {server.id: serverJson},
          snippets: const {},
          keys: const {},
          container: const {},
          history: const {},
          settings: const {},
        ).toJsonString(),
      ) as Map<String, dynamic>;

      await BackupV2.fromJson(raw).merge(force: true);

      expect(Stores.server.fetchOneRaw(server.id), server);
    });

    group('PVE', () {
      const server = Spi(
        id: 'pve-host',
        name: 'pve host',
        ssh: SshCredential(ip: '10.0.0.2'),
      );
      const pve = PveConfig(
        addr: 'https://127.0.0.1:8006',
        auth: PveAuth.token,
        tokenId: 'root@pam!sb',
        tokenSecret: 'secret',
        certSha256: 'ab12',
      );

      test('exports and restores the configuration beside its server', () async {
        Stores.server.put(server);
        Stores.pve.put(server.id, pve);

        final backup = BackupV2.fromJsonString(
          (await BackupV2.loadFromStore()).toJsonString(),
        );
        expect(backup.pve[server.id], isA<Map>());
        Stores.pve.remove(server.id);
        await backup.merge(force: true);

        expect(Stores.pve.fetch(server.id), pve);
      });

      test('a server the backup has without PVE loses it here', () async {
        Stores.server.put(server);
        final backup = BackupV2.fromJsonString(
          (await BackupV2.loadFromStore()).toJsonString(),
        );
        Stores.pve.put(server.id, pve);

        await backup.merge(force: true);

        expect(Stores.pve.fetch(server.id), isNull);
      });

      /// A file from before `server_pve`: no `pve` section, and the fields
      /// that build kept in the server's `custom`. Those are not read: such a
      /// file restores its servers without PVE.
      Map<String, dynamic> preSection({String addr = 'https://10.0.0.9:8006'}) {
        final serverJson = json.decode(json.encode(server.toJson())) as Map;
        serverJson['custom'] = {
          'pveAddr': addr,
          'pveIgnoreCert': true,
          'pvePwd': 'p',
        };
        final raw = json.decode(
          BackupV2(
            version: 30,
            date: 1,
            spis: {
              server.id: serverJson,
              StoreDefaults.defaultLastUpdateTsKey: {
                server.id: DateTime.now().millisecondsSinceEpoch + 60000,
              },
            },
            snippets: const {},
            keys: const {},
            container: const {},
            history: const {},
            settings: const {},
          ).toJsonString(),
        ) as Map<String, dynamic>;
        return raw..remove('pve');
      }

      test('restoring an older backup is its state: no PVE', () async {
        Stores.server.put(server);
        Stores.pve.put(server.id, pve);

        await BackupV2.fromJson(preSection()).merge(force: true);

        expect(Stores.server.fetchOneRaw(server.id)?.name, server.name);
        expect(Stores.pve.fetch(server.id), isNull);
        expect(Stores.pve.fetchAll(), isEmpty, reason: 'nothing from custom');
      });

      test('a sync from an older build leaves the row here', () async {
        Stores.server.put(server);
        Stores.pve.put(server.id, pve);

        await BackupV2.fromJson(
          preSection(addr: 'https://10.0.0.3:8006'),
        ).merge();

        // It cannot say "removed" any other way than "never had", and the
        // address in its `custom` is not taken either.
        expect(Stores.pve.fetch(server.id), pve);
      });

      test('a new backup carries PVE only in its section', () async {
        Stores.server.put(server);
        Stores.pve.put(server.id, pve);

        final raw =
            json.decode((await BackupV2.loadFromStore()).toJsonString())
                as Map<String, dynamic>;
        for (final MapEntry(:key, :value) in (raw['spis'] as Map).entries) {
          if (value is! Map) continue;
          expect((value['custom'] as Map?)?['pveAddr'], isNull, reason: '$key');
        }
        expect(raw['pve'][server.id], isA<Map>());
      });

      test('the committed v33 backup restores without inventing PVE', () async {
        final file = BackupV2.fromJsonString(
          File('test/fixtures/backup/backup_v4.json').readAsStringSync(),
        );
        expect(file.carriesPveSection, isTrue);
        expect(file.pve, isEmpty);

        await file.merge(force: true);

        expect(Stores.server.fetchOneRaw('srv-fixture')?.name, 'fixture');
        expect(Stores.pve.fetchAll(), isEmpty);
      });

      test('removing PVE still reaches another new build', () async {
        Stores.server.put(server);
        final raw =
            json.decode((await BackupV2.loadFromStore()).toJsonString())
                as Map<String, dynamic>;
        // The file is the other device after it removed PVE: a newer record,
        // no `pve` entry, and no legacy fields either.
        final ts = raw['spis'][StoreDefaults.defaultLastUpdateTsKey] as Map;
        ts[server.id] = (ts[server.id] as int) + 60000;
        Stores.pve.put(server.id, pve);

        await BackupV2.fromJson(raw).merge();

        expect(Stores.pve.fetch(server.id), isNull);
      });

      test('a restored row keeps the timestamp the file carried', () async {
        Stores.server.put(server);
        Stores.pve.put(server.id, pve);
        final raw =
            json.decode((await BackupV2.loadFromStore()).toJsonString())
                as Map<String, dynamic>;
        final ts = raw['spis'][StoreDefaults.defaultLastUpdateTsKey] as Map;
        final incoming = (ts[server.id] as int) + 60000;
        ts[server.id] = incoming;
        (raw['pve'] as Map)[server.id] = pve
            .copyWith(tokenId: 'root@pam!other')
            .toJson();

        await BackupV2.fromJson(raw).merge();

        expect(Stores.pve.fetch(server.id)?.tokenId, 'root@pam!other');
        // Stamped with now, an older file would outrank a later edit made
        // on another device.
        expect(Stores.server.timestamps[server.id], incoming);
      });

      test('an unreadable entry leaves the credentials here', () async {
        Stores.server.put(server);
        Stores.pve.put(server.id, pve);
        for (final bad in <Object>[
          {'auth': 'token'},
          'not an object',
        ]) {
          final raw =
              json.decode((await BackupV2.loadFromStore()).toJsonString())
                  as Map<String, dynamic>;
          final ts = raw['spis'][StoreDefaults.defaultLastUpdateTsKey] as Map;
          ts[server.id] = (ts[server.id] as int) + 60000;
          (raw['pve'] as Map)[server.id] = bad;

          await BackupV2.fromJson(raw).merge();

          expect(Stores.pve.fetch(server.id), pve, reason: '$bad');
        }
      });

      test('a server deleted by a merge is announced to PVE', () async {
        // This group's database is opened without it; the cascade is the
        // subject here.
        SqliteDb.instance.execute('PRAGMA foreign_keys = ON;');
        Stores.server.put(server);
        Stores.pve.put(server.id, pve);
        final raw =
            json.decode((await BackupV2.loadFromStore()).toJsonString())
                as Map<String, dynamic>;
        final spis = raw['spis'] as Map;
        final ts = spis[StoreDefaults.defaultLastUpdateTsKey] as Map;
        ts[server.id] = (ts[server.id] as int) + 60000;
        spis.remove(server.id);
        (raw['pve'] as Map).remove(server.id);

        var events = 0;
        final sub = Stores.pve.watch().listen((_) => events++);
        addTearDown(sub.cancel);

        await BackupV2.fromJson(raw).merge();
        await Future<void>.delayed(Duration.zero);

        expect(Stores.server.fetchOneRaw(server.id), isNull);
        expect(Stores.pve.fetchAll(), isEmpty);
        expect(events, greaterThan(0));
      });
    });

    test('leaves the Agent local-exec permission out of the file', () async {
      Stores.setting.agentLocalExec.put(true);

      final backup = await BackupV2.loadFromStore();

      expect(backup.settings.containsKey('agentLocalExec'), isFalse);
    });

    test('and does not take it from one either', () async {
      Stores.setting.agentLocalExec.put(false);

      final backup = BackupV2(
        version: BackupV2.formatVer,
        date: 1,
        spis: const {},
        snippets: const {},
        keys: const {},
        container: const {},
        history: const {},
        settings: {
          'agentLocalExec': true,
          'timeOut': 9,
          Stores.setting.lastUpdateTsKey: <String, int>{},
        },
      );
      await backup.merge(force: true);

      expect(Stores.setting.agentLocalExec.fetch(), isFalse);
      expect(Stores.setting.timeout.fetch(), 9, reason: 'the rest still lands');
    });

    test('the Live Activity switch travels no further either', () async {
      // Same rule, one screen out: it decides whether a server's name and the
      // state of a connection to it are readable without unlocking. Restoring
      // one phone's backup onto a second would otherwise start putting them on
      // that phone's lock screen with nobody having decided it.
      Stores.setting.liveActivity.put(true);

      final backup = await BackupV2.loadFromStore();

      expect(backup.settings.containsKey('liveActivity'), isFalse);
    });

    test('and a file cannot switch it on or off', () async {
      // Both directions, because this one is iOS-only: a backup taken on
      // Android carries the untouched default, and letting that land would
      // switch it *off* on an iPhone that had it on.
      for (final (before, inFile) in [(false, true), (true, false)]) {
        Stores.setting.liveActivity.put(before);

        final backup = BackupV2(
          version: BackupV2.formatVer,
          date: 1,
          spis: const {},
          snippets: const {},
          keys: const {},
          container: const {},
          history: const {},
          settings: {
            'liveActivity': inFile,
            'timeOut': 9,
            Stores.setting.lastUpdateTsKey: <String, int>{},
          },
        );
        await backup.merge(force: true);

        expect(
          Stores.setting.liveActivity.fetch(),
          before,
          reason: 'a backup holding $inFile changed a device answering $before',
        );
      }
    });

    test('a file carrying no settings leaves the local ones alone', () async {
      Stores.setting.homeTabs.put(const [
        AppTab.server,
        AppTab.ssh,
        AppTab.file,
        AppTab.snippet,
      ]);

      final backup = BackupV2(
        version: BackupV2.formatVer,
        date: 1,
        spis: const {},
        snippets: const {},
        keys: const {},
        container: const {},
        history: const {},
        settings: const {},
      );
      await backup.merge(force: true);

      expect(Stores.setting.homeTabs.fetch(), const [
        AppTab.server,
        AppTab.ssh,
        AppTab.file,
        AppTab.snippet,
      ]);
    });

    test('a settings step runs only on a file older than it', () async {
      // m021 reads any bar of exactly the old five tabs as the old default;
      // on a file written after it, that bar is the user's choice.
      const five = ['server', 'ssh', 'file', 'snippet', 'agent'];
      BackupV2 withTabs(int version) => BackupV2(
        version: version,
        date: 1,
        spis: const {},
        snippets: const {},
        keys: const {},
        container: const {},
        history: const {},
        settings: {
          'homeTabs': five,
          Stores.setting.lastUpdateTsKey: <String, int>{},
        },
      );

      await withTabs(BackupV2.formatVer).merge(force: true);
      expect(
        [for (final t in Stores.setting.homeTabs.fetch()) t.name],
        five,
      );

      await withTabs(HomeTabsBarMigration.appliedAt).merge(force: true);
      expect(
        [for (final t in Stores.setting.homeTabs.fetch()) t.name],
        five.take(4),
      );
    });

    test('does not apply device-local markers from an older backup', () async {
      const importMarker = '${StoreDefaults.prefixKey}hiveImported';
      Stores.setting.set(importMarker, true, updateLastUpdateTsOnSet: false);
      final originalSchema = SchemaVersion.stored;

      final backup = BackupV2(
        version: BackupV2.formatVer,
        date: 1,
        spis: const {},
        snippets: const {},
        keys: const {},
        container: const {},
        history: const {},
        settings: {
          importMarker: false,
          Stores.setting.schemaVersion.key: 2,
          Stores.setting.lastUpdateTsKey: <String, int>{},
        },
      );
      await backup.merge(force: true);

      expect(Stores.setting.get<bool>(importMarker), isTrue);
      expect(SchemaVersion.stored, originalSchema);
    });

    test('regroups the settings a pre-grouping backup brings back', () async {
      Stores.setting.set('askAi', {'model': 'current-model'});
      await Stores.setting.agentShell.width.set(999);

      final backup = BackupV2(
        version: const GroupedSettingsMigration().from,
        date: 1,
        spis: const {},
        snippets: const {},
        keys: const {},
        container: const {},
        history: const {},
        settings: {
          'askAiModel': 'from-backup',
          'askAiApiKey': 'sk-from-backup',
          'agentShellWidth': 321.0,
          Stores.setting.lastUpdateTsKey: <String, int>{},
        },
      );
      await backup.merge(force: true);

      // As the plain map `LegacyAskAiMigration` takes over at launch.
      expect(Stores.setting.get<Object>('askAi'), {
        'model': 'from-backup',
        'apiKey': 'sk-from-backup',
      });
      expect(Stores.setting.agentShell.width.get(), 321.0);
      expect(Stores.setting.get<Object>('askAiModel'), isNull);
      expect(Stores.setting.get<Object>('agentShellWidth'), isNull);
    });

    test('versions the AI endpoint a pre-m022 backup brings back', () async {
      final backup = BackupV2(
        version: AiEndpointVersionMigration.appliedAt,
        date: 1,
        spis: const {},
        snippets: const {},
        keys: const {},
        container: const {},
        history: const {},
        settings: {
          'askAi': {
            'baseUrl': 'https://api.openai.com',
            'apiKey': 'sk-from-backup',
            'model': 'gpt-5.6-luna',
          },
          Stores.setting.lastUpdateTsKey: <String, int>{},
        },
      );
      await backup.merge(force: true);

      // Unversioned, `LegacyAskAiMigration` makes it a provider that 404s.
      expect(
        (Stores.setting.get<Object>('askAi')! as Map)['baseUrl'],
        'https://api.openai.com/v1',
      );
    });

    test('restore settings steps are schema steps, in schema order', () {
      final froms = [for (final m in kRestoreSettingsMigrations) m.from];
      expect(froms, [...froms]..sort());
      expect(froms.toSet(), hasLength(froms.length));
      for (final step in kRestoreSettingsMigrations) {
        expect(
          kSchemaMigrations.where((m) => m.runtimeType == step.runtimeType),
          hasLength(1),
          reason: '${step.runtimeType}',
        );
      }
    });

    test(
      'rewrites a legacy key-name server reference to the local key id',
      () async {
        Stores.key.put(
          const PrivateKeyInfo(
            id: 'generated-local-id',
            name: 'work',
            key: 'LOCAL',
          ),
        );
        final server = const Spi(
          id: 'srv-1',
          name: 'prod',
          ssh: SshCredential(ip: '10.0.0.1', keyId: 'work'),
        );
        final backup = BackupV2(
          version: BackupV2.formatVer,
          date: 1,
          spis: {
            'srv-1': json.decode(
              json.encode(
                server.toJson(),
                toEncodable: (value) => (value as dynamic).toJson(),
              ),
            ),
          },
          snippets: const {},
          keys: const {
            'work': {'name': 'work', 'private_key': 'BACKUP'},
          },
          container: const {},
          history: const {},
          settings: const {},
        );

        await backup.merge(force: true);

        expect(
          Stores.server.fetchOneRaw('srv-1')?.ssh?.keyId,
          'generated-local-id',
        );
      },
    );

    test(
      'same-name servers keep the local id across restored references',
      () async {
        const local = Spi(
          id: 'local-server-id',
          name: 'prod',
          ssh: SshCredential(ip: '10.0.0.1'),
        );
        Stores.server.put(local);
        final incoming = local.copyWith(
          id: 'backup-server-id',
          ssh: const SshCredential(ip: '10.0.0.2'),
        );
        const snippet = Snippet(
          id: 'snippet-1',
          name: 'deploy',
          script: 'echo deploy',
          autoRunOn: ['backup-server-id'],
        );
        const forward = PortForwardConfig(
          id: 'forward-1',
          serverId: 'backup-server-id',
          name: 'web',
          type: PortForwardType.local,
          localPort: 8080,
        );
        const remoteDesktop = RemoteDesktopProfile(
          id: 'desktop-1',
          serverId: 'backup-server-id',
          name: 'Windows',
          protocol: RemoteDesktopProtocol.rdp,
          port: 3389,
        );
        final backup = BackupV2(
          version: BackupV2.formatVer,
          date: 1,
          spis: {
            'legacy-prod-key': json.decode(
              json.encode(
                incoming.toJson(),
                toEncodable: (value) => (value as dynamic).toJson(),
              ),
            ),
          },
          snippets: {'snippet-1': snippet.toJson()},
          keys: const {},
          portForwards: {'forward-1': forward.toJson()},
          remoteDesktopProfiles: {'desktop-1': remoteDesktop.toJson()},
          container: const {
            'backup-server-id': {'host_docker': 'tcp://10.0.0.2:2375'},
          },
          history: {
            'sshServerHistory': ['backup-server-id'],
            'sshTabs': json.encode([
              {'sourceId': 'backup-server-id'},
            ]),
          },
          settings: const {},
        );

        await backup.merge(force: true);

        expect(Stores.server.fetch(), hasLength(1));
        expect(Stores.server.fetch().single.id, local.id);
        expect(Stores.server.fetch().single.ssh?.ip, '10.0.0.2');
        expect(Stores.snippet.fetch().single.autoRunOn, [local.id]);
        expect(
          Stores.portForward.fetchForServer(local.id).single.id,
          forward.id,
        );
        expect(
          Stores.remoteDesktop.fetchForServer(local.id).single.id,
          remoteDesktop.id,
        );
        expect(
          Stores.container.fetch(local.id, ContainerType.docker),
          'tcp://10.0.0.2:2375',
        );
        expect(Stores.history.get<List>('sshServerHistory'), isNull);
        expect(Stores.history.get<String>('sshTabs'), isNull);
      },
    );

    test(
      'rejects duplicate embedded server ids before writing stores',
      () async {
        const first = Spi(
          id: 'shared-backup-id',
          name: 'first',
          ssh: SshCredential(ip: '10.0.0.1'),
        );
        const second = Spi(
          id: 'shared-backup-id',
          name: 'second',
          ssh: SshCredential(ip: '10.0.0.2'),
        );
        Map<String, Object?> stored(Spi server) => Map<String, Object?>.from(
          json.decode(
                json.encode(
                  server.toJson(),
                  toEncodable: (value) => (value as dynamic).toJson(),
                ),
              )
              as Map,
        );

        final backup = BackupV2(
          version: BackupV2.formatVer,
          date: 1,
          spis: {'first-key': stored(first), 'second-key': stored(second)},
          snippets: const {
            'snippet-duplicate': {
              'id': 'snippet-duplicate',
              'name': 'duplicate',
              'script': 'echo duplicate',
              'autoRunOn': ['first-key'],
            },
          },
          keys: const {},
          portForwards: const {
            'forward-duplicate': {
              'id': 'forward-duplicate',
              'serverId': 'second-key',
              'name': 'duplicate',
              'type': 'local',
              'localPort': 8080,
            },
          },
          container: const {
            'first-key': {'host_docker': 'tcp://10.0.0.1:2375'},
          },
          history: const {},
          settings: const {},
        );

        await expectLater(
          backup.merge(force: true),
          throwsA(isA<FormatException>()),
        );
        expect(Stores.server.fetch(), isEmpty);
        expect(Stores.snippet.fetch(), isEmpty);
        expect(Stores.portForward.fetch(), isEmpty);
        expect(
          Stores.container.fetch('shared-backup-id', ContainerType.docker),
          isNull,
        );
      },
    );

    test(
      'rolls every store back when a later store cannot be written',
      () async {
        const original = Spi(
          id: 'srv-atomic',
          name: 'before',
          ssh: SshCredential(ip: '10.0.0.1'),
        );
        Stores.server.put(original);
        final replacement = original.copyWith(name: 'after');
        final stored = json.decode(
          json.encode(
            replacement.toJson(),
            toEncodable: (value) => (value as dynamic).toJson(),
          ),
        );
        final backup = BackupV2(
          version: BackupV2.formatVer,
          date: 1,
          spis: {'srv-atomic': stored},
          snippets: const {},
          keys: const {},
          container: const {},
          history: {'cannot-encode': _NotJsonEncodable()},
          settings: const {},
        );

        await expectLater(
          backup.merge(force: true),
          throwsA(isA<UnsupportedError>()),
        );
        Stores.server.dropCache();
        expect(Stores.server.fetchOneRaw('srv-atomic'), original);
        expect(Stores.history.get<Object>('cannot-encode'), isNull);
      },
    );

    test('rolls every store back when a settings conversion fails', () async {
      const original = Spi(
        id: 'srv-conversion-atomic',
        name: 'before',
        ssh: SshCredential(ip: '10.0.0.1'),
      );
      Stores.server.put(original);
      final replacement = original.copyWith(name: 'after');
      final stored = json.decode(
        json.encode(
          replacement.toJson(),
          toEncodable: (value) => (value as dynamic).toJson(),
        ),
      );
      SqliteDb.instance.execute('''
        CREATE TRIGGER fail_restored_ssh_mode_conversion
        BEFORE UPDATE OF value ON kv
        WHEN NEW.store = 'setting'
          AND NEW.key = 'sshConnectionMode'
          AND NEW.value IN ('true', 'false')
        BEGIN
          SELECT RAISE(ABORT, 'blocked conversion');
        END;
      ''');
      final backup = BackupV2(
        version: SettingsFixupsMigration.appliedAt,
        date: 1,
        spis: {'srv-conversion-atomic': stored},
        snippets: const {},
        keys: const {},
        container: const {},
        history: const {},
        settings: const {'sshConnectionMode': 0},
      );

      await expectLater(backup.merge(force: true), throwsStateError);
      Stores.server.dropCache();
      expect(Stores.server.fetchOneRaw(original.id), original);
      expect(
        SqliteDb.instance
            .select(
              'SELECT count(*) AS n FROM kv '
              "WHERE store = 'setting' AND key = 'sshConnectionMode';",
            )
            .single['n'],
        0,
      );
    });

    test(
      'container restore removes hosts and runtime omitted by the backup',
      () async {
        const server = Spi(
          id: 'srv-container',
          name: 'container-host',
          ssh: SshCredential(ip: '10.0.0.2'),
        );
        Stores.server.put(server);
        Stores.container.put(
          server.id,
          ContainerType.docker,
          'tcp://old-docker:2375',
        );
        Stores.container.put(
          server.id,
          ContainerType.podman,
          'tcp://old-podman:2375',
        );
        Stores.container.setType(ContainerType.podman, server.id);
        final stored = json.decode(
          json.encode(
            server.toJson(),
            toEncodable: (value) => (value as dynamic).toJson(),
          ),
        );
        final backup = BackupV2(
          version: BackupV2.formatVer,
          date: 1,
          spis: {server.id: stored},
          snippets: const {},
          keys: const {},
          container: const {
            'srv-container': {'host_docker': 'tcp://new-docker:2375'},
          },
          history: const {},
          settings: const {},
        );

        await backup.merge(force: true);

        expect(
          Stores.container.fetch(server.id, ContainerType.docker),
          'tcp://new-docker:2375',
        );
        expect(Stores.container.fetch(server.id, ContainerType.podman), isNull);
        expect(
          SqliteDb.instance.select(
            'SELECT count(*) AS n FROM container_runtime WHERE server_id = ?;',
            [server.id],
          ).single['n'],
          0,
        );
      },
    );
  });
}

final class _NotJsonEncodable {}

final class _ThrowingPrivateKeyInfo extends PrivateKeyInfo {
  const _ThrowingPrivateKeyInfo()
    : super(
        id: 'bad',
        name: 'bad',
        key: '-----BEGIN OPENSSH PRIVATE KEY-----\nbad',
      );

  @override
  Map<String, dynamic> toJson() => throw StateError('broken toJson');
}
