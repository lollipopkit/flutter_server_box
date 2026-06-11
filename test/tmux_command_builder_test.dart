import 'package:server_box/data/ssh/tmux/tmux_command_builder.dart';
import 'package:test/test.dart';

void main() {
  group('TmuxCommandBuilder', () {
    test('escapeArg wraps in single quotes', () {
      expect(TmuxCommandBuilder.escapeArg('main'), "'main'");
    });

    test('escapeArg escapes single quotes', () {
      expect(TmuxCommandBuilder.escapeArg("it's"), "'it'\\''s'");
    });

    test('attachSession builds correct command', () {
      expect(
        TmuxCommandBuilder.attachSession('main'),
        "env LANG='en_US.UTF-8' LC_CTYPE='en_US.UTF-8' LC_ALL='en_US.UTF-8' tmux attach-session -t 'main'",
      );
    });

    test('attachSessionWindow builds correct command', () {
      expect(
        TmuxCommandBuilder.attachSessionWindow('main', 2),
        "env LANG='en_US.UTF-8' LC_CTYPE='en_US.UTF-8' LC_ALL='en_US.UTF-8' tmux attach-session -t 'main:2'",
      );
    });

    test('commands support custom tmux binary path', () {
      const tmuxBin = '/home/linuxbrew/.linuxbrew/bin/tmux';
      expect(
        TmuxCommandBuilder.attachSession('main', tmuxBin: tmuxBin),
        "env LANG='en_US.UTF-8' LC_CTYPE='en_US.UTF-8' LC_ALL='en_US.UTF-8' $tmuxBin attach-session -t 'main'",
      );
      expect(
        TmuxCommandBuilder.attachSessionWindow('main', 2, tmuxBin: tmuxBin),
        "env LANG='en_US.UTF-8' LC_CTYPE='en_US.UTF-8' LC_ALL='en_US.UTF-8' $tmuxBin attach-session -t 'main:2'",
      );
      expect(
        TmuxCommandBuilder.newSessionOrAttach('server_box', tmuxBin: tmuxBin),
        "env LANG='en_US.UTF-8' LC_CTYPE='en_US.UTF-8' LC_ALL='en_US.UTF-8' $tmuxBin new-session -A -s 'server_box'",
      );
    });

    test('newSession builds correct command', () {
      expect(
        TmuxCommandBuilder.newSession('dev'),
        "env LANG='en_US.UTF-8' LC_CTYPE='en_US.UTF-8' LC_ALL='en_US.UTF-8' tmux new-session -s 'dev'",
      );
    });

    test('newSessionOrAttach builds correct command', () {
      expect(
        TmuxCommandBuilder.newSessionOrAttach('server_box'),
        "env LANG='en_US.UTF-8' LC_CTYPE='en_US.UTF-8' LC_ALL='en_US.UTF-8' tmux new-session -A -s 'server_box'",
      );
    });

    test('killSession builds correct command', () {
      expect(
        TmuxCommandBuilder.killSession('old'),
        "env LANG='en_US.UTF-8' LC_CTYPE='en_US.UTF-8' LC_ALL='en_US.UTF-8' tmux kill-session -t 'old'",
      );
    });

    test('listSessions is correct format string', () {
      expect(
        TmuxCommandBuilder.listSessionsCmd(),
        contains('tmux list-sessions'),
      );
      expect(TmuxCommandBuilder.listSessionsCmd(), contains('#{session_name}'));
      expect(
        TmuxCommandBuilder.listSessionsCmd(),
        contains('#{session_windows}'),
      );
    });

    test('listClients uses client session and window fields', () {
      expect(
        TmuxCommandBuilder.listClients(),
        "env LANG='en_US.UTF-8' LC_CTYPE='en_US.UTF-8' LC_ALL='en_US.UTF-8' tmux list-clients -F "
        '"#{client_tty}|#{client_session}|#{window_index}|#{client_activity}"',
      );
    });

    test('switchClient targets a specific client tty', () {
      expect(
        TmuxCommandBuilder.switchClient('/dev/pts/3', 'main:2'),
        "env LANG='en_US.UTF-8' LC_CTYPE='en_US.UTF-8' LC_ALL='en_US.UTF-8' tmux switch-client -c '/dev/pts/3' -t 'main:2'",
      );
    });

    test('checkTmux includes multiple paths', () {
      expect(TmuxCommandBuilder.findTmux, contains('command -v tmux'));
    });

    test('attachSession handles special characters', () {
      expect(
        TmuxCommandBuilder.attachSession('my session'),
        "env LANG='en_US.UTF-8' LC_CTYPE='en_US.UTF-8' LC_ALL='en_US.UTF-8' tmux attach-session -t 'my session'",
      );
    });

    test('newSession handles special characters in name', () {
      expect(
        TmuxCommandBuilder.newSession("user's-work"),
        "env LANG='en_US.UTF-8' LC_CTYPE='en_US.UTF-8' LC_ALL='en_US.UTF-8' tmux new-session -s 'user'\\''s-work'",
      );
    });
  });
}
