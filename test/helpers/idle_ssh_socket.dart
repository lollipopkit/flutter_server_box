import 'dart:async';
import 'dart:typed_data';

import 'package:dartssh2/dartssh2.dart';

/// A socket that never answers: an [SSHClient] over it is open and silent,
/// like one whose server has stopped replying.
class IdleSshSocket implements SSHSocket {
  final _incoming = StreamController<Uint8List>();
  // Broadcast: nothing listens, so writes are dropped rather than buffered,
  // and `close` completes rather than waiting for a listener forever.
  final _outgoing = StreamController<List<int>>.broadcast();
  final _done = Completer<void>();

  @override
  Stream<Uint8List> get stream => _incoming.stream;

  @override
  StreamSink<List<int>> get sink => _outgoing.sink;

  @override
  Future<void> get done => _done.future;

  @override
  Future<void> close() async {
    if (!_done.isCompleted) _done.complete();
    await _incoming.close();
    await _outgoing.close();
  }

  @override
  void destroy() => unawaited(close());

  @override
  Future<void> flush() async {}
}
