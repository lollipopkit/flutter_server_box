import 'dart:async';
import 'dart:io';

import 'package:dartssh2/dartssh2.dart';
import 'package:fl_lib/fl_lib.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:server_box/core/utils/local_server.dart';
import 'package:server_box/core/utils/monitor_tunnel.dart';
import 'package:server_box/core/utils/ssh_local_tunnel.dart';
import 'package:server_box/data/model/app/error.dart';
import 'package:server_box/data/model/server/connect_credential.dart';
import 'package:server_box/data/model/server/monitor_http_credential.dart';
import 'package:server_box/data/model/server/monitor_remote_access.dart';
import 'package:server_box/data/model/server/server_private_info.dart';
import 'package:server_box/data/provider/server/monitor_http.dart';
import 'package:server_box/data/provider/server/single.dart';

/// An open SSH connection, as far as [ServerTcpDialer] needs one: a way to
/// open a direct-tcpip channel, and the connection's end.
class ServerTcpSsh {
  const ServerTcpSsh({required this.forward, required this.done});

  ServerTcpSsh.client(SSHClient client)
    : this(
        forward: (host, port) => SshLocalTunnel.forward(client, host, port),
        done: client.done,
      );

  final Future<SshTunnelChannel> Function(String host, int port) forward;
  final Future<void> done;
}

/// A connection opened by [ServerTcpDialer.open], and the transport it went
/// over.
class ServerTcpChannel implements SshTunnelChannel {
  ServerTcpChannel._(this.transport, this._inner);

  final ServerTransport transport;
  final SshTunnelChannel _inner;

  @override
  Stream<List<int>> get stream => _inner.stream;

  @override
  StreamSink<List<int>> get sink => _inner.sink;

  @override
  Future<void> close() => _inner.close();
}

/// Opens TCP connections to `host:port` *as seen from a server*, over
/// whichever way that server is reached.
///
/// - SSH: a direct-tcpip channel (`SSHClient.forwardLocal`).
/// - monitor agent: `MonitorTunnelChannel`, dialled by the agent from its own
///   machine — only when its `stream` grant is not refused.
/// - local: `Socket.connect` from this device, which is the server.
///
/// So a host name resolves on the far end, and `localhost` means the server
/// in all three.
///
/// Same ordering as `ServerNotifier.ensureExec()`: the leading transport is
/// tried, and a server carrying both falls through to the other when the
/// first cannot open the connection. Every failure is a [ServerTcpErr] naming
/// the transport, and, when there were two, what happened on the other.
///
/// Holds one [MonitorHttpClient] for [open] and [connect], created on first
/// use and released by [close]: it carries the login the relay is authorised
/// with, and one per connection would log in again for each. A [loopback]
/// tunnel owns its own instead, for the tunnel's life, so it outlives neither
/// the dialer nor the other way round.
class ServerTcpDialer {
  ServerTcpDialer({
    required this.spi,
    required Future<ServerTcpSsh> Function() ssh,
    MonitorRemoteAccess? Function()? relayGrant,
    this.transports = const {...ServerTransport.values},
  }) : _ssh = ssh,
       _relayGrant = relayGrant ?? _notRead;

  /// The dialer for [spi], connecting through its `ServerNotifier`: the SSH
  /// client it holds, and the relay grant it last read from the agent.
  factory ServerTcpDialer.of(
    Ref ref,
    Spi spi, {
    Set<ServerTransport> transports = const {...ServerTransport.values},
  }) => ServerTcpDialer(
    spi: spi,
    ssh: () async => ServerTcpSsh.client(
      await ref.read(serverProvider(spi.id).notifier).ensureShellClient(),
    ),
    relayGrant: () => ref.read(serverProvider(spi.id)).remoteAccess,
    transports: transports,
  );

  static const openTimeout = Duration(seconds: 15);

  final Spi spi;

  /// Which transports the caller uses. One left out is skipped as though it
  /// could not carry the connection — remote desktop leaves out `local`.
  final Set<ServerTransport> transports;

