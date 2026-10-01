import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:fl_lib/fl_lib.dart';
import 'package:server_box/core/utils/ssh_local_tunnel.dart';
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
  final Set<SshTunnelBridge> _bridges = {};
  var _closed = false;

  /// The port the agent bound, which is the one asked for unless that was 0.
  late final int port;

  /// Completes when the listener has stopped, from either side.
  Future<void> get done => _done.future;

  /// Asks the agent on [socket] — `MonitorHttpClient.openListen` — to listen
  /// on [bindHost]:[bindPort], carrying each connection to [connectLocal].
  ///
  /// [claim] opens the relay for one announced connection; a parameter so the
  /// lifecycle here can be tested without an agent.
  static Future<MonitorRemoteListener> start({
    required WebSocket socket,
    required String bindHost,
    required int bindPort,
    required Future<SshTunnelChannel> Function(String id) claim,
    required Future<Socket> Function() connectLocal,
    Duration timeout = const Duration(seconds: 15),
  }) async {
    final listener = MonitorRemoteListener._(socket, claim, connectLocal);
    socket.listen(
      listener._onFrame,
      onError: (Object e, StackTrace s) {
        Loggers.app.warning('Monitor listener socket error', e, s);
        unawaited(listener.close());
      },
      onDone: () => unawaited(listener.close()),
      cancelOnError: true,
    );
    socket.add(jsonEncode({'type': 'listen', 'host': bindHost, 'port': bindPort}));
    try {
      listener.port = await listener._ready.future.timeout(
        timeout,
        onTimeout: () => throw const MonitorHttpErr(
          type: MonitorHttpErrType.net,
          message: 'The monitor agent did not start listening in time',
        ),
      );
    } catch (_) {
      await listener.close();
      rethrow;
    }
    return listener;
  }

  void _onFrame(dynamic event) {
    if (event is! String) return;
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

  Future<void> close() async {
    if (_closed) return _done.future;
    _closed = true;
    if (!_ready.isCompleted) {
      _ready.completeError(
        const MonitorHttpErr(
          type: MonitorHttpErrType.net,
          message: 'The monitor agent closed the listener',
        ),
      );
    }
    await _socket.close().catchError((_) {});
    final bridges = _bridges.toList();
    _bridges.clear();
    await Future.wait(bridges.map((b) => b.close()));
    if (!_done.isCompleted) _done.complete();
  }
}
