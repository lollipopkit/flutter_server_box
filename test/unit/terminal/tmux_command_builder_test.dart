import 'dart:io';

import 'package:server_box/data/ssh/tmux/tmux_command_builder.dart';
import 'package:server_box/src/rust/api/tmux.dart' as ffi;
import 'package:test/test.dart';

import '../../helpers/rust_lib_helper.dart';

void main() {
  setUpAll(initRustLibForTest);

  group('TmuxCommandBuilder', () {
    test('attachSession builds correct command', () {
      expect(
        TmuxCommandBuilder.attachSession('main'),
        "'tmux' -u -CC attach-session -t 'main'",
      );
    });

    test('attachSessionWindow builds correct command', () {
      expect(
        TmuxCommandBuilder.attachSessionWindow('main', 2),
        "'tmux' -u -CC attach-session -t 'main:2'",
      );
    });

    test('commands support custom tmux binary path', () {
      const tmuxBin = '/home/linuxbrew/.linuxbrew/bin/tmux';
      expect(
        TmuxCommandBuilder.attachSession('main', tmuxBin: tmuxBin),
        "'$tmuxBin' -u -CC attach-session -t 'main'",
      );
      expect(
        TmuxCommandBuilder.attachSessionWindow('main', 2, tmuxBin: tmuxBin),
        "'$tmuxBin' -u -CC attach-session -t 'main:2'",
      );
      expect(
        TmuxCommandBuilder.newSessionOrAttach('server_box', tmuxBin: tmuxBin),
        "'$tmuxBin' -u -CC new-session -A -s 'server_box'",
      );
    });

    test('newSessionOrAttach builds correct command', () {
      expect(
        TmuxCommandBuilder.newSessionOrAttach('server_box'),
        "'tmux' -u -CC new-session -A -s 'server_box'",
      );
    });

    test('listSessions uses shell-generated tab separators', () {
      const shellTab = "\$(printf '\\t')";
      final command = TmuxCommandBuilder.listSessionsCmd();
      expect(command, contains("'tmux' -u list-sessions"));
      expect(command, contains('"#{session_id}$shellTab#{q:session_name}'));
      expect(
        command,
        contains('#{session_windows}$shellTab#{session_attached}'),
      );
      expect(command, contains(shellTab));
      expect(command.contains('\t'), isFalse);
    });

    test('listSessions output parses against real tmux', () {
      if (Platform.isWindows) {
        markTestSkipped('the real tmux command harness is POSIX-only');
        return;
      }
      try {
        final version = Process.runSync('tmux', ['-V']);
        if (version.exitCode != 0) {
          markTestSkipped('tmux is not installed');
          return;
        }
      } on ProcessException {
        markTestSkipped('tmux is not installed');
        return;
      }

      final shell = _pickPosixShell();
      final tempDir = Directory.systemTemp.createTempSync('sb-list-sessions-');
      final environment = {
        ...Platform.environment,
        'TMUX_TMPDIR': tempDir.path,
        'TMUX': '',
        'TMUX_PANE': '',
        // This is the condition that broke the Android app: an exec shell can
        // have no locale at all, which leaves tmux in the C locale and makes
        // it replace tab separators with underscores unless `-u` is passed.
        'LANG': 'C',
        'LC_ALL': 'C',
        'LC_CTYPE': 'C',
      };
      try {
        final created = Process.runSync('tmux', [
          'new-session',
          '-d',
          '-s',
          'dis|covery',
        ], environment: environment);
        expect(created.exitCode, 0);

        final result = Process.runSync(shell, [
          '-c',
          TmuxCommandBuilder.listSessionsCmd(),
        ], environment: environment);
        expect(result.exitCode, 0);

        final sessions = ffi
            .tmuxParseSessions(output: result.stdout as String)
            .sessions;
        expect(sessions, isNotEmpty);
        expect(sessions.map((session) => session.name), contains('dis|covery'));
      } finally {
        Process.runSync('tmux', ['kill-server'], environment: environment);
        try {
          tempDir.deleteSync(recursive: true);
        } on FileSystemException {
          // tmux can remove its socket directory concurrently with the test.
        }
      }
    });

    test('discovery commands force UTF-8 output', () {
      expect(
        TmuxCommandBuilder.listSessionsCmd(),
        startsWith("'tmux' -u list-sessions"),
      );
      expect(
        TmuxCommandBuilder.listWindows('main'),
        startsWith("'tmux' -u list-windows"),
      );
    });

    test('checkTmux includes multiple paths', () {
      expect(TmuxCommandBuilder.findTmux, contains('command -v tmux'));
    });

    test('attachSession handles special characters', () {
      expect(
        TmuxCommandBuilder.attachSession('my session'),
        "'tmux' -u -CC attach-session -t 'my session'",
      );
    });

    test('newSessionOrAttach handles special characters in name', () {
      expect(
        TmuxCommandBuilder.newSessionOrAttach("user's-work"),
        "'tmux' -u -CC new-session -A -s 'user'\\''s-work'",
      );
    });

    test('tmux binary is escaped as one shell argument', () {
      expect(
        TmuxCommandBuilder.attachSession(
          'main',
          tmuxBin: "/opt/tmux builds/tmux'; echo injected; '",
        ),
        "'/opt/tmux builds/tmux'\\''; echo injected; '\\''' -u -CC attach-session -t 'main'",
      );
    });
  });
}

String _pickPosixShell() {
  final result = Process.runSync('/bin/sh', ['-c', 'command -v dash']);
  if (result.exitCode == 0) {
    final path = (result.stdout as String).trim();
    if (path.isNotEmpty) return path;
  }
  return '/bin/sh';
}
