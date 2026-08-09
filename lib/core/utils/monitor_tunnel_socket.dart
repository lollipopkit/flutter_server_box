import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:dartssh2/dartssh2.dart';
import 'package:fl_lib/fl_lib.dart';
import 'package:server_box/data/model/app/error.dart';
import 'package:server_box/data/model/server/monitor_http_credential.dart';
import 'package:server_box/data/provider/server/monitor_http.dart';

/// An [SSHSocket] whose bytes travel over a `monitor` agent's WebSocket
/// tunnel instead of a direct TCP connection.
///
/// For servers whose SSH port isn't reachable but whose monitor endpoint is.
/// The agent relays bytes and nothing more: the SSH session is still
/// negotiated end to end with the real sshd, and `genClient` still verifies
/// the host key at this end, so an agent in the middle can neither read the
/// session nor impersonate the server.
///
/// The target is not ours to choose — the agent connects to whatever its own
/// `remote_access.ssh_addr` says and accepts no address from clients, which is
/// what stops an agent from being usable as a way into its network.
///
/// Sits alongside [ProxyCommandSocket] as a second answer to "where does the
/// byte stream come from"; everything above `SSHSocket` is unaffected, which
/// is why terminal, SFTP, container management and port forwarding all work
/// over it without knowing it exists.
class MonitorTunnelSocket implements SSHSocket {
  MonitorTunnelSocket._(this._socket, this._client)
    : _incoming = StreamController<Uint8List>(),
      _done = Completer<void>() {
    _socket.listen(
      (event) {
        // The relay only ever sends binary; a text frame would mean the
        // agent and this client disagree about the protocol, and feeding it
        // into the SSH parser would fail somewhere far less obvious.
        if (event is List<int>) {
          _incoming.add(Uint8List.fromList(event));
        } else {
          Loggers.app.warning('Monitor tunnel sent a non-binary frame');
        }
      },
      onError: (Object e, StackTrace s) {
        _incoming.addError(e, s);
        _finish(e, s);
      },
      onDone: () {
        unawaited(_incoming.close());
        _finish(null, null);
      },
      cancelOnError: true,
    );
  }

  final WebSocket _socket;

  /// Owns the session this tunnel was authorised with; disposed together with
  /// the socket so a closed tunnel doesn't leave a logged-in client behind.
  final MonitorHttpClient _client;

  final StreamController<Uint8List> _incoming;
  final Completer<void> _done;

  /// The agent's WebSocket codec caps a frame at 64 KiB. dartssh2 writes one
  /// SSH packet at a time and stays well under that, but a single oversized
  /// write would be dropped by the relay with no error visible to SSH, so
  /// outgoing data is split defensively rather than trusted to be small.
  static const _maxFrame = 32 * 1024;

  /// Logs in, takes a single-use ticket, and opens the tunnel.
  ///
  /// Builds its own [MonitorHttpClient] rather than sharing the one the status
  /// poller owns: `genClient` is also called from background isolates, where
  /// no such instance is reachable. The cost is one extra login per SSH
  /// connection, against a connection that is about to live for minutes.
  static Future<SSHSocket> connect({
    required MonitorHttpCredential monitor,
    Duration? timeout,
  }) async {
    final client = MonitorHttpClient(monitor);
    try {
      final socket = await client.openTunnel(timeout: timeout);
      return MonitorTunnelSocket._(socket, client);
    } catch (e) {
      client.dispose();
      if (e is MonitorHttpErr) rethrow;
      throw MonitorHttpErr(
        type: MonitorHttpErrType.net,
        message: 'Monitor tunnel failed: $e',
      );
    }
  }

  @override
  Stream<Uint8List> get stream => _incoming.stream;

  @override
  StreamSink<List<int>> get sink => _MonitorTunnelSink(this);

  @override
  Future<void> get done => _done.future;

  @override
  Future<void> close() {
    unawaited(_socket.close());
    return done;
  }

  /// A no-op: `WebSocket.add` hands the frame to the underlying socket
  /// immediately, so there is no buffer of ours left to push out.
  @override
  Future<void> flush() async {}

  @override
  void destroy() {
    unawaited(_socket.close(WebSocketStatus.goingAway));
    _finish(null, null);
  }

  void _add(List<int> data) {
    if (data.isEmpty) return;
    for (var offset = 0; offset < data.length; offset += _maxFrame) {
      final end = (offset + _maxFrame).clamp(0, data.length);
      _socket.add(data.sublist(offset, end));
    }
  }

  void _finish(Object? error, StackTrace? stack) {
    if (_done.isCompleted) return;
    _client.dispose();
    if (error == null) {
      _done.complete();
    } else {
      _done.completeError(error, stack);
    }
  }
}

/// dartssh2 writes through a [StreamSink]; this forwards into the WebSocket
/// and reports the socket's own lifetime as the sink's.
class _MonitorTunnelSink implements StreamSink<List<int>> {
  _MonitorTunnelSink(this._socket);

  final MonitorTunnelSocket _socket;

  @override
  void add(List<int> data) => _socket._add(data);

  @override
  void addError(Object error, [StackTrace? stackTrace]) {
    Loggers.app.warning('Monitor tunnel sink error', error, stackTrace);
  }

  @override
  Future<void> addStream(Stream<List<int>> stream) async {
    await for (final chunk in stream) {
      _socket._add(chunk);
    }
  }

  @override
  Future<void> close() => _socket.close();

  @override
  Future<void> get done => _socket.done;
}
