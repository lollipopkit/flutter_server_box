import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:dartssh2/dartssh2.dart';
import 'package:fl_lib/fl_lib.dart';
import 'package:server_box/core/utils/socks5.dart';

typedef SshTunnelDialer = Future<SshTunnelChannel> Function();

/// Opens a channel to an address a connection named itself — see
/// [SshLocalTunnel.bindSocks].
typedef SshTunnelTargetDialer =
    Future<SshTunnelChannel> Function(String host, int port);

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
/// **A SOCKS tunnel** ([bindSocks]) is a dynamic port forward: each connection
/// is a SOCKS5 client naming where it wants to go, and that address is dialled
/// for it rather than one fixed for the whole tunnel.
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
    SshTunnelDialer? dialer,
    SshTunnelTargetDialer? socks,
    required Future<void> sshDone,
    this.accessToken,
    this.once = false,
  }) : assert((dialer == null) != (socks == null)),
       _listener = listener,
       _dialer = dialer,
       _socks = socks {
    _subscription = _listener.listen(_accept, onError: _listenerError);
    unawaited(sshDone.then<void>((_) => close(), onError: (_, _) => close()));
  }

  final ServerSocket _listener;

  /// One of these two: every connection to one address, or each to the one
  /// it names.
  final SshTunnelDialer? _dialer;
  final SshTunnelTargetDialer? _socks;
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

  /// A dynamic forward: a SOCKS5 proxy on [bindHost]:[bindPort] whose every
  /// connection is dialled by [dial], to the address its client named.
  static Future<SshLocalTunnel> bindSocks({
    required String bindHost,
    int bindPort = 0,
    required Future<void> sshDone,
    required SshTunnelTargetDialer dial,
  }) async {
    final listener = await ServerSocket.bind(bindHost, bindPort);
    return SshLocalTunnel._(listener: listener, socks: dial, sshDone: sshDone);
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

  /// Reads what [socket] says before its own bytes — the token, a SOCKS
  /// handshake — and carries the rest; drops a connection that does not say
  /// it.
  Future<void> _admit(Socket socket) async {
    final token = accessToken;
    final socks = _socks;
    // Nothing to read first and nothing to count: the socket is the stream.
    if (token == null && socks == null && !once) {
      await _bridge(socket, socket.cast<List<int>>(), _dialer!);
      return;
    }

    final head = SocketHead(socket);
    if (token != null && !await _presented(head, token)) {
      return _drop(socket, head);
    }
    if (once) {
      if (_carried) return _drop(socket, head);
      _carried = true;
      // Nothing more to take: no port left open for the life of the session.
      unawaited(_stopListening());
    }
    if (socks == null) {
      await _bridge(socket, head.rest(), _dialer!);
      return;
    }

    final Socks5Target? target;
    try {
      target = await Socks5.negotiate(head, socket).timeout(accessTimeout);
    } catch (_) {
      return _drop(socket, head);
    }
    if (target == null) return _drop(socket, head);
    await _bridge(
      socket,
      head.rest(),
      () => socks(target!.host, target.port),
      socks: true,
    );
  }

  Future<void> _drop(Socket socket, SocketHead head) async {
    _pendingSockets.remove(socket);
    await head.cancel();
    // Flushed first, so what was said to a client being turned away — a
    // SOCKS refusal — reaches it rather than being cut off with the socket.
    await socket.flush().catchError((_) {});
    socket.destroy();
  }

  Future<void> _stopListening() async {
    await _subscription?.cancel();
    _subscription = null;
    await _listener.close().catchError((_) => _listener);
  }

  /// Whether [head] starts with [token]: false for a mismatch, the socket
  /// ending first, or [accessTimeout] passing.
  static Future<bool> _presented(SocketHead head, Uint8List token) async {
    try {
      final presented = await head
          .take(token.length)
          .timeout(accessTimeout);
      return _sameBytes(presented, token);
    } catch (_) {
      return false;
    }
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

  /// [socks] answers the client's request once the far end is open or has
  /// failed, which is when a SOCKS client is told whether it may start.
  Future<void> _bridge(
    Socket socket,
    Stream<List<int>> incoming,
    SshTunnelDialer dial, {
    bool socks = false,
  }) async {
    SshTunnelChannel? channel;
    late final Future<SshTunnelChannel> opening;
    try {
      opening = dial();
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

      if (socks) socket.add(Socks5.reply(Socks5.succeeded));
      final connection = SshTunnelBridge(socket, channel, incoming: incoming);
      _connections.add(connection);
      await connection.pipe();
      _connections.remove(connection);
      await connection.close();
    } catch (e, s) {
      _pendingSockets.remove(socket);
      if (socks && channel == null) {
        socket.add(
          Socks5.reply(
            e is TimeoutException
                ? Socks5.hostUnreachable
                : Socks5.generalFailure,
          ),
        );
        await socket.flush().catchError((_) {});
      }
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
