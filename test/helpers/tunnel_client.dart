import 'dart:io';

import 'package:server_box/core/utils/ssh_local_tunnel.dart';

/// Connects to [tunnel] as the remote desktop engine does: its access token
/// first, when it has one.
Future<Socket> connectTunnel(SshLocalTunnel tunnel) async {
  final socket = await Socket.connect(tunnel.address, tunnel.port);
  if (tunnel.accessToken case final token?) socket.add(token);
  return socket;
}
