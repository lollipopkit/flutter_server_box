import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:fl_lib/fl_lib.dart';
import 'package:server_box/core/ssh/local_tunnel.dart';
import 'package:server_box/data/model/app/error.dart';

/// A remote port forward through a monitor agent: the agent listens on the
/// server, and each connection it takes is claimed over its relay and carried
/// to an address on this device — what `ssh -R` does with sshd.
///
/// # Wire format
///
/// One control socket, `/api/v1/listen/ws`, for the life of the forward. This
/// side asks `{"type":"listen","host":..,"port":..}` once; the agent answers
/// `{"type":"ready","port":..}` when it has bound, then
/// `{"type":"incoming","id":..,"peer":..}` for each connection it accepts.
/// Each is claimed by opening the relay with `{"type":"accept","id":..}` —
/// one socket per connection, so each keeps the relay's own flow control —
/// and a connection nobody claims is dropped by the agent after a few
/// seconds. Closing the control socket stops the listener.
class MonitorRemoteListener {
  MonitorRemoteListener._(this._socket, this._claim, this._connectLocal);

  final WebSocket _socket;
  final Future<SshTunnelChannel> Function(String id) _claim;
  final Future<Socket> Function() _connectLocal;

  final _ready = Completer<int>();
  final _done = Completer<void>();
  final _peerEnded = Completer<void>();
  final Set<SshTunnelBridge> _bridges = {};
  final Set<Future<void>> _closingBridges = {};
  StreamSubscription<dynamic>? _sub;
  Future<void>? _remoteClose;
  var _closed = false;

  /// The port the agent bound, which is the one asked for unless that was 0.
  late final int port;

  /// Whether this side has closed the listener locally.
  bool get isClosed => _closed;

  /// Completes when the listener has stopped, including peer closure or timeout.
  Future<void> get done => _done.future;

  /// Asks the agent on [socket] — `MonitorHttpClient.openListen` — to listen
  /// on [bindHost]:[bindPort], carrying each connection to [connectLocal].
  ///
  /// [claim] opens the relay for one announced connection; a parameter so the
  /// lifecycle here can be tested without an agent.
  ///
  /// [onCreated] is invoked synchronously once the listener owns [socket],
  /// before `listen` is sent, so a caller can cancel it while waiting for
  /// `ready`.
  static Future<MonitorRemoteListener> start({
    required WebSocket socket,
    required String bindHost,
    required int bindPort,
    required Future<SshTunnelChannel> Function(String id) claim,
    required Future<Socket> Function() connectLocal,
    void Function(MonitorRemoteListener listener)? onCreated,
    Duration timeout = const Duration(seconds: 15),
  }) async {
    final listener = MonitorRemoteListener._(socket, claim, connectLocal);
    listener._sub = socket.listen(
      listener._onFrame,
      onError: (Object e, StackTrace s) {
        Loggers.app.warning('Monitor listener socket error', e, s);
        listener._markPeerEnded();
        unawaited(listener.close());
      },
      onDone: () {
        listener._markPeerEnded();
        unawaited(listener.close());
      },
      cancelOnError: true,
    );
    try {
      onCreated?.call(listener);
      if (listener._closed) {
        throw const MonitorHttpErr(
          type: MonitorHttpErrType.net,
          message: 'The Monitor listener was canceled before starting',
        );
      }
      socket.add(
        jsonEncode({'type': 'listen', 'host': bindHost, 'port': bindPort}),
      );
      listener.port = await listener._ready.future.timeout(
        timeout,
        onTimeout: () => throw const MonitorHttpErr(
          type: MonitorHttpErrType.net,
          message: 'The Monitor did not start listening in time',
        ),
      );
    } catch (_) {
      // Ensure any error completed on `_ready` before it was awaited does not
      // surface as an unhandled async error.
      listener._ready.future.ignore();
      await listener.close(waitRemote: false);
      rethrow;
    }
    return listener;
  }

  void _markPeerEnded() {
    if (!_peerEnded.isCompleted) _peerEnded.complete();
  }

