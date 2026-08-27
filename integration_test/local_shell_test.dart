import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:fl_lib/fl_lib.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:server_box/core/utils/local_shell.dart';
import 'package:server_box/data/model/server/shell_backend.dart';
import 'package:server_box/data/res/build_data.dart';
import 'package:server_box/data/res/misc.dart';

/// What `flutter test` cannot answer.
///
/// [LocalShellBackend] is FFI over a plugin, and the unit suite runs under
/// `flutter_tester`, which loads no plugins — so nothing there has ever
/// spawned a shell. These run inside a real app, which is the only place the
/// question "does a terminal on this machine actually work" can be asked.
/// Why these cannot run in this build, or null when they can.
///
/// Derived from what the app itself claims rather than re-deciding it here, so
/// the suite means "wherever a local shell is offered, it works" — and cannot
/// drift from the thing it is checking.
///
/// The App Store build is sandboxed and claims nothing: a sandboxed process
/// cannot open a pseudo-terminal's slave device. Measured — `Process.run`
/// succeeds, the `forkpty` child exits 255 before it can exec, and neither a
/// home-relative-path nor a `/dev/` exception changes it. Run these against
/// the DMG configuration, which is signed without the sandbox.
String? get _cannotRun {
  if (LocalShellBackend.isSupported) return null;
  return 'this build offers no local shell'
      '${Platform.isMacOS && LocalShellBackend.isSandboxed ? ' — it is sandboxed, so it cannot host a pseudo-terminal' : ''}';
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  // What the app does before anything opens a shell. `LocalShellBackend`
  // starts one in the app's own directory on Android, and that directory is
  // decided here — a test that skips it is testing a state the app is never in.
  setUpAll(() => Paths.init(BuildData.name, bakName: Miscs.bakFileName));

  String markerCommand(String suffix, {String? onlyIf}) {
    if (Platform.isWindows) {
      final condition = onlyIf == null ? '' : '$onlyIf && ';
      return 'set "SBM_MARK_A=SBM_"\r'
          'set "SBM_MARK_B=$suffix"\r'
          '$condition'
          'echo %SBM_MARK_A%%SBM_MARK_B%\r';
    }
    final condition = onlyIf == null ? '' : '$onlyIf && ';
    return '${condition}echo "SBM_""$suffix"\n';
  }

  /// Reads until [marker] shows up, or gives up.
  ///
  /// The commands below are written so that only the *output* can contain the
  /// marker: a pseudo-terminal echoes what is typed, and zsh echoes it more
  /// than once — raw, then redrawn with highlighting — so counting occurrences
  /// is not a way to tell input from output. Splitting the marker in the
  /// source (`"SBM_" "ALIVE"`) is.
  Future<String> readUntil(
    ShellSession shell,
    String marker, {
    int occurrences = 1,
  }) async {
    final seen = StringBuffer();
    final done = Completer<String>();
    final sub = shell.stdout!.listen((chunk) {
      seen.write(utf8.decode(chunk, allowMalformed: true));
      if (marker.allMatches(seen.toString()).length >= occurrences &&
          !done.isCompleted) {
        done.complete(seen.toString());
      }
    });
    try {
      return await done.future.timeout(
        const Duration(seconds: 20),
        onTimeout: () => throw TimeoutException(
          'never saw "$marker" $occurrences time(s); got: $seen',
        ),
      );
    } finally {
      await sub.cancel();
    }
  }

  testWidgets('a shell on this machine runs a command and answers', (_) async {
    final backend = LocalShellBackend();
    addTearDown(backend.close);

    final shell = await backend.openShell(width: 80, height: 24);
    shell.write(utf8.encode(markerCommand('ALIVE')));

    final out = await readUntil(shell, 'SBM_ALIVE');
    expect(out, contains('SBM_ALIVE'));
  }, skip: _cannotRun != null);

  testWidgets('it starts in the home directory, not wherever the app was '
      'launched from', (_) async {
    // Not `Platform.environment['HOME']`: an Android app has none, and the
    // answer there is the app's own directory — the only place it can write.
    final home = LocalShellBackend.homeDir;
    expect(home, isNotNull, reason: 'nowhere to start');

    final backend = LocalShellBackend();
    addTearDown(backend.close);

    final shell = await backend.openShell(width: 80, height: 24);
    // A marker of its own rather than reading the prompt: what a prompt looks
    // like is the user's business, and `$` is not even zsh's.
    if (Platform.isWindows) {
      shell.write(
        utf8.encode(
          'set "SBM_MARK_A=SBM_"\r'
          'set "SBM_MARK_B=PWD:"\r'
          'echo %SBM_MARK_A%%SBM_MARK_B%%CD%\r',
        ),
      );
    } else {
      shell.write(utf8.encode('echo "SBM_""PWD:\$PWD"\n'));
    }

    final out = await readUntil(shell, 'SBM_PWD:');
    expect(
      out,
      contains('SBM_PWD:$home'),
      reason:
          'a shell that merely inherited the app\'s working directory '
          'would open at / — under Finder on macOS, and always on Android',
    );
  }, skip: _cannotRun != null);

  testWidgets('it can read where it starts', (_) async {
    // A child process inherits whatever confines the app, so on macOS this is
    // the check that the terminal is in the user's files rather than a
    // container beside them. On Android it is the check that `HOME` was
    // exported at all — without it `$HOME` is empty and `ls` reads `/`.
    final backend = LocalShellBackend();
    addTearDown(backend.close);

    final shell = await backend.openShell(width: 80, height: 24);
    shell.write(
      utf8.encode(
        markerCommand(
          'HOME_OK',
          onlyIf: Platform.isWindows ? 'dir . >nul' : 'ls "\$HOME" >/dev/null',
        ),
      ),
    );

    final out = await readUntil(shell, 'SBM_HOME_OK');
    expect(
      out,
      contains('SBM_HOME_OK'),
      reason: 'the shell could not list the home directory',
    );
  }, skip: _cannotRun != null);

  testWidgets('a command run beside the shell reports what it printed', (
    _,
  ) async {
    final backend = LocalShellBackend();
    addTearDown(backend.close);

    final session = await backend.execute(
      'echo SBM_EXEC_OK',
      width: 80,
      height: 24,
    );
    // No echo here: nothing was typed, the command was the argument.
    final out = await readUntil(session, 'SBM_EXEC_OK');
    expect(out, contains('SBM_EXEC_OK'));
    await session.done;
  }, skip: _cannotRun != null);

  testWidgets('closing the backend ends the shell', (_) async {
    final backend = LocalShellBackend();
    final shell = await backend.openShell(width: 80, height: 24);
    shell.write(utf8.encode(markerCommand('ALIVE')));
    await readUntil(shell, 'SBM_ALIVE');

    backend.close();

    await shell.done.timeout(
      const Duration(seconds: 10),
      onTimeout: () => fail('the shell outlived the backend that opened it'),
    );
  }, skip: _cannotRun != null);
}
