import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:fl_lib/fl_lib.dart';
import 'package:server_box/core/utils/monitor_ws_frames.dart';
import 'package:server_box/core/utils/ssh_local_tunnel.dart';
import 'package:server_box/data/model/app/error.dart';
import 'package:server_box/data/provider/server/monitor_http.dart';

/// A TCP connection carried by a `monitor` agent's relay.
///
/// What a monitor-only server has instead of an SSH direct-tcpip channel. An
/// agent is an HTTP API and has no socket this app can point anywhere, so
/// `MonitorHttpCapabilities` answers no to `byteStream` — this is the endpoint
/// that answers yes to `tcpRelay`, and a remote desktop session is what needs
/// it. See `monitor/src/api/ws/stream.rs`.
///
/// The pair with `SshTunnelChannel` is deliberate: `SshLocalTunnel.bindWithDialer`
/// takes a dialer, and both transports produce one, so the local loopback a
/// session connects to is built the same way whichever is underneath.
///
/// # Wire format
///
/// One socket is one connection. Text frames are control JSON — the request
/// first, `{"type":"open","host":..,"port":..}` — or `{"type":"accept",
/// "id":..}` for a connection the agent's listener took, see [accept] — then
/// `ready`, `error` or `exit`; and Binary frames are the bytes of the
/// connection, both ways.
class MonitorTunnelChannel implements SshTunnelChannel {
  MonitorTunnelChannel._(this._socket);

  final WebSocket _socket;

  final _data = StreamController<List<int>>();
  final _ready = Completer<void>();

  bool _finished = false;

  /// The Binary frames out, bound to the socket once (`addStream`): the one
  /// way into a dart:io WebSocket that is paced by the connection. `add`
  /// queues without limit — a 2 GiB upload was read into memory as fast as
  /// the disk gave it, and a cancel left what was queued still going out.
  StreamController<List<int>>? _out;
  Future<void>? _bound;

  /// What [_DirectSink.addStream] is reading: paused while [_out] is.
  StreamSubscription<List<int>>? _source;

  /// The future [_addStream] handed out for [_source], completed by [_finish]
  /// when it cancels the read: a cancelled subscription reports neither done
  /// nor an error, and the pipe waiting on it — `SshTunnelBridge` — would wait
  /// forever, holding up the tunnel's close.
  Completer<void>? _sourceDone;

  /// The socket's close, started once and awaited by [close].
  ///
  /// Held rather than called twice: `_finish` reaches the close from paths that
  /// cannot await it, and [close] has to be able to wait for that same close
  /// rather than start a second one.
  Future<void>? _closing;

  /// Dials [host]:[port] from the agent and hands back the channel.
  ///
  /// The address travels on the socket rather than in the URL: it is the
  /// operator's own network, and there is no reason for it to be written into
  /// every access log between here and the agent.
  static Future<MonitorTunnelChannel> dial({
    required MonitorHttpClient client,
    required String remoteHost,
    required int remotePort,
    Duration timeout = const Duration(seconds: 15),
  }) => _start(
    client,
    {'type': 'open', 'host': remoteHost, 'port': remotePort},
    timeout,
  );

  /// Takes over the connection the agent's listener announced as [id] — see
  /// `MonitorRemoteListener` — and hands back the channel.
  static Future<MonitorTunnelChannel> accept({
    required MonitorHttpClient client,
    required String id,
    Duration timeout = const Duration(seconds: 15),
  }) => _start(client, {'type': 'accept', 'id': id}, timeout);

  /// Opens the relay, says which connection it is for, and waits for `ready`.
  static Future<MonitorTunnelChannel> _start(
    MonitorHttpClient client,
    Map<String, Object> request,
    Duration timeout,
  ) async {
    final socket = await client.openStream(timeout: timeout);
    final channel = MonitorTunnelChannel._(socket);
    channel._listen();
    socket.add(jsonEncode(request));
    try {
      await channel._ready.future.timeout(
        timeout,
        onTimeout: () {
          channel.close();
          throw const MonitorHttpErr(
            type: MonitorHttpErrType.net,
            message: 'The monitor agent did not open the connection in time',
          );
        },
      );
    } catch (_) {
      await channel.close();
      rethrow;
    }
    return channel;
  }

  @override
  Stream<List<int>> get stream => _data.stream;

  /// Nothing buffered: a remote desktop's frames are sent as they are produced,
  /// and the shell's habit of queueing a paste would only make a stalled link
  /// hold stale input.
  @override
  StreamSink<List<int>> get sink => _DirectSink(_write, _addStream);

  /// Ends it at once — nothing more is read or written — and waits a little
  /// for the socket to close behind it, not for a stalled link to drain.
  @override
  Future<void> close() async {
    _finish();
    await _closing?.timeout(const Duration(seconds: 5), onTimeout: () {});
  }

