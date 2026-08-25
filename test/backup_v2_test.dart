import 'dart:convert';
import 'dart:io';

import 'package:fl_lib/fl_lib.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/data/model/app/bak/backup2.dart';
import 'package:server_box/data/model/app/tab.dart';
import 'package:server_box/data/model/server/bmc_cfg.dart';
import 'package:server_box/data/model/server/port_forward.dart';
import 'package:server_box/data/model/server/private_key_info.dart';
import 'package:server_box/data/model/server/server_private_info.dart';
import 'package:server_box/data/model/server/snippet.dart';
import 'package:server_box/data/model/server/ssh_credential.dart';
import 'package:server_box/data/res/store.dart';
import 'package:server_box/data/store/schema.dart';

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
      expect(restored.bmc, const BmcCfg(
        addr: 'https://10.0.0.9',
        credId: 'cred-1',
        certSha256: 'ab12',
      ));
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
  });

  group('BackupV2 store export', () {
    late Directory tempDir;

    setUpAll(() async {
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
      expect(backup.settings.containsKey(Stores.setting.schemaVersion.key), isFalse);
      expect(backup.settings.containsKey(Stores.setting.lastUpdateTsKey), isTrue);
      expect(backup.settings['timeOut'], 11);
    });

    test('leaves the Agent local-exec permission out of the file', () async {
      // "The Agent may run commands on *this* device" is a question about the
      // machine, and a backup file does not know which machine it is being
      // read on. It exported as an ordinary settings row, so a file written
      // where the Agent had been let loose turned it on wherever it landed.
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

    test('a file carrying no settings leaves the local ones alone', () async {
      // `includeSettings: false`. The three settings migrations convert what
      // *arrived*; run over the local settings anyway, `_migrateHomeTabsAgent`
      // put Agent back for somebody who had taken it out.
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
      // A restore is neither a launch nor a version bump, so nothing else
      // looks at what lands. This file carries the old per-field keys and no
      // grouped row; `mergeStore` reads an absent key as a deletion, so a
      // forced restore takes `askAi` and `agentShell` out and writes fourteen
      // rows nothing reads in their place. `schemaVersion` is kept out of the
      // merge, so it stays put and the migrator would never fold them again.
      await Stores.setting.askAiModel.set('current-model');
      await Stores.setting.agentShellWidth.set(999);

      final backup = BackupV2(
        version: BackupV2.formatVer,
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

      expect(Stores.setting.askAiModel.get(), 'from-backup');
      expect(Stores.setting.askAiApiKey.get(), 'sk-from-backup');
      expect(Stores.setting.agentShellWidth.get(), 321.0);
      // And the old keys do not survive to be exported all over again.
      expect(Stores.setting.get<Object>('askAiModel'), isNull);
      expect(Stores.setting.get<Object>('agentShellWidth'), isNull);
    });

    test('rewrites a legacy key-name server reference to the local key id',
        () async {
      Stores.key.put(const PrivateKeyInfo(
        id: 'generated-local-id',
        name: 'work',
        key: 'LOCAL',
      ));
      final server = const Spi(
        id: 'srv-1',
        name: 'prod',
        ssh: SshCredential(
          ip: '10.0.0.1',
          keyId: 'work',
        ),
      );
      final backup = BackupV2(
        version: BackupV2.formatVer,
        date: 1,
        spis: {
          'srv-1': json.decode(json.encode(
            server.toJson(),
            toEncodable: (value) => (value as dynamic).toJson(),
          )),
        },
        snippets: const {},
        keys: const {
          'work': {'id': 'work', 'private_key': 'BACKUP'},
        },
        container: const {},
        history: const {},
        settings: const {},
      );

      await backup.merge(force: true);

      expect(Stores.server.fetchOneRaw('srv-1')?.ssh?.keyId,
          'generated-local-id');
    });
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
