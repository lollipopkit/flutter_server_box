import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/data/model/server/monitor_http_credential.dart';
import 'package:server_box/data/model/server/monitor_remote_access.dart';
import 'package:server_box/data/model/server/server_private_info.dart';
import 'package:server_box/data/model/server/shell_backend.dart';
import 'package:server_box/data/model/server/ssh_credential.dart';
import 'package:server_box/data/ssh/terminal_session.dart';
import 'package:server_box/data/ssh/terminal_source.dart';

/// A shell whose bytes the test writes itself.
class _FakeShell implements ShellSession {
  final _stdout = StreamController<Uint8List>();
  final _done = Completer<void>();

  final written = <int>[];
  var closed = false;
  (int, int)? resizedTo;

  @override
  Stream<Uint8List>? get stdout => _stdout.stream;

  /// Null, like a PTY: one stream, the way a real terminal has one.
  @override
  Stream<Uint8List>? get stderr => null;

  @override
  void write(List<int> data) => written.addAll(data);

  @override
  void resizeTerminal(int width, int height) => resizedTo = (width, height);

  @override
  Future<void> get done => _done.future;

  @override
  void close() {
    closed = true;
    finish();
  }

  void emit(String data) => _stdout.add(Uint8List.fromList(utf8.encode(data)));

  void finish() {
    if (!_done.isCompleted) _done.complete();
  }
}

/// Long enough for the session's own output flush, which batches a frame's
/// worth rather than writing every packet straight through.
Future<void> flushed() =>
    Future<void>.delayed(const Duration(milliseconds: 50));

