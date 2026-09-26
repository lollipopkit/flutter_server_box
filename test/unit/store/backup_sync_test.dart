import 'dart:io';

import 'package:fl_lib/fl_lib.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/core/sync.dart';
import 'package:server_box/data/model/app/bak/backup2.dart';
import 'package:server_box/data/res/misc.dart';
import 'package:server_box/data/res/store.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A full `bakSync.sync` cycle against a remote holding [remote], which is
/// where #1562 lived: `fromFile` used to run inside `compute`, so the
/// "Sync app settings" pref read there answered its default and every synced
/// setting was dropped before the merge, with no error anywhere.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late File remote;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('sbm-backup-sync-');
    Paths.doc = tempDir.path;
    Paths.bakName = Miscs.bakFileName;
    Paths.bak = tempDir.path.joinPath(Miscs.bakFileName);
    remote = File(tempDir.path.joinPath('remote.json'));
    SharedPreferences.setMockInitialValues({});
    await PrefStore.shared.init();
  });

  tearDownAll(() async => tempDir.delete(recursive: true));

  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({
      SecureStoreProps.bakPwd.key: 'remote-password',
    });
    SqliteDb.openInMemory();
    await Stores.init();
    await PrefProps.syncAppSettings.set(true);
  });

  tearDown(() async {
    await PrefProps.syncAppSettings.set(false);
    await getIt.reset();
    await SqliteDb.close();
  });

  /// Replaces this device's data with an empty one, as a second device that
  /// has never been edited.
  Future<void> becomeAnotherDevice() async {
    await getIt.reset();
    await SqliteDb.close();
    SqliteDb.openInMemory();
    await Stores.init();
  }

  test('a synced setting from another device is applied', () async {
    Stores.setting.timeout.put(17);
    final written = await bakSync.writeEncryptedBackup(name: 'remote.json');
    expect(written, remote.path);
    await becomeAnotherDevice();
    expect(Stores.setting.timeout.fetch(), 5);

    final rs = _FileRemote(remote);
    await bakSync.sync(throttleMilli: 0, rs: rs);

    expect(Stores.setting.timeout.fetch(), 17);
    expect(rs.uploads, 1);
    final uploaded = BackupV2.fromJsonString(
      await File(Paths.bak).readAsString(),
      'remote-password',
    );
    expect(
      uploaded.settings['timeOut'],
      17,
      reason: 'the upload must carry the settings it merged',
    );
  });

  test('a synced setting is not applied with the switch off', () async {
    Stores.setting.timeout.put(17);
    await bakSync.writeEncryptedBackup(name: 'remote.json');
    await becomeAnotherDevice();
    await PrefProps.syncAppSettings.set(false);

    await bakSync.sync(throttleMilli: 0, rs: _FileRemote(remote));

    expect(Stores.setting.timeout.fetch(), 5);
  });

  test('a remote from a newer build is recorded and not uploaded over', () async {
    await remote.writeAsString(
      '{"version": ${BackupV2.formatVer + 1}, "date": 0}',
    );
    final rs = _FileRemote(remote);

    await bakSync.sync(throttleMilli: 0, rs: rs);

    expect(BakSyncer.remoteTooNew, isNotNull);
    expect(rs.uploads, 0);
  });
}

/// Serves [file] as the remote backup and counts uploads.
final class _FileRemote extends RemoteStorage<String> {
  _FileRemote(this.file);

  final File file;
  int uploads = 0;

  @override
  Future<void> download({
    required String relativePath,
    String? localPath,
  }) => file.copy(localPath ?? Paths.bak);

  @override
  Future<void> upload({
    required String relativePath,
    String? localPath,
  }) async => uploads++;

  @override
  Future<bool> exists(String relativePath) => file.exists();

  @override
  Future<void> delete(String relativePath) async {}

  @override
  Future<List<String>> list() async => const [];
}
