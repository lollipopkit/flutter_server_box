import 'package:server_box/data/ssh/tmux/tmux_launch_plan.dart';
import 'package:server_box/data/ssh/tmux/tmux_restore_state.dart';
import 'package:server_box/data/ssh/tmux/tmux_session.dart';
import 'package:server_box/data/ssh/tmux/tmux_session_info.dart';
import 'package:test/test.dart';

void main() {
  group('buildRestoredTmuxLaunchPlan', () {
    test('builds attach command for existing restored session', () {
      final plan = buildRestoredTmuxLaunchPlan(
        const TmuxRestoreState(sessionName: 'main', windowIndex: 2),
        const [TmuxSessionInfo(name: 'main', windows: 3, attached: true)],
      );

      expect(plan.shouldLaunchTmux, isTrue);
      expect(plan.command, "tmux attach-session -t 'main:2'");
      expect(plan.sessionName, 'main');
      expect(plan.windowIndex, 2);
    });

    test('returns none when restored session no longer exists', () {
      final plan = buildRestoredTmuxLaunchPlan(
        const TmuxRestoreState(sessionName: 'ghost'),
        const [TmuxSessionInfo(name: 'main', windows: 1, attached: false)],
      );

      expect(plan.shouldLaunchTmux, isFalse);
      expect(plan.command, isNull);
    });
  });

  group('buildChosenTmuxLaunchPlan', () {
    test('uses attach-session for existing session choice', () {
      final plan = buildChosenTmuxLaunchPlan(
        const TmuxAttachExisting(sessionName: 'dev'),
      );

      expect(plan.command, "tmux attach-session -t 'dev'");
      expect(plan.sessionName, 'dev');
      expect(plan.windowIndex, isNull);
    });

    test('uses new-session -A for auto/new session choice', () {
      final plan = buildChosenTmuxLaunchPlan(
        const TmuxAttachNew(sessionName: 'server_box'),
      );

      expect(plan.command, "tmux new-session -A -s 'server_box'");
      expect(plan.sessionName, 'server_box');
      expect(plan.windowIndex, isNull);
    });

    test('uses custom tmux binary path', () {
      const tmuxBin = '/home/linuxbrew/.linuxbrew/bin/tmux';
      final plan = buildChosenTmuxLaunchPlan(
        const TmuxAttachExisting(sessionName: 'codex', windowIndex: 0),
        tmuxBin: tmuxBin,
      );

      expect(plan.command, "$tmuxBin attach-session -t 'codex:0'");
      expect(plan.sessionName, 'codex');
      expect(plan.windowIndex, 0);
    });

    test('uses explicit lang when provided', () {
      final plan = buildChosenTmuxLaunchPlan(
        const TmuxAttachExisting(sessionName: 'dev'),
        lang: 'zh_CN.UTF-8',
      );

      expect(
        plan.command,
        "env LANG='zh_CN.UTF-8' LC_CTYPE='zh_CN.UTF-8' LC_ALL='zh_CN.UTF-8' tmux attach-session -t 'dev'",
      );
    });
  });
}
