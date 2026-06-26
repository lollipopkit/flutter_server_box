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
        "tmux attach-session -t 'main'",
      );
    });

    test('attachSessionWindow builds correct command', () {
      expect(
        TmuxCommandBuilder.attachSessionWindow('main', 2),
        "tmux attach-session -t 'main:2'",
      );
    });

    test('commands support custom tmux binary path', () {
      const tmuxBin = '/home/linuxbrew/.linuxbrew/bin/tmux';
      expect(
        TmuxCommandBuilder.attachSession('main', tmuxBin: tmuxBin),
        "$tmuxBin attach-session -t 'main'",
      );
      expect(
        TmuxCommandBuilder.attachSessionWindow('main', 2, tmuxBin: tmuxBin),
        "$tmuxBin attach-session -t 'main:2'",
      );
      expect(
        TmuxCommandBuilder.newSessionOrAttach('server_box', tmuxBin: tmuxBin),
        "$tmuxBin new-session -A -s 'server_box'",
      );
    });

    test('newSession builds correct command', () {
      expect(TmuxCommandBuilder.newSession('dev'), "tmux new-session -s 'dev'");
    });

    test('newSessionOrAttach builds correct command', () {
      expect(
        TmuxCommandBuilder.newSessionOrAttach('server_box'),
        "tmux new-session -A -s 'server_box'",
      );
    });

    test('killSession builds correct command', () {
      expect(
        TmuxCommandBuilder.killSession('old'),
        "tmux kill-session -t 'old'",
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
        'tmux list-clients -F '
        '"#{client_tty}|#{client_session}|#{window_index}|#{client_activity}"',
      );
    });

    test('switchClient targets a specific client tty', () {
      expect(
        TmuxCommandBuilder.switchClient('/dev/pts/3', 'main:2'),
        "tmux switch-client -c '/dev/pts/3' -t 'main:2'",
      );
    });

    test('commands include locale only when lang is explicit', () {
      expect(
        TmuxCommandBuilder.attachSession('main', lang: 'C.UTF-8'),
        "env LANG='C.UTF-8' LC_CTYPE='C.UTF-8' LC_ALL='C.UTF-8' tmux attach-session -t 'main'",
      );
      expect(TmuxCommandBuilder.tmuxPrefix(lang: ''), 'tmux');
    });

    test('checkTmux includes multiple paths', () {
      expect(TmuxCommandBuilder.findTmux, contains('command -v tmux'));
    });

    test('attachSession handles special characters', () {
      expect(
        TmuxCommandBuilder.attachSession('my session'),
        "tmux attach-session -t 'my session'",
      );
    });

    test('newSession handles special characters in name', () {
      expect(
        TmuxCommandBuilder.newSession("user's-work"),
        "tmux new-session -s 'user'\\''s-work'",
      );
    });
  });
}
