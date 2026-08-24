import 'dart:async';
import 'dart:typed_data';

final class FakeStreamSink implements StreamSink<Uint8List> {
  final void Function(Uint8List data) _onAdd;
  final _done = Completer<void>();
  bool _closed = false;

  FakeStreamSink(this._onAdd);

  @override
  void add(Uint8List data) {
    if (_closed) throw StateError('Cannot add to a closed sink');
    _onAdd(data);
  }

  @override
  void addError(Object error, [StackTrace? stackTrace]) {
    if (_closed) throw StateError('Cannot add errors to a closed sink');
  }

  @override
  Future<void> addStream(Stream<Uint8List> stream) async {
    if (_closed) throw StateError('Cannot add a stream to a closed sink');
    await for (final chunk in stream) {
      add(chunk);
    }
  }

  @override
  Future<void> close() {
    if (!_closed) {
      _closed = true;
      _done.complete();
    }
    return done;
  }

  @override
  Future<void> get done => _done.future;
}
