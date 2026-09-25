import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

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
///
/// **An authenticated tunnel** ([accessToken] set) is one for a client inside
/// this app — the remote desktop engine. A loopback port is open to every
/// process on the device, and without this the first one to connect would get
/// the remote end: a guest's console, a desktop. So such a tunnel carries only
/// a connection whose first [accessTokenLength] bytes are the token, compared
/// in constant time within [accessTimeout]; any other connection is dropped
/// before anything is dialled, and the token is never on the wire beyond this
/// device's loopback. The engine gets the token in-process, through FFI.
class SshLocalTunnel {
  SshLocalTunnel._({
    required ServerSocket listener,
    required SshTunnelDialer dialer,
    required Future<void> sshDone,
    this.accessToken,
    this.once = false,
  }) : _listener = listener,
       _dialer = dialer {
    _subscription = _listener.listen(_accept, onError: _listenerError);
    unawaited(sshDone.then<void>((_) => close(), onError: (_, _) => close()));
  }

  final ServerSocket _listener;
  final SshTunnelDialer _dialer;
  final Set<Socket> _pendingSockets = {};
  final Set<SshTunnelBridge> _connections = {};
  final Set<Future<void>> _bridges = {};
  final _openingStops = <Completer<SshTunnelChannel>>{};
  final Completer<void> _done = Completer<void>();
  StreamSubscription<Socket>? _subscription;
  Future<void>? _closing;
  bool _closed = false;

  static const accessTokenLength = 32;
  static const accessTimeout = Duration(seconds: 5);

  /// What a connection must present first; null for a tunnel open to any
  /// local client (the port-forward feature, which is meant to be).
  final Uint8List? accessToken;

