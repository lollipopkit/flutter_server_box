import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:fl_lib/fl_lib.dart';
import 'package:fl_pi_llm/fl_pi_llm.dart' show LlmPermissionMode;
import 'package:fl_pi_llm_ui/fl_pi_llm_ui.dart' show LlmApprovals;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/core/sync/category.dart';
import 'package:server_box/data/model/server/snippet.dart';
import 'package:server_box/data/store/stores.dart';
import 'package:server_box/data/store/sync_recorder.dart';
import 'package:server_box/data/store/sync_records.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/sync_key.dart';

/// A WebDAV or iCloud folder, in memory.
final class _Folder implements SyncFiles {
  final files = <String, ({Uint8List body, DateTime at})>{};

  /// Written, and not here yet for the other devices (iCloud's delivery).
  final hidden = <String>{};

  var writes = 0;

  /// The next write fails: having landed, or not.
  bool? failNext;

  @override
  Future<void> write(String name, Uint8List body) async {
    writes++;
    final fail = failNext;
    failNext = null;
    if (fail != true) files[name] = (body: body, at: DateTime.now());
    if (fail != null) throw const SocketException('lost');
  }

  @override
  Future<Uint8List?> read(String name) async => hidden.contains(name) ? null : files[name]?.body;

  @override
  Future<List<({String name, DateTime? at})>> list(String prefix) async => [
    for (final MapEntry(:key, :value) in files.entries)
      if (key.startsWith(prefix) && !hidden.contains(key)) (name: key, at: value.at),
  ];

  @override
  Future<void> delete(String name) async {
    files.remove(name);
  }

  Iterable<String> segmentsOf(String device) => files.keys.where((k) => k.startsWith('seg-$device-'));
}

/// A record larger than this goes as a blob (`fl_sync_engine`).
const _inlineMax = 64 << 10;

/// Snapshots written after this many segments read or written.
const _compactEvery = 32;

/// The folder's key file; apart from [_Folder], so its writes are not counted.
var _keyFile = MemoryKeyFile('folder');
late SyncKeyHandle _key;

/// This device's keychain: [kept], the keys it holds (none: only the
/// password), opening [_keyFile].
Future<void> _keychain([String? kept]) async {
  FlutterSecureStorage.setMockInitialValues({
    SecureStoreProps.bakPwd.key: 'pw',
    'syncIdentity.${_keyFile.id}': ?kept,
  });
  SecureProp.resetRateLimits();
  SyncKeyring.resetForTest();
  SyncKeyring.init(label: 'ServerBox sync key');
  _key = await SyncKeyring.ofFiles(_keyFile);
}

/// The keys this device holds, the newest first.
Future<String?> _held() => const FlutterSecureStorage().read(key: 'syncIdentity.${_keyFile.id}');

Future<String> _device() async {
  KvStore.onEdit = null;
  await Future<void>.delayed(Duration.zero);
  if (SqliteDb.isOpen) {
    await getIt.reset();
    await SqliteDb.close();
  }
  SqliteDb.openInMemory();
  await Stores.init();
  SyncRecorder.resetForTest();
  SyncedStores.install();
  ServerSyncRecords.install();
  SyncCategory.define();
  await syncCall(() => SyncSegmentEngine.bind(store: 'folder', host: SyncHost().call));
  return SyncRecorder.deviceHexOf(SyncRecorder.device);
}

/// A device's segment sync on [folder].
final class _Sync {
  _Sync(_Folder folder) : _engine = SyncSegmentEngine(key: _key, host: SyncHost(files: folder).call);

  final SyncSegmentEngine _engine;

  Future<void> sync() => syncCall(_engine.run);

  Future<void> reset() => syncCall(_engine.reset);

  bool get tooNew => _engine.tooNew();
}

_Sync _sync(_Folder folder) => _Sync(folder);

/// [json], sealed to the folder's key.
Uint8List _sealed(Object json) => _key.seal(plain: Uint8List.fromList(gzip.encode(utf8.encode(jsonEncode(json)))));

