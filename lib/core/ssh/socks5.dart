import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

/// The first bytes of a socket, read before the rest of it is handed on.
///
/// What a listener needs whenever a connection says something before its own
/// bytes start: the access token a tunnel for this app's own engine is opened
/// with, a SOCKS5 handshake. Each is a few [take]s and then [rest], which is
/// everything after them, at the pace whoever reads it sets.
///
/// The socket is paused whenever nothing is asking for bytes: between a
/// handshake and the remote end being dialled can be a whole connect timeout,
/// and a buffer with no reader grows without limit.
class SocketHead {
  SocketHead(Stream<List<int>> source) {
    _sub = source.listen(_onData, onError: _onError, onDone: _onDone);
    _sub.pause();
  }

  late final StreamSubscription<List<int>> _sub;
  final _buffer = BytesBuilder(copy: false);
  Completer<Uint8List>? _waiting;
  var _wanted = 0;
  StreamController<List<int>>? _rest;
  Object? _error;
  var _ended = false;

  /// The next [count] bytes. Fails if the socket ends or errors first.
  Future<Uint8List> take(int count) {
    if (_waiting != null || _rest != null) {
      throw StateError('SocketHead is already being read');
    }
    if (_buffer.length >= count) return Future.value(_split(count));
    if (_error case final error?) return Future.error(error);
    if (_ended) return Future.error(const SocketException('Socket closed'));
    _wanted = count;
    final waiting = _waiting = Completer<Uint8List>();
    _sub.resume();
    return waiting.future;
  }

  /// Everything after what was taken: what is buffered, then the socket.
  ///
  /// Whoever reads it sets the pace, as reading the socket would.
  Stream<List<int>> rest() {
    if (_rest != null) throw StateError('SocketHead.rest already taken');
    final rest = _rest = StreamController<List<int>>(
      onPause: _sub.pause,
      onResume: _sub.resume,
      onCancel: _sub.cancel,
    );
    rest.onListen = () {
      if (_buffer.isNotEmpty) rest.add(_buffer.takeBytes());
      if (_error case final error?) rest.addError(error);
      if (_ended) {
        unawaited(rest.close());
        return;
      }
      _sub.resume();
    };
    return rest.stream;
  }

  /// Stops reading, for a connection that is being dropped.
  Future<void> cancel() => _sub.cancel();

  Uint8List _split(int count) {
    final bytes = _buffer.takeBytes();
    if (bytes.length > count) {
      _buffer.add(Uint8List.sublistView(bytes, count));
    }
    return Uint8List.sublistView(bytes, 0, count);
  }

  void _onData(List<int> chunk) {
    if (_rest case final rest?) {
      rest.add(chunk);
      return;
    }
    _buffer.add(chunk);
    final waiting = _waiting;
    if (waiting == null || _buffer.length < _wanted) return;
    _waiting = null;
    _sub.pause();
    waiting.complete(_split(_wanted));
  }

  void _onError(Object error, StackTrace stackTrace) {
    _error = error;
    if (_rest case final rest?) {
      rest.addError(error, stackTrace);
      return;
    }
    final waiting = _waiting;
    _waiting = null;
    waiting?.completeError(error, stackTrace);
  }

  void _onDone() {
    _ended = true;
    if (_rest case final rest?) {
      unawaited(rest.close());
      return;
    }
    final waiting = _waiting;
    _waiting = null;
    waiting?.completeError(const SocketException('Socket closed'));
  }
}

/// Where a SOCKS5 client asked to be connected.
typedef Socks5Target = ({String host, int port});

/// The server half of a SOCKS5 `CONNECT` (RFC 1928), without authentication.
///
/// Only what a dynamic port forward is: a client on this device names an
/// address, and the connection is dialled from the far side. A domain name is
/// handed on as it was given, so it is resolved there — which is what a
/// forward through a server is for, and what `ssh -D` does.
abstract final class Socks5 {
  static const _version = 0x05;
  static const _noAuth = 0x00;
  static const _noAcceptable = 0xFF;
  static const _connect = 0x01;

  /// Reply codes, for [reply].
  static const succeeded = 0x00;
  static const generalFailure = 0x01;
  static const hostUnreachable = 0x04;
  static const commandNotSupported = 0x07;
  static const addressNotSupported = 0x08;

  /// Reads the greeting and the request from [head], answering the greeting
  /// on [socket].
  ///
  /// The target, or null for a client that cannot be served — it has been told
  /// why where the protocol has a way to say it, and the caller drops it.
  /// Fails as [head] does when the socket ends partway.
  static Future<Socks5Target?> negotiate(SocketHead head, Socket socket) async {
    final greeting = await head.take(2);
    if (greeting[0] != _version) return null;
    final methods = await head.take(greeting[1]);
    if (!methods.contains(_noAuth)) {
      socket.add(const [_version, _noAcceptable]);
      return null;
    }
    socket.add(const [_version, _noAuth]);

    final request = await head.take(4);
    if (request[0] != _version) return null;
    final host = switch (request[3]) {
      0x01 => InternetAddress.fromRawAddress(await head.take(4)).address,
      0x03 => String.fromCharCodes(await head.take((await head.take(1))[0])),
      0x04 => InternetAddress.fromRawAddress(await head.take(16)).address,
      _ => null,
    };
    if (host == null) {
      socket.add(reply(addressNotSupported));
      return null;
    }
    final portBytes = await head.take(2);
    final port = portBytes[0] << 8 | portBytes[1];
    // Only CONNECT: BIND and UDP ASSOCIATE would need the far side to listen,
    // and that is a remote forward's business, not a proxy's.
    if (request[1] != _connect) {
      socket.add(reply(commandNotSupported));
      return null;
    }
    if (host.isEmpty || port == 0) {
      socket.add(reply(generalFailure));
      return null;
    }
    return (host: host, port: port);
  }

  /// The reply to a request, with an unspecified bound address: nothing a
  /// client of a forward does with it.
  static List<int> reply(int code) => [
    _version,
    code,
    0x00,
    0x01,
    0, 0, 0, 0,
    0, 0,
  ];
}
