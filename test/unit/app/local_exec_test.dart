import 'dart:io';

import 'package:fl_tty/fl_tty.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/data/model/server/server_exec.dart';

import '../../helpers/rust_lib_helper.dart';

/// `runWithSudo` is ServerBox's, over fl_tty's [ProcessExec]; the rest of
/// ProcessExec is tested in fl_tty.
void main() {
  setUpAll(initRustLibForTest);

  const exec = ProcessExec();
  final onPosix = !Platform.isWindows;

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
