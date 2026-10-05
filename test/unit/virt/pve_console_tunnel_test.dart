/// `PveConsoleTunnelChannel.loopbackOnce` — what puts a graphical PVE
/// console on a loopback port for the VNC engine — over a fake console and a
/// real loopback socket: bytes both ways and in order, one connection only,
/// and the tunnel and the console each ending the other.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/core/utils/pve_console.dart';
import 'package:server_box/core/utils/ssh_local_tunnel.dart';

import '../../helpers/fake_pve_console.dart';
import '../../helpers/tunnel_client.dart';

void main() {
  late FakePveConsole console;

  setUp(() => console = FakePveConsole());

  Future<void> until(bool Function() done) async {
    final deadline = DateTime.now().add(const Duration(seconds: 5));
    while (!done()) {
      if (DateTime.now().isAfter(deadline)) fail('timed out');
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
  }

  Future<SshLocalTunnel> open() async =>
      PveConsoleTunnelChannel.loopbackOnce(PveConsoleTunnelChannel(console));

  String sent() => console.calls
      .where((c) => c.startsWith('send:'))
      .map((c) => c.substring(5))
      .join();

  test('bytes cross both ways, in order', () async {
    final tunnel = await open();
    addTearDown(tunnel.close);
    expect(tunnel.address.isLoopback, isTrue);

    final client = await connectTunnel(tunnel);
    addTearDown(client.destroy);
    final fromTunnel = BytesBuilder();
    client.listen(fromTunnel.add);

    // The RFB greeting a VNC server opens with, and the client's answer.
    console
      ..output(ascii.encode('RFB 003.008\n'))
      ..output(const [0, 1, 2, 255]);
    await until(() => fromTunnel.length >= 16);
    expect(fromTunnel.takeBytes(), [...ascii.encode('RFB 003.008\n'), 0, 1, 2, 255]);

    client.add(ascii.encode('RFB 003.008\n'));
    await client.flush();
    client.add(ascii.encode('more'));
    await client.flush();
    await until(() => sent().length >= 16);
    expect(sent(), 'RFB 003.008\nmore');
  });

  test('a second connection is refused: one ticket, one console', () async {
    final tunnel = await open();
    addTearDown(tunnel.close);

    final first = await connectTunnel(tunnel);
    addTearDown(first.destroy);
    first.add(const [7]);
    await until(() => sent().isNotEmpty);

    // The listener is gone once the one connection is through: nothing is
    // left open on the port for the rest of the session.
    await expectLater(connectTunnel(tunnel), throwsA(isA<SocketException>()));
  });

  test('the console ending closes the connection and the tunnel', () async {
    final tunnel = await open();
    final client = await connectTunnel(tunnel);
    addTearDown(client.destroy);
    final ended = client.drain<void>().timeout(const Duration(seconds: 5));
    client.add(const [1]);
    await until(() => sent().isNotEmpty);

    console.end();
    await ended;
    await tunnel.done.timeout(const Duration(seconds: 5));
    expect(tunnel.isClosed, isTrue);
  });

  test('closing the tunnel before any client closes the console', () async {
    // The console caller keeps only the tunnel; the dialer that would have
    // handed the console to a connection never ran.
    final tunnel = await open();
    await tunnel.close();
    await until(() => console.closed);
  });

  test('closing the tunnel with its client connected closes the console', () async {
    // The client's bytes are piped into the channel's sink for the whole
    // connection; closing the controller under that pipe threw, before the
    // console was closed.
    final tunnel = await open();
    final client = await connectTunnel(tunnel);
    addTearDown(client.destroy);
    client.add(const [1]);
    await until(() => sent().isNotEmpty);

    await tunnel.close().timeout(const Duration(seconds: 5));
    expect(console.closed, isTrue);
  });

  test('an error in what is piped in closes the console', () async {
    final channel = PveConsoleTunnelChannel(console);
    // What `SshTunnelBridge` forwards when the local socket's read fails.
    await channel.sink.addStream(
      Stream<List<int>>.error(const SocketException('read failed')),
    );
    await until(() => console.closed);
  });

  test('a failed send closes the console', () async {
    final channel = PveConsoleTunnelChannel(console);
    console.failSends = true;
    channel.sink.add(const [1]);
    await channel.done.timeout(const Duration(seconds: 5));
    expect(console.closed, isTrue);
  });

  test('the client hanging up closes the console', () async {
    final tunnel = await open();
    addTearDown(tunnel.close);
    final client = await connectTunnel(tunnel);
    client.add(const [1]);
    await until(() => sent().isNotEmpty);

    await client.close();
    await until(() => console.closed);
  });
}
