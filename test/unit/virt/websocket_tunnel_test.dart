/// `WebSocketTunnelChannel.loopbackOnce` — the adapter that puts PVE's
/// `vncwebsocket` on a loopback port for the VNC engine — against a real
/// websocket server and a real loopback socket: bytes both ways, text frames
/// dropped, one connection only, and the tunnel following the websocket's
/// end.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/core/utils/websocket_tunnel.dart';

void main() {
  late HttpServer server;
  late Completer<WebSocket> accepted;
  late List<List<int>> received;
  late Completer<void> farEnded;

  setUp(() async {
    received = [];
    accepted = Completer();
    farEnded = Completer();
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      final ws = await WebSocketTransformer.upgrade(
        request,
        protocolSelector: (protocols) => protocols.first,
      );
      ws.listen(
        (frame) {
          if (frame is List<int>) received.add(frame);
        },
        onDone: farEnded.complete,
      );
      accepted.complete(ws);
    });
  });

  tearDown(() => server.close(force: true));

  Future<WebSocketTunnelChannel> open() async => WebSocketTunnelChannel(
    await WebSocket.connect(
      'ws://127.0.0.1:${server.port}/',
      protocols: const ['binary'],
    ),
  );

  Future<void> until(bool Function() done) async {
    final deadline = DateTime.now().add(const Duration(seconds: 5));
    while (!done()) {
      if (DateTime.now().isAfter(deadline)) fail('timed out');
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
  }

  test('bytes cross both ways; text frames are not part of the stream', () async {
    final tunnel = await WebSocketTunnelChannel.loopbackOnce(await open());
    addTearDown(tunnel.close);
    expect(tunnel.address.isLoopback, isTrue);
    final far = await accepted.future;

    final client = await Socket.connect(tunnel.address, tunnel.port);
    addTearDown(client.destroy);
    final fromTunnel = BytesBuilder();
    client.listen(fromTunnel.add);

    // The RFB greeting a VNC server opens with, and the client's answer.
    far.add(Uint8List.fromList(ascii.encode('RFB 003.008\n')));
    far.add('not part of the stream');
    far.add(Uint8List.fromList(const [0, 1, 2, 255]));
    await until(() => fromTunnel.length >= 16);
    expect(fromTunnel.takeBytes(), [
      ...ascii.encode('RFB 003.008\n'),
      0,
      1,
      2,
      255,
    ]);

    client.add(ascii.encode('RFB 003.008\n'));
    client.add(const [1]);
    await client.flush();
    await until(() => received.expand((f) => f).length >= 13);
    expect(received.expand((f) => f).toList(), [
      ...ascii.encode('RFB 003.008\n'),
      1,
    ]);
  });

  test('a second connection is refused: one ticket, one socket', () async {
    final tunnel = await WebSocketTunnelChannel.loopbackOnce(await open());
    addTearDown(tunnel.close);
    await accepted.future;

    final first = await Socket.connect(tunnel.address, tunnel.port);
    addTearDown(first.destroy);
    first.add(const [7]);
    await until(() => received.isNotEmpty);

    final second = await Socket.connect(tunnel.address, tunnel.port);
    addTearDown(second.destroy);
    // Closed by the tunnel without a byte.
    final bytes = await second
        .fold<int>(0, (n, b) => n + b.length)
        .timeout(const Duration(seconds: 5));
    expect(bytes, 0);
  });

  test('the websocket ending closes the connection and the tunnel', () async {
    final tunnel = await WebSocketTunnelChannel.loopbackOnce(await open());
    final far = await accepted.future;
    final client = await Socket.connect(tunnel.address, tunnel.port);
    addTearDown(client.destroy);
    final ended = client.drain<void>().timeout(const Duration(seconds: 5));
    client.add(const [1]);
    await until(() => received.isNotEmpty);

    await far.close();
    await ended;
    await tunnel.done.timeout(const Duration(seconds: 5));
    expect(tunnel.isClosed, isTrue);
  });

  test('the client hanging up closes the websocket', () async {
    final tunnel = await WebSocketTunnelChannel.loopbackOnce(await open());
    addTearDown(tunnel.close);
    await accepted.future;
    final client = await Socket.connect(tunnel.address, tunnel.port);
    client.add(const [1]);
    await until(() => received.isNotEmpty);

    await client.close();
    await farEnded.future.timeout(const Duration(seconds: 5));
  });
}
