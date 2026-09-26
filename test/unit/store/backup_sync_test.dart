import 'dart:async';
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
      await remote.readAsString(),
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

  test('a sync nobody waits for handles its own network failure', () async {
    // What every edit starts. The remote not answering used to reach the
    // zone as an uncaught error (SERVERBOX-8B).
    Stores.setting.timeout.put(17);
    if (remote.existsSync()) remote.deleteSync();
    final uncaught = <Object>[];
    final rs = _FileRemote(
      remote,
      uploadError: const SocketException('Connection refused'),
    );
    // The assertions stay outside: a failure inside the guarded zone goes to
    // its handler, and the zone's future then never completes.
    await runZonedGuarded(() async {
      bakSync.syncSoon(rs: rs);
      // Its one-second delay, then the base's five-second throttle.
      await Future<void>.delayed(const Duration(milliseconds: 6500));
    }, (e, _) => uncaught.add(e));

    expect(rs.uploads, 1, reason: 'the upload was attempted and failed');
    expect(uncaught, isEmpty);
  });

  test('without a backup password nothing is attempted', () async {
    // Syncs start on every edit and nobody awaits them, so a missing
    // password used to surface as an unhandled error per edit.
    FlutterSecureStorage.setMockInitialValues({});
    Stores.setting.timeout.put(17);
    await remote.writeAsString('not read');
    final rs = _FileRemote(remote);

    await bakSync.sync(throttleMilli: 0, rs: rs);

    expect(rs.downloads, 0);
    expect(rs.uploads, 0);
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

/// Serves [file] as the remote backup: a download copies it out, an upload
/// copies over it.
final class _FileRemote extends RemoteStorage<String> {
  _FileRemote(this.file, {this.uploadError});

  final File file;
  final Object? uploadError;
  int downloads = 0;
  int uploads = 0;

  @override
  Future<void> download({
    required String relativePath,
    String? localPath,
  }) async {
    downloads++;
    await file.copy(localPath ?? Paths.bak);
  }

  @override
  Future<void> upload({
    required String relativePath,
    String? localPath,
  }) async {
    uploads++;
    if (uploadError case final e?) throw e;
    await File(localPath ?? Paths.bak).copy(file.path);
  }

  @override
  Future<bool> exists(String relativePath) => file.exists();

  @override
  Future<void> delete(String relativePath) async {}

  @override
  Future<List<String>> list() async => const [];
}
