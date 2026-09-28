import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:server_box/data/model/app/error.dart';
import 'package:server_box/data/model/server/shell_backend.dart';

/// Proxmox VE's `termproxy` protocol, spoken over a node's `vncwebsocket`.
///
/// Written against PVE's own client, `pve-xtermjs` (`xterm.js/src/main.js`,
/// `startConnection`), and the server it talks to, `proxmox-termproxy`:
///
/// - The websocket is opened with the `binary` subprotocol; the proxy relays
///   frame payloads to termproxy's TCP socket byte for byte.
/// - First, the client sends `<user>:<ticket>\n` — the `user` and `ticket`
///   `POST .../termproxy` answered. For an API token that user is the token
///   itself (`root@pam!name`); the bare `root@pam` is refused. termproxy
///   checks the ticket against the API and answers `OK`, or closes the
///   connection.
/// - Then, client to server: `0:<length>:<data>` for input, where `<length>`
///   is the byte length of the UTF-8 `<data>`; `1:<cols>:<rows>:` to resize;
///   `2` as a keep-alive, which `main.js` sends every 30 seconds.
/// - Server to client: raw terminal output in binary frames.
///
/// `main.js` sends its messages as text frames; binary frames are sent here,
/// which carry input that is not valid UTF-8 unharmed.
///
/// Verified on PVE 9.2.2 (proxmox-termproxy 2.1.0, pve-xtermjs 6.0.0) by
/// `test/e2e/virt_real_test.dart`, over an SSH channel and directly:
/// - `OK` arrives as a binary frame of exactly those two bytes, the output
///   (a container's getty, `ESC[H ESC[J` first) in the frames after it.
/// - Input is accepted in binary frames and in text frames alike; resize and
///   keep-alive leave the session running.
/// - A refused ticket, or the wrong user beside a good one, gets no answer at
///   all: the websocket ends without a close frame (1006). So a refusal
///   reads as the connection closing before `OK`, not as a reply.
abstract final class PveTermProxy {
  /// The first message: who the ticket was issued to, and the ticket.
  static Uint8List auth(String user, String ticket) =>
      _bytes('$user:$ticket\n');

  /// [data], framed as input.
  static Uint8List input(List<int> data) {
    final head = ascii.encode('0:${data.length}:');
    return Uint8List(head.length + data.length)
      ..setRange(0, head.length, head)
      ..setRange(head.length, head.length + data.length, data);
  }

  /// A new terminal size.
  static Uint8List resize(int cols, int rows) => _bytes('1:$cols:$rows:');

  /// Keeps an idle connection from being timed out by the proxy.
  static final keepAlive = _bytes('2');

  /// termproxy's answer to an accepted ticket, before any output.
  static const accepted = [0x4f, 0x4b]; // "OK"

  /// How often [keepAlive] is sent: `main.js`'s interval.
  static const keepAliveInterval = Duration(seconds: 30);

  static Uint8List _bytes(String s) => Uint8List.fromList(utf8.encode(s));
}

/// A termproxy console as a [ShellBackend], so the terminal page shows it the
/// way it shows any shell.
///
/// One shell per backend: a termproxy ticket and its port are good for one
/// connection, so a reconnect is a new ticket, a new socket and a new backend.
/// [isClosed] is true once the socket has ended under the shell, which the
/// terminal page reads as a lost connection and answers by connecting again;
/// the shell being closed from this side — a disconnect from the
/// notification — ends it without that, as closing an SSH channel does.
class PveTermShellBackend implements ShellBackend {
  PveTermShellBackend._(this._socket);

  final WebSocket _socket;

  /// Output after `OK`, held until the shell is bound.
  final _output = StreamController<Uint8List>();
  final _done = Completer<void>();
  final _handshake = Completer<void>();
  final _pending = BytesBuilder(copy: false);
  late final StreamSubscription<dynamic> _sub;
  Timer? _keepAliveTimer;
  PveTermShellSession? _session;
  bool _accepted = false;

  /// [close] was called: the backend is spent.
  bool _closed = false;

  /// The shell was closed from this side, which is an ending, not a loss.
  bool _shellClosed = false;

  static const handshakeTimeout = Duration(seconds: 15);

  /// Authenticates on [socket] — an open `vncwebsocket` for a `termproxy`
  /// ticket — and answers once termproxy has accepted it.
  ///
  /// Throws [VirtErr] with [VirtErrType.unreachable] when the socket ends or
  /// stays silent before `OK` — which is also how termproxy refuses a ticket
  /// — and [VirtErrType.authFailed] should it ever answer something else.
  /// The socket is closed on any failure.
  static Future<PveTermShellBackend> start(
    WebSocket socket, {
    required String user,
    required String ticket,
    Duration timeout = handshakeTimeout,
    Duration keepAlive = PveTermProxy.keepAliveInterval,
  }) async {
    final backend = PveTermShellBackend._(socket);
    backend._listen();
    try {
      socket.add(PveTermProxy.auth(user, ticket));
      await backend._handshake.future.timeout(timeout);
    } catch (e) {
      backend.close();
      if (e is VirtErr) rethrow;
      throw VirtErr(
        type: VirtErrType.unreachable,
        message: e is TimeoutException
            ? 'termproxy did not answer'
            : e.toString(),
        cause: e,
      );
    }
    backend._keepAliveTimer = Timer.periodic(keepAlive, (_) {
      backend._send(PveTermProxy.keepAlive);
    });
    return backend;
  }

