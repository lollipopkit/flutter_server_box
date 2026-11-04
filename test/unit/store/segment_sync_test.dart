import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:fl_lib/fl_lib.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/core/sync/key.dart';
import 'package:server_box/core/sync/log.dart';
import 'package:server_box/data/model/server/snippet.dart';
import 'package:server_box/data/store/stores.dart';
import 'package:server_box/data/store/sync_recorder.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  Future<void> putBlob(String name, Uint8List body) => write(name, body);

  @override
  Future<Uint8List?> getBlob(String name) async => hidden.contains(name) ? null : files[name]?.body;

  @override
  Future<List<({String name, DateTime? at})>> blobs(String prefix) async => [
    for (final MapEntry(:key, :value) in files.entries)
      if (key.startsWith(prefix) && !hidden.contains(key)) (name: key, at: value.at),
  ];

  @override
  Future<void> deleteBlob(String name) async => files.remove(name);

  Iterable<String> segmentsOf(String device) => files.keys.where((k) => k.startsWith('seg-$device-'));
}

/// No encryption: what is under test is what goes into it.
final class _Clear implements SyncSeal {
  @override
  Future<Uint8List> open(Uint8List sealed) async => sealed;
  @override
  Future<Uint8List> seal(Uint8List plain) async => plain;

  @override
  String nameOf(List<int> data) => syncBlobName(secret: 'test', data: data);

  @override
  Future<bool> refresh() async => false;
}

/// The key file cannot be reached.
final class _Offline extends _Clear {
  @override
  Future<Uint8List> open(Uint8List sealed) async => throw const SocketException('offline');
}

/// A key per device; [remote] is what the key file holds.
final class _Keyed implements SyncSeal {
  _Keyed(this.remote, this.held);

  final List<String> remote;
  List<String> held;

  @override
  Future<Uint8List> seal(Uint8List plain) async => Uint8List.fromList([...utf8.encode('${held.first}|'), ...plain]);

  @override
  Future<Uint8List> open(Uint8List sealed) async {
    final bar = sealed.indexOf(124);
    if (!held.contains(utf8.decode(sealed.sublist(0, bar)))) throw const FormatException('not ours');
    return Uint8List.sublistView(sealed, bar + 1);
  }

  @override
  String nameOf(List<int> data) => syncBlobName(secret: held.first, data: data);

  @override
  Future<bool> refresh() async {
    if (remote.every(held.contains)) return false;
    held = {...held, ...remote}.toList();
    return true;
  }
}

/// [SyncKey]'s file, in memory; while [blind], a device that does not see
/// the one there yet (iCloud's delivery, a write at the same time).
final class _KeyFile implements SyncKeyFile {
  Uint8List? body;
  var blind = false;

  @override
  String get id => 'test';

  @override
  PrefProp<bool> get rewrap => SyncKey.filesRewrap;

  @override
  Future<Uint8List?> read() async => blind ? null : body;

  @override
  Future<bool> write(Uint8List body, {required bool replace}) async {
    if (!replace && this.body != null && !blind) return false;
    this.body = body;
    return true;
  }
}

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
  SyncRecorder.install();
  SegmentSync.bind('folder');
  return SyncRecorder.deviceHexOf(SyncRecorder.device);
}

SegmentSync _sync(_Folder folder, [SyncSeal? seal]) => SegmentSync(folder, seal ?? _Clear());

Uint8List _snapshotOf(Map<String, int> covers) =>
    Uint8List.fromList(gzip.encode(utf8.encode(jsonEncode({'v': 1, 'ops': [], 'covers': covers}))));