Uint8List _snapshotOf(Map<String, int> covers) => _sealed({'v': 1, 'ops': [], 'covers': covers});

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await PrefStore.shared.init();
    // The mock keeps one map whatever the store's options: one store here.
    SecureProp.legacyApart = false;
    _keyFile = MemoryKeyFile('folder');
    await _keychain();
  });

  setUpAll(() async {
    final dir = await Directory.systemTemp.createTemp('sbm-segment-sync-');
    Paths.doc = dir.path;
    addTearDown(() => dir.delete(recursive: true));
  });

  tearDown(() async {
    KvStore.onEdit = null;
    await Future<void>.delayed(Duration.zero);
    await getIt.reset();
    await SqliteDb.close();
  });

  const snippet = Snippet(id: 'sn1', name: 'uptime', script: 'uptime');

  test("one device's edits reach another, and its edits back; each writes only its own", () async {
    final folder = _Folder();
    final a = await _device();
    Stores.snippet.put(snippet);
    Stores.setting.timeout.put(17);
    await _sync(folder).sync();
    expect(folder.segmentsOf(a), hasLength(1));

    final b = await _device();
    await _sync(folder).sync();
    expect(Stores.snippet.fetchOneRaw(snippet.id)?.script, 'uptime');
    expect(Stores.setting.timeout.fetch(), 17);

    Stores.snippet.delete(snippet);
    Stores.setting.timeout.put(30);
    final before = Map.of(folder.files);
    await _sync(folder).sync();
    for (final name in before.keys) {
      expect(identical(folder.files[name]?.body, before[name]?.body), isTrue, reason: '$name is written once');
    }
    expect(folder.segmentsOf(b), isNotEmpty);

    // A third device reads both.
    await _device();
    await _sync(folder).sync();
    expect(Stores.snippet.fetchOneRaw(snippet.id), isNull);
    expect(Stores.setting.timeout.fetch(), 30);
  });

  test('a category turned on again takes what came while it was off', () async {
    SharedPreferences.setMockInitialValues({});
    await PrefStore.shared.init();
    final folder = _Folder();
    await _device();
    LlmApprovals.pickMode(LlmPermissionMode.auto);
    await _sync(folder).sync();

    await _device();
    await SyncCategory.ai.pref.set(false);
    final b = _sync(folder);
    await b.sync();
    expect(LlmApprovals.stored.defaultMode, isNot(LlmPermissionMode.auto));

    await SyncCategory.ai.pref.set(true);
    await b.reset();
    await b.sync();
    expect(LlmApprovals.stored.defaultMode, LlmPermissionMode.auto);
  });

  test('a newer format stops the read and is shown, for this engine only', () async {
    final folder = _Folder();
    final a = await _device();
    Stores.snippet.put(snippet);
    await _sync(folder).sync();
    final name = folder.segmentsOf(a).single;
    folder.files[name] = (body: _sealed({'v': 99, 'ops': []}), at: DateTime.now());

    await _device();
    final sync = _sync(folder);
    await expectLater(sync.sync(), throwsA(isA<SyncLogTooNew>()));
    expect(sync.tooNew, isTrue);

    await sync.reset();
    expect(sync.tooNew, isFalse);
  });

  test('a number once taken is not written again, though what was sent is forgotten', () async {
    final folder = _Folder();
    final a = await _device();
    Stores.setting.timeout.put(17);
    await _sync(folder).sync();
    await syncCall(() => SyncSegmentEngine.forget(host: SyncHost().call));
    Stores.setting.timeout.put(18);
    await _sync(folder).sync();
    expect(folder.segmentsOf(a).toSet(), {'seg-$a-1.age', 'seg-$a-2.age'});
  });

  test('a write that failed is written again under its number unless it landed', () async {
    final folder = _Folder();
    final a = await _device();
    final sync = _sync(folder);
    Stores.setting.timeout.put(17);
    folder.failNext = true;
    await expectLater(sync.sync(), throwsA(isA<SyncError>()));
    await sync.sync();
    expect(folder.segmentsOf(a).toSet(), {'seg-$a-1.age'});

    Stores.setting.timeout.put(18);
    folder.failNext = false;
    await expectLater(sync.sync(), throwsA(isA<SyncError>()));
    await sync.sync();
    expect(folder.segmentsOf(a).toSet(), {'seg-$a-1.age', 'seg-$a-2.age', 'seg-$a-3.age'});

    await _device();
    await _sync(folder).sync();
    expect(Stores.setting.timeout.fetch(), 18);
  });

  test('an old segment that fails to open for another reason is not passed over', () async {
    final folder = _Folder();
    final c = await _device();
    folder.files['seg-$c-1.age'] = (body: Uint8List(1), at: DateTime.now().subtract(const Duration(days: 8)));
    await _device();
    // Not one no key opens: the key file, looked at again, out of reach.
    _keyFile.offline = true;
    await expectLater(_sync(folder).sync(), throwsA(isA<SyncError>()));
    _keyFile.offline = false;
    expect(SqliteDb.instance.select("SELECT v FROM sync_state WHERE k = 'seg.cur.$c';"), isEmpty);
  });

  test('a segment not here yet stops the read of its device until it is', () async {
    final folder = _Folder();
    final a = await _device();
    final sync = _sync(folder);
    Stores.setting.timeout.put(17);
    await sync.sync();
    Stores.setting.timeout.put(18);
    await sync.sync();
    folder.hidden.add('seg-$a-1.age');

    await _device();
    final reader = _sync(folder);
    await reader.sync();
    expect(Stores.setting.timeout.fetch(), isNot(18), reason: 'segment 2 waits for 1');

    folder.hidden.clear();
    await reader.sync();
    expect(Stores.setting.timeout.fetch(), 18);
  });

  test('a segment no key here opens holds its device while recent, and is passed over once old', () async {
    final folder = _Folder();
    final a = await _device();
    Stores.setting.timeout.put(17);
    await _sync(folder).sync();
    expect(folder.segmentsOf(a), isNotEmpty);
    final heldA = await _held();

    // Another device made its own key at the same time, before either saw
    // the other's: it wrote over the file.
    await _device();
    _keyFile.blind = true;
    await _keychain();
    _keyFile.blind = false;
    final heldB = await _held();
    await _sync(folder).sync();
    expect(Stores.setting.timeout.fetch(), isNot(17));

    // The writer merged its key into the file.
    await _keychain(heldA);
    await _keychain(heldB);
    await _sync(folder).sync();
    expect(Stores.setting.timeout.fetch(), 17);

    // One no key ever opens, past the wait: passed over, and what follows read.
    final c = await _device();
    final old = DateTime.now().subtract(const Duration(days: 8));
    folder.files['seg-$c-1.age'] = (body: Uint8List.fromList(utf8.encode('kz|x')), at: old);
    folder.files['seg-$c-2.age'] = (body: Uint8List.fromList(utf8.encode('kz|x')), at: DateTime.now());
    await _device();
    final r = _sync(folder);
    await r.sync();
    await r.sync();
    final rows = SqliteDb.instance.select("SELECT v FROM sync_state WHERE k = 'seg.cur.$c';");
    expect(rows.single['v'], '1', reason: 'the old one passed over, the recent one waited for');
  });

  test('a snapshot every so often; own segments removed once every snapshot covers them', () async {
    final folder = _Folder();
    final a = await _device();
    final sync = _sync(folder);
    // Another device, read up to segment 5 of this one.
    folder.files['snap-00000000000000bb.age'] = (body: _snapshotOf({a: 5}), at: DateTime.now());
    for (var i = 0; i < _compactEvery + 1; i++) {
      Stores.setting.timeout.put(100 + i);
      await sync.sync();
    }
    expect(folder.files.containsKey('snap-$a.age'), isTrue);
    final left = folder.segmentsOf(a).toSet();
    expect(left.contains('seg-$a-5.age'), isFalse);
    expect(left.contains('seg-$a-6.age'), isTrue, reason: 'the other snapshot covers only up to 5');

    // A device that joins after the gap reads the snapshot first.
    await _device();
    await _sync(folder).sync();
    expect(Stores.setting.timeout.fetch(), 100 + _compactEvery);
  });

  test('segments are removed down to the last when the snapshots cover them all', () async {
    final folder = _Folder();
    final a = await _device();
    final sync = _sync(folder);
    for (var i = 0; i < _compactEvery + 2; i++) {
      Stores.setting.timeout.put(100 + i);
      await sync.sync();
    }
    final left = folder.segmentsOf(a).toList();
    expect(left, isNotEmpty);
    expect(left.length, lessThan(_compactEvery));

    await _device();
    await _sync(folder).sync();
    expect(Stores.setting.timeout.fetch(), 100 + _compactEvery + 1);
  });

  test('a large record goes as a blob named by its device', () async {
    final folder = _Folder();
    final a = await _device();
    final big = 'x' * (_inlineMax + 1);
    Stores.setting.set('bigNote', big);
    await _sync(folder).sync();
    expect(folder.files.keys.where((k) => k.startsWith('op-$a-')), hasLength(1));

    await _device();
    await _sync(folder).sync();
    expect(Stores.setting.get<String>('bigNote'), big);
  });
}
