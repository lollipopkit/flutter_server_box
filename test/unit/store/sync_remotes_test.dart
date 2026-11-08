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
    await PrefProps.gistId.set('g1');
    await SecureStoreProps.webdavPwd.write('pw');
    await SecureStoreProps.githubToken.write('tok');

    await SyncRemotes.adopt();

    expect(SyncRemotes.webdavUrl, 'https://dav.example/');
    expect(SyncRemotes.webdavUser, 'u');
    expect(SyncRemotes.webdavPwd, 'pw');
    expect(SyncRemotes.gistId, 'g1');
    expect(SyncRemotes.githubToken, 'tok');
    expect(PrefProps.webdavUrl.get(), isNull);
    expect(PrefProps.gistId.get(), isNull);
    expect(await SecureStoreProps.webdavPwd.read(), isNull);
    expect(await SecureStoreProps.githubToken.read(), isNull);

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

  test('the gist the first upload made is kept', () async {
    SyncRemotes.setGist(token: 'tok', id: null);
    final gist = SyncRemotes.gist;
    expect(gist.token, 'tok');
    await gist.onCreated!('new-id');
    expect(SyncRemotes.gistId, 'new-id');
    expect(PrefProps.gistId.get(), isNull);
    expect(SyncRemotes.gist.gistId, 'new-id');
  });
}