void main() {
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

  test('a number once taken is not written again, though what was sent is forgotten', () async {
    final folder = _Folder();
    final a = await _device();
    Stores.setting.timeout.put(17);
    await _sync(folder).sync();
    SegmentSync.forget();
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
    await expectLater(sync.sync(), throwsA(isA<SocketException>()));
    await sync.sync();
    expect(folder.segmentsOf(a).toSet(), {'seg-$a-1.age'});

    Stores.setting.timeout.put(18);
    folder.failNext = false;
    await expectLater(sync.sync(), throwsA(isA<SocketException>()));
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
    await expectLater(_sync(folder, _Offline()).sync(), throwsA(isA<SocketException>()));
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
    // Made at the same time as the reader's key, before either saw the other.
    await _sync(folder, _Keyed(['ka'], ['ka'])).sync();
    Stores.setting.timeout.put(17);
    await _sync(folder, _Keyed(['ka'], ['ka'])).sync();
    expect(folder.segmentsOf(a), isNotEmpty);

    await _device();
    final remote = ['kb'];
    final key = _Keyed(remote, ['kb']);
    final reader = _sync(folder, key);
    await reader.sync();
    expect(Stores.setting.timeout.fetch(), isNot(17));

    // The writer merged its key into the file.
    remote.add('ka');
    await reader.sync();
    expect(Stores.setting.timeout.fetch(), 17);

    // One no key ever opens, past the wait: passed over, and what follows read.
    final c = await _device();
    final old = DateTime.now().subtract(const Duration(days: 8));
    folder.files['seg-$c-1.age'] = (body: Uint8List.fromList(utf8.encode('kz|x')), at: old);
    folder.files['seg-$c-2.age'] = (body: Uint8List.fromList(utf8.encode('kz|x')), at: DateTime.now());
    await _device();
    final r = _sync(folder, _Keyed(['ka', 'kb'], ['ka', 'kb']));
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
    for (var i = 0; i < SegmentSync.compactEvery + 1; i++) {
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
    expect(Stores.setting.timeout.fetch(), 100 + SegmentSync.compactEvery);
  });

  test('segments are removed down to the last when the snapshots cover them all', () async {
    final folder = _Folder();
    final a = await _device();
    final sync = _sync(folder);
    for (var i = 0; i < SegmentSync.compactEvery + 2; i++) {
      Stores.setting.timeout.put(100 + i);
      await sync.sync();
    }
    final left = folder.segmentsOf(a).toList();
    expect(left, isNotEmpty);
    expect(left.length, lessThan(SegmentSync.compactEvery));

    await _device();
    await _sync(folder).sync();
    expect(Stores.setting.timeout.fetch(), 100 + SegmentSync.compactEvery + 1);
  });

  test('a large record goes as a blob named by its device', () async {
    final folder = _Folder();
    final a = await _device();
    final big = 'x' * (SyncEngine.inlineMax + 1);
    Stores.setting.set('bigNote', big);
    await _sync(folder).sync();
    expect(folder.files.keys.where((k) => k.startsWith('op-$a-')), hasLength(1));

    await _device();
    await _sync(folder).sync();
    expect(Stores.setting.get<String>('bigNote'), big);
  });

  group('SyncKey', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      await PrefStore.shared.init();
    });

    test('two devices that made a key at once end with both, sealing with one', () async {
      final file = _KeyFile();
      FlutterSecureStorage.setMockInitialValues({SecureStoreProps.bakPwd.key: 'pwd'});
      final a = await SyncKey.load(file);
      final sealedByA = await a.seal(Uint8List.fromList([1]));

      // B did not see A's file yet, and wrote over it.
      FlutterSecureStorage.setMockInitialValues({SecureStoreProps.bakPwd.key: 'pwd'});
      file.blind = true;
      final b = await SyncKey.load(file);
      file.blind = false;
      final sealedByB = await b.seal(Uint8List.fromList([2]));
      await expectLater(a.open(sealedByB), throwsFormatException);

      // A, on its keys, meets B's file: puts its own back beside B's.
      expect(await a.refresh(), isTrue);
      expect(await a.open(sealedByB), [2]);
      expect(await b.refresh(), isTrue);
      expect(await b.open(sealedByA), [1]);
      expect(a.nameOf([0]), b.nameOf([0]), reason: 'both seal with the same key now');
      expect(await a.refresh(), isFalse);
    });
  });
}