  /// Ends the connection: the stream ends, a waiting handshake is refused, and
  /// the socket is closed.
  ///
  /// One place rather than two, because every path here means the same thing —
  /// the agent said `error` or `exit`, the socket errored or closed, or a write
  /// failed — and a path that only stopped feeding the stream left the socket
  /// open, with the agent still holding a connection nothing was reading.
  void _finish() {
    if (_finished) return;
    _finished = true;
    // Not awaited: this runs from `onDone` and from a failing write, neither of
    // which has anywhere to await it. A single-subscription controller's
    // `close()` future only completes once the stream has been listened to and
    // drained, and a connection that was opened and abandoned has no listener —
    // which hung every teardown waiting on it. Readers still see the stream end.
    if (!_data.isClosed) unawaited(_data.close());
    // What was still to be read is not: a cancelled upload stops here, with
    // at most a frame or two queued behind it.
    unawaited(_source?.cancel());
    _source = null;
    final sourceDone = _sourceDone;
    _sourceDone = null;
    if (sourceDone != null && !sourceDone.isCompleted) sourceDone.complete();
    final out = _out;
    if (out != null && !out.isClosed) unawaited(out.close());
    // A WebSocket cannot close while bound, and dart:io has no way to abort
    // one: what was already queued — a frame or two here, the agent's own
    // bounded queue behind it — goes out at the link's pace first. A link
    // that is gone ends the bind with its error.
    _closing ??= () async {
      try {
        await _bound;
        await _socket.close();
      } catch (_) {}
    }();
    if (!_ready.isCompleted) {
      // A close before `ready` is the failure this channel reports; a caller
      // waiting on the handshake must not be left waiting for a socket that
      // has already gone.
      _ready.completeError(
        const MonitorHttpErr(
          type: MonitorHttpErrType.net,
          message: 'The monitor agent closed the connection',
        ),
      );
    }
  }

  void _listen() {
    _socket.listen(
      _onFrame,
      onError: (Object e, StackTrace s) {
        Loggers.app.warning('Monitor stream socket error', e, s);
        _finish();
      },
      onDone: _finish,
      cancelOnError: true,
    );
  }

  void _onFrame(dynamic event) {
    if (event is List<int>) {
      if (!_data.isClosed) _data.add(event);
      return;
    }
    if (event is! String) {
      Loggers.app.warning('Monitor stream sent an unexpected frame');
      return;
    }
    final Map<String, dynamic> msg;
    try {
      msg = jsonDecode(event) as Map<String, dynamic>;
    } catch (e) {
      Loggers.app.warning('Monitor stream sent malformed control JSON', e);
      return;
    }
    switch (msg['type']) {
      case 'ready':
        if (!_ready.isCompleted) _ready.complete();
      case 'error':
        final message = msg['message'] as String? ?? 'Stream error';
        if (!_ready.isCompleted) {
          _ready.completeError(
            MonitorHttpErr(type: MonitorHttpErrType.net, message: message),
          );
        } else {
          Loggers.app.warning('Monitor stream error: $message');
        }
        _finish();
      case 'exit':
        _finish();
      default:
        // `pong` and anything a later agent adds. Unknown control frames are
        // ignored rather than treated as a failure: the bytes are the
        // connection, and this side has nothing to negotiate.
        break;
    }
  }

  /// [_out], made and bound on the first write — after the `open` request,
  /// which went straight to the socket.
  StreamController<List<int>> _outgoing() {
    final existing = _out;
    if (existing != null) return existing;
    final out = StreamController<List<int>>(
      onPause: () => _source?.pause(),
      onResume: () => _source?.resume(),
    );
    _out = out;
    _bound = _socket.addStream(out.stream).catchError((Object e, StackTrace s) {
      Loggers.app.warning('Monitor stream write failed', e, s);
      _finish();
    });
    return out;
  }

  void _write(List<int> data) {
    if (_finished || data.isEmpty) return;
    final out = _outgoing();
    if (out.isClosed) return;
    monitorWsFrames(data).forEach(out.add);
  }

  /// Reads [stream] into the connection no faster than the connection takes
  /// it: paused whenever [_out] is.
  Future<void> _addStream(Stream<List<int>> stream) {
    if (_finished) return Future<void>.value();
    final out = _outgoing();
    final done = Completer<void>();
    final sub = stream.listen(
      _write,
      onError: (Object e, StackTrace s) {
        if (!done.isCompleted) done.completeError(e, s);
      },
      onDone: () {
        if (!done.isCompleted) done.complete();
      },
      cancelOnError: true,
    );
    _source = sub;
    _sourceDone = done;
    // Held back from the start only by a connection that is: a controller
    // with no listener yet also reads as paused, and the socket's listening
    // is `onListen`, which would never resume it.
    if (out.hasListener && out.isPaused) sub.pause();
    return done.future.whenComplete(() {
      if (identical(_source, sub)) _source = null;
      if (identical(_sourceDone, done)) _sourceDone = null;
    });
  }
}

/// Writes straight to the socket, one frame per `add`.
///
/// `IOSink`-shaped rather than a controller, because there is nothing to
/// buffer for: a websocket frame either goes or the connection has failed, and
/// pretending otherwise would make the failure arrive late.
class _DirectSink implements StreamSink<List<int>> {
  _DirectSink(this._write, this._addStream);

  final void Function(List<int>) _write;
  final Future<void> Function(Stream<List<int>>) _addStream;

  @override
  void add(List<int> event) => _write(event);

  @override
  void addError(Object error, [StackTrace? stackTrace]) =>
      Loggers.app.warning('Monitor stream sink error', error, stackTrace);

  /// Paced by the connection — see [MonitorTunnelChannel._out].
  @override
  Future<void> addStream(Stream<List<int>> stream) => _addStream(stream);

  @override
  Future<void> close() async {}

  @override
  Future<void> get done => Future<void>.value();
}
