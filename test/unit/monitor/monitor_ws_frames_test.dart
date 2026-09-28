import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/core/utils/monitor_ws_frames.dart';

class _RealHttp extends HttpOverrides {}

/// The frames a write becomes, as the peer receives them: an agent before its
/// own upgrade drops the connection on one over 64 KiB, so a terminal paste
/// and a relayed upload are both split.
void main() {
  Future<List<int>> framesOf(List<int> data) => HttpOverrides.runWithHttpOverrides(
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final frames = <int>[];
      final got = Completer<void>();
      final accepted = <WebSocket>[];
      WebSocket? client;
      // Released on every path, a timeout included.
      try {
        server.listen((req) async {
          final ws = await WebSocketTransformer.upgrade(req);
          accepted.add(ws);
          var total = 0;
          ws.listen((m) {
            frames.add((m as List<int>).length);
            total += m.length;
            if (total == data.length) got.complete();
          });
        });
        client = await WebSocket.connect(
          'ws://127.0.0.1:${server.port}',
        ).timeout(const Duration(seconds: 5));
        monitorWsAddBinary(client, data);
        await got.future.timeout(const Duration(seconds: 5));
        return frames;
      } finally {
        await client?.close();
        for (final ws in accepted) {
          await ws.close();
        }
        await server.close(force: true);
      }
    },
    _RealHttp(),
  );

  test('a write over the limit goes as frames of the limit and a remainder', () async {
    final data = List.generate(2 * monitorWsMaxFrameBytes + 1, (i) => i % 251);
    expect(await framesOf(data), [monitorWsMaxFrameBytes, monitorWsMaxFrameBytes, 1]);
  });

  test('a write within the limit is one frame', () async {
    expect(await framesOf(List.filled(monitorWsMaxFrameBytes, 7)), [monitorWsMaxFrameBytes]);
    expect(await framesOf(const [1, 2, 3]), [3]);
  });
}
