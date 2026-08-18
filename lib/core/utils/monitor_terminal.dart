import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:fl_lib/fl_lib.dart';
import 'package:server_box/data/model/app/error.dart';
import 'package:server_box/data/model/server/monitor_http_credential.dart';
import 'package:server_box/data/model/server/shell_backend.dart';
import 'package:server_box/data/provider/server/monitor_http.dart';

/// A shell from a `monitor` agent, with no SSH anywhere in it.
///
/// The agent runs the PTY on the machine it is installed on, as the account it
/// runs as, and a panel login is the only thing authorising it. That is the
/// whole point of the feature and also its entire cost: none of sshd's
/// authentication, logging or second factor applies. The agent decides whether
/// to offer it at all (`remote_access.passwordless_terminal`, off by default
/// outside Linux) and re-checks when the request arrives, so this is never the
/// thing granting access — it only asks.
///
/// # Wire format
///
/// Frame type is the channel selector: Binary is PTY bytes both ways, Text is
/// control JSON. Mirrors the panel's client (`monitor/frontend/src/lib/
/// terminal.svelte.ts`), and `monitor/src/api/ws/terminal.rs` is the spec.
///
/// # Reconnecting
///
/// Sessions outlive their WebSocket, so a dropped link is recovered here
/// rather than surfaced: [ShellSession.done] completes when the *shell* ends,
/// not when the socket does. A phone changing network mid-session would
/// otherwise tear the terminal down, which is exactly the case this has to
/// survive. The client reports how many bytes it has rendered and the agent
/// replays only the gap.
class MonitorShellBackend implements ShellBackend {
  MonitorShellBackend(this.monitor);

  final MonitorHttpCredential monitor;

  MonitorShellSession? _session;
  bool _closed = false;

  @override
  bool get isClosed => _closed;

  /// A PTY is one stream. A command written into it would land in the user's
  /// shell rather than run beside it, so everything built on a second channel
  /// — tmux, snippets that probe first, the AI helper — must not be offered.
  @override
  bool get supportsExec => false;

  @override
  Future<ShellSession> openShell({
    required int width,
    required int height,
    Map<String, String>? environment,
  }) async {
    if (_closed) {
      throw const MonitorHttpErr(
        type: MonitorHttpErrType.net,
        message: 'Monitor terminal backend is closed',
      );
    }
    final session = MonitorShellSession._(
      MonitorHttpClient(monitor),
      cols: width,
      rows: height,
    );
    _session = session;
    await session._start();
    return session;
  }

  @override
  Future<ShellSession> execute(
    String command, {
    required int width,
    required int height,
    Map<String, String>? environment,
  }) {
    throw UnsupportedError(
      'A monitor terminal has a single PTY and cannot run a second command',
    );
  }

  /// The session heals dropped links on its own, so the only failure this can
  /// report is one it cannot recover from.
  @override
  Future<void> ping() async {
    final session = _session;
    if (_closed) throw StateError('Monitor terminal backend is closed');
    if (session != null && session._finished) {
      throw StateError('Monitor terminal session has ended');
    }
  }

  @override
  void close() {
    _closed = true;
    _session?.close();
    _session = null;
  }
}

/// One PTY on the agent, kept alive across reconnects.
class MonitorShellSession implements ShellSession {
  MonitorShellSession._(this._client, {required int cols, required int rows})
    : _cols = cols,
      _rows = rows;

  /// Missing this much heartbeat means the link is gone. The agent sends one
  /// every 15s; three misses rather than one, so a stalled radio isn't
  /// mistaken for a dead session.
  static const _deadLink = Duration(seconds: 45);

  static const _term = 'xterm-256color';
  static const _reconnectBase = Duration(milliseconds: 500);
  static const _reconnectMax = Duration(seconds: 10);

  /// Sent to the terminal when the agent had to truncate the replay, so the
  /// screen isn't a silent mix of old and new output.
  static const _reset = [0x1b, 0x63];

  final MonitorHttpClient _client;

