import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:server_box/core/utils/ssh_local_tunnel.dart';
import 'package:server_box/src/rust/api/pve.dart';

/// An open PVE console, as the console views use it: bytes in and out, and a
/// terminal size. `sbm_virt::pve::console::Console` does the rest — the
/// websocket, termproxy's login, framing and keep-alive.
abstract interface class PveConsoleLink {
  /// The next bytes, or null once the console has ended.
  Future<Uint8List?> recv();

  Future<void> send(List<int> data);

  /// A text console's new size; nothing for a graphical one.
  Future<void> resize(int cols, int rows);

  Future<void> close();
}

/// [PveConsoleLink] over the FFI's [PveConsoleChannel].
final class PveConsoleChannelLink implements PveConsoleLink {
  PveConsoleChannelLink(this._channel);

  final PveConsoleChannel _channel;

  @override
  Future<Uint8List?> recv() => _channel.recv();

  @override
  Future<void> send(List<int> data) => _channel.send(data: data);

  @override
  Future<void> resize(int cols, int rows) =>
      _channel.resize(cols: cols, rows: rows);

  @override
  Future<void> close() => _channel.close();
}

/// Calls on a [PveConsoleLink] one after another, in the order they were
/// made: each is its own FFI call, and two in flight at once could reach the
/// console in either order.
///
/// Bytes queued behind a call in flight go out together in the next one, and
/// no more than [maxPending] of them wait: a console that has taken nothing
/// for that long has stopped, and is ended rather than buffered for.
final class PveConsoleWriter {
  PveConsoleWriter(this._link, {required this.onError});

  final PveConsoleLink _link;

  /// A write failed, or the queue overflowed: the console has gone.
  final void Function(Object error) onError;

  static const maxPending = 1 << 20;

  /// Each a byte run to send, or a size: `(cols, rows)`.
  final _queue = <Object>[];
  var _pending = 0;
  Completer<void>? _drained;
  var _failed = false;

  /// Completes once what is queued now has been sent.
  Future<void> send(List<int> data) {
    if (data.isEmpty) return _idle;
    final last = _queue.lastOrNull;
    if (last is BytesBuilder) {
      last.add(data);
    } else {
      _queue.add(BytesBuilder()..add(data));
    }
    _pending += data.length;
    if (_pending > maxPending) {
      _fail(StateError('The console is not taking input'));
    }
    return _run();
  }

  Future<void> resize(int cols, int rows) {
    _queue.add((cols, rows));
    return _run();
  }

  Future<void> get _idle => _drained?.future ?? Future<void>.value();

  Future<void> _run() {
    if (_failed) {
      _queue.clear();
      return Future<void>.value();
    }
    final running = _drained;
    if (running != null) return running.future;
    final drained = _drained = Completer<void>();
    () async {
      try {
        while (_queue.isNotEmpty && !_failed) {
          switch (_queue.removeAt(0)) {
            case final BytesBuilder bytes:
              _pending -= bytes.length;
              await _link.send(bytes.takeBytes());
            case (final int cols, final int rows):
              await _link.resize(cols, rows);
          }
        }
      } catch (e) {
        _fail(e);
      } finally {
        _drained = null;
        drained.complete();
      }
    }();
    return drained.future;
  }

  void _fail(Object error) {
    if (_failed) return;
    _failed = true;
    _queue.clear();
    _pending = 0;
    onError(error);
  }
}

/// A graphical PVE console as a tunnel channel, so [SshLocalTunnel] can hand
/// its RFB stream to the VNC engine, which only takes a host and a port.
class PveConsoleTunnelChannel implements SshTunnelChannel {
  PveConsoleTunnelChannel(this._link) {
    _writer = PveConsoleWriter(_link, onError: (_) => unawaited(close()));
    _sending = _outgoing.stream.listen(
      // Paused until each slice is sent: the local socket is read no faster
      // than the console takes it.
      (bytes) => _sending.pause(_writer.send(bytes)),
      // What is piped in failed — the local socket's read, forwarded by
      // `SshTunnelBridge` — which ends the connection like its end does.
      onError: (Object _) => unawaited(close()),
      onDone: () => unawaited(close()),
      cancelOnError: true,
    );
    _incoming = StreamController<List<int>>(
      onListen: _pump,
      onResume: () => _resumed?.complete(),
    );
  }

  final PveConsoleLink _link;
  late final PveConsoleWriter _writer;
  final _outgoing = StreamController<List<int>>();
  late final StreamSubscription<List<int>> _sending;
  late final StreamController<List<int>> _incoming;
  Completer<void>? _resumed;
  final _done = Completer<void>();
  var _closed = false;

  /// Completes when the console has ended, from either side.
  Future<void> get done => _done.future;

  @override
  Stream<List<int>> get stream => _incoming.stream;

  @override
  StreamSink<List<int>> get sink => _outgoing.sink;

  /// Reads the console for as long as [stream] is listened to, waiting
  /// while it is paused.
  Future<void> _pump() async {
    try {
      while (!_closed) {
        if (_incoming.isPaused) {
          await (_resumed = Completer<void>()).future;
          _resumed = null;
          continue;
        }
        final bytes = await _link.recv();
        if (bytes == null || _closed) break;
        _incoming.add(bytes);
      }
    } catch (_) {
      // Failed reading: the same ending as the console closing.
    }
    unawaited(close());
  }

  @override
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    _resumed?.complete();
    // Cancelled rather than closed: `SshTunnelBridge` pipes the local socket
    // into [sink], and closing a controller with an `addStream` in progress
    // throws. Cancelling ends that `addStream` instead, and the pipe then
    // closes the controller itself.
    unawaited(_sending.cancel());
    if (!_incoming.isClosed) unawaited(_incoming.close());
    await _link
        .close()
        .timeout(const Duration(seconds: 3), onTimeout: () {})
        .catchError((_) {});
    if (!_done.isCompleted) _done.complete();
  }

  /// A loopback listener that carries one connection over [channel]: the
  /// first to present the tunnel's `SshLocalTunnel.accessToken`. Any other
  /// is dropped unread, and the listener closes once that one is through.
  ///
  /// One connection because the console behind [channel] is one: a PVE
  /// console ticket opens one socket, and a client connecting a second time
  /// needs a new ticket — which is the caller's to fetch, with a new tunnel.
  /// The tunnel closes when the console does, and the console when the
  /// tunnel does — also before any client took it, when nothing else would.
  static Future<SshLocalTunnel> loopbackOnce(
    PveConsoleTunnelChannel channel,
  ) async {
    var taken = false;
    final SshLocalTunnel tunnel;
    try {
      tunnel = await SshLocalTunnel.bindWithDialer(
        bindHost: InternetAddress.loopbackIPv4.address,
        sshDone: channel.done,
        authenticated: true,
        once: true,
        dialer: () async {
          if (taken) {
            throw StateError('This console tunnel carries one connection');
          }
          taken = true;
          return channel;
        },
      );
    } catch (_) {
      await channel.close();
      rethrow;
    }
    unawaited(tunnel.done.whenComplete(channel.close));
    return tunnel;
  }
}
