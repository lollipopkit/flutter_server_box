import 'dart:io';

import 'package:fl_lib/fl_lib.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/core/sync.dart';
import 'package:server_box/data/model/app/bak/backup2.dart';
import 'package:server_box/data/res/store.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
    await getIt.reset();
    await SqliteDb.close();
  });

  test('remote backup writes require a non-empty password', () async {
    final path = tempDir.path.joinPath('missing-password.json');

    await expectLater(
      bakSync.writeEncryptedBackup(name: 'missing-password.json'),
      throwsA(isA<StateError>()),
    );

    expect(File(path).existsSync(), isFalse);
  });

  test('every new remote backup write is encrypted', () async {
    FlutterSecureStorage.setMockInitialValues({
      SecureStoreProps.bakPwd.key: 'remote-password',
    });

    final path = await bakSync.writeEncryptedBackup(name: 'encrypted.json');
    final content = await File(path).readAsString();

    expect(Cryptor.isEncrypted(content), isTrue);
    expect(
      BackupV2.fromJsonString(content, 'remote-password').version,
      BackupV2.formatVer,
    );
  });

  test('a legacy plaintext remote backup remains readable', () async {
    FlutterSecureStorage.setMockInitialValues({
      SecureStoreProps.bakPwd.key: 'remote-password',
    });
    await PrefProps.syncAppSettings.set(true);
    addTearDown(() => PrefProps.syncAppSettings.set(false));
    final plaintext = BackupV2(
      version: BackupV2.formatVer,
      date: 123,
      spis: const {},
      snippets: const {},
      keys: const {},
      container: const {},
      history: const {},
      settings: const {'timeOut': 17},
    ).toJsonString();
    final legacyFile = File(tempDir.path.joinPath('legacy-plaintext.json'));
    await legacyFile.writeAsString(plaintext);

    final restored = await bakSync.fromFile(legacyFile.path);

    expect(restored, isA<BackupV2>());
    final legacyBackup = restored as BackupV2;
    expect(legacyBackup.date, 123);
    expect(legacyBackup.settings['timeOut'], 17);
    await legacyBackup.merge(force: true);

    final replacementPath = await bakSync.writeEncryptedBackup(
      name: 'replacement.json',
    );
    final replacement = await File(replacementPath).readAsString();
    expect(Cryptor.isEncrypted(replacement), isTrue);
    expect(
      BackupV2.fromJsonString(
        replacement,
        'remote-password',
      ).settings['timeOut'],
      17,
      reason: 'the encrypted replacement must retain the restored data',
    );
  });
}