  final _output = StreamController<Uint8List>.broadcast();
  final _done = Completer<void>();

  WebSocket? _socket;
  StreamSubscription<dynamic>? _socketSub;
  Timer? _watchdog;
  Timer? _retry;
  int _attempt = 0;

  /// The handle that makes this session rejoinable. Null until the first
  /// `ready`; once set, a dropped socket is recoverable.
  String? _handle;

  /// Absolute position of the next byte to render — the resume point. Only
  /// ever set from the agent's `since`, never added to across a reconnect.
  int _rendered = 0;

  int _cols;
  int _rows;

  bool _finished = false;
  Completer<void>? _ready;

  @override
  Stream<Uint8List> get stdout => _output.stream;

  /// A PTY merges the two the way a real terminal does.
  @override
  Stream<Uint8List>? get stderr => null;

  @override
  Future<void> get done => _done.future;

  Future<void> _start() async {
    final ready = Completer<void>();
    _ready = ready;
    await _connect();
    await ready.future.timeout(
      const Duration(seconds: 20),
      onTimeout: () {
        close();
        throw const MonitorHttpErr(
          type: MonitorHttpErrType.net,
          message: 'The monitor agent did not open a shell in time',
        );
      },
    );
  }

  Future<void> _connect() async {
    if (_finished) return;
    final socket = await _client.openTerminal();
    if (_finished) {
      unawaited(socket.close());
      return;
    }
    _socket = socket;
    _socketSub = socket.listen(
      _onFrame,
      onError: (Object e, StackTrace s) {
        Loggers.app.warning('Monitor terminal socket error', e, s);
        _onDisconnect();
      },
      onDone: _onDisconnect,
      cancelOnError: true,
    );
    _armWatchdog();

    final handle = _handle;
    _send(
      handle == null
          ? {
              'type': 'open',
              // Ignored on this path — the agent runs the shell as itself, and
              // sending a name here would suggest otherwise
              'user': '',
              'auth': {'kind': 'local'},
              'cols': _cols,
              'rows': _rows,
              'term': _term,
            }
          : {
              'type': 'attach',
              'session': handle,
              'since': _rendered,
              'cols': _cols,
              'rows': _rows,
            },
    );
  }

  void _onFrame(dynamic event) {
    _armWatchdog();
    if (event is String) {
      _onControl(event);
      return;
    }
    if (event is List<int>) {
      final data = event is Uint8List ? event : Uint8List.fromList(event);
      _rendered += data.length;
      if (!_output.isClosed) _output.add(data);
      return;
    }
    Loggers.app.warning('Monitor terminal sent an unexpected frame');
  }

  void _onControl(String raw) {
    final Map<String, dynamic> msg;
    try {
      msg = jsonDecode(raw) as Map<String, dynamic>;
    } catch (e) {
      Loggers.app.warning('Monitor terminal sent malformed control JSON', e);
      return;
    }

    switch (msg['type']) {
      case 'ready':
        _handle = msg['session'] as String? ?? _handle;
        // The absolute position the stream that follows starts at, so it is
        // assigned rather than added to: after a truncated replay it moves
        // forward past output nobody will ever see.
        _rendered = (msg['since'] as num?)?.toInt() ?? 0;
        _attempt = 0;
        _ready?.complete();
        _ready = null;
      case 'error':
        _onError(msg);
      case 'exit':
        _finish();
      case 'hb':
        break;
      case 'prompt':
        // Only the SSH paths can ask for anything; there is nothing to answer
        // here, and silently ignoring it would leave the session wedged.
        _fail('The agent asked for credentials on a passwordless session');
      default:
        break;
    }
  }

  void _onError(Map<String, dynamic> msg) {
    final code = msg['code'] as String?;
    final message = msg['message'] as String? ?? 'Terminal error';

    switch (code) {
      // Not a failure: the session is fine, only the scrollback fell behind.
      // The screen is reset because what is on it is now a mix of output from
      // either side of a gap.
      case 'gap_truncated':
        if (!_output.isClosed) _output.add(Uint8List.fromList(_reset));
      // Another connection took the session over. Reconnecting would take it
      // straight back and the two would trade it forever.
      case 'superseded':
      case 'session_gone':
        _fail(message);
      default:
        _fail(message);
    }
  }

