import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/core/utils/ssh_local_tunnel.dart';

void main() {
  test('the desktop listener is IPv4 loopback on an ephemeral port', () async {
    final sshDone = Completer<void>();
    final tunnel = await SshLocalTunnel.bindWithDialer(
      bindHost: InternetAddress.loopbackIPv4.address,
      sshDone: sshDone.future,
      dialer: () async => _EchoChannel(),
    );
    addTearDown(tunnel.close);

    expect(tunnel.address.address, InternetAddress.loopbackIPv4.address);
    expect(tunnel.address.isLoopback, isTrue);
    expect(tunnel.port, greaterThan(0));
  });

  test('each local connection gets its own SSH channel', () async {
    final sshDone = Completer<void>();
    var channels = 0;
    final tunnel = await SshLocalTunnel.bindWithDialer(
      bindHost: InternetAddress.loopbackIPv4.address,
      sshDone: sshDone.future,
      dialer: () async {
        channels++;
        return _EchoChannel();
      },
    );
    addTearDown(tunnel.close);

    final first = await Socket.connect(tunnel.address, tunnel.port);
    final second = await Socket.connect(tunnel.address, tunnel.port);
    addTearDown(first.destroy);
    addTearDown(second.destroy);

    expect(await _echo(first, [1, 2, 3]), [1, 2, 3]);
    expect(await _echo(second, [4, 5]), [4, 5]);
    expect(channels, 2);
  });

  test('SSH disconnect closes the listener and active channels', () async {
    final sshDone = Completer<void>();
    final made = <_EchoChannel>[];
    final tunnel = await SshLocalTunnel.bindWithDialer(
      bindHost: InternetAddress.loopbackIPv4.address,
      sshDone: sshDone.future,
      dialer: () async {
        final channel = _EchoChannel();
        made.add(channel);
        return channel;
      },
    );
    final port = tunnel.port;
    final socket = await Socket.connect(tunnel.address, port);
    await _echo(socket, [1]);

    sshDone.complete();
    await tunnel.done.timeout(const Duration(seconds: 1));

    expect(tunnel.isClosed, isTrue);
    expect(made.single.closed, isTrue);
    final rebound = await ServerSocket.bind(InternetAddress.loopbackIPv4, port);
    await rebound.close();
  });

  test(
    'closing while a channel is opening leaves no listener or channel',
    () async {
      final sshDone = Completer<void>();
      final dialStarted = Completer<void>();
      final channelReady = Completer<SshTunnelChannel>();
      final channel = _EchoChannel();
      final tunnel = await SshLocalTunnel.bindWithDialer(
        bindHost: InternetAddress.loopbackIPv4.address,
        sshDone: sshDone.future,
        dialer: () {
          if (!dialStarted.isCompleted) dialStarted.complete();
          return channelReady.future;
        },
      );
      final port = tunnel.port;
      final socket = await Socket.connect(tunnel.address, port);
      await dialStarted.future.timeout(const Duration(seconds: 1));

      final closing = tunnel.close();
      channelReady.complete(channel);
      await closing.timeout(const Duration(seconds: 1));
      socket.destroy();

      expect(channel.closed, isTrue);
      final rebound = await ServerSocket.bind(
        InternetAddress.loopbackIPv4,
        port,
      );
      await rebound.close();
    },
  );
}

Future<List<int>> _echo(Socket socket, List<int> bytes) async {
  final response = socket.first;
  socket.add(bytes);
  await socket.flush();
  return (await response.timeout(const Duration(seconds: 1))).toList();
}

class _EchoChannel implements SshTunnelChannel {
  final StreamController<List<int>> _controller =
      StreamController<List<int>>.broadcast();
  bool closed = false;

  @override
  Stream<List<int>> get stream => _controller.stream;

  @override
  StreamSink<List<int>> get sink => _controller.sink;

  @override
  Future<void> close() async {
    if (closed) return;
    closed = true;
    await _controller.close();
  }
}
