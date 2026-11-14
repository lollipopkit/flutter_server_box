import 'dart:async';
import 'dart:typed_data';

import 'package:dartssh2/dartssh2.dart';

/// [inner], and what carries it, released together: the jump client a
/// forwarded channel came through, the OpenSSH master's control connection.
///
/// `forwardLocal` and a master hand back a stream and nothing else, so what
/// carries it had no owner: on success nobody held it, and closing the stream
/// left it running until the far end timed it out.
class OwningSocket implements SSHSocket {
  OwningSocket(this._inner, this._release);

  final SSHSocket _inner;
  final void Function() _release;
  var _released = false;

  void _releaseOnce() {
    if (_released) return;
    _released = true;
    _release();
  }

  @override
  Stream<Uint8List> get stream => _inner.stream;

  @override
  StreamSink<List<int>> get sink => _inner.sink;

  @override
  Future<void> get done => _inner.done;

  @override
  Future<void> close() async {
    try {
      await _inner.close();
    } finally {
      _releaseOnce();
    }
  }

  @override
  void destroy() {
    try {
      _inner.destroy();
    } finally {
      _releaseOnce();
    }
  }

  @override
  Future<void> flush() => _inner.flush();

  @override
  String toString() => 'OwningSocket($_inner)';
}