  /// Writes a message into the terminal itself before ending. There is no
  /// other place a user would see it — the page only learns that [done]
  /// completed.
  void _fail(String message) {
    if (!_output.isClosed) {
      _output.add(Uint8List.fromList(utf8.encode('\r\n$message\r\n')));
    }
    _finish();
  }

  void _onDisconnect() {
    _watchdog?.cancel();
    _watchdog = null;
    unawaited(_socketSub?.cancel());
    _socketSub = null;
    _socket = null;
    if (_finished) return;

    // Nothing to rejoin: the session never got far enough to have a handle,
    // so a retry would open a second shell rather than resume this one.
    if (_handle == null) {
      _fail('The monitor terminal closed before the shell started');
      return;
    }
    _scheduleReconnect();
  }

  void _scheduleReconnect() {
    _retry?.cancel();
    final backoffMs =
        (_reconnectBase.inMilliseconds << _attempt.clamp(0, 5)).clamp(
          _reconnectBase.inMilliseconds,
          _reconnectMax.inMilliseconds,
        );
    _attempt += 1;
    _retry = Timer(Duration(milliseconds: backoffMs), () async {
      if (_finished) return;
      try {
        await _connect();
      } catch (e, s) {
        Loggers.app.info('Monitor terminal reconnect failed: $e');
        // An agent that refuses outright — the terminal switched off, the
        // account gone — will keep refusing, but telling those apart from a
        // flaky link is the agent's answer, not ours; the backoff caps at
        // [_reconnectMax] either way.
        Loggers.app.finer('Monitor terminal reconnect', e, s);
        _onDisconnect();
      }
    });
  }

  /// Restarted on every frame, control or data: any traffic proves the link.
  void _armWatchdog() {
    _watchdog?.cancel();
    _watchdog = Timer(_deadLink, () {
      Loggers.app.info('Monitor terminal heartbeat lost, reconnecting');
      unawaited(_socket?.close());
      _onDisconnect();
    });
  }

  void _send(Map<String, dynamic> msg) {
    final socket = _socket;
    if (socket == null) return;
    try {
      socket.add(jsonEncode(msg));
    } catch (e, s) {
      Loggers.app.warning('Monitor terminal send failed', e, s);
    }
  }

  @override
  void write(List<int> data) {
    if (data.isEmpty) return;
    final socket = _socket;
    // Dropped rather than queued while reconnecting: by the time the link is
    // back the keystroke is stale, and a shell replaying a burst of buffered
    // input is worse than one that missed it.
    if (socket == null) return;
    try {
      socket.add(data);
    } catch (e, s) {
      Loggers.app.warning('Monitor terminal write failed', e, s);
    }
  }

  @override
  void resizeTerminal(int width, int height) {
    if (width == _cols && height == _rows) return;
    _cols = width;
    _rows = height;
    // Remembered even when there is no socket: a reattach carries the size,
    // so a rotation during an outage still reaches the shell
    _send({'type': 'resize', 'cols': width, 'rows': height});
  }

  @override
  void close() {
    if (_finished) return;
    // Distinguishes "end this shell" from "this connection is going away",
    // which is the difference between a session that can be rejoined and one
    // that is gone.
    _send({'type': 'close'});
    _finish();
  }

  void _finish() {
    if (_finished) return;
    _finished = true;
    _retry?.cancel();
    _watchdog?.cancel();
    unawaited(_socketSub?.cancel());
    unawaited(_socket?.close());
    _socket = null;
    _ready?.completeError(
      const MonitorHttpErr(
        type: MonitorHttpErrType.net,
        message: 'The monitor terminal ended before it was ready',
      ),
    );
    _ready = null;
    unawaited(_output.close());
    _client.dispose();
    if (!_done.isCompleted) _done.complete();
  }
}
