import 'dart:io';
import 'dart:math';

/// The largest Binary frame sent to a monitor agent's WebSocket endpoints
/// (`/terminal/ws`, `/stream/ws`). An agent before its own upgrade
/// (`monitor/src/api/ws/upgrade.rs`) takes ntex's default codec, which
/// refuses a frame over 64 KiB by dropping the connection; one since takes
/// 4 MiB.
///
/// TODO: remove the split once agents before the 4 MiB limit are gone.
const monitorWsMaxFrameBytes = 64 * 1024;

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
