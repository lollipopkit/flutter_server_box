import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/core/extension/ssh_client.dart';

void main() {
  group('SSHExecResult', () {
    test('accepts stderr warnings when the remote command succeeds', () {
      const result = SSHExecResult(
        exitCode: 0,
        stdout: '',
        stderr:
            'Could not chdir to home directory /home/test: No such file or directory',
      );

      expect(result.succeeded, isTrue);
    });

    test('rejects non-zero exit codes', () {
      const failed = SSHExecResult(
        exitCode: 1,
        stdout: '',
        stderr: 'mkdir: Permission denied',
      );

      expect(failed.succeeded, isFalse);
    });

    test('falls back to stderr when the server omits the exit code', () {
      const succeeded = SSHExecResult(
        exitCode: null,
        stdout: '',
        stderr: '',
      );
      const failed = SSHExecResult(
        exitCode: null,
        stdout: '',
        stderr: 'mkdir: Permission denied',
      );

      expect(succeeded.succeeded, isTrue);
      expect(failed.succeeded, isFalse);
    });
  });
}