  final Future<ServerTcpSsh> Function() _ssh;
  final MonitorRemoteAccess? Function() _relayGrant;

  MonitorHttpClient? _monitor;
  bool _closed = false;

  static MonitorRemoteAccess? _notRead() => null;

  /// A byte stream to [host]:[port].
  Future<ServerTcpChannel> open(String host, int port) =>
      _either((credential) async {
        final channel = await _channelOver(credential, host, port);
        return ServerTcpChannel._(_transportOf(credential), channel);
      });

  /// A `dart:io` [Socket] to [host]:[port], for what needs one — an
  /// `HttpClient.connectionFactory`, or `SecureSocket.secure` on top.
  ///
  /// Local is a direct socket. Otherwise a loopback socket pair whose far end
  /// is bridged to the channel: `SecureSocket` only wraps a socket `dart:io`
  /// made itself, so a channel cannot be handed over as one.
  Future<Socket> connect(String host, int port) => _either((credential) async {
    if (credential is ServerConnectCredentialLocal) {
      return Socket.connect(host, port, timeout: openTimeout);
    }
    return _socketPair(await _channelOver(credential, host, port));
  });

  /// [connect] in the shape `HttpClient.connectionFactory` returns.
  ///
  /// A socket that arrives after the task was cancelled is destroyed.
  ConnectionTask<Socket> startConnect(String host, int port) {
    var cancelled = false;
    final socket = connect(host, port).then((socket) {
      if (!cancelled) return socket;
      socket.destroy();
      throw const SocketException('Connection attempt cancelled');
    });
    // `HttpClient` listens to the task's socket only after it has awaited the
    // factory's own future. A refusal decided before dialling — a relay the
    // agent does not grant — fails this first, and a future that fails with
    // no listener is reported to the zone as uncaught even though the request
    // then fails with it as it should. Marked handled; `HttpClient` still gets
    // the error when it listens.
    socket.ignore();
    return ConnectionTask.fromSocket(socket, () => cancelled = true);
  }

  /// A listener on an ephemeral IPv4 loopback port whose every accepted
  /// socket is carried to [host]:[port] — for a client that must be given a
  /// port number, such as the remote desktop engine.
  ///
  /// Authenticated: a connection must present the tunnel's
  /// `SshLocalTunnel.accessToken` first, which the engine is handed with the
  /// port. Another process on this device gets nothing from the port.
  ///
  /// The transport is chosen when the listener is bound, not per connection.
  /// The tunnel closes itself when an SSH connection under it ends.
  Future<SshLocalTunnel> loopback(String host, int port) =>
      _either((credential) => _loopbackOver(credential, host, port));

  /// Releases the monitor client [open] and [connect] share. Channels and
  /// tunnels already open are not affected.
  void close() {
    _closed = true;
    _monitor?.dispose();
    _monitor = null;
  }

  /// Tries the leading transport, then the other.
  Future<T> _either<T>(
    Future<T> Function(ServerConnectCredential credential) over,
  ) async {
    if (_closed) throw StateError('ServerTcpDialer used after close');
    final ServerTcpErr first;
    final StackTrace firstTrace;
    try {
      return await _attempt(ServerConnectCredential.fromSpi(spi), over);
    } on ServerTcpErr catch (e, s) {
      first = e;
      firstTrace = s;
    }

    // Reached for a transport that will not carry this as well as for one
    // that failed: both mean "not this way".
    final fallback = ServerConnectCredential.fallbackOf(spi);
    if (fallback == null) Error.throwWithStackTrace(first, firstTrace);
    if (first.type == ServerTcpErrType.dial) {
      Loggers.app.info(
        'TCP over ${first.transport.name} for ${spi.name} failed, '
        'falling back to ${_transportOf(fallback).name}',
        first.cause,
        firstTrace,
      );
    }
    try {
      return await _attempt(fallback, over);
    } on ServerTcpErr catch (second, s) {
      // What was actually tried is the better answer; a transport skipped
      // before anything was dialled is the context.
      if (second.type != ServerTcpErrType.dial &&
          first.type == ServerTcpErrType.dial) {
        Error.throwWithStackTrace(_withOther(first, second), firstTrace);
      }
      Error.throwWithStackTrace(_withOther(second, first), s);
    }
  }

