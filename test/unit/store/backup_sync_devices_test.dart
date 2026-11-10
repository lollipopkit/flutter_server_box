import 'dart:convert';
import 'dart:io';

import 'package:fl_lib/fl_lib.dart';
import 'package:fl_pi_llm_ui/fl_pi_llm_ui.dart' show LlmStores;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/core/sync/sync.dart';
import 'package:server_box/data/model/app/bak/backup2.dart';
import 'package:server_box/data/model/server/private_key_info.dart';
import 'package:server_box/data/res/misc.dart';
import 'package:server_box/data/store/entity_store.dart';
import 'package:server_box/data/store/setting.dart';
import 'package:server_box/data/store/stores.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/spi_fixture.dart';
import '../../helpers/sync_key.dart';

/// Two devices on one remote: a phone holding servers and keys, and a new
/// install whose only data is a setting changed after the phone's. Each must
/// end with the other's newer part, whichever syncs first.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory root;
  late Directory tempDir;
  late Directory phone;
  late Directory desktop;
  late _FileRemote remote;

  // Each device's own: prefs are one store here, two devices there.
  const checkpoint = PrefProp<String>('sync_checkpoint');
  final checkpoints = <String, String?>{};
  Directory? current;

  setUpAll(() async {
    root = await Directory.systemTemp.createTemp('sbm-sync-devices-');
    Paths.doc = root.path;
    Paths.bakName = Miscs.bakFileName;
    Paths.bak = root.path.joinPath(Miscs.bakFileName);
    SharedPreferences.setMockInitialValues({});
    await PrefStore.shared.init();
  });

  tearDownAll(() => root.delete(recursive: true));

  setUp(() async {
    tempDir = await root.createTemp();
    phone = await Directory(tempDir.path.joinPath('phone')).create();
    desktop = await Directory(tempDir.path.joinPath('desktop')).create();
    remote = _FileRemote(File(tempDir.path.joinPath('remote')));
    // The remote's `identity.age`; both devices keep its keys in one keychain.
    final keyFile = MemoryKeyFile();
    BakSyncer.keyForTest = (_) => keyOf(keyFile);
    checkpoints.clear();
    current = null;
    await checkpoint.remove();
    SecureProp.resetRateLimits();
    // The mock keeps one map whatever the store's options: one store here.
    SecureProp.legacyApart = false;
    FlutterSecureStorage.setMockInitialValues({
      SecureStoreProps.bakPwd.key: 'remote-password',
    });
    await PrefProps.syncAppSettings.set(true);
  });

  tearDown(() async {
    BakSyncer.keyForTest = null;
    SyncKeyring.resetForTest();
    SyncKeyring.init(label: 'ServerBox sync key');
    SecureProp.legacyApart = null;
    await _leave();
    await PrefProps.syncAppSettings.set(false);
    await tempDir.delete(recursive: true);
  });

  Future<void> become(Directory device) async {
    await _leave();
    if (current case final was?) checkpoints[was.path] = checkpoint.get();
    current = device;
    final mine = checkpoints[device.path];
    mine == null ? await checkpoint.remove() : await checkpoint.set(mine);
    await SqliteDb.open(device.path);
    await Stores.init();
  }

  Future<void> sync() => bakSync.sync(throttleMilli: 0, rs: remote);

  /// The phone's data, all older than the desktop's setting.
  Future<void> seedPhone() async {
    await become(phone);
    Stores.key.put(const PrivateKeyInfo(id: 'k1', name: 'work', key: 'KEY'));
    Stores.server.put(spiFixture(id: 's1', name: 'web', ip: '10.0.0.1', keyId: 'k1'));
    Stores.server.put(spiFixture(id: 's2', name: 'db', ip: '10.0.0.2', keyId: 'k1'));
    Stores.setting.timeout.put(17);
    Stores.setting.maxRetryCount.put(9);
    await _settle();
  }

  Future<void> seedDesktop() async {
    await become(desktop);
    Stores.setting.timeout.put(30);
    await _settle();
  }

  Future<void> expectMerged(Directory device) async {
    await become(device);
    expect(
      Stores.server.fetch().map((s) => s.id).toSet(),
      {'s1', 's2'},
      reason: '${device.path}: the phone\'s servers',
    );
    expect(Stores.key.fetch().map((k) => k.id), ['k1']);
    expect(Stores.setting.timeout.fetch(), 30, reason: 'the desktop\'s newer setting');
    expect(Stores.setting.maxRetryCount.fetch(), 9, reason: 'the phone\'s other setting');
  }

  test('the phone synced before the desktop signed in', () async {
    await seedPhone();
    await sync();
    await seedDesktop();
    await sync();
    await become(phone);
    await sync();

    await expectMerged(phone);
    await expectMerged(desktop);
  });

  test('the desktop synced first, to an empty remote', () async {
    await seedPhone();
    await seedDesktop();
    await sync();
    await become(phone);
    await sync();
    await become(desktop);
    await sync();

    await expectMerged(phone);
    await expectMerged(desktop);
  });

  test('once both hold the same, neither writes it back', () async {
    await seedPhone();
    await sync();
    await seedDesktop();
    await sync();
    await become(phone);
    await sync();

    // What two listening devices do on hearing each other's write. A merge
    // that changed one costs it one upload, which the other does not answer.
    Future<int> round() async {
      final before = remote.uploads;
      await become(desktop);
      await sync();
      await become(phone);
      await sync();
      return remote.uploads - before;
    }

    expect(await round(), lessThanOrEqualTo(1));
    expect(await round(), 0, reason: 'or they answer each other forever');
    expect(await round(), 0);
    final settled = remote.uploads;

    // And an edit still goes up.
    Stores.setting.maxRetryCount.put(4);
    await _settle();
    await sync();
    expect(remote.uploads, settled + 1);
  });

  test('the same value set later there takes the later stamp', () async {
    await become(phone);
    Stores.setting.maxRetryCount.put(9);
    await _settle();
    await sync();
    await become(desktop);
    Stores.setting.maxRetryCount.put(9);
    await _settle();
    final later = Stores.setting.lastUpdateTs!['maxRetryCount'];
    await sync();

    await become(phone);
    await sync();
    expect(Stores.setting.lastUpdateTs!['maxRetryCount'], later);
    expect(
      Stores.setting.get<Object>(Stores.setting.lastUpdateTsKey),
      isA<Map>(),
      reason: 'the shape KvStore writes, or backups differ in it',
    );
  });

  test('an edit to a synced setting starts a sync', () async {
    await become(phone);
    var edits = 0;
    final subs = BakSyncer.watchEdits(() => edits++);
    addTearDown(() => Future.wait([for (final s in subs) s.cancel()]));

    Stores.setting.maxRetryCount.put(6);
    await _settle();
    expect(edits, 1);

    Stores.setting.set('windowState', const {'x': 1});
    await _settle();
    expect(edits, 1, reason: 'device-local');

    Stores.history.set('homeTab', 2);
    await _settle();
    expect(edits, 1, reason: 'the history goes with the next sync');

    LlmStores.tool.enabled.put(false);
    await _settle();
    expect(edits, 2, reason: "the Agent's settings sync too");

    await PrefProps.syncAppSettings.set(false);
    Stores.setting.maxRetryCount.put(7);
    await _settle();
    expect(edits, 2, reason: 'settings not synced');
  });

  test('a remote written over with less is written back by a device that was not edited', () async {
    await seedPhone();
    await sync();
    await become(desktop);
    await sync();

    // What a device that synced less leaves there (an older build, a
    // restore): no `s2`, and no delete of it either.
    final full = await BackupV2.loadFromStore();
    final spis = Map<String, Object?>.of(full.spis)..remove('s2');
    final stamps = Map<String, Object?>.from(
      spis[EntityStore.lastModKey] as Map,
    )..remove('s2');
    spis[EntityStore.lastModKey] = stamps;
    final short = full.copyWith(spis: spis);
    await remote.file.writeAsString(
      await AgeCryptor.encrypt(
        gzip.encode(utf8.encode(short.toJsonString())),
        'remote-password',
      ),
    );
    remote.uploads++;
    final before = remote.uploads;

    await become(phone);
    await sync();
    expect(remote.uploads, before + 1, reason: 'or the remote stays without s2');
    await become(desktop);
    await sync();
    expect(Stores.server.fetch().map((s) => s.id).toSet(), {'s1', 's2'});
  });

  test('a merged setting reaches what is showing it', () async {
    await seedPhone();
    await sync();
    await become(desktop);
    final shown = Stores.setting.maxRetryCount.listenable();
    var heard = 0;
    void listener() => heard++;
    shown.addListener(listener);
    await sync();
    shown.removeListener(listener);
    expect(Stores.setting.maxRetryCount.fetch(), 9);
    expect(heard, greaterThan(0));
    expect(shown.value, 9);
  });

  test('device-local settings stay on their device', () async {
    expect(SettingStore.deviceLocalKeys, containsAll(_deviceLocal));
    await become(phone);
    for (final key in _deviceLocal) {
      Stores.setting.set(key, 'phone-$key');
    }
    await _settle();
    expect(
      Stores.setting.lastUpdateTs?.keys ?? const <String>[],
      isNot(anyOf([for (final key in _deviceLocal) contains(key)])),
      reason: 'not an edit a sync moves',
    );
    await sync();
    await become(desktop);
    await sync();

    for (final key in _deviceLocal) {
      expect(Stores.setting.get<Object>(key), isNull, reason: key);
    }
  });

  test('stamps an older build left on device-local settings stay too', () async {
    await become(phone);
    Stores.setting.timeout.put(17);
    await _settle();
    final before = Stores.lastModTime;
    final later = before + 60000;
    writeStamps({...?Stores.setting.lastUpdateTs, for (final k in _deviceLocal) k: later});
    expect(Stores.lastModTime, before);

    final backup = await BackupV2.loadFromStore();
    expect(
      _stampsOf(backup.settings).keys,
      isNot(anyOf([for (final key in _deviceLocal) contains(key)])),
      reason: 'a build that does not hold them device-local deletes its own',
    );

    // An older build's backup, carrying them: this device keeps its own and
    // its clock.
    await become(desktop);
    Stores.setting.set('agentShell', {'x': 1});
    await _settle();
    final mine = Stores.lastModTime;
    await backup
        .copyWith(
          settings: {
            ...backup.settings,
            'agentShell': {'x': 2},
            Stores.setting.lastUpdateTsKey: {
              ..._stampsOf(backup.settings),
              'agentShell': later,
            },
          },
        )
        .merge();
    expect(Stores.setting.get<Object>('agentShell'), {'x': 1});
    expect(Stores.setting.lastUpdateTs?.keys, isNot(contains('agentShell')));
    expect(Stores.lastModTime, isNot(later));
    expect(Stores.lastModTime, greaterThanOrEqualTo(mine));
  });
}

