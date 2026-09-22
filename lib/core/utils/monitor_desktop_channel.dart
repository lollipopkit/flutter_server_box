import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:server_box/core/utils/local_tcp_tunnel.dart';
import 'package:server_box/data/provider/server/monitor_http.dart';

/// One authenticated monitor WebSocket carrying a desktop TCP connection.
class MonitorDesktopChannel implements TcpTunnelChannel {
  MonitorDesktopChannel._(this._socket) {
    _incoming = StreamController<List<int>>(
      sync: true,
      onPause: () => _subscription.pause(),
      onResume: () => _subscription.resume(),
    );
    _outgoing = StreamController<List<int>>(sync: true);
    _outgoingSubscription = _outgoing.stream.listen(
      _socket.add,
      onDone: () => unawaited(_socket.close()),
    );
    _subscription = _socket.listen(
      _onMessage,
      onError: _onError,
      onDone: _onDone,
    );
  }

  final WebSocket _socket;
  final Completer<void> _ready = Completer<void>();
  late final StreamController<List<int>> _incoming;
  late final StreamController<List<int>> _outgoing;
  late final StreamSubscription<dynamic> _subscription;
  late final StreamSubscription<List<int>> _outgoingSubscription;
  Future<void>? _closing;

  static Future<MonitorDesktopChannel> open(
    MonitorHttpClient client, {
    required String host,
    required int port,
  }) async {
    final channel = MonitorDesktopChannel._(await client.openDesktop());
    try {
      channel._socket.add(jsonEncode({'host': host, 'port': port}));
      await channel._ready.future.timeout(const Duration(seconds: 15));
      return channel;
    } catch (_) {
      await channel.close();
      rethrow;
    }
  }

  void _onMessage(dynamic message) {
    if (!_ready.isCompleted) {
      if (message is! String) {
        _ready.completeError(
          const FormatException('Invalid desktop relay response'),
        );
        return;
      }
      try {
        final response = jsonDecode(message) as Map<String, dynamic>;
        if (response['type'] == 'ready') {
          _ready.complete();
        } else {
          _ready.completeError(
            StateError(
              response['message'] as String? ?? 'Desktop relay failed',
            ),
          );
        }
      } catch (error, stack) {
        if (!_ready.isCompleted) _ready.completeError(error, stack);
      }
      return;
    }
    if (message is List<int> && !_incoming.isClosed) {
      _incoming.add(message);
    }
  }

  void _onError(Object error, StackTrace stack) {
    if (!_ready.isCompleted) _ready.completeError(error, stack);
    if (!_incoming.isClosed) _incoming.addError(error, stack);
  }

  void _onDone() {
    if (!_ready.isCompleted) {
      _ready.completeError(
        StateError('Desktop relay closed before connecting'),
      );
    }
    if (!_incoming.isClosed) unawaited(_incoming.close());
  }

  @override
  Stream<List<int>> get stream => _incoming.stream;

  @override
  StreamSink<List<int>> get sink => _outgoing.sink;

  @override
  Future<void> close() => _closing ??= _close();

  Future<void> _close() async {
    await _outgoing.close();
    await _outgoingSubscription.cancel();
    await _subscription.cancel();
    await _incoming.close();
    await _socket.close();
  }
}