  Future<T> _attempt<T>(
    ServerConnectCredential credential,
    Future<T> Function(ServerConnectCredential credential) over,
  ) async {
    final transport = _transportOf(credential);
    final refusal = _refusal(credential, transport);
    if (refusal != null) throw refusal;
    try {
      return await over(credential);
    } on ServerTcpErr {
      rethrow;
    } catch (e, s) {
      // A refused relay found out from the agent — it will not mint a stream
      // ticket — rather than from the grant [_refusal] reads first. Typed the
      // same, so what the user is told does not depend on whether the status
      // poll had answered yet.
      final refused =
          e is MonitorHttpErr && e.type == MonitorHttpErrType.notGranted;
      Error.throwWithStackTrace(
        ServerTcpErr(
          type: refused
              ? ServerTcpErrType.relayNotGranted
              : ServerTcpErrType.dial,
          transport: transport,
          message: refused ? e.message : e.toString(),
          cause: e,
        ),
        s,
      );
    }
  }

  /// Why [credential] cannot carry a connection, decided without dialling;
  /// null when it may.
  ///
  /// An agent's grant that has not been read yet is not a "no". Nothing has
  /// asked this agent, and treating "not looked" as "cannot" would hide a
  /// server that can, which is the same mistake the server list refuses to
  /// make.
  ServerTcpErr? _refusal(
    ServerConnectCredential credential,
    ServerTransport transport,
  ) {
    if (!transports.contains(transport)) {
      return ServerTcpErr(
        type: ServerTcpErrType.notOffered,
        transport: transport,
        message: 'Not used for this connection',
      );
    }
    switch (credential) {
      case ServerConnectCredentialSsh():
        return null;
      case ServerConnectCredentialMonitorHttp():
        // Asked before dialling: an agent older than the endpoint reports
        // `full_access` and would refuse the upgrade, and one with the grant
        // off answers 403. Finding that out at the dial would be after a
        // loopback listener had been handed to a client.
        final granted = _relayGrant();
        if (granted != null && !granted.stream) {
          return ServerTcpErr(
            type: ServerTcpErrType.relayNotGranted,
            transport: transport,
            message: 'The monitor agent does not relay TCP connections',
          );
        }
        return null;
      case ServerConnectCredentialLocal():
        if (LocalServer.isSupported) return null;
        return ServerTcpErr(
          type: ServerTcpErrType.localUnsupported,
          transport: transport,
          message: 'This device cannot stand for a local server',
        );
    }
  }

  Future<SshTunnelChannel> _channelOver(
    ServerConnectCredential credential,
    String host,
    int port,
  ) async {
    switch (credential) {
      case ServerConnectCredentialSsh():
        final ssh = await _ssh();
        return _opened(ssh.forward(host, port));
      case ServerConnectCredentialMonitorHttp(:final monitor):
        return MonitorTunnelChannel.dial(
          client: _monitorClient(monitor),
          remoteHost: host,
          remotePort: port,
          timeout: openTimeout,
        );
      case ServerConnectCredentialLocal():
        return _SocketChannel(
          await Socket.connect(host, port, timeout: openTimeout),
        );
    }
  }

