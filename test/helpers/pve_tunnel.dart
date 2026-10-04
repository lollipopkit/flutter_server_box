import 'dart:async';
import 'dart:io';

import 'package:server_box/core/utils/ssh_local_tunnel.dart';

/// An authenticated loopback tunnel whose every connection is carried to
/// [port] on this machine — what `ServerTcpDialer.loopback` gives
/// `PveBackend`, with a fake PVE as the far end.
Future<SshLocalTunnel> loopbackTo(int port) => SshLocalTunnel.bindWithDialer(
  bindHost: InternetAddress.loopbackIPv4.address,
  sshDone: Completer<void>().future,
  dialer: () async =>
      _SocketChannel(await Socket.connect(InternetAddress.loopbackIPv4, port)),
  authenticated: true,
);

class _SocketChannel implements SshTunnelChannel {
  _SocketChannel(this._socket);

  final Socket _socket;

  @override
  Stream<List<int>> get stream => _socket.cast<List<int>>();

  @override
  StreamSink<List<int>> get sink => _socket;

  @override
  Future<void> close() async => _socket.destroy();
}
