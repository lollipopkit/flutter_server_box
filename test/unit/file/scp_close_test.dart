import 'dart:async';

import 'package:dartssh2/dartssh2.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/core/utils/scp_file_backend.dart';

/// Never reached: the write under test is still spooling its input when the
/// backend is closed, which is before any channel is asked for.
final class _UnusedClient implements SSHClient {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('no channel should be opened');
}

void main() {
  test('close ends an unsized write that is still spooling', () async {
    final cancelled = Completer<void>();
    final producer = StreamController<List<int>>(
      onCancel: () => cancelled.complete(),
    );
    producer.add([1, 2, 3]);

    final backend = ScpFileBackend(_UnusedClient());
    final write = backend.write('/tmp/x', producer.stream);
    await Future<void>.delayed(const Duration(milliseconds: 50));

    await backend.close();

    await expectLater(write, throwsA(isA<ScpShellException>()));
    await cancelled.future.timeout(const Duration(seconds: 5));
  });
}
