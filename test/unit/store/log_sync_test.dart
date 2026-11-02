import 'dart:io';
import 'dart:typed_data';

import 'package:fl_lib/fl_lib.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/core/log_sync.dart';
import 'package:server_box/data/model/container/type.dart';
import 'package:server_box/data/model/server/pve_config.dart';
import 'package:server_box/data/model/server/snippet.dart';
import 'package:server_box/data/res/store.dart';
import 'package:server_box/data/store/sync_recorder.dart';
import 'package:server_box/data/store/sync_records.dart';

import '../../helpers/spi_fixture.dart';

/// LK Cloud's log, in memory: batches numbered as appended, once per key.
final class _Log implements SyncLogTransport {
  final batches = <(int, Uint8List)>[];
  final keys = <String, int>{};
  ({int seq, Uint8List body})? snap;

  /// Batches below this are gone: a read from under it is sent to [snap].
  var floor = 0;
  var compactAfter = 1 << 30;
  var failNext = false;

  /// Live batches refused past this until a snapshot covers them.
  var fullAfter = 1 << 30;

  @override
  Future<({String log, int seq, bool compact})> append(String key, Uint8List body) async {
    if (failNext) {
      failNext = false;
      // Taken, and the answer lost.
      _take(key, body);
      throw const SocketException('lost');
    }
    if (!keys.containsKey(key) && batches.length - (snap?.seq ?? 0) >= fullAfter) throw const SyncLogFull();
    final seq = _take(key, body);
    return (log: 'L1', seq: seq, compact: batches.length > compactAfter);
  }

  int _take(String key, Uint8List body) => keys[key] ??= (batches..add((batches.length + 1, body))).length;

  @override
  Future<SyncLogPage> read(int after, String? log) async {
    if (after < floor) return const SyncLogPage.compacted(log: 'L1');
    final rest = batches.where((b) => b.$1 > after).toList();
    return SyncLogPage(log: batches.isEmpty ? null : 'L1', batches: rest.take(2).toList(), more: rest.length > 2);
  }

  @override
  Future<bool> putSnapshot(int seq, Uint8List body) async {
    if ((snap?.seq ?? 0) >= seq) return false;
    snap = (seq: seq, body: body);
    return true;
  }

  @override
  Future<({String log, int seq, Uint8List body})?> snapshot() async =>
      snap == null ? null : (log: 'L1', seq: snap!.seq, body: snap!.body);
}

/// No encryption: what is under test is what goes into it.
final class _Clear implements SyncSeal {
  @override
  Future<Uint8List> open(Uint8List sealed) async => sealed;
  @override
  Future<Uint8List> seal(Uint8List plain) async => plain;
}

Future<void> _device() async {
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
}

LogSync _sync(_Log log, {bool settings = true}) =>
    LogSync(log, _Clear(), carries: (c) => settings || c != 'kv:setting');

