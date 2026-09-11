import 'dart:collection';

import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/core/utils/privileged_exec.dart';
import 'package:server_box/data/model/server/server_exec.dart';

final class _Call {
  const _Call(this.script, this.entry, this.stdin);

  final String script;
  final String? entry;
  final String? stdin;
}

final class _QueueExec implements ServerExec {
  _QueueExec(List<ExecResult> results) : results = Queue.of(results);

  final Queue<ExecResult> results;
  final calls = <_Call>[];

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
    calls.add(_Call(script, entry, stdin));
    final result = results.removeFirst();
    if (result.stdout.isNotEmpty) onStdout?.call(result.stdout);
    if (result.stderr.isNotEmpty) onStderr?.call(result.stderr);
    return result;
  }
}

void main() {
  test('root sends only the script to sh', () async {
    final exec = _QueueExec([
      const ExecResult(exitCode: 0, stdout: '', stderr: ''),
    ]);

    await PrivilegedExec.run(exec, 'useradd deploy', isRoot: true);

    expect(exec.calls, hasLength(1));
    expect(exec.calls.first.script, 'useradd deploy');
    expect(exec.calls.first.entry, 'sh');
    expect(exec.calls.first.stdin, isNull);
  });

  test('a rejected probe never sends the mutation script', () async {
    final exec = _QueueExec([
      const ExecResult(
        exitCode: 1,
        stdout: '',
        stderr: 'sudo: a password is required',
      ),
    ]);

    final result = await PrivilegedExec.run(
      exec,
      'userdel deploy',
      isRoot: false,
    );

    expect(result.exitCode, kSudoPasswordRejected);
    expect(exec.calls, hasLength(1));
    expect(exec.calls.first.script, "sudo -S -p '' true");
  });

  test('a passwordless sudo probe is followed by sudo -n sh', () async {
    final exec = _QueueExec([
      const ExecResult(exitCode: 0, stdout: '', stderr: ''),
      const ExecResult(exitCode: 0, stdout: '', stderr: ''),
    ]);

    await PrivilegedExec.run(exec, 'usermod deploy', isRoot: false);

    expect(exec.calls, hasLength(2));
    expect(exec.calls.last.script, 'usermod deploy');
    expect(exec.calls.last.entry, 'sudo -n sh');
    expect(exec.calls.last.stdin, isNull);
  });

  test('a supplied password is separate from the script', () async {
    final exec = _QueueExec([
      const ExecResult(exitCode: 0, stdout: '', stderr: ''),
    ]);

    await PrivilegedExec.run(
      exec,
      'useradd deploy',
      isRoot: false,
      password: 'secret',
    );

    expect(exec.calls, hasLength(1));
    expect(exec.calls.first.script, 'useradd deploy');
    expect(exec.calls.first.entry, "sudo -S -p '' sh");
    expect(exec.calls.first.stdin, 'secret\n');
  });
}
