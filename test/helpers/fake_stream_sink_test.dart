import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'fake_stream_sink.dart';

void main() {
  test('done completes on close and close is idempotent', () async {
    final sink = FakeStreamSink((_) {});
    var completed = false;
    sink.done.then((_) => completed = true);

    await sink.close();
    await sink.close();

    expect(completed, isTrue);
  });

  test('closed sinks reject data and errors', () async {
    final sink = FakeStreamSink((_) {});
    await sink.close();

    expect(() => sink.add(Uint8List(0)), throwsStateError);
    expect(() => sink.addError(StateError('late')), throwsStateError);
    await expectLater(
      sink.addStream(const Stream<Uint8List>.empty()),
      throwsStateError,
    );
  });
}