  void _listen() {
    _sub = _socket.listen(
      (frame) {
        final bytes = switch (frame) {
          final List<int> b => b,
          final String s => utf8.encode(s),
          _ => const <int>[],
        };
        if (_accepted) {
          if (bytes.isNotEmpty) _output.add(Uint8List.fromList(bytes));
          return;
        }
        _pending.add(bytes);
        if (_pending.length < PveTermProxy.accepted.length) return;
        final head = _pending.takeBytes();
        if (head[0] != PveTermProxy.accepted[0] ||
            head[1] != PveTermProxy.accepted[1]) {
          if (!_handshake.isCompleted) {
            _handshake.completeError(
              const VirtErr(
                type: VirtErrType.authFailed,
                message: 'termproxy refused the console ticket',
              ),
            );
          }
          return;
        }
        _accepted = true;
        if (head.length > PveTermProxy.accepted.length) {
          _output.add(
            Uint8List.sublistView(head, PveTermProxy.accepted.length),
          );
        }
        if (!_handshake.isCompleted) _handshake.complete();
      },
      onError: (Object e, StackTrace s) {
        if (!_handshake.isCompleted) _handshake.completeError(e, s);
        _finish();
      },
      onDone: () {
        if (!_handshake.isCompleted) {
          _handshake.completeError(
            VirtErr(
              type: VirtErrType.unreachable,
              message:
                  'termproxy closed the connection'
                  '${_socket.closeReason?.isNotEmpty == true ? ': ${_socket.closeReason}' : ''}',
            ),
          );
        }
        _finish();
      },
      cancelOnError: true,
    );
  }

  void _finish() {
    _keepAliveTimer?.cancel();
    _keepAliveTimer = null;
    if (!_output.isClosed) unawaited(_output.close());
    if (!_done.isCompleted) _done.complete();
  }

  void _send(List<int> bytes) {
    if (_done.isCompleted) return;
    try {
      _socket.add(bytes);
    } catch (_) {
      // Closed under us; `onDone` reports it.
    }
  }

  @override
  bool get isClosed => _closed || (_done.isCompleted && !_shellClosed);

  /// One stream, the console's: nothing can run beside it.
  @override
  bool get supportsExec => false;

  @override
  Future<ShellSession> openShell({
    required int width,
    required int height,
    Map<String, String>? environment,
  }) async {
    if (_session != null) {
      throw StateError('A termproxy console carries one shell');
    }
    if (_done.isCompleted) {
      throw const VirtErr(
        type: VirtErrType.unreachable,
        message: 'The console has closed',
      );
    }
    final session = PveTermShellSession._(this);
    _session = session;
    session.resizeTerminal(width, height);
    return session;
  }

  @override
  Future<ShellSession> execute(
    String command, {
    required int width,
    required int height,
    Map<String, String>? environment,
  }) {
    throw UnsupportedError('A termproxy console cannot run a command');
  }

  @override
  Future<void> ping() async {
    if (_done.isCompleted) throw StateError('The console has closed');
  }

  @override
  void close() {
    _closed = true;
    _hangUp();
  }

  void _hangUp() {
    _keepAliveTimer?.cancel();
    _keepAliveTimer = null;
    unawaited(_socket.close(WebSocketStatus.normalClosure).catchError((_) {}));
    // Not waiting for the close handshake: a peer that never answers it must
    // not keep the session open.
    unawaited(_sub.cancel());
    _finish();
  }
}

/// The shell of a [PveTermShellBackend].
class PveTermShellSession implements ShellSession {
  PveTermShellSession._(this._backend);

  final PveTermShellBackend _backend;

  @override
  Stream<Uint8List>? get stdout => _backend._output.stream;

  /// termproxy runs its command on a PTY, which merges the two.
  @override
  Stream<Uint8List>? get stderr => null;

  @override
  void write(List<int> data) {
    if (data.isEmpty) return;
    _backend._send(PveTermProxy.input(data));
  }

  @override
  void resizeTerminal(int width, int height) {
    if (width <= 0 || height <= 0) return;
    _backend._send(PveTermProxy.resize(width, height));
  }

  @override
  Future<void> get done => _backend._done.future;

  @override
  void close() {
    _backend._shellClosed = true;
    _backend._hangUp();
  }
}
