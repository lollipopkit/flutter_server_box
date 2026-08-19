import 'dart:io';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:fl_lib/fl_lib.dart';
import 'package:server_box/data/model/app/bak/backup2.dart';
import 'package:server_box/data/model/app/tab.dart';
import 'package:server_box/data/model/server/private_key_info.dart';
import 'package:server_box/data/model/server/server_private_info.dart';
import 'package:server_box/data/model/server/snippet.dart';
import 'package:server_box/data/res/store.dart';
import 'package:server_box/data/store/schema.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('BackupV2 JSON encoding', () {
    test('serializes typed store objects as JSON objects', () {
      final backup = BackupV2(
        version: BackupV2.formatVer,
        date: 1,
        spis: {'server': Spix.example},
        snippets: {'snippet': Snippet.example},
        keys: {
          'key': const PrivateKeyInfo(
            id: 'key',
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
  });
}

final class _NotJsonEncodable {}

final class _ThrowingPrivateKeyInfo extends PrivateKeyInfo {
  const _ThrowingPrivateKeyInfo()
    : super(id: 'bad', key: '-----BEGIN OPENSSH PRIVATE KEY-----\nbad');

  @override
  Map<String, dynamic> toJson() => throw StateError('broken toJson');
}
