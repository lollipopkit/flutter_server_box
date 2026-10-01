import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/core/utils/socks5.dart';
import 'package:server_box/core/utils/ssh_local_tunnel.dart';

/// A dynamic forward: a SOCKS5 proxy on this device whose every connection is
/// dialled to the address its client named.
void main() {
  late List<Socks5Target> dialled;

  setUp(() => dialled = []);

  Future<SshLocalTunnel> proxy({bool fail = false}) async {
    final tunnel = await SshLocalTunnel.bindSocks(
      bindHost: InternetAddress.loopbackIPv4.address,
      sshDone: Completer<void>().future,
      dial: (host, port) async {
        dialled.add((host: host, port: port));
        if (fail) throw const SocketException('refused');
        return _EchoChannel();
      },
    );
    addTearDown(tunnel.close);
    return tunnel;
  }

  Future<_Client> connect(SshLocalTunnel tunnel) async {
    final client = _Client(await Socket.connect(tunnel.address, tunnel.port));
    addTearDown(client.socket.destroy);
    return client;
  }

  /// No authentication, then CONNECT to an address of [atyp].
  Future<void> request(_Client client, int atyp, List<int> addr, int port) async {
    client.socket.add([5, 1, 0]);
    expect(await client.read(2), [5, 0]);
    client.socket.add([5, 1, 0, atyp, ...addr, port >> 8, port & 0xff]);
  }

  test('an IPv4 address is dialled, and the bytes are carried', () async {
    final client = await connect(await proxy());
    await request(client, 1, [10, 0, 0, 7], 8080);

    expect(await client.read(10), Socks5.reply(Socks5.succeeded));
    expect(dialled, [(host: '10.0.0.7', port: 8080)]);
    client.socket.add([1, 2, 3]);
    expect(await client.read(3), [1, 2, 3]);
  });

  test('a domain name is handed on unresolved', () async {
    // Resolved on the far side, which is what a forward through a server is
    // for — the same as `ssh -D`.
    final client = await connect(await proxy());
    await request(client, 3, [12, ...'intranet.lan'.codeUnits], 443);

    expect(await client.read(10), Socks5.reply(Socks5.succeeded));
    expect(dialled, [(host: 'intranet.lan', port: 443)]);
  });

  test('an IPv6 address is dialled', () async {
    final client = await connect(await proxy());
    await request(client, 4, [...List.filled(15, 0), 1], 22);

    expect(await client.read(10), Socks5.reply(Socks5.succeeded));
    expect(dialled, [(host: '::1', port: 22)]);
  });

  test('the handshake split across writes still parses', () async {
    final client = await connect(await proxy());
    client.socket.add([5]);
    await Future<void>.delayed(const Duration(milliseconds: 20));
    client.socket.add([1, 0]);
    expect(await client.read(2), [5, 0]);
    client.socket.add([5, 1, 0, 1, 127]);
    await Future<void>.delayed(const Duration(milliseconds: 20));
    client.socket.add([0, 0, 1, 0, 80]);

    expect(await client.read(10), Socks5.reply(Socks5.succeeded));
    expect(dialled, [(host: '127.0.0.1', port: 80)]);
  });

  test('BIND is refused, and nothing is dialled', () async {
    final client = await connect(await proxy());
    client.socket.add([5, 1, 0]);
    expect(await client.read(2), [5, 0]);
    client.socket.add([5, 2, 0, 1, 127, 0, 0, 1, 0, 80]);

    expect(await client.read(10), Socks5.reply(Socks5.commandNotSupported));
    await client.closed;
    expect(dialled, isEmpty);
  });

  test('a client offering only password auth is turned away', () async {
    final client = await connect(await proxy());
    client.socket.add([5, 1, 2]);

    expect(await client.read(2), [5, 0xFF]);
    await client.closed;
    expect(dialled, isEmpty);
  });

  test('a far end that cannot be reached is a failure reply', () async {
    final client = await connect(await proxy(fail: true));
    await request(client, 1, [10, 0, 0, 7], 8080);

    expect(await client.read(10), Socks5.reply(Socks5.generalFailure));
    await client.closed;
  });
}

/// Reads a socket by count, which is how a SOCKS client reads its replies.
class _Client {
  _Client(this.socket) {
    socket.listen(
      (chunk) {
        _buffer.addAll(chunk);
        _wake();
      },
      onDone: () {
        if (!_done.isCompleted) _done.complete();
        _wake();
      },
      onError: (_) {
        if (!_done.isCompleted) _done.complete();
      },
    );
  }

  final Socket socket;
  final _buffer = <int>[];
  final _done = Completer<void>();
  Completer<void>? _more;

  Future<void> get closed => _done.future.timeout(const Duration(seconds: 2));

  void _wake() {
    final more = _more;
    _more = null;
    more?.complete();
  }

  Future<List<int>> read(int count) async {
    final deadline = DateTime.now().add(const Duration(seconds: 2));
    while (_buffer.length < count) {
      if (_done.isCompleted) fail('socket closed with ${_buffer.length} bytes');
      if (DateTime.now().isAfter(deadline)) fail('timed out reading $count');
      await (_more = Completer<void>()).future.timeout(
        const Duration(seconds: 2),
      );
    }
    final bytes = _buffer.sublist(0, count);
    _buffer.removeRange(0, count);
    return bytes;
  }
}

class _EchoChannel implements SshTunnelChannel {
  final _controller = StreamController<List<int>>();

  @override
  Stream<List<int>> get stream => _controller.stream;

  @override
  StreamSink<List<int>> get sink => _controller.sink;

  @override
  Future<void> close() => _controller.close();
}
