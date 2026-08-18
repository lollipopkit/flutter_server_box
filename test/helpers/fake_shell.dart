import 'dart:async';
import 'dart:typed_data';

import 'package:server_box/data/model/server/shell_backend.dart';

/// A shell that is a controller, so a terminal test is about the terminal.
///
/// The three real backends each reach for something a test does not have — a
/// socket, an agent's HTTP PTY, a process — and `TerminalSession.over` exists
/// so a page can be built on this instead.
class FakeShellBackend implements ShellBackend {
  FakeShellBackend({this.supportsExec = true});

  @override
  final bool supportsExec;

  bool _closed = false;

  @override
  bool get isClosed => _closed;

  @override
  Future<ShellSession> openShell({
    required int width,
    required int height,
    Map<String, String>? environment,
  }) async {
    return FakeShellSession();
  }

  @override
  Future<ShellSession> execute(
    String _, {
    required int width,
    required int height,
    Map<String, String>? environment,
  }) async {
    if (!supportsExec) throw UnsupportedError('no second channel');
    final session = FakeShellSession()..finish();
    return session;
  }

  @override
  Future<void> ping() async {
    if (_closed) throw StateError('the fake backend is closed');
  }

  @override
  void close() => _closed = true;
}

class FakeShellSession implements ShellSession {
  final _out = StreamController<Uint8List>.broadcast();
  final _done = Completer<void>();

  /// What the terminal typed, as text.
  final written = StringBuffer();

  @override
  Stream<Uint8List>? get stdout => _out.stream;

  /// Null, like a pty: the two streams are merged, which is the shape the
  /// terminal page is written against.
  @override
  Stream<Uint8List>? get stderr => null;

  @override
  Future<void> get done => _done.future;

  @override
  void write(List<int> data) => written.write(String.fromCharCodes(data));

  @override
  void resizeTerminal(int width, int height) {}

  @override
  void close() => finish();

  /// Ends the shell for good.
  void finish() {
    if (!_done.isCompleted) _done.complete();
    if (!_out.isClosed) _out.close();
  }
}
