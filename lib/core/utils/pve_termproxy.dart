import 'dart:async';
import 'dart:typed_data';

import 'package:server_box/core/utils/pve_console.dart';
import 'package:server_box/data/model/app/error.dart';
import 'package:server_box/data/model/server/shell_backend.dart';

/// A PVE `termproxy` console as a [ShellBackend], so the terminal page shows
/// it the way it shows any shell.
///
/// termproxy itself — the ticket login, the input and resize framing, the
/// keep-alive — is `sbm_virt::pve::console::Console`'s, behind [PveConsoleLink];
/// this only carries terminal bytes and sizes.
///
/// One shell per backend: a termproxy ticket and its port are good for one
/// connection, so a reconnect is a new ticket, a new console and a new
/// backend. [isClosed] is true once the console has ended under the shell,
/// which the terminal page reads as a lost connection and answers by
/// connecting again; the shell being closed from this side — a disconnect
/// from the notification — ends it without that, as closing an SSH channel
/// does.
class PveTermShellBackend implements ShellBackend {
  PveTermShellBackend(this._link) {
    _writer = PveConsoleWriter(_link, onError: (_) => _finish());
    _output = StreamController<Uint8List>(
      onResume: () => _resumed?.complete(),
    );
    unawaited(_pump());
  }

  final PveConsoleLink _link;
  late final PveConsoleWriter _writer;

  /// The console's output, held until the shell is bound.
  late final StreamController<Uint8List> _output;
  Completer<void>? _resumed;
  final _done = Completer<void>();
  PveTermShellSession? _session;

  /// [close] was called: the backend is spent.
  bool _closed = false;

  /// The shell was closed from this side, which is an ending, not a loss.
  bool _shellClosed = false;

  /// Reads the console until it ends, no faster than the shell takes it.
  Future<void> _pump() async {
    try {
      while (!_done.isCompleted) {
        if (_output.isPaused && _output.hasListener) {
          await (_resumed = Completer<void>()).future;
          _resumed = null;
          continue;
        }
        final bytes = await _link.recv();
        if (bytes == null || _done.isCompleted) break;
        if (bytes.isNotEmpty) _output.add(bytes);
      }
    } catch (_) {
      // Failed reading: the same ending as the console closing.
    }
    _finish();
  }

  void _finish() {
    _resumed?.complete();
    if (!_output.isClosed) unawaited(_output.close());
    if (!_done.isCompleted) _done.complete();
  }

  @override
  bool get isClosed => _closed || (_done.isCompleted && !_shellClosed);

  /// One stream, the console's: nothing can run beside it.
  @override
  bool get supportsExec => false;

  @override
  bool get supportsTmux => false;

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
    // Not waiting for the close handshake: a peer that never answers it must
    // not keep the session open.
    unawaited(_link.close().catchError((_) {}));
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
    if (data.isEmpty || _backend._done.isCompleted) return;
    unawaited(_backend._writer.send(data));
  }

  @override
  void resizeTerminal(int width, int height) {
    if (width <= 0 || height <= 0 || _backend._done.isCompleted) return;
    unawaited(_backend._writer.resize(width, height));
  }

  @override
  Future<void> get done => _backend._done.future;

  @override
  void close() {
    _backend._shellClosed = true;
    _backend._hangUp();
  }
}
