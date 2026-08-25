import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/core/utils/local_exec.dart';
import 'package:server_box/core/utils/shell_quote.dart';
import 'package:server_box/data/model/server/server_exec.dart';

/// Unlike the terminal's backend, this one is `dart:io` and nothing else, so
/// it can be exercised here rather than only inside a real app.
void main() {
  const exec = ProcessExec();

  // Nothing below has a Windows spelling, and the ones that matter are checked
  // on the platforms that run CI for this.
  final onPosix = !Platform.isWindows;

  group('running a command', () {
    test(
      'a missing rootfs fails closed instead of using the host shell',
      () async {
        await expectLater(
          const ProcessExec(inRootfs: true).run('echo must-not-run'),
          throwsA(isA<StateError>()),
        );
      },
    );

    test('its output and exit code come back', () async {
      final result = await exec.run('echo hello');

      expect(result.stdout.trim(), 'hello');
      expect(result.exitCode, 0);
      expect(result.succeeded, isTrue);
    }, skip: !onPosix);

    test('a failure is reported as one', () async {
      final result = await exec.run('exit 3');

      expect(result.exitCode, 3);
      expect(result.succeeded, isFalse);
    }, skip: !onPosix);

    test('the two streams stay apart, unlike a terminal', () async {
      // What `runWithSudo` depends on: it watches stderr for a rejected
      // password, and a pty would have merged that into the command's output.
      final result = await exec.run('echo out; echo err >&2');

      expect(result.stdout.trim(), 'out');
      expect(result.stderr.trim(), 'err');
    }, skip: !onPosix);

    test('what it printed arrives as it goes, not only at the end', () async {
      final chunks = <String>[];
      await exec.run('echo a; echo b', onStdout: chunks.add);

      expect(chunks.join(), contains('a'));
      expect(chunks.join(), contains('b'));
    }, skip: !onPosix);
  });

  group('stdin', () {
    test(
      'is left free for the caller when the script is the command',
      () async {
        // This is what lets a sudo password go somewhere a process list cannot
        // read it. `cat` proves the channel is the caller's.
        final result = await exec.run('cat', stdin: 'secret\n');

        expect(result.stdout, 'secret\n');
      },
      skip: !onPosix,
    );

    test('carries the script when there is an entry to read it', () async {
      final result = await exec.run('echo from-stdin', entry: 'sh');

      expect(result.stdout.trim(), 'from-stdin');
    }, skip: !onPosix);
  });

  group('cancelling', () {
    test('stops waiting, and says the exit code is not meaningful', () async {
      final cancel = Completer<void>();
      final running = exec.run('sleep 30', cancel: cancel.future);

      // Long enough for the process to exist, short enough that a test that
      // regresses to waiting for `sleep` fails rather than hangs.
      await Future<void>.delayed(const Duration(milliseconds: 300));
      cancel.complete();

      final result = await running.timeout(
        const Duration(seconds: 5),
        onTimeout: () => fail('cancelling did not end the command'),
      );
      expect(result.exitCode, isNull);
    }, skip: !onPosix);

    test('a signal that never comes does not hold the result up', () async {
      final never = Completer<void>();
      final result = await exec
          .run('echo done', cancel: never.future)
          .timeout(
            const Duration(seconds: 5),
            onTimeout: () => fail('an uncompleted cancel blocked the result'),
          );

      expect(result.stdout.trim(), 'done');
      expect(result.exitCode, 0);
    }, skip: !onPosix);

    test('an inherited output pipe does not hold the result up', () async {
      final result = await exec
          .run('(sleep 30) & printf done')
          .timeout(
            const Duration(seconds: 5),
            onTimeout: () => fail('a descendant kept the output pipe open'),
          );

      expect(result.stdout, 'done');
      expect(result.exitCode, 0);
    }, skip: !onPosix);

    test('also stops background descendants', () async {
      final temp = await Directory.systemTemp.createTemp(
        'server-box-exec-tree-',
      );
      final marker = File('${temp.path}/survived');
      final cancel = Completer<void>();
      final command = Platform.isWindows
          ? _windowsDescendantCommand(marker.path)
          : '(sleep 2; printf alive > ${shellSingleQuote(marker.path)}) & sleep 30';

      try {
        final running = exec.run(command, cancel: cancel.future);
        await Future<void>.delayed(const Duration(milliseconds: 300));
        cancel.complete();
        await running.timeout(const Duration(seconds: 5));
        await Future<void>.delayed(const Duration(seconds: 3));
        expect(marker.existsSync(), isFalse);
      } finally {
        await temp.delete(recursive: true);
      }
    });
  });

  group('sudo', () {
    test(
      'a rejected password is told apart from the command failing',
      () async {
        // The extension reads stderr for what sudo says, so a fake that says it
        // exercises the real path.
        final result = await exec.runWithSudo(
          'echo "Sorry, try again." >&2; exit 1',
          password: 'hunter2',
        );

        expect(result.exitCode, kSudoPasswordRejected);
      },
      skip: !onPosix,
    );

    test('an ordinary failure keeps its own exit code', () async {
      final result = await exec.runWithSudo('exit 7', password: 'hunter2');

      expect(result.exitCode, 7);
    }, skip: !onPosix);
  });
}

String _windowsDescendantCommand(String marker) {
  final escaped = marker.replaceAll("'", "''");
  final script =
      "Start-Sleep -Seconds 2; Set-Content -LiteralPath '$escaped' -Value alive";
  final utf16 = <int>[];
  for (final unit in script.codeUnits) {
    utf16
      ..add(unit & 0xff)
      ..add(unit >> 8);
  }
  return 'start "" /B powershell -NoProfile -EncodedCommand ${base64.encode(utf16)} '
      '& ping -n 30 127.0.0.1 >nul';
}
