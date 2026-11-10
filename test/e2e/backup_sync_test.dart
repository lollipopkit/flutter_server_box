/// Opt-in end-to-end test of the backup sync (#1772) against a real WebDAV,
/// configured as the backup page does: the upload is sealed to the sync key
/// under the v5 name, the key in `srvbox_sync/identity.age` sealed with the
/// backup password; another device restores it, and a remote holding only
/// an older name is inherited once and moved to v5.
///
/// In the environment or the workspace-root `.env`: `SBM_E2E_WEBDAV_URL`,
/// `_USER`, `_PASSWORD`; `SBM_E2E_BACKUP_OUT`: a directory the uploaded
/// backup and its key file are copied to, for the `age` CLI to open.
///
/// `scripts/app-backup-e2e.sh` starts rclone's WebDAV and runs this against
/// it. What it puts on the remote it removes.
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:fl_lib/fl_lib.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/core/sync/file_log.dart';
import 'package:server_box/core/sync/key.dart';
import 'package:server_box/core/sync/remotes.dart';
import 'package:server_box/core/sync/sync.dart';
import 'package:server_box/data/model/app/bak/backup2.dart';
import 'package:server_box/data/model/app/error.dart';
import 'package:server_box/data/model/server/server_private_info.dart';
import 'package:server_box/data/model/server/ssh_credential.dart';
import 'package:server_box/data/res/misc.dart';
import 'package:server_box/data/store/stores.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/rust_lib_helper.dart';
import '../helpers/ssh_e2e.dart';

const _password = 'e2e-backup-password';