void main() {
  final ssh = Spi(
    name: 'ssh',
    id: 'ssh',
    ssh: const SshCredential(ip: '10.0.0.1'),
  );
  final monitor = Spi(
    name: 'agent',
    id: 'agent',
    monitorHttp: const MonitorHttpCredential(addr: 'https://agent:3770'),
  );

  group('the shell on screen', () {
    test('what it prints reaches the terminal', () async {
      final session = TerminalSession(source: ServerSource(ssh));
      final shell = _FakeShell();
      session.bindForeground(shell);

      shell.emit('hello');
      await flushed();

      expect(session.terminal.buffer.currentLine.toString().trim(), 'hello');
      expect(session.outputTail, 'hello');
      session.dispose();
    });

    test('what is typed reaches the shell', () async {
      final session = TerminalSession(source: ServerSource(ssh));
      final shell = _FakeShell();
      session.bindForeground(shell);

      session.terminal.textInput('ls');

      expect(utf8.decode(shell.written), 'ls');
      session.dispose();
    });

    test('the terminal resizing resizes the shell', () async {
      final session = TerminalSession(source: ServerSource(ssh));
      final shell = _FakeShell();
      session.bindForeground(shell);

      session.terminal.resize(100, 40);

      expect(shell.resizedTo, (100, 40));
      session.dispose();
    });

    test('the end of the shell is announced once it has all been read', () async {
      final session = TerminalSession(source: ServerSource(ssh));
      final shell = _FakeShell();
      ShellSession? ended;
      session.onForegroundDone = (s) => ended = s;
      session.bindForeground(shell);

      // Printed and finished in the same breath, which is what a command that
      // says something and exits does. The last line must not be lost to the
      // flush that had not run yet.
      shell.emit('done');
      shell.finish();
      await flushed();

      expect(ended, same(shell));
      expect(session.foreground, isNull);
      expect(session.terminal.buffer.currentLine.toString().trim(), 'done');
      session.dispose();
    });

    test('a shell that was replaced does not announce the end', () async {
      final session = TerminalSession(source: ServerSource(ssh));
      final first = _FakeShell();
      final second = _FakeShell();
      var ends = 0;
      session.onForegroundDone = (_) => ends++;

      session.bindForeground(first);
      // What a tmux attach and a reconnect both do: the old channel closes
      // once the new one has the terminal, and that is not the terminal ending.
      session.bindForeground(second);
      first.finish();
      await flushed();

      expect(ends, 0);
      expect(session.foreground, same(second));
      session.dispose();
    });

    test('the old shell stops writing to the terminal once replaced', () async {
      final session = TerminalSession(source: ServerSource(ssh));
      final first = _FakeShell();
      final second = _FakeShell();

      session.bindForeground(first);
      session.bindForeground(second);
      first.emit('stale');
      second.emit('live');
      await flushed();

      expect(session.outputTail, 'live');
      session.dispose();
    });
  });

  group('what the tail keeps', () {
    test('it is bounded, keeping the end', () async {
      final session = TerminalSession(source: ServerSource(ssh));
      final shell = _FakeShell();
      session.bindForeground(shell);

      shell.emit('x' * 9000);
      shell.emit('tail');
      await flushed();

      // Read by the sudo prompt detector and the AI helper, both of which want
      // the last thing printed — a cap that dropped the newest would answer
      // with whatever scrolled past instead.
      expect(session.outputTail.length, lessThanOrEqualTo(8192));
      expect(session.outputTail.endsWith('tail'), isTrue);
      session.dispose();
    });

    test('it can be forgotten, so one answer is not read twice', () async {
      final session = TerminalSession(source: ServerSource(ssh));
      final shell = _FakeShell();
      session.bindForeground(shell);

      shell.emit('[sudo] password:');
      await flushed();
      session.clearOutputTail();

      expect(session.outputTail, isEmpty);
      session.dispose();
    });
  });

  group('this device', () {
    test('is a source of shells with nothing to connect to', () {
      final session = TerminalSession(source: const LocalSource());
      // Nothing to adopt: no connection anybody else could be holding, so the
      // shell is this session's own from the start.
      session.adopt(null);

      expect(session.backend, isNotNull);
      // A local process can start another, so tmux and the AI probe are on the
      // table here in a way they are not over a monitor agent's single PTY.
      expect(session.canExec, isTrue);
      expect(session.client, isNull);
    });

    test('has no server behind it', () {
      final session = TerminalSession(source: const LocalSource());
      expect(session.spi, isNull);
      // Nothing to add to what a login shell already knows about its own
      // machine.
      expect(session.environment, isNull);
    });

    test('closing hangs up the shell it opened', () {
      final session = TerminalSession(source: const LocalSource());
      session.adopt(null);

      session.close();

      expect(session.backend, isNull);
    });
  });

  group('where the shells come from', () {
    test('an agent that granted full access is a source of shells', () {
      final session = TerminalSession(source: ServerSource(monitor));
      session.adopt(null, granted: const MonitorRemoteAccess(fullAccess: true));

      expect(session.backend, isNotNull);
      // One PTY, so nothing that needs a second channel — tmux, the AI helper's
      // probe — may be offered.
      expect(session.canExec, isFalse);
    });

    test('an agent that granted nothing is not', () {
      final session = TerminalSession(source: ServerSource(monitor));
      session.adopt(null, granted: MonitorRemoteAccess.none);

      expect(session.backend, isNull);
    });

    test('an SSH server with no connection to adopt has none yet', () {
      final session = TerminalSession(source: ServerSource(ssh));
      session.adopt(null, granted: const MonitorRemoteAccess(fullAccess: true));

      // The grant is the agent's, and this server has no agent. Answering
      // otherwise would open the wrong machine's shell.
      expect(session.backend, isNull);
    });

    test('closing hangs up a connection this session opened', () {
      final session = TerminalSession(source: ServerSource(monitor));
      session.adopt(null, granted: const MonitorRemoteAccess(fullAccess: true));

      session.close();

      expect(session.backend, isNull);
    });

    test('closing closes the shell that was on screen', () {
      final session = TerminalSession(source: ServerSource(ssh));
      final shell = _FakeShell();
      session.bindForeground(shell);

      session.close();

      expect(shell.closed, isTrue);
      expect(session.foreground, isNull);
    });
  });
}
