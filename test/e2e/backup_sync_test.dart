/// Opt-in end-to-end test of the backup sync (#1772) against a real remote,
/// configured as the backup page does: the upload is armored age under the v4
/// name, another device restores it, and a remote holding only the v3 name is
/// inherited once and moved to v4.
///
/// One remote per run, in the environment or the workspace-root `.env`:
///
/// - `SBM_E2E_BACKUP_REMOTE=webdav`: `SBM_E2E_WEBDAV_URL`, `_USER`,
///   `_PASSWORD`.
/// - `SBM_E2E_BACKUP_REMOTE=monitor`: a monitor agent's backup store,
///   `SBM_E2E_MONITOR_ADDR` and `SBM_E2E_MONITOR_PASSWORD` (plain HTTP).
/// - `SBM_E2E_BACKUP_OUT`: where the uploaded file is copied, for the `age`
///   CLI to open.
///
/// `scripts/app-backup-e2e.sh` starts rclone's WebDAV and a monitor and runs
/// this against each. What it puts on the remote it removes.
library;

import 'dart:convert';
import 'dart:io';

import 'package:fl_lib/fl_lib.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/core/sync.dart';
import 'package:server_box/data/model/app/bak/backup2.dart';
import 'package:server_box/data/model/server/monitor_http_credential.dart';
import 'package:server_box/data/model/server/server_private_info.dart';
import 'package:server_box/data/res/misc.dart';
import 'package:server_box/data/res/store.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/rust_lib_helper.dart';
import '../helpers/ssh_e2e.dart';

const _password = 'e2e-backup-password';

/// The fixture's: `test/fixtures/backup/README.md`.
const _fixturePassword = 'fixture-password';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final remote = e2eEnv('SBM_E2E_BACKUP_REMOTE');
  final webdav = (
    url: e2eEnv('SBM_E2E_WEBDAV_URL'),
    user: e2eEnv('SBM_E2E_WEBDAV_USER'),
    pwd: e2eEnv('SBM_E2E_WEBDAV_PASSWORD'),
  );
  final agent = MonitorHttpCredential(
    addr: e2eEnv('SBM_E2E_MONITOR_ADDR') ?? '',
    pwd: e2eEnv('SBM_E2E_MONITOR_PASSWORD'),
    allowInsecure: true,
  );
  final configured = switch (remote) {
    'webdav' => webdav.url != null,
    'monitor' => agent.addr.isNotEmpty && agent.pwd != null,
    _ => false,
  };
  if (!configured) {
    test('backup sync e2e', () {}, skip: 'SBM_E2E_BACKUP_REMOTE and its remote are not set');
    return;
  }

  const agentId = 'e2e-agent';
  late Directory dir;
  late RemoteStorage rs;

  /// This device's data replaced by an empty one, as a second device; the
  /// agent's record put back where the remote is one, as the user would.
  Future<void> becomeDevice() async {
    await getIt.reset();
    await SqliteDb.close();
    SqliteDb.openInMemory();
    await Stores.init();
    if (remote == 'monitor') {
      Stores.server.put(Spi(id: agentId, name: 'e2e agent', monitorHttp: agent));
    }
  }

  Future<void> removeOurs() async {
    for (final name in [Miscs.bakFileName, ...Miscs.legacyBakFileNames]) {
      if (await rs.exists(name)) await rs.delete(name);
    }
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
    // What is asserted on is a setting: they travel only with this on.
    await PrefProps.syncAppSettings.set(true);
    FlutterSecureStorage.setMockInitialValues({
      SecureStoreProps.bakPwd.key: _password,
      if (webdav.pwd != null) SecureStoreProps.webdavPwd.key: webdav.pwd!,
    });
    switch (remote) {
      case 'webdav':
        await PrefProps.webdavUrl.set(webdav.url!);
        await PrefProps.webdavUser.set(webdav.user ?? '');
        await Webdav.initShared();
        await PrefProps.webdavSync.set(true);
      case 'monitor':
        await BakSyncer.monitorSync.set(true);
        await BakSyncer.monitorSyncServer.set(agentId);
    }
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

  test('a sync uploads armored age under the v4 name, and nothing else', () async {
    Stores.setting.timeout.put(17);
    await bakSync.sync(throttleMilli: 0);

    expect(await rs.exists(Miscs.bakFileName), isTrue);
    for (final name in Miscs.legacyBakFileNames) {
      expect(await rs.exists(name), isFalse, reason: 'an older build would read $name');
    }
    final bytes = await downloaded(Miscs.bakFileName);
    expect(utf8.decode(bytes), startsWith('-----BEGIN AGE ENCRYPTED FILE-----'));
    expect((await BackupV2.open(bytes, _password)).settings['timeOut'], 17);
    await expectLater(BackupV2.open(bytes, 'not it'), throwsA(isA<WrongPasswordException>()));
    if (e2eEnv('SBM_E2E_BACKUP_OUT') case final out?) await File(out).writeAsBytes(bytes);
  });

  test('another device restores it', () async {
    await becomeDevice();
    expect(Stores.setting.timeout.fetch(), isNot(17));
    await bakSync.sync(throttleMilli: 0);
    expect(Stores.setting.timeout.fetch(), 17);
  });

  test('a remote with only the v3 name is inherited once, then moved to v4', () async {
    await removeOurs();
    final v3 = File(dir.path.joinPath('v3'));
    await v3.writeAsString(await File('test/fixtures/backup/lkfl_enc_v02.txt').readAsString());
    await rs.upload(relativePath: Miscs.legacyBakFileNames.first, localPath: v3.path);
    FlutterSecureStorage.setMockInitialValues({SecureStoreProps.bakPwd.key: _fixturePassword});
    await becomeDevice();

    await bakSync.inheritLegacyRemote();
    expect(Stores.server.fetchOneRaw('srv-fixture'), isNotNull, reason: 'the v3 history is read');
    expect(Stores.setting.timeout.fetch(), 17);

    await bakSync.sync(throttleMilli: 0);
    final v4 = await BackupV2.open(await downloaded(Miscs.bakFileName), _fixturePassword);
    expect(v4.spis.containsKey('srv-fixture'), isTrue, reason: 'the inherited history moves to v4');
  });
}
