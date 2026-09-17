import 'dart:async';
import 'dart:typed_data';

import 'package:dartssh2/dartssh2.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/core/utils/sftp_file_backend.dart';

void main() {
  test('only a missing path is reported as absent', () async {
    final client = _Client();
    final backend = SftpFileBackend(client);
    client.statError = SftpStatusError(SftpStatusCode.noSuchFile, 'missing');
    expect(await backend.stat('/x'), isNull);
    client.statError = SftpStatusError(
      SftpStatusCode.permissionDenied,
      'denied',
    );
    await expectLater(backend.stat('/x'), throwsA(same(client.statError)));
    expect(client.followedLink, isFalse);
    await backend.close();
    expect(client.closed, 1);
  });

  test(
    'a failed read closes its handle and preserves the stream error',
    () async {
      final client = _Client();
      final failure = StateError('read failed');
      final file = _File(Stream.error(failure));
      client.opened.complete(file);
      final backend = SftpFileBackend(client);
      await expectLater(
        backend.read('/x', offset: 42).drain<void>(),
        throwsA(same(failure)),
      );
      expect(file.offset, 42);
      expect(file.closed, 1);
      await backend.close();
    },
  );

  test('cancelling a read closes its handle', () async {
    final bytes = StreamController<Uint8List>();
    final client = _Client();
    final file = _File(bytes.stream);
    client.opened.complete(file);
    final backend = SftpFileBackend(client);
    final first = backend.read('/x').first;
    bytes.add(Uint8List.fromList([1, 2]));
    expect(await first, [1, 2]);
    await file.closedSignal.future.timeout(const Duration(seconds: 1));
    expect(file.closed, 1);
    await bytes.close();
    await backend.close();
  });

  test('a timed out open closes the channel and a late handle', () async {
    final client = _Client();
    final backend = SftpFileBackend(
      client,
      timeout: const Duration(milliseconds: 10),
    );
    await expectLater(
      backend.read('/x').drain<void>(),
      throwsA(isA<TimeoutException>()),
    );
    expect(client.closed, 1);
    final file = _File(const Stream.empty());
    client.opened.complete(file);
    await file.closedSignal.future.timeout(const Duration(seconds: 1));
    expect(file.closed, 1);
  });
}

class _Client implements SftpClient {
  final opened = Completer<SftpFile>();
  Object? statError;
  bool? followedLink;
  int closed = 0;
  @override
  Future<SftpFile> open(
    String filename, {
    SftpFileOpenMode mode = SftpFileOpenMode.read,
  }) => opened.future;
  @override
  Future<SftpFileAttrs> stat(String path, {bool followLink = true}) async {
    followedLink = followLink;
    throw statError!;
  }

  @override
  Future<void> close() async {
    closed++;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _File implements SftpFile {
  _File(this.bytes);
  final Stream<Uint8List> bytes;
  final closedSignal = Completer<void>();
  int closed = 0;
  int? offset;
  @override
  Stream<Uint8List> read({
    int? length,
    int offset = 0,
    void Function(int)? onProgress,
    int chunkSize = 32768,
    int maxPendingRequests = 64,
  }) {
    this.offset = offset;
    return bytes;
  }

  @override
  Future<void> close() async {
    closed++;
    if (!closedSignal.isCompleted) closedSignal.complete();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