  Future<SshLocalTunnel> _loopbackOver(
    ServerConnectCredential credential,
    String host,
    int port,
  ) async {
    final bindHost = InternetAddress.loopbackIPv4.address;
    switch (credential) {
      case ServerConnectCredentialSsh():
        final ssh = await _ssh();
        return SshLocalTunnel.bindWithDialer(
          bindHost: bindHost,
          sshDone: ssh.done,
          dialer: () => ssh.forward(host, port),
          authenticated: true,
        );
      case ServerConnectCredentialMonitorHttp(:final monitor):
        // One client for the tunnel's life rather than one per dial: it holds
        // the login the relay socket is authorised with, and a fresh one per
        // attempt would log in again each time.
        final client = MonitorHttpClient(monitor);
        final SshLocalTunnel tunnel;
        try {
          tunnel = await SshLocalTunnel.bindWithDialer(
            bindHost: bindHost,
            dialer: () => MonitorTunnelChannel.dial(
              client: client,
              remoteHost: host,
              remotePort: port,
            ),
            // No SSH connection to outlive: the relay socket is opened per
            // accepted connection, and `MonitorTunnelChannel.close` ends it.
            sshDone: Completer<void>().future,
            authenticated: true,
          );
        } catch (_) {
          client.dispose();
          rethrow;
        }
        unawaited(tunnel.done.whenComplete(client.dispose));
        return tunnel;
      case ServerConnectCredentialLocal():
        return SshLocalTunnel.bindWithDialer(
          bindHost: bindHost,
          dialer: () async => _SocketChannel(
            await Socket.connect(host, port, timeout: openTimeout),
          ),
          sshDone: Completer<void>().future,
          authenticated: true,
        );
    }
  }

  MonitorHttpClient _monitorClient(MonitorHttpCredential monitor) =>
      _monitor ??= MonitorHttpClient(monitor);

  /// [opening] within [openTimeout]. A direct-tcpip open cannot be cancelled
  /// through dartssh2, so one that completes late is closed on arrival.
  static Future<SshTunnelChannel> _opened(
    Future<SshTunnelChannel> opening,
  ) async {
    try {
      return await opening.timeout(openTimeout);
    } on TimeoutException {
      unawaited(
        opening.then<void>((late) => late.close()).catchError((_) {}),
      );
      rethrow;
    }
  }

  /// A connected loopback socket whose peer is bridged to [channel].
  ///
  /// The listener accepts only the socket this side connected — matched by
  /// its port — and closes at once, so no other local process can take the
  /// connection in between.
  static Future<Socket> _socketPair(SshTunnelChannel channel) async {
    ServerSocket? listener;
    StreamIterator<Socket>? accepted;
    Socket? near;
    try {
      listener = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      accepted = StreamIterator(listener);
      final firstAccept = accepted.moveNext();
      near = await Socket.connect(listener.address, listener.port);
      Socket? far;
      var next = firstAccept;
      while (far == null) {
        if (!await next.timeout(openTimeout)) {
          throw const SocketException('Loopback listener closed');
        }
        final socket = accepted.current;
        if (socket.remotePort == near.port &&
            socket.remoteAddress.isLoopback) {
          far = socket;
        } else {
          socket.destroy();
          next = accepted.moveNext();
        }
      }
      final bridge = SshTunnelBridge(far, channel);
      unawaited(bridge.pipe().whenComplete(bridge.close));
      return near;
    } catch (_) {
      near?.destroy();
      await channel.close().catchError((_) {});
      rethrow;
    } finally {
      await accepted?.cancel();
      await listener?.close();
    }
  }

  static ServerTcpErr _withOther(ServerTcpErr err, ServerTcpErr other) =>
      ServerTcpErr(
        type: err.type,
        transport: err.transport,
        message: err.message,
        cause: err.cause,
        other: other,
      );

  static ServerTransport _transportOf(ServerConnectCredential credential) =>
      switch (credential) {
        ServerConnectCredentialSsh() => ServerTransport.ssh,
        ServerConnectCredentialMonitorHttp() => ServerTransport.monitorHttp,
        ServerConnectCredentialLocal() => ServerTransport.local,
      };
}

/// A plain socket as a tunnel channel: the local case, where this device is
/// the server and there is nothing to tunnel through.
class _SocketChannel implements SshTunnelChannel {
  _SocketChannel(this._socket);

  final Socket _socket;

  // Typed as `Stream<List<int>>` at runtime too, or piping it into another
  // socket fails: a `Stream<Uint8List>` wants a `StreamConsumer<Uint8List>`.
  @override
  Stream<List<int>> get stream => _socket.cast<List<int>>();

  @override
  StreamSink<List<int>> get sink => _socket;

  @override
  Future<void> close() async => _socket.destroy();
}