/// The fixture's: `test/fixtures/backup/README.md`.
const _fixturePassword = 'fixture-password';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final webdav = (
    url: e2eEnv('SBM_E2E_WEBDAV_URL'),
    user: e2eEnv('SBM_E2E_WEBDAV_USER'),
    pwd: e2eEnv('SBM_E2E_WEBDAV_PASSWORD'),
  );
  if (webdav.url == null) {
    test('backup sync e2e', () {}, skip: 'SBM_E2E_WEBDAV_URL is not set');
    return;
  }

  late Directory dir;
  late RemoteStorage rs;

  /// This device's data replaced by an empty one, as a second device.
  Future<void> becomeDevice() async {
    await getIt.reset();
    await SqliteDb.close();
    SqliteDb.openInMemory();
    await Stores.init();
    SyncKey.resetForTest();
    SecureProp.resetRateLimits();
    SyncRemotes.setWebdav(url: webdav.url!, user: webdav.user ?? '', pwd: webdav.pwd ?? '');
  }

  Future<void> removeOurs() async {
    for (final name in [Miscs.bakFileName, ...Miscs.legacyBakFileNames]) {
      if (await rs.exists(name)) await rs.delete(name);
    }
    await WebdavSyncFiles(() => SyncRemotes.webdav).deleteBlob('identity.age');
    SyncKey.resetForTest();
  }

  Future<List<int>> downloaded(String name) async {
    final local = dir.path.joinPath('downloaded-$name');
    await rs.download(relativePath: name, localPath: local);
    return File(local).readAsBytes();
  }

  setUpAll(() async {
    // The test binding answers every HTTP request 400; this one is real.
    HttpOverrides.global = null;
    await initRustLibForTest();
    dir = await Directory.systemTemp.createTemp('sbm-backup-e2e-');
    Paths.doc = dir.path;
    Paths.bakName = Miscs.bakFileName;
    Paths.bak = dir.path.joinPath(Miscs.bakFileName);
    SharedPreferences.setMockInitialValues({});
    await PrefStore.shared.init();
    // The mock keeps one map whatever the store's options: one store here.
    SecureProp.legacyApart = false;
    // What is asserted on is a setting: they travel only with this on.
    await PrefProps.syncAppSettings.set(true);
    FlutterSecureStorage.setMockInitialValues({SecureStoreProps.bakPwd.key: _password});
    await PrefProps.webdavSync.set(true);
    await becomeDevice();
    rs = bakSync.remoteStorage!;
    await removeOurs();
  });

  tearDownAll(() async {
    await removeOurs();
    await getIt.reset();
    await SqliteDb.close();
    await dir.delete(recursive: true);
  });

  test('a sync uploads the backup sealed to the key under the v5 name, and nothing else', () async {
    Stores.setting.timeout.put(17);
    await bakSync.sync(throttleMilli: 0);
    expect(bakSync.lastFailure.value, isNull);

    expect(await rs.exists(Miscs.bakFileName), isTrue);
    for (final name in Miscs.legacyBakFileNames) {
      expect(await rs.exists(name), isFalse, reason: 'an older build would read $name');
    }
    final bytes = Uint8List.fromList(await downloaded(Miscs.bakFileName));
    expect(SyncKey.sealedToKey(bytes), isTrue);
    final key = await BakSyncer.keyOf(rs);
    expect(BackupV2.fromPlainBytes(await key.open(bytes)).settings['timeOut'], 17);
    final keyFile = (await WebdavSyncFiles(() => SyncRemotes.webdav).getBlob('identity.age'))!;
    expect(await AgeCryptor.decrypt(keyFile, _password), isNotEmpty);
    if (e2eEnv('SBM_E2E_BACKUP_OUT') case final out?) {
      await File(out.joinPath('backup.age')).writeAsBytes(bytes);
      await File(out.joinPath('identity.age')).writeAsBytes(keyFile);
    }
  });

  test('another device restores it', () async {
    await becomeDevice();
    expect(Stores.setting.timeout.fetch(), isNot(17));
    await bakSync.sync(throttleMilli: 0);
    expect(Stores.setting.timeout.fetch(), 17);
  });

  test('a device whose password does not open the key syncs nothing', () async {
    await becomeDevice();
    final before = await downloaded(Miscs.bakFileName);
    await SecureStoreProps.bakPwd.write('another-password');
    Stores.setting.timeout.put(23);
    await bakSync.sync(throttleMilli: 0);
    expect(bakSync.lastFailure.value, isA<SyncPasswordMismatch>());
    expect(await downloaded(Miscs.bakFileName), before);
    await SecureStoreProps.bakPwd.write(_password);
  });

  for (final (name, password, make) in [
    ('v4', _password, (String path) async {
      Stores.setting.timeout.put(17);
      Stores.server.put(Spi(id: 'srv-fixture', name: 'fixture', ssh: SshCredential(ip: '10.0.0.9', user: 'root')));
      await File(await BackupV2.backup(null, _password)).copy(path);
    }),
    ('v3', _fixturePassword, (String path) async {
      await File(path).writeAsString(await File('test/fixtures/backup/lkfl_enc_v02.txt').readAsString());
    }),
  ]) {
    test('a remote with only the $name name is inherited once, then moved to v5', () async {
      await removeOurs();
      final legacy = File(dir.path.joinPath(name));
      await becomeDevice();
      await make(legacy.path);
      await rs.upload(relativePath: Miscs.legacyBakFileNames[name == 'v4' ? 0 : 1], localPath: legacy.path);
      FlutterSecureStorage.setMockInitialValues({SecureStoreProps.bakPwd.key: password});
      await becomeDevice();

      bakSync.forgetInheritForTest();
      await bakSync.inheritLegacyRemote();
      expect(Stores.server.fetchOneRaw('srv-fixture'), isNotNull, reason: 'the $name history is read');
      expect(Stores.setting.timeout.fetch(), 17);

      await bakSync.sync(throttleMilli: 0);
      final key = await BakSyncer.keyOf(rs);
      final v5 = BackupV2.fromPlainBytes(await key.open(Uint8List.fromList(await downloaded(Miscs.bakFileName))));
      expect(v5.spis.containsKey('srv-fixture'), isTrue, reason: 'the inherited history moves to v5');
    });
  }
}