  void _onFrame(dynamic event) {
    if (_closed || event is! String) return;
    final Map<String, dynamic> msg;
    try {
      msg = jsonDecode(event) as Map<String, dynamic>;
    } catch (e) {
      Loggers.app.warning('Monitor listener sent malformed control JSON', e);
      return;
    }
    switch (msg['type']) {
      case 'ready':
        final port = msg['port'];
        if (!_ready.isCompleted && port is int) _ready.complete(port);
      case 'incoming':
        final id = msg['id'];
        if (id is String && id.isNotEmpty) unawaited(_carry(id));
      case 'error':
        final err = MonitorHttpErr(
          type: msg['code'] == 'forbidden' || msg['code'] == 'not_permitted'
              ? MonitorHttpErrType.notGranted
              : MonitorHttpErrType.net,
          message: msg['message'] as String? ?? 'Listener error',
        );
        if (!_ready.isCompleted) {
          _ready.completeError(err);
        } else {
          Loggers.app.warning('Monitor listener error: ${err.message}');
        }
        unawaited(close());
      default:
        // `pong`, and anything a later agent adds.
        break;
    }
  }

  /// Claims [id] and carries it to this device's end of the forward.
  ///
  /// Claimed before the local end is dialled, so a local end that is down
  /// closes the connection at once rather than leaving whoever made it
  /// waiting out the agent's timeout.
  Future<void> _carry(String id) async {
    SshTunnelChannel? channel;
    try {
      channel = await _claim(id);
      if (_closed) {
        await channel.close();
        return;
      }
      final socket = await _connectLocal();
      if (_closed) {
        socket.destroy();
        await channel.close();
        return;
      }
      final bridge = SshTunnelBridge(socket, channel);
      _bridges.add(bridge);
      await bridge.pipe();
      _bridges.remove(bridge);
      await bridge.close();
    } catch (e, s) {
      await channel?.close().catchError((_) {});
      if (!_closed) {
        Loggers.app.warning('Monitor remote forward connection failed', e, s);
      }
    }
  }

  /// Stops accepting connections and tears down this listener.
  ///
  /// Local shutdown happens immediately (`_closed = true`, control stream
  /// unsubscribed, pending `ready` failed, `_socket.close()` initiated, and
  /// active bridge local sockets destroyed). When [waitRemote] is false, this
  /// returns once local teardown finishes without waiting for remote WebSocket
  /// or bridge channel close handshakes — useful on server deletion when the
  /// network may be gone.
  Future<void> close({bool waitRemote = true}) async {
    if (!_closed) {
      _closed = true;
      if (!_ready.isCompleted) {
        _ready.completeError(
          const MonitorHttpErr(
            type: MonitorHttpErrType.net,
            message: 'The Monitor closed the listener',
          ),
        );
      }
    }

    // Keep the receive subscription attached until the peer terminates or the
    // close handshake times out; `_onFrame` discards frames while `_closed`.
    final remoteSocketClose = _remoteClose ??= _closeControlSocket();

    final bridges = _bridges.toList();
    _bridges.clear();
    for (final bridge in bridges) {
      late final Future<void> f;
      f = bridge.close(waitRemote: true).catchError((_) {}).whenComplete(() {
        _closingBridges.remove(f);
      });
      _closingBridges.add(f);
      if (!waitRemote) {
        // `bridge.close` destroys the local socket synchronously before its
        // first await; leave the remote channel close in the background.
        unawaited(f);
      }
    }

    if (waitRemote) {
      await Future.wait([remoteSocketClose, ..._closingBridges]);
    }
  }

  Future<void> _closeControlSocket() async {
    try {
      unawaited(
        _socket
            .close()
            .timeout(const Duration(seconds: 5), onTimeout: () => null)
            .catchError((_) {}),
      );
      await _peerEnded.future.timeout(
        const Duration(seconds: 5),
        onTimeout: () {},
      );
    } finally {
      final sub = _sub;
      _sub = null;
      if (sub != null) unawaited(sub.cancel().catchError((_) {}));
      if (!_done.isCompleted) _done.complete();
    }
  }
}