const _deviceLocal = {
  'rootfsManifestSerial',
  'rootfsManifestCache',
  'rootfsManifestCacheSig',
  'lastVer',
  'introVer',
  'featureIntroVer',
  'diagnosticsConsentVer',
  'dmgTipBuild',
  'legacyStatusNoticePending',
  'firstTimeReadSSHCfg',
  'fontPath',
  'sshBgImage',
  'windowState',
  'agentShell',
  'terminalShell',
  'useBioAuth',
  'delayBioAuthLock',
  'bgRun',
  'linuxProfile',
  'linuxDns',
  'textFactor',
  'termFontSize',
  'editorFontSize',
  'paneListWidth',
  'paneListCollapsed',
  'fullScreen',
  'rightHanded',
};


/// The timestamp map of a store's rows, in either shape.
Map<String, Object?> _stampsOf(Map<String, Object?> rows) {
  final ts = rows[Stores.setting.lastUpdateTsKey];
  return Map<String, Object?>.from(ts is String ? json.decode(ts) as Map : ts as Map);
}

/// The timestamps as [map], as an older build's writes left them.
void writeStamps(Map<String, int> map) {
  Stores.setting.set(Stores.setting.lastUpdateTsKey, map, updateLastUpdateTsOnSet: false);
}

/// Lets the timestamps written behind the stores land.
Future<void> _settle() async {
  await Future<void>.delayed(const Duration(milliseconds: 5));
}

Future<void> _leave() async {
  await _settle();
  await getIt.reset();
  await SqliteDb.close();
}

final class _FileRemote extends RemoteStorage<String> {
  _FileRemote(this.file);

  final File file;
  var uploads = 0;

  @override
  Future<void> download({required String relativePath, String? localPath}) =>
      file.copy(localPath ?? Paths.bak);

  @override
  Future<void> upload({required String relativePath, String? localPath}) {
    uploads++;
    return File(localPath ?? Paths.bak).copy(file.path);
  }

  /// Moves with every write, as a real backend's ETag does.
  @override
  Future<String?> versionTag(String relativePath) async =>
      await file.exists() ? 'v$uploads' : null;

  @override
  Future<bool> exists(String relativePath) => file.exists();

  @override
  Future<void> delete(String relativePath) async {}

  @override
  Future<List<String>> list() async => const [];
}
