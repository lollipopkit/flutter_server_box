import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/core/utils/ssh_exec.dart';
import 'package:server_box/data/model/container/type.dart';
import 'package:server_box/data/model/server/server_exec.dart';
import 'package:server_box/data/provider/container.dart';

/// Records what it was asked to run instead of running it.
class _RecordingExec implements ServerExec {
  String? script;
  String? entry;
  String? stdin;

  ExecResult result = const ExecResult(exitCode: 0, stdout: '', stderr: '');

  @override
  Future<ExecResult> run(
    String script, {
    String? entry,
    Map<String, String>? env,
    String? stdin,
    OnExecOutput? onStdout,
    OnExecOutput? onStderr,
    Future<void>? cancel,
  }) async {
    this.script = script;
    this.entry = entry;
    this.stdin = stdin;
    if (result.stdout.isNotEmpty) onStdout?.call(result.stdout);
    if (result.stderr.isNotEmpty) onStderr?.call(result.stderr);
    return result;
  }
}

void main() {
  group('collectSshExecOutput', () {
    test(
      'accepts streams that close before the command exit arrives',
      () async {
        final stdout = StreamController<List<int>>();
        final stderr = StreamController<List<int>>();
        final commandDone = Completer<void>();
        final collecting = collectSshExecOutput(
          stdout: stdout.stream,
          stderr: stderr.stream,
          commandDone: commandDone.future,
          drainTimeout: const Duration(milliseconds: 20),
        );

        stdout.add(utf8.encode('container json'));
        await stdout.close();
        await stderr.close();
        commandDone.complete();

        final result = await collecting;
        expect(result.stdout, 'container json');
        expect(result.stderr, isEmpty);
        expect(result.outputIncomplete, isFalse);
      },
    );

    test('still reports a stream held open after command exit', () async {
      final stdout = StreamController<List<int>>();
      final stderr = StreamController<List<int>>();
      final commandDone = Completer<void>();
      final collecting = collectSshExecOutput(
        stdout: stdout.stream,
        stderr: stderr.stream,
        commandDone: commandDone.future,
        drainTimeout: const Duration(milliseconds: 20),
      );

      stdout.add(utf8.encode('partial output'));
      commandDone.complete();

      final result = await collecting;
      expect(result.stdout, 'partial output');
      expect(result.outputIncomplete, isTrue);

      await stdout.close();
      await stderr.close();
    });

    test('preserves output received before a stream error', () async {
      final stdout = StreamController<List<int>>();
      final stderr = StreamController<List<int>>();
      final commandDone = Completer<void>();
      final error = StateError('stdout connection lost');
      final collecting = collectSshExecOutput(
        stdout: stdout.stream,
        stderr: stderr.stream,
        commandDone: commandDone.future,
        drainTimeout: const Duration(milliseconds: 20),
      );

      stdout
        ..add(utf8.encode('partial container json'))
        ..addError(error);
      commandDone.complete();
      await stderr.close();

      final result = await collecting;
      expect(result.stdout, 'partial container json');
      expect(result.streamError, same(error));
      expect(result.outputIncomplete, isFalse);

      await stdout.close();
    });
  });

  group('ExecResult', () {
    test('accepts output when the SSH server omits a clean exit status', () {
      const result = ExecResult(
        exitCode: null,
        stdout: 'container output',
        stderr: '',
      );

      expect(result.succeeded, isTrue);
    });

    test('rejects a missing exit status when stderr reports a failure', () {
      const result = ExecResult(
        exitCode: null,
        stdout: '',
        stderr: 'permission denied',
      );

      expect(result.succeeded, isFalse);
    });

    test('rejects a command whose output stream failed', () {
      final result = ExecResult(
        exitCode: 0,
        stdout: 'partial output',
        stderr: '',
        streamError: StateError('connection lost'),
      );

      expect(result.succeeded, isFalse);
    });
  });

  group('runWithSudo', () {
    test('the password goes to stdin, never into the command', () async {
      final exec = _RecordingExec();
      await exec.runWithSudo('sudo -S docker ps', password: 'hunter2');

      expect(exec.stdin, 'hunter2\n');
      expect(exec.script, isNot(contains('hunter2')));
    });

    test('a password with no newline still ends the line sudo reads', () async {
      final exec = _RecordingExec();
      await exec.runWithSudo('sudo -S id', password: 'pw');
      expect(exec.stdin, endsWith('\n'));
    });

    test('no password means no input at all', () async {
      final exec = _RecordingExec();
      await exec.runWithSudo('sudo -S id');
      expect(exec.stdin, isNull);
    });

    test('a rejected password is reported as exit code 2', () async {
      final exec = _RecordingExec()
        ..result = const ExecResult(
          exitCode: 1,
          stdout: '',
          stderr: 'Sorry, try again.',
        );
      final result = await exec.runWithSudo('sudo -S id', password: 'wrong');
      expect(result.exitCode, 2);
    });

    test('sudo asked for a password it was never given', () async {
      // What the power buttons rely on to know they have to prompt: the script
      // reaches for `sudo -S`, gets EOF, and says so. Any other non-zero exit
      // means the command itself failed and a password would not help.
      final exec = _RecordingExec()
        ..result = const ExecResult(
          exitCode: 1,
          stdout: '',
          stderr: 'sudo: a password is required',
        );
      final result = await exec.runWithSudo('sudo -S shutdown -h now');
      expect(result.exitCode, kSudoPasswordRejected);
      expect(exec.stdin, isNull);
    });

    test('an ordinary failure keeps its own exit code', () async {
      final exec = _RecordingExec()
        ..result = const ExecResult(
          exitCode: 127,
          stdout: '',
          stderr: 'docker: not found',
        );
      final result = await exec.runWithSudo('sudo -S docker ps', password: 'p');
      expect(result.exitCode, 127);
    });
  });

  group('buildContainerRuntimeCommand', () {
    test('sudo carries no credential of its own', () {
      // `sudo -S` reads the password from stdin, which is why there is nowhere
      // in this string for one to be — not the agent's audit log, not the
      // machine's process list.
      final command = buildContainerRuntimeCommand(
        command: 'docker ps',
        type: ContainerType.docker,
        sudo: true,
      );
      expect(command, startsWith('sudo -S env '));
      expect(command, isNot(contains('base64')));
      expect(command, isNot(contains('echo')));
    });
  });
}
