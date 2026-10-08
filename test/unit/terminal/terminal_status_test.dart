import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/data/model/server/server_private_info.dart';
import 'package:server_box/data/model/server/shell_backend.dart';
import 'package:server_box/data/model/server/ssh_credential.dart';
import 'package:server_box/data/ssh/terminal_session.dart';
import 'package:server_box/data/ssh/terminal_source.dart';
import 'package:server_box/data/ssh/terminal_status.dart';
import 'package:server_box/data/ssh/tmux/tmux_ids.dart';
import 'package:xterm/core.dart';

class _FakeShell implements ShellSession {
  final _stdout = StreamController<Uint8List>();
  final _done = Completer<void>();
  final written = <int>[];

  @override
  Stream<Uint8List>? get stdout => _stdout.stream;

  @override
  Stream<Uint8List>? get stderr => null;

  @override
  void write(List<int> data) => written.addAll(data);

  @override
  void resizeTerminal(int width, int height) {}

  @override
  Future<void> get done => _done.future;

  @override
  void close() => finish();

  void emit(String data) => _stdout.add(Uint8List.fromList(utf8.encode(data)));

  void finish() {
    if (!_done.isCompleted) _done.complete();
  }
}

Future<void> flushed() =>
    Future<void>.delayed(const Duration(milliseconds: 50));

ProgramStatusReport report(String payload) =>
    ProgramStatusReport.parse([payload])!;

void main() {
  group('TerminalStatus', () {
    test('state is the most urgent of the shell and every pane', () {
      final status = TerminalStatus();
      final pane = TmuxPaneId('%1');
      status.shell.apply(report('state=working'));
      status.applyPane(pane, report('state=blocked'));
      expect(status.state, ProgramState.blocked);
      expect(status.headlineOf([TmuxPaneId('%2')]), isNull);
      expect(status.headlineOf([pane])!.state, ProgramState.blocked);
    });

    test('a pane with nothing to show keeps no records', () {
      final status = TerminalStatus();
      var notified = 0;
      status.addListener(() => notified++);
      status.applyPane(TmuxPaneId('%1'), report('state=clear'));
      expect(status.pane(TmuxPaneId('%1')), isNull);
      expect(notified, 0);

      status
        ..applyPane(TmuxPaneId('%1'), report('state=working'))
        ..applyPane(TmuxPaneId('%1'), report('state=clear'));
      expect(status.pane(TmuxPaneId('%1')), isNull);
      expect(notified, 2);
    });

    test('says every record as plain lines for the Agent', () {
      final status = TerminalStatus()
        ..shell.apply(report('state=working:app=deploy'))
        ..shell.apply(
          report('state=blocked:kind=permission:id=eu:msg=QXBwcm92ZT8'),
        )
        ..shell.apply(const ShellMark(ShellMarkKind.commandExecuted))
        ..applyPane(TmuxPaneId('%3'), report('state=done'));
      expect(
        status.describeForAgent(paneLabel: (_) => '1:logs'),
        'shell: working app=deploy\n'
        'shell [eu]: blocked (permission) app=deploy msg="Approve?"\n'
        'shell: a command is running\n'
        'tmux pane %3 (1:logs): done',
      );
      expect(TerminalStatus().describeForAgent(), isEmpty);
    });

    test('a closed pane takes its records with it', () {
      final status = TerminalStatus()
        ..applyPane(TmuxPaneId('%1'), report('state=done'))
        ..applyPane(TmuxPaneId('%2'), report('state=error'));
      status.retainPanes([TmuxPaneId('%2')]);
      expect(status.state, ProgramState.error);
      status.clearPanes();
      expect(status.state, isNull);
    });
  });

  group('TerminalSession', () {
    final ssh = Spi(
      name: 'ssh',
      id: 'ssh',
      ssh: const SshCredential(ip: '10.0.0.1'),
    );

    test('reads what the shell reports and answers the query', () async {
      final session = TerminalSession(source: ServerSource(ssh));
      final shell = _FakeShell();
      session.bindForeground(shell);

      shell.emit(
        '\x1b]7501;?\x1b\\'
        '\x1b]7501;state=blocked:kind=auth:id=a\x1b\\'
        '\x1b]7501;state=done:id=b\x07',
      );
      await flushed();

      expect(session.status.state, ProgramState.blocked);
      expect(utf8.decode(shell.written), '\x1b]7501;?\x1b\\');

      // The shell's next prompt: the program that was blocked has exited.
      shell.emit('\x1b]133;A\x07');
      await flushed();
      expect(session.status.state, ProgramState.done);
      session.dispose();
    });

    test('the shell exiting drops what only lasts while it runs', () async {
      final session = TerminalSession(source: ServerSource(ssh));
      final shell = _FakeShell();
      session.bindForeground(shell);
      shell.emit('\x1b]7501;state=working\x07\x1b]9;4;2\x07');
      await flushed();
      expect(session.status.state, ProgramState.error);

      shell.finish();
      await flushed();
      expect(session.status.shell.records, isEmpty);
      expect(session.status.state, ProgramState.error);
      session.dispose();
    });

    test('a new shell starts without the old one\'s running programs', () async {
      final session = TerminalSession(source: ServerSource(ssh));
      final first = _FakeShell();
      session.bindForeground(first);
      first.emit('\x1b]7501;state=working\x07\x1b]7501;state=done:id=x\x07');
      await flushed();

      session.unbindForeground();
      session.bindForeground(_FakeShell());
      expect(session.status.state, ProgramState.done);
      session.dispose();
    });
  });
}
