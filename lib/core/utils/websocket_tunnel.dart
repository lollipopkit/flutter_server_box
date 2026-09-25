import 'dart:async';
import 'dart:io';

import 'package:server_box/core/utils/ssh_local_tunnel.dart';

/// A websocket whose binary frames carry a TCP byte stream, as a tunnel
/// channel — so [SshLocalTunnel] can hand it to a client that only takes a
/// host and a port.
///
/// For PVE's `vncwebsocket` behind `vncproxy`: each binary frame is a slice
/// of the RFB stream, the way noVNC reads it. Frame boundaries mean nothing;
/// a text frame is not part of the stream and is dropped.
class WebSocketTunnelChannel implements SshTunnelChannel {
  WebSocketTunnelChannel(this._socket) {
    _outgoing.stream.listen(
      (bytes) {
        if (_closed) return;
        try {
          _socket.add(bytes);
        } catch (_) {
          // Closed from the other side; the stream's end reports it.
        }
      },
      onDone: () => unawaited(close()),
      cancelOnError: true,
    );
  }

  final WebSocket _socket;
  final _outgoing = StreamController<List<int>>();
  var _closed = false;

  /// Completes when the websocket has ended, from either side.
  Future<void> get done => _socket.done.then<void>((_) {}, onError: (_) {});

  @override
  Stream<List<int>> get stream => _socket
      .where((frame) => frame is List<int>)
      .cast<List<int>>();

  @override
  StreamSink<List<int>> get sink => _outgoing.sink;

  @override
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    if (!_outgoing.isClosed) unawaited(_outgoing.close());
    await _socket
        .close(WebSocketStatus.normalClosure)
        .timeout(const Duration(seconds: 3), onTimeout: () {})
        .catchError((_) {});
  }

  /// A loopback listener that carries one connection over [channel]: the
  /// first to present the tunnel's `SshLocalTunnel.accessToken`. Any other
  /// is dropped unread, and the listener closes once that one is through.
  ///
  /// One connection because the websocket behind [channel] is one: a PVE
  /// console ticket opens one socket, and a client connecting a second time
  /// needs a new ticket — which is the caller's to fetch, with a new tunnel.
  /// The tunnel closes when the websocket does.
  static Future<SshLocalTunnel> loopbackOnce(
    WebSocketTunnelChannel channel,
  ) async {
    var taken = false;
    try {
      return await SshLocalTunnel.bindWithDialer(
        bindHost: InternetAddress.loopbackIPv4.address,
        sshDone: channel.done,
        authenticated: true,
        once: true,
        dialer: () async {
          if (taken) {
            throw StateError('This console tunnel carries one connection');
          }
          taken = true;
          return channel;
        },
      );
    } catch (_) {
      await channel.close();
      rethrow;
    }
  }
}
