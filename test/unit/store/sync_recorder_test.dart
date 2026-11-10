import 'dart:io';

import 'package:fl_lib/fl_lib.dart';
import 'package:fl_pi_llm_ui/fl_pi_llm_ui.dart' show LlmStores;
import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/data/model/app/bak/backup2.dart';
import 'package:server_box/data/model/server/snippet.dart';
import 'package:server_box/data/store/stores.dart';
import 'package:server_box/data/store/sync_recorder.dart';

String? _stampOf(String c, String id) => SqliteDb.instance
    .select('SELECT hlc FROM sync_record WHERE c = ? AND id = ?;', [c, id])
    .firstOrNull?['hlc'] as String?;

void main() {
  setUpAll(() async {
    final dir = await Directory.systemTemp.createTemp('sbm-sync-recorder-');
    Paths.doc = dir.path;
    addTearDown(() => dir.delete(recursive: true));
  });

  setUp(() async {
    SqliteDb.openInMemory();
    await Stores.init();
    SyncRecorder.resetForTest();
    SyncRecorder.install();
  });

  tearDown(() async {
    KvStore.onEdit = null;
    await Future<void>.delayed(Duration.zero);
    await getIt.reset();
    await SqliteDb.close();
  });

  test('a record changed here is pending, newest stamp last', () {
    const snippet = Snippet(id: 'sn1', name: 'uptime', script: 'uptime');
    Stores.snippet.put(snippet);
    final first = _stampOf('snippet', snippet.id)!;
    Stores.snippet.delete(snippet);
    final second = _stampOf('snippet', snippet.id)!;
    expect(second.compareTo(first), greaterThan(0));

    final pending = SyncRecorder.pending('');
    expect(pending.map((p) => (p.c, p.id)), [('snippet', snippet.id)]);
    expect(pending.single.hlc, second);
    expect(SyncRecorder.pending(second), isEmpty);
  });

  test('settings sync, history and device-local settings do not', () {
    Stores.setting.timeout.put(17);
    Stores.history.sftpGoPath.add('/srv');
    final pending = SyncRecorder.pending('').map((p) => p.c).toSet();
    expect(pending, {'kv:setting'});
    expect(SyncRecorder.pending('').map((p) => p.id), [Stores.setting.timeout.key]);
  });

  test("the Agent's settings and memory sync, its chats do not", () {
    LlmStores.tool.enabled.put(false);
    LlmStores.memory.write('MEMORY.md', 'note');
    LlmStores.chat.set('c1', const {'id': 'c1'});
    final pending = {for (final p in SyncRecorder.pending('')) (p.c, p.id)};
    expect(pending, {('kv:tool', 'enabled'), ('kv:memory', 'MEMORY.md')});
  });

  test("another device's change is held, and never pending", () {
    const snippet = Snippet(id: 'sn2', name: 'df', script: 'df -h');
    SyncRecorder.applying(() => Stores.snippet.put(snippet));
    expect(_stampOf('snippet', snippet.id), isNotNull);
    expect(SyncRecorder.pending(''), isEmpty);
  });

  test('what came from elsewhere moves the clock', () {
    final ahead = SyncClock.now() + 3600 * 1000;
    SyncRecorder.applying(() => SyncRecorder.record('snippet', 'far', at: ahead));
    SyncRecorder.record('snippet', 'near');
    final far = _stampOf('snippet', 'far')!;
    final near = _stampOf('snippet', 'near')!;
    expect(near.compareTo(far), greaterThan(0));
  });

  test("a store that is not synced is not recorded (the Agent's chats)", () {
    SqliteStore('chats').set('c1', {'title': 'hi'});
    expect(SyncRecorder.pending(''), isEmpty);
  });

  test("a merged setting is stamped as no device's, a restored one as ours", () async {
    final bak = await BackupV2.loadFromStore();
    final later = SyncClock.now() + 60000;
    final settings = {
      ...bak.settings,
      Stores.setting.timeout.key: 30,
      Stores.setting.lastUpdateTsKey: {Stores.setting.timeout.key: later},
    };
    await bak.copyWith(settings: settings).merge();
    expect(Stores.setting.timeout.fetch(), 30);
    expect(_stampOf('kv:setting', Stores.setting.timeout.key), isNotNull);
    expect(SyncRecorder.pending(''), isEmpty);

    await bak.copyWith(settings: {...settings, Stores.setting.timeout.key: 40}).merge(force: true);
    expect(SyncRecorder.pending('').map((p) => p.id), contains(Stores.setting.timeout.key));
  });

  test('seeds from every sync root', () {
    expect(SyncRecorder.roots.toSet(), Stores.syncedTables.toSet());
  });

  test('the device id is made once and kept', () {
    final id = SyncRecorder.device;
    expect(id, isNot(SyncRecorder.legacy));
    SyncRecorder.resetForTest();
    expect(SyncRecorder.device, id);
  });

  test("a stamp never moves back, and an edit's updated_at is its stamp's time", () {
    const snippet = Snippet(id: 'sn9', name: 'echo', script: 'echo');
    Stores.snippet.put(snippet);
    final own = _stampOf('snippet', snippet.id)!;
    final at = SqliteDb.instance.select('SELECT updated_at FROM snippet WHERE id = ?;', [snippet.id]).first['updated_at'] as int;
    expect(at, SyncRecorder.msOf(own));

    // The snapshot sync taking the same edit back from another device.
    SyncRecorder.applying(() => SyncRecorder.record('snippet', snippet.id, at: at));
    expect(_stampOf('snippet', snippet.id), own);
  });
}
