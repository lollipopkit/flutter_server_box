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
      await closing.timeout(const Duration(seconds: 1));
      channelReady.complete(channel);
      await channel.closedSignal.future.timeout(const Duration(seconds: 1));
      socket.destroy();

      expect(channel.closed, isTrue);
      final rebound = await ServerSocket.bind(
        InternetAddress.loopbackIPv4,
        port,
      );
      await rebound.close();
    },
  );
  test('a channel stream error releases both directions', () async {
    final ready = Completer<_FailureChannel>();
    final listening = Completer<void>();
    final tunnel = await SshLocalTunnel.bindWithDialer(
      bindHost: InternetAddress.loopbackIPv4.address,
      sshDone: Completer<void>().future,
      dialer: () async {
        final channel = _FailureChannel(listening);
        ready.complete(channel);
        return channel;
      },
    );
    addTearDown(tunnel.close);
    final socket = await Socket.connect(tunnel.address, tunnel.port);
    addTearDown(socket.destroy);
    final ended = socket.drain<void>();
    final channel = await ready.future;
    await listening.future;
    channel._controller.addError(const SocketException('SSH stream failed'));
    await channel.closedSignal.future.timeout(const Duration(seconds: 1));
    await ended.timeout(const Duration(seconds: 1));
  });

  group('authenticated', () {
    /// A tunnel for the engine, and how many channels it has dialled.
    Future<(SshLocalTunnel, List<int> Function())> authed({
      bool once = false,
    }) async {
      var dialled = 0;
      final tunnel = await SshLocalTunnel.bindWithDialer(
        bindHost: InternetAddress.loopbackIPv4.address,
        sshDone: Completer<void>().future,
        dialer: () async {
          dialled++;
          return _EchoChannel();
        },
        authenticated: true,
        once: once,
      );
      addTearDown(tunnel.close);
      return (tunnel, () => [dialled]);
    }

    /// Everything [socket] receives until the tunnel ends it.
    Future<int> drained(Socket socket) => socket
        .fold<int>(0, (n, b) => n + b.length)
        .timeout(const Duration(seconds: 5));

    test('a token of its own, the whole length, unguessable', () async {
      final (a, _) = await authed();
      final (b, _) = await authed();
      expect(a.accessToken, hasLength(SshLocalTunnel.accessTokenLength));
      expect(a.accessToken, isNot(b.accessToken));
    });

    test('a connection without it gets nothing, and nothing is dialled', () async {
      final (tunnel, dialled) = await authed();
      final stranger = await Socket.connect(tunnel.address, tunnel.port);
      stranger.add(List.filled(SshLocalTunnel.accessTokenLength, 0));
      expect(await drained(stranger), 0);
      expect(dialled(), [0]);

      // The engine still gets through afterwards.
      final engine = await Socket.connect(tunnel.address, tunnel.port);
      addTearDown(engine.destroy);
      engine.add(tunnel.accessToken!);
      expect(await _echo(engine, [1, 2, 3]), [1, 2, 3]);
      expect(dialled(), [1]);
    });

    test('a token one byte off is refused', () async {
      final (tunnel, dialled) = await authed();
      final wrong = [...tunnel.accessToken!];
      wrong[wrong.length - 1] ^= 1;
      final socket = await Socket.connect(tunnel.address, tunnel.port);
      socket.add(wrong);
      expect(await drained(socket), 0);
      expect(dialled(), [0]);
    });

    test('split across writes, and what follows it is carried', () async {
      final (tunnel, _) = await authed();
      final socket = await Socket.connect(tunnel.address, tunnel.port);
      addTearDown(socket.destroy);
      final token = tunnel.accessToken!;
      socket.add(token.sublist(0, 5));
      await socket.flush();
      await Future<void>.delayed(const Duration(milliseconds: 20));
      // The rest of the token and the first bytes of the protocol together.
      socket.add([...token.sublist(5), 9, 8]);
      final echoed = <int>[];
      final sub = socket.listen(echoed.addAll);
      addTearDown(sub.cancel);
      for (var i = 0; i < 100 && echoed.length < 2; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
      expect(echoed, [9, 8]);
    });

    test('once: one connection, then no port left open', () async {
      final (tunnel, dialled) = await authed(once: true);
      final engine = await Socket.connect(tunnel.address, tunnel.port);
      addTearDown(engine.destroy);
      engine.add(tunnel.accessToken!);
      expect(await _echo(engine, [5]), [5]);
      await expectLater(
        Socket.connect(tunnel.address, tunnel.port),
        throwsA(isA<SocketException>()),
      );
      expect(dialled(), [1]);
    });
  });
}

Future<List<int>> _echo(Socket socket, List<int> bytes) async {
  final response = socket.first;
  socket.add(bytes);
  await socket.flush();
  return (await response.timeout(const Duration(seconds: 1))).toList();
}

class _EchoChannel implements SshTunnelChannel {
  _EchoChannel({Completer<void>? onListen})
    : _controller = StreamController<List<int>>.broadcast(
        onListen: () {
          if (onListen != null && !onListen.isCompleted) {
            onListen.complete();
          }
        },
      );

  final StreamController<List<int>> _controller;
  bool closed = false;
  final closedSignal = Completer<void>();

  @override
  Stream<List<int>> get stream => _controller.stream;

  @override
  StreamSink<List<int>> get sink => _controller.sink;

  @override
  Future<void> close() async {
    if (closed) return;
    closed = true;
    closedSignal.complete();
    await _controller.close();
  }
}

class _FailureChannel extends _EchoChannel {
  _FailureChannel(Completer<void> onListen) : super(onListen: onListen);

  final input = StreamController<List<int>>()..stream.listen((_) {});
  @override
  StreamSink<List<int>> get sink => input.sink;
}
