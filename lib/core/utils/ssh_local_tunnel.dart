import 'dart:async';
import 'dart:io';

import 'package:dartssh2/dartssh2.dart';
import 'package:fl_lib/fl_lib.dart';

typedef SshTunnelDialer = Future<SshTunnelChannel> Function();

/// The byte-stream surface a local SSH tunnel needs from a direct-tcpip
/// channel. Keeping this seam small makes the listener lifecycle testable
/// without constructing an authenticated SSH transport.
abstract interface class SshTunnelChannel {
  Stream<List<int>> get stream;
  StreamSink<List<int>> get sink;
  Future<void> close();
}

/// A local TCP listener whose accepted sockets are carried by SSH
/// direct-tcpip channels.
///
/// [loopback] is the remote-desktop entry point: it always asks the OS for an
/// ephemeral IPv4 loopback port. [bind] also serves the existing configurable
/// port-forward feature, which may intentionally expose a chosen interface and
/// port.
class SshLocalTunnel {
  SshLocalTunnel._({
    required ServerSocket listener,
    required SshTunnelDialer dialer,
    required Future<void> sshDone,
  }) : _listener = listener,
       _dialer = dialer {
    _subscription = _listener.listen(_accept, onError: _listenerError);
    unawaited(
      sshDone.then<void>(
        (_) => close(),
        onError: (_, _) => close(),
      ),
    );
  }

  final ServerSocket _listener;
  final SshTunnelDialer _dialer;
  final Set<Socket> _pendingSockets = {};
  final Set<Future<SshTunnelChannel>> _pendingChannels = {};
  final Set<_TunnelConnection> _connections = {};
  final Set<Future<void>> _bridges = {};
  final Completer<void> _done = Completer<void>();
  StreamSubscription<Socket>? _subscription;
  Future<void>? _closing;
  bool _closed = false;

  InternetAddress get address => _listener.address;
  int get port => _listener.port;
  bool get isClosed => _closed;
  Future<void> get done => _done.future;

  /// Opens the loopback-only ephemeral listener used by RDP and VNC sessions.
  static Future<SshLocalTunnel> loopback({
    required SSHClient client,
    required String remoteHost,
    required int remotePort,
  }) => bind(
    client: client,
    remoteHost: remoteHost,
    remotePort: remotePort,
    bindHost: InternetAddress.loopbackIPv4.address,
  );

  /// Opens a configurable local forward while sharing the same lifecycle.
  static Future<SshLocalTunnel> bind({
    required SSHClient client,
    required String remoteHost,
    required int remotePort,
    required String bindHost,
    int bindPort = 0,
  }) => bindWithDialer(
    bindHost: bindHost,
    bindPort: bindPort,
    sshDone: client.done,
    dialer: () async => _DartSshTunnelChannel(
      await client.forwardLocal(remoteHost, remotePort),
    ),
  );

  /// The lifecycle seam used by tests and alternative SSH transports.
  static Future<SshLocalTunnel> bindWithDialer({
    required String bindHost,
    int bindPort = 0,
    required Future<void> sshDone,
    required SshTunnelDialer dialer,
  }) async {
    final listener = await ServerSocket.bind(bindHost, bindPort);
    return SshLocalTunnel._(
      listener: listener,
      dialer: dialer,
      sshDone: sshDone,
    );
  }

  void _accept(Socket socket) {
    if (_closed) {
      socket.destroy();
      return;
    }
    _pendingSockets.add(socket);
    late final Future<void> bridge;
    bridge = _bridge(socket).whenComplete(() => _bridges.remove(bridge));
    _bridges.add(bridge);
    unawaited(bridge);
  }

  Future<void> _bridge(Socket socket) async {
    SshTunnelChannel? channel;
    late final Future<SshTunnelChannel> opening;
    try {
      opening = _dialer();
      _pendingChannels.add(opening);
      try {
        channel = await opening.timeout(const Duration(seconds: 15));
      } on TimeoutException {
        // A direct-tcpip open cannot be cancelled through dartssh2. If it
        // completes after the timeout (or after close), close the channel as
        // soon as it arrives instead of leaking it.
        unawaited(
          opening.then<void>((lateChannel) => lateChannel.close()).catchError((_) {}),
        );
        rethrow;
      } finally {
        _pendingChannels.remove(opening);
      }
      _pendingSockets.remove(socket);
      if (_closed) {
        socket.destroy();
        await channel.close();
        return;
      }

      final connection = _TunnelConnection(socket, channel);
      _connections.add(connection);
      await connection.pipe();
      _connections.remove(connection);
      await connection.close();
    } catch (e, s) {
      _pendingSockets.remove(socket);
      socket.destroy();
      await channel?.close().catchError((_) {});
      if (!_closed) {
        Loggers.app.warning('SSH local tunnel connection failed', e, s);
      }
    }
  }

  void _listenerError(Object error, StackTrace stackTrace) {
    if (_closed) return;
    Loggers.app.warning('SSH local tunnel listener failed', error, stackTrace);
    unawaited(close());
  }

  Future<void> close() {
    final existing = _closing;
    if (existing != null) return existing;
    late final Future<void> closing;
    closing = _close().whenComplete(() {
      if (!_done.isCompleted) _done.complete();
    });
    _closing = closing;
    return closing;
  }

  Future<void> _close() async {
    _closed = true;
    await _subscription?.cancel();
    await _listener.close();

    for (final socket in _pendingSockets.toList()) {
      socket.destroy();
    }
    _pendingSockets.clear();

    for (final opening in _pendingChannels.toList()) {
      unawaited(
        opening.then<void>((channel) => channel.close()).catchError((_) {}),
      );
    }

    final connections = _connections.toList();
    _connections.clear();
    for (final connection in connections) {
      await connection.close();
    }
    await Future.wait(
      _bridges.toList().map((bridge) => bridge.catchError((_) {})),
    );
  }
}

class _DartSshTunnelChannel implements SshTunnelChannel {
  const _DartSshTunnelChannel(this._channel);

  final SSHForwardChannel _channel;

  @override
  Stream<List<int>> get stream => _channel.stream.cast<List<int>>();

  @override
  StreamSink<List<int>> get sink => _channel.sink;

  @override
  Future<void> close() => _channel.close();
}

class _TunnelConnection {
  _TunnelConnection(this.socket, this.channel);

  final Socket socket;
  final SshTunnelChannel channel;
  bool _closed = false;

  Future<void> pipe() => Future.wait([
    channel.stream.pipe(socket).catchError((_) {}),
    socket.cast<List<int>>().pipe(channel.sink).catchError((_) {}),
  ]);

  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    socket.destroy();
    await channel.close().catchError((_) {});
  }
}
