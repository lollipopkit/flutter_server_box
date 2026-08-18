import 'dart:async';
import 'dart:typed_data';

final class FakeStreamSink implements StreamSink<Uint8List> {
  final void Function(Uint8List data) _onAdd;

  FakeStreamSink(this._onAdd);

  @override
  void add(Uint8List data) => _onAdd(data);

  @override
  void addError(Object error, [StackTrace? stackTrace]) {}

  @override
  Future<void> addStream(Stream<Uint8List> stream) async {
    await for (final chunk in stream) {
      add(chunk);
    }
  }

  @override
  Future<void> close() async {}

  @override
  Future<void> get done async {}
}
