import 'dart:convert';
import 'dart:io';

import 'package:fl_lib/fl_lib.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/core/sync/key.dart';
import 'package:server_box/core/sync/sync.dart';
import 'package:server_box/data/model/app/bak/backup2.dart';
import 'package:server_box/data/res/misc.dart';
import 'package:server_box/data/store/stores.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/sync_key.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('sbm-backup-sync-');
    Paths.doc = tempDir.path;
    SharedPreferences.setMockInitialValues({});
    await PrefStore.shared.init();
  });

  tearDownAll(() async => tempDir.delete(recursive: true));

  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({});
    SqliteDb.openInMemory();
    await Stores.init();
  });

  tearDown(() async {
    SyncKey.resetForTest();
    await getIt.reset();
    await SqliteDb.close();
  });

  test('the synced backup is sealed to the key; an export to the password, as age -d opens it', () async {
    FlutterSecureStorage.setMockInitialValues({
      SecureStoreProps.bakPwd.key: 'remote-password',
    });
    final key = await SyncKey.of(MemoryKeyFile());

    final synced = await File(await BackupV2.backup(null, null, key: key)).readAsBytes();
    expect(SyncKey.sealedToKey(synced), isTrue);
    await expectLater(BackupV2.unlock(synced, 'remote-password'), throwsA(isA<Object>()));
    expect(BackupV2.fromPlainBytes(await key.open(synced)).version, BackupV2.formatVer);

    final export = await BackupV2.backup(null, 'remote-password');
    expect(export, endsWith(Miscs.exportBakFileName));
    final content = await File(export).readAsString();
    // Armored age, as `age -p -a` writes it.
    expect(content, startsWith(AgeCryptor.armorHeader));
    expect(SyncKey.sealedToKey(utf8.encode(content)), isFalse);
    expect(
      (await BackupV2.open(utf8.encode(content), 'remote-password')).version,
      BackupV2.formatVer,
    );
  });

  test('a v4 remote, sealed with the password, and a plaintext one are read to be inherited', () async {
    FlutterSecureStorage.setMockInitialValues({
      SecureStoreProps.bakPwd.key: 'remote-password',
    });
    await PrefProps.syncAppSettings.set(true);
    addTearDown(() => PrefProps.syncAppSettings.set(false));
    final backup = BackupV2(
      version: BackupV2.formatVer,
      date: 123,
      spis: const {},
      snippets: const {},
      keys: const {},
      container: const {},
      history: const {},
      settings: const {'timeOut': 17},
    );
    final plainFile = File(tempDir.path.joinPath('legacy-plaintext.json'));
    await plainFile.writeAsString(backup.toJsonString());
    final v4 = File(tempDir.path.joinPath('v4.age'));
    await v4.writeAsString(await AgeCryptor.encrypt(gzip.encode(utf8.encode(backup.toJsonString())), 'remote-password'));

    for (final file in [plainFile, v4]) {
      final restored = await bakSync.fromFile(file.path);
      expect(restored, isA<BackupV2>(), reason: file.path);
      expect((restored as BackupV2).settings['timeOut'], 17, reason: file.path);
    }
  });
}