  /// Stops listening once one connection has been carried: for a remote end
  /// that takes one (a console ticket's websocket).
  final bool once;

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
    dialer: () => forward(client, remoteHost, remotePort),
  );

  /// A direct-tcpip channel on [client] to [remoteHost]:[remotePort].
  static Future<SshTunnelChannel> forward(
    SSHClient client,
    String remoteHost,
    int remotePort,
  ) async =>
      _DartSshTunnelChannel(await client.forwardLocal(remoteHost, remotePort));

  /// The lifecycle seam used by tests and alternative SSH transports.
  ///
  /// [authenticated] makes it a tunnel with an [accessToken] — see the class.
  static Future<SshLocalTunnel> bindWithDialer({
    required String bindHost,
    int bindPort = 0,
    required Future<void> sshDone,
    required SshTunnelDialer dialer,
    bool authenticated = false,
    bool once = false,
  }) async {
    final listener = await ServerSocket.bind(bindHost, bindPort);
    return SshLocalTunnel._(
      listener: listener,
      dialer: dialer,
      sshDone: sshDone,
      accessToken: authenticated ? _newToken() : null,
      once: once,
    );
  }

  static Uint8List _newToken() {
    final random = Random.secure();
    return Uint8List.fromList([
      for (var i = 0; i < accessTokenLength; i++) random.nextInt(256),
    ]);
  }

  /// A connection has been let through, for [once].
  var _carried = false;

  void _accept(Socket socket) {
    if (_closed || (once && _carried)) {
      socket.destroy();
      return;
    }
    _pendingSockets.add(socket);
    late final Future<void> bridge;
    bridge = _admit(socket).whenComplete(() => _bridges.remove(bridge));
    _bridges.add(bridge);
    unawaited(bridge);
  }

  /// [socket]'s bytes after the token, or all of them for a tunnel without
  /// one; null for a connection that did not present it.
  Future<void> _admit(Socket socket) async {
    final token = accessToken;
    final Stream<List<int>>? incoming;
    if (token == null) {
      incoming = socket.cast<List<int>>();
    } else {
      incoming = await _presented(socket, token);
      if (incoming == null) {
        _pendingSockets.remove(socket);
        socket.destroy();
        return;
      }
    }
    if (once) {
      if (_carried) {
        _pendingSockets.remove(socket);
        socket.destroy();
        return;
      }
      _carried = true;
      // Nothing more to take: no port left open for the life of the session.
      unawaited(_stopListening());
    }
    await _bridge(socket, incoming);
  }

  Future<void> _stopListening() async {
    await _subscription?.cancel();
    _subscription = null;
    await _listener.close().catchError((_) => _listener);
  }

  /// Reads [token]'s length from [socket] and compares it with [token]:
  /// the rest of the stream when they match, null otherwise — a mismatch,
  /// the socket ending first, or [accessTimeout] passing.
  static Future<Stream<List<int>>?> _presented(
    Socket socket,
    Uint8List token,
  ) async {
    final head = BytesBuilder(copy: false);
    final rest = StreamController<List<int>>();
    final verdict = Completer<bool>();
    late final StreamSubscription<Uint8List> sub;
    sub = socket.listen(
      (chunk) {
        if (verdict.isCompleted) {
          rest.add(chunk);
          return;
        }
        head.add(chunk);
        if (head.length < token.length) return;
        final bytes = head.takeBytes();
        final ok = _sameBytes(Uint8List.sublistView(bytes, 0, token.length), token);
        verdict.complete(ok);
        if (ok && bytes.length > token.length) {
          rest.add(Uint8List.sublistView(bytes, token.length));
        }
      },
      onError: (Object e, StackTrace s) {
        if (!verdict.isCompleted) {
          verdict.complete(false);
        } else {
          rest.addError(e, s);
        }
      },
      onDone: () {
        if (!verdict.isCompleted) verdict.complete(false);
        unawaited(rest.close());
      },
    );
    // Whoever reads the rest sets the pace, as reading the socket would.
    rest
      ..onPause = sub.pause
      ..onResume = sub.resume
      ..onCancel = sub.cancel;
    final ok = await verdict.future.timeout(
      accessTimeout,
      onTimeout: () => false,
    );
    if (ok) return rest.stream;
    await sub.cancel();
    // Not awaited: nobody listens to it, and a close with no listener never
    // completes.
    unawaited(rest.close());
    return null;
  }

  /// Every byte compared, whatever the first difference: how long this takes
  /// says nothing about how much of a guess was right.
  static bool _sameBytes(Uint8List a, Uint8List b) {
    if (a.length != b.length) return false;
    var diff = 0;
    for (var i = 0; i < a.length; i++) {
      diff |= a[i] ^ b[i];
    }
    return diff == 0;
  }

  Future<void> _bridge(Socket socket, Stream<List<int>> incoming) async {
    SshTunnelChannel? channel;
    late final Future<SshTunnelChannel> opening;
    try {
      opening = _dialer();
      final stopped = Completer<SshTunnelChannel>();
      _openingStops.add(stopped);
      if (_closed) stopped.completeError(StateError('Tunnel closed'));
      try {
        channel = await Future.any([
          opening,
          stopped.future,
        ]).timeout(const Duration(seconds: 15));
      } on TimeoutException {
        // A direct-tcpip open cannot be cancelled through dartssh2. If it
        // completes after the timeout (or after close), close the channel as
        // soon as it arrives instead of leaking it.
        unawaited(
          opening
              .then<void>((lateChannel) => lateChannel.close())
              .catchError((_) {}),
        );
        rethrow;
      } catch (_) {
        if (_closed) {
          unawaited(
            opening
                .then<void>((lateChannel) => lateChannel.close())
                .catchError((_) {}),
          );
        }
        rethrow;
      } finally {
        // Do not retain a completed channel through a tunnel-wide stop future.
        _openingStops.remove(stopped);
      }
      _pendingSockets.remove(socket);
      if (_closed) {
        socket.destroy();
        await channel.close();
        return;
      }

      final connection = SshTunnelBridge(socket, channel, incoming: incoming);
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
    for (final stopped in _openingStops.toList()) {
      if (!stopped.isCompleted) {
        stopped.completeError(StateError('Tunnel closed'));
      }
    }
    await _stopListening();

    for (final socket in _pendingSockets.toList()) {
      socket.destroy();
    }
    _pendingSockets.clear();

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

/// Carries bytes between a local [socket] and a tunnel [channel], both ways,
/// until either side ends; then tears both down.
class SshTunnelBridge {
  SshTunnelBridge(this.socket, this.channel, {Stream<List<int>>? incoming})
    : _incoming = incoming ?? socket.cast<List<int>>();

  final Socket socket;
  final SshTunnelChannel channel;

  /// What [socket] sends: the socket itself, or what is left of it once a
  /// tunnel has read its access token off the front.
  final Stream<List<int>> _incoming;
  bool _closed = false;

  Future<void> pipe() => Future.wait([
    channel.stream.pipe(socket).catchError((_) => close()),
    _incoming.pipe(channel.sink).catchError((_) => close()),
  ]);

  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    socket.destroy();
    await channel.close().catchError((_) {});
  }
}