void main() {
  setUpAll(() async {
    final dir = await Directory.systemTemp.createTemp('sbm-log-sync-');
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

  test("one device's edits reach another, and its edits back", () async {
    final log = _Log();
    await _device();
    Stores.snippet.put(snippet);
    Stores.setting.timeout.put(17);
    await _sync(log).sync();
    expect(log.batches, isNotEmpty);

    await _device();
    await _sync(log).sync();
    expect(Stores.snippet.fetchOneRaw(snippet.id)?.script, 'uptime');
    expect(Stores.setting.timeout.fetch(), 17);

    Stores.snippet.delete(snippet);
    Stores.setting.timeout.put(30);
    await _sync(log).sync();

    // A third device reads everything both sent.
    await _device();
    await _sync(log).sync();
    expect(Stores.snippet.fetchOneRaw(snippet.id), isNull);
    expect(Stores.setting.timeout.fetch(), 30);
    expect(SyncRecords.read('snippet', snippet.id), isNull);
  });

  test('an older op does not overwrite a newer edit here', () async {
    final log = _Log();
    await _device();
    Stores.setting.timeout.put(17);
    await _sync(log).sync();

    await _device();
    final sync = _sync(log);
    // Edited here after the other device: its op loses.
    await Future<void>.delayed(const Duration(milliseconds: 2));
    Stores.setting.timeout.put(25);
    await sync.sync();
    expect(Stores.setting.timeout.fetch(), 25);
  });

  test('settings stay unless they are carried', () async {
    final log = _Log();
    await _device();
    Stores.setting.timeout.put(17);
    Stores.snippet.put(snippet);
    await _sync(log, settings: false).sync();

    await _device();
    await _sync(log).sync();
    expect(Stores.snippet.fetchOneRaw(snippet.id), isNotNull);
    expect(Stores.setting.timeout.fetch(), isNot(17));
  });

  test('a snapshot is written when asked for, and read by a device behind it', () async {
    final log = _Log()..compactAfter = 0;
    await _device();
    Stores.snippet.put(snippet);
    await _sync(log).sync();
    expect(log.snap?.seq, log.batches.length);

    log.floor = log.batches.length;
    await _device();
    await _sync(log).sync();
    expect(Stores.snippet.fetchOneRaw(snippet.id)?.script, 'uptime');
  });

  test('a batch whose answer was lost is sent again under its key', () async {
    final log = _Log();
    await _device();
    final sync = _sync(log);
    Stores.setting.timeout.put(17);
    await sync.sync();
    final before = log.batches.length;

    Stores.snippet.put(snippet);
    log.failNext = true;
    await expectLater(sync.sync(), throwsA(isA<SocketException>()));
    expect(log.batches, hasLength(before + 1));
    await sync.sync();
    expect(log.batches, hasLength(before + 1), reason: 'the same key is taken once, and nothing sent twice');
  });

  test('a server carries its container host and PVE settings', () async {
    final log = _Log();
    await _device();
    final spi = spiFixture(name: 'web', id: 'srv1', ip: '10.0.0.2', tags: ['prod']);
    Stores.server.put(spi);
    Stores.container.put(spi.id, ContainerType.podman, 'unix:///run/podman.sock');
    Stores.pve.put(spi.id, PveConfig.example);
    await _sync(log).sync();

    await _device();
    await _sync(log).sync();
    expect(Stores.server.fetchOneRaw(spi.id)?.tags, ['prod']);
    expect(Stores.container.fetch(spi.id, ContainerType.podman), 'unix:///run/podman.sock');
    expect(Stores.pve.fetch(spi.id), PveConfig.example);
  });

  test('a batch nothing here can read is passed over; a newer format stops the read, not the send', () async {
    final log = _Log()..batches.add((1, Uint8List.fromList([1, 2, 3])));
    await _device();
    Stores.snippet.put(snippet);
    await _sync(log).sync();
    expect(LogSync.behind(1), isFalse);
    expect(log.batches.length, greaterThan(1));

    final sent = log.batches.length;
    log.batches.add((sent + 1, Uint8List.fromList(gzip.encode('{"v":99,"ops":[]}'.codeUnits))));
    Stores.setting.timeout.put(9);
    await expectLater(_sync(log).sync(), throwsA(isA<SyncLogTooNew>()));
    expect(log.batches.length, sent + 2, reason: 'the edit is sent all the same');
    expect(LogSync.behind(sent + 1), isTrue);
  });

  test('a full log is compacted, then the batch sent', () async {
    final log = _Log()..fullAfter = 1;
    await _device();
    final sync = _sync(log);
    Stores.snippet.put(snippet);
    await sync.sync();
    Stores.setting.timeout.put(9);
    await sync.sync();
    expect(log.snap?.seq, 1);
    expect(log.batches, hasLength(2));
  });

  test('a device that left settings out writes no snapshot', () async {
    final log = _Log();
    await _device();
    Stores.setting.timeout.put(17);
    await _sync(log).sync();

    log.compactAfter = 0;
    await _device();
    Stores.snippet.put(snippet);
    await _sync(log, settings: false).sync();
    expect(log.snap, isNull);
  });

  test("this device's own append moves the cursor when nothing is between", () async {
    final log = _Log();
    await _device();
    final sync = _sync(log);
    Stores.snippet.put(snippet);
    await sync.sync();
    expect(LogSync.behind(log.batches.length), isFalse);
  });
}
