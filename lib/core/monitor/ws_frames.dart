import 'dart:io';
import 'dart:math';

/// The largest Binary frame sent to a monitor agent's WebSocket endpoints
/// (`/terminal/ws`, `/stream/ws`): the agent's `ws::upgrade::MAX_FRAME`. It
/// drops the connection on a larger one.
const monitorWsMaxFrameBytes = 4 << 20;

/// Sends [data] to [socket] as Binary frames of at most
/// [monitorWsMaxFrameBytes]: a write is whatever the other end wrote at once
/// — an SSH client's upload, an HTTP body, a paste.
void monitorWsAddBinary(WebSocket socket, List<int> data) {
  monitorWsFrames(data).forEach(socket.add);
}

/// [data] as the Binary frames [monitorWsAddBinary] sends.
Iterable<List<int>> monitorWsFrames(List<int> data) sync* {
  for (var at = 0; at < data.length; at += monitorWsMaxFrameBytes) {
    final end = min(at + monitorWsMaxFrameBytes, data.length);
    yield at == 0 && end == data.length ? data : data.sublist(at, end);
  }
}
