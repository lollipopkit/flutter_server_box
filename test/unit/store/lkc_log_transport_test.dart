import 'dart:typed_data';

import 'package:fl_lib/fl_lib.dart';
import 'package:flutter_rust_bridge/flutter_rust_bridge_for_generated.dart' show PlatformInt64;
import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/core/sync/lkc_log.dart';
import 'package:server_box/core/sync/log.dart';

/// The LK Cloud adapter's contract: which of the account's refusals mean
/// something to the sync engine, and that every other one reaches it as is.
///
/// The engine is tested through fakes of [SyncLogTransport] and
/// [SyncKeyFile]; this is the other side of those fakes, against a stub of the
/// client the real ones wrap.
void main() {
  const full = LkcSyncError(kind: LkcSyncErrorKind.refused, reason: 'sync_log_full', detail: '');
  const stale = LkcSyncError(kind: LkcSyncErrorKind.refused, reason: 'sync_snapshot_stale', detail: '');
  const quota = LkcSyncError(kind: LkcSyncErrorKind.refused, reason: 'sync_quota', detail: '');
  const changed = LkcSyncError(kind: LkcSyncErrorKind.changed, detail: '');
  final body = Uint8List.fromList(const [1, 2, 3]);

  group('append', () {
    test('a full log is SyncLogFull, for the engine to write a snapshot', () async {
      final t = LkcLogTransport(_Sync(throws: full));
      await expectLater(t.append('k' * 16, body), throwsA(isA<SyncLogFull>()));
    });

    test('any other refusal is rethrown', () async {
      final t = LkcLogTransport(_Sync(throws: quota));
      await expectLater(t.append('k' * 16, body), throwsA(quota));
    });
  });

  group('putSnapshot', () {
    test('a stale snapshot is false: a newer one is already there', () async {
      expect(await LkcLogTransport(_Sync(throws: stale)).putSnapshot(3, body), isFalse);
    });

    test('written is true', () async {
      expect(await LkcLogTransport(_Sync()).putSnapshot(3, body), isTrue);
    });

    test('any other refusal is rethrown', () async {
      await expectLater(LkcLogTransport(_Sync(throws: quota)).putSnapshot(3, body), throwsA(quota));
    });
  });

  group('putBlob', () {
    test('changed is done: a blob is named by its content', () async {
      await LkcLogTransport(_Sync(throws: changed)).putBlob('blob-a', body);
    });

    test('any other refusal is rethrown', () async {
      await expectLater(LkcLogTransport(_Sync(throws: quota)).putBlob('blob-a', body), throwsA(quota));
    });
  });

  group('the key file', () {
    test('a replace names the version it read', () async {
      final sync = _Sync(etag: 'v1');
      expect(await LkcKeyFile(sync, 'acct').write(body, replace: true), isTrue);
      expect(sync.ifMatch, 'v1');
    });

    test('changed meanwhile is false, for the caller to read again', () async {
      expect(await LkcKeyFile(_Sync(throws: changed), 'acct').write(body, replace: false), isFalse);
    });

    test('any other refusal is rethrown', () async {
      await expectLater(LkcKeyFile(_Sync(throws: quota), 'acct').write(body, replace: false), throwsA(quota));
    });
  });
}

/// Answers the writes the adapter makes, or throws [throws] from each.
final class _Sync implements LkcSync {
  _Sync({this.throws, this.etag});

  final LkcSyncError? throws;
  final String? etag;
  String? ifMatch;

  @override
  Future<LkcAppended> append({required String key, required List<int> body}) async {
    if (throws case final e?) throw e;
    throw UnimplementedError('only refusals are exercised');
  }

  @override
  Future<String> putSnapshot({required PlatformInt64 seq, required String from}) async {
    if (throws case final e?) throw e;
    return 'etag';
  }

  @override
  Future<String?> head({required String name}) async => etag;

  @override
  Future<String> upload({required String name, required String from, String? ifMatch}) async {
    this.ifMatch = ifMatch;
    if (throws case final e?) throw e;
    return 'etag';
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
