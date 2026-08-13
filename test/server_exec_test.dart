import 'package:flutter_test/flutter_test.dart';
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
  group('runWithSudo', () {
    test('the password goes to stdin, never into the command', () {
      final exec = _RecordingExec();
      exec.runWithSudo('sudo -S docker ps', password: 'hunter2');

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
