import 'dart:io';

import 'package:fl_lib/fl_lib.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/core/sync/category.dart';
import 'package:server_box/core/sync/remotes.dart';
import 'package:server_box/data/store/stores.dart';
import 'package:server_box/data/store/sync_recorder.dart';
import 'package:shared_preferences/shared_preferences.dart';

String? _stampOf(String id) => SqliteDb.instance
    .select('SELECT hlc FROM sync_record WHERE c = ? AND id = ?;', ['kv:${Stores.syncRemote.name}', id])
    .firstOrNull?['hlc'] as String?;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    final dir = await Directory.systemTemp.createTemp('sbm-sync-remotes-');
    Paths.doc = dir.path;
    addTearDown(() => dir.delete(recursive: true));
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await PrefStore.shared.init();
    FlutterSecureStorage.setMockInitialValues({});
    SqliteDb.openInMemory();
    await Stores.init();
    SyncRecorder.resetForTest();
    SyncRecorder.install();
  });

  tearDown(() async {
    await getIt.reset();
    await SqliteDb.close();
  });

  test('synced with the secrets', () {
    expect(SyncCategory.of('kv:${Stores.syncRemote.name}'), SyncCategory.secrets);
    expect(SyncRecorder.syncedStores, containsPair(Stores.syncRemote.name, Stores.syncRemote));
  });

  test('what builds before kept is moved in once, as no device\'s edit at no time, and removed there', () async {
    await PrefProps.webdavUrl.set('https://dav.example/');
    await PrefProps.webdavUser.set('u');
    await SecureStoreProps.webdavPwd.write('pw');

    await SyncRemotes.adopt();

    expect(SyncRemotes.webdavUrl, 'https://dav.example/');
    expect(SyncRemotes.webdavUser, 'u');
    expect(SyncRemotes.webdavPwd, 'pw');
    expect(PrefProps.webdavUrl.get(), isNull);
    expect(await SecureStoreProps.webdavPwd.read(), isNull);

    final adopted = _stampOf('webdavPwd')!;
    expect(SyncRecorder.msOf(adopted), 0, reason: 'any edit made anywhere wins over it');
    expect(adopted, endsWith(SyncRecorder.deviceHexOf(SyncRecorder.legacy)));
    expect(Stores.syncRemote.lastUpdateTs?['webdavPwd'], isNull, reason: 'the whole backup compares this');
    SyncRemotes.setWebdav(url: 'https://dav.example/', user: 'u', pwd: 'new');
    expect(_stampOf('webdavPwd')!.compareTo(adopted), greaterThan(0), reason: 'an edit wins over it');

    // Once: what is set here now is not replaced.
    await PrefProps.webdavUrl.set('https://old.example/');
    await SyncRemotes.adopt();
    expect(SyncRemotes.webdavUrl, 'https://dav.example/');
  });

  test('a changed setting is a new client; one in use keeps its server', () {
    expect(SyncRemotes.webdav.client, isNull);
    SyncRemotes.setWebdav(url: 'https://a.example/', user: 'u', pwd: 'p');
    final a = SyncRemotes.webdav;
    expect(SyncRemotes.webdav, same(a));
    SyncRemotes.setWebdav(url: 'https://b.example/', user: 'u', pwd: 'p');
    expect(SyncRemotes.webdav, isNot(same(a)));
    expect(a.client!.url, 'https://a.example/');
    expect(SyncRemotes.webdav.client!.url, 'https://b.example/');
  });

  test('what the retired Gist and monitor syncs left is removed, everywhere', () async {
    Stores.syncRemote.set('gistId', 'g1');
    Stores.syncRemote.set('githubToken', 'tok');
    await PrefProps.gistSync.set(true);
    await const PrefPropDefault('monitor_sync', false).set(true);
    await SecureStoreProps.githubToken.write('tok');

    await SyncRemotes.dropRetired();

    expect(Stores.syncRemote.get<String>('gistId'), isNull);
    expect(Stores.syncRemote.get<String>('githubToken'), isNull);
    expect(_stampOf('githubToken'), isNotNull, reason: 'a removal other devices take too');
    expect(PrefProps.gistSync.get(), isFalse);
    expect(const PrefPropDefault('monitor_sync', false).get(), isFalse);
    expect(await SecureStoreProps.githubToken.read(), isNull);

    // Brought back by a restore or another device: removed again.
    Stores.syncRemote.set('githubToken', 'tok');
    await Future<void>.delayed(Duration.zero);
    expect(Stores.syncRemote.get<String>('githubToken'), isNull);
  });
}
