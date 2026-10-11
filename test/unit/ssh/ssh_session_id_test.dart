import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/core/utils/ssh_exec.dart';

/// [SshSessionId.wrap] is handed to whatever the account's login shell is.
/// Run here by the shells this machine has, as sshd would: `<shell> -c`, with
/// `SHELL` set to it.
void main() {
  // Quotes of both kinds, backslashes, an arithmetic expansion and a newline:
  // what a single-quoted wrapper has to carry through unchanged.
  const script =
      "printf '%s|' \"a'b\" 'c\\\\d' \"\$((1+2))\" '\\0047'\n"
      "echo 'line2 \\n' done";

  // The ones the wrapper has to work in; csh is the one it may not.
  const required = ['sh', 'bash', 'zsh', 'fish', 'dash'];
  const shells = [...required, 'csh', 'tcsh'];

  String? find(String name) {
    for (final dir in ['/bin', '/usr/bin', '/usr/local/bin', '/opt/homebrew/bin']) {
      final path = '$dir/$name';
      if (File(path).existsSync()) return path;
    }
    return null;
  }

  for (final name in shells) {
    final shell = find(name);
    test(
      'in $name, runs the command as before after printing its session',
      () async {
        final env = {'SHELL': shell!};
        final plain = await Process.run(shell, ['-c', script], environment: env);
        final wrapped = await Process.run(shell, [
          '-c',
          SshSessionId.wrap(script, 'n0nce'),
        ], environment: env);
        final marker = SshSessionId.marker.firstMatch(wrapped.stderr as String);
        if (marker == null) {
          // Refused, and so nothing of it ran: `SshExec` runs it plainly.
          expect(required, isNot(contains(name)));
          expect(wrapped.stdout, isEmpty);
          return;
        }
        expect(wrapped.stdout, plain.stdout);
        expect(wrapped.exitCode, plain.exitCode);
        expect(marker.start, 0, reason: 'printed before anything else');
      },
      skip: shell == null ? '$name is not installed' : null,
    );
  }

  test('keeps the exit code', () async {
    final r = await Process.run('/bin/sh', [
      '-c',
      SshSessionId.wrap('exit 7', 'n0nce'),
    ], environment: {'SHELL': '/bin/sh'});
    expect(r.exitCode, 7);
  });

  test('hands the run its nonce', () async {
    final r = await Process.run('/bin/sh', [
      '-c',
      SshSessionId.wrap('echo "\$${SshSessionId.envName}"', 'n0nce'),
    ], environment: {'SHELL': '/bin/sh'});
    expect(r.stdout, 'n0nce\n');
  });

  // These go to the login shell as one command too, sudo in front.
  for (final name in ['sh', 'fish']) {
    final shell = find(name);
    test(
      'in $name, the kill is one command',
      () async {
        for (final kill in [
          SshSessionId.kill(123),
          SshSessionId.owns(123, 'n0nce'),
        ]) {
          // `printf` in place of `sh`: what the login shell hands on, unrun.
          final r = await Process.run(shell!, [
            '-c',
            kill.replaceFirst('sh -c ', 'printf %s '),
          ]);
          expect(r.exitCode, 0, reason: '${r.stderr}');
          final program = r.stdout as String;
          // What `sh -c` then reads must parse.
          final parsed = await Process.run('/bin/sh', ['-n', '-c', program]);
          expect(parsed.exitCode, 0, reason: '${parsed.stderr}');
        }
      },
      skip: shell == null ? '$name is not installed' : null,
    );
  }
}
