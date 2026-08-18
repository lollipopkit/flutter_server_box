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

  /// Every shell this handed out, so a test can write to the one the page is
  /// showing and see it arrive.
  final sessions = <FakeShellSession>[];

  /// Every command run on a channel of its own, in order. tmux and the AI
  /// probe both go through here, and a test that did not expect them should
  /// be able to see that they happened.
  final executed = <String>[];

  @override
  Future<ShellSession> openShell({
    required int width,
    required int height,
    Map<String, String>? environment,
  }) async {
    final session = FakeShellSession();
    sessions.add(session);
    return session;
  }

  @override
  Future<ShellSession> execute(
    String command, {
    required int width,
    required int height,
    Map<String, String>? environment,
  }) async {
    if (!supportsExec) throw UnsupportedError('no second channel');
    executed.add(command);
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

  /// The last size the page asked for, which is how a test sees a resize
  /// arrive without a real pty to measure.
  (int width, int height)? resizedTo;

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
  void resizeTerminal(int width, int height) => resizedTo = (width, height);

  @override
  void close() => finish();

  /// Sends [text] to the terminal, as the far side would.
  void emit(String text) {
    if (_out.isClosed) return;
    _out.add(Uint8List.fromList(text.codeUnits));
  }

  /// Ends the shell for good.
  void finish() {
    if (!_done.isCompleted) _done.complete();
    if (!_out.isClosed) _out.close();
  }
}
