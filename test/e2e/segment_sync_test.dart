/// Opt-in end-to-end test of the log sync on WebDAV (#1843): each device's
/// segments, sealed to the sync key `identity.age` holds, reach the others.
///
/// `SBM_E2E_WEBDAV_URL`, `_USER`, `_PASSWORD` in the environment or the
/// workspace-root `.env`; `SBM_E2E_SEGMENT_OUT`: a directory the key file
/// and a segment are copied to, for the `age` CLI to open.
///
/// `scripts/app-backup-e2e.sh` starts rclone's WebDAV and runs this. What it
/// puts on the remote it removes.
library;

import 'dart:io';

import 'package:fl_lib/fl_lib.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/core/sync/file_log.dart';
import 'package:server_box/data/model/server/snippet.dart';
import 'package:server_box/data/store/stores.dart';
import 'package:server_box/data/store/sync_recorder.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:webdav_client_plus/webdav_client_plus.dart';

import '../helpers/rust_lib_helper.dart';
import '../helpers/ssh_e2e.dart';

const _password = 'e2e-backup-password';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final url = e2eEnv('SBM_E2E_WEBDAV_URL');
  final user = e2eEnv('SBM_E2E_WEBDAV_USER');
  final pwd = e2eEnv('SBM_E2E_WEBDAV_PASSWORD');
  final out = e2eEnv('SBM_E2E_SEGMENT_OUT');
  if (url == null) {
    test('segment sync e2e', () {}, skip: 'SBM_E2E_WEBDAV_URL is not set');
    return;
  }

  late Directory dir;
  final folder = '${Webdav.defaultPrefix}srvbox_sync/';
  WebdavClient client() => Webdav.shared.client!;

  /// A device of its own: an empty database, a new device id, and only the
  /// backup password in the keychain (the sync key is read from the remote).
  Future<String> becomeDevice() async {
    if (SqliteDb.isOpen) {
      await getIt.reset();
      await SqliteDb.close();
    }
    FlutterSecureStorage.setMockInitialValues({
      SecureStoreProps.bakPwd.key: _password,
      SecureStoreProps.webdavPwd.key: ?pwd,
    });
    SqliteDb.openInMemory();
    await Stores.init();
    SyncRecorder.resetForTest();
    SyncRecorder.install();
    FileLogSync.reset();
    return SyncRecorder.deviceHexOf(SyncRecorder.device);
  }

  Future<List<String>> listed() async => [for (final f in await client().readDir(folder)) f.name];

  Future<void> removeOurs() async {
    try {
      await client().remove(folder);
    } catch (_) {}
  }

  setUpAll(() async {
    // The test binding answers every HTTP request 400; this one is real.
    HttpOverrides.global = null;
    await initRustLibForTest();
    dir = await Directory.systemTemp.createTemp('sbm-segment-e2e-');
    Paths.doc = dir.path;
    SharedPreferences.setMockInitialValues({});
    await PrefStore.shared.init();
    await PrefProps.syncAppSettings.set(true);
    FlutterSecureStorage.setMockInitialValues({SecureStoreProps.webdavPwd.key: ?pwd});
    await PrefProps.webdavUrl.set(url);
    await PrefProps.webdavUser.set(user ?? '');
    await Webdav.initShared();
    await PrefProps.webdavSync.set(true);
    await removeOurs();
  });

  tearDownAll(() async {
    await removeOurs();
    await getIt.reset();
    await SqliteDb.close();
    await dir.delete(recursive: true);
  });

  const snippet = Snippet(id: 'e2e-sn', name: 'uptime', script: 'uptime');

  test("one device's edits reach the others through its own files", () async {
    final a = await becomeDevice();
    Stores.snippet.put(snippet);
    Stores.setting.timeout.put(17);
    await FileLogSync.sync();
    final written = await listed();
    expect(written, containsAll(['identity.age', 'seg-$a-1.age']));
    if (out != null) {
      for (final name in ['identity.age', 'seg-$a-1.age']) {
        await File('$out/$name').writeAsBytes(await client().read('$folder$name'));
      }
    }

    final b = await becomeDevice();
    await FileLogSync.sync();
    expect(Stores.snippet.fetchOneRaw(snippet.id)?.script, 'uptime');
    expect(Stores.setting.timeout.fetch(), 17);

    Stores.setting.timeout.put(30);
    await FileLogSync.sync();
    expect(await listed(), contains('seg-$b-2.age'), reason: "the second of B's: its first sent what it joined with");

    await becomeDevice();
    await FileLogSync.sync();
    expect(Stores.setting.timeout.fetch(), 30);
    expect(Stores.snippet.fetchOneRaw(snippet.id)?.script, 'uptime');
  });
}
