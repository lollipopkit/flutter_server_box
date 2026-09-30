import 'package:server_box/data/ssh/tmux/tmux_ids.dart';
import 'package:server_box/data/ssh/tmux/tmux_launch_plan.dart';
import 'package:server_box/data/ssh/tmux/tmux_restore_state.dart';
import 'package:server_box/data/ssh/tmux/tmux_session.dart';
import 'package:server_box/data/ssh/tmux/tmux_session_info.dart';
import 'package:server_box/data/ssh/tmux/tmux_window_info.dart';
import 'package:test/test.dart';

void main() {
  group('buildRestoredTmuxLaunchPlan', () {
    test('builds attach command for existing restored session', () {
      final plan = buildRestoredTmuxLaunchPlan(
        const TmuxRestoreState(sessionName: 'main', windowIndex: 2),
        [
          TmuxSessionInfo(
            id: TmuxSessionId(r'$0'),
            name: 'main',
            windows: 3,
            attached: true,
          ),
        ],
        windows: const [
          TmuxWindowInfo(index: 2, name: 'shell', active: true, panes: 1),
        ],
      );

      expect(plan.shouldLaunchTmux, isTrue);
      expect(plan.command, "'tmux' -u -CC attach-session -t '\$0:2'");
      expect(plan.sessionName, 'main');
      expect(plan.windowIndex, 2);
    });

    test('returns none when restored session no longer exists', () {
      final plan = buildRestoredTmuxLaunchPlan(
        const TmuxRestoreState(sessionName: 'ghost'),
        [
          TmuxSessionInfo(
            id: TmuxSessionId(r'$0'),
            name: 'main',
            windows: 1,
            attached: false,
          ),
        ],
        windows: const [],
      );

      expect(plan.shouldLaunchTmux, isFalse);
      expect(plan.command, isNull);
    });

    test('falls back to the session when restored window is gone', () {
      final plan = buildRestoredTmuxLaunchPlan(
        const TmuxRestoreState(sessionName: 'main', windowIndex: 4),
        [
          TmuxSessionInfo(
            id: TmuxSessionId(r'$0'),
            name: 'main',
            windows: 1,
            attached: false,
          ),
        ],
        windows: const [
          TmuxWindowInfo(index: 0, name: 'shell', active: true, panes: 1),
        ],
      );

      expect(plan.command, "'tmux' -u -CC attach-session -t '\$0'");
      expect(plan.windowIndex, isNull);
    });
  });

  group('selectAutoTmuxSession', () {
    test('prefers the default session name when it exists', () {
      final selected = selectAutoTmuxSession([
        TmuxSessionInfo(
          id: TmuxSessionId(r'$0'),
          name: 'main',
          windows: 1,
          attached: true,
        ),
        TmuxSessionInfo(
          id: TmuxSessionId(r'$1'),
          name: 'server_box',
          windows: 2,
          attached: false,
        ),
      ], defaultSessionName: 'server_box');

      expect(selected?.id, TmuxSessionId(r'$1'));
      expect(selected?.name, 'server_box');
    });

    test('prefers an attached session when the default name is absent', () {
      final selected = selectAutoTmuxSession([
        TmuxSessionInfo(
          id: TmuxSessionId(r'$0'),
          name: 'main',
          windows: 1,
          attached: false,
        ),
        TmuxSessionInfo(
          id: TmuxSessionId(r'$1'),
          name: 'work',
          windows: 1,
          attached: true,
        ),
      ], defaultSessionName: 'server_box');

      expect(selected?.id, TmuxSessionId(r'$1'));
      expect(selected?.attached, isTrue);
    });

    test('falls back to the first session when none are attached', () {
      final selected = selectAutoTmuxSession([
        TmuxSessionInfo(
          id: TmuxSessionId(r'$0'),
          name: 'main',
          windows: 1,
          attached: false,
        ),
        TmuxSessionInfo(
          id: TmuxSessionId(r'$1'),
          name: 'work',
          windows: 1,
          attached: false,
        ),
      ], defaultSessionName: 'server_box');

      expect(selected?.id, TmuxSessionId(r'$0'));
    });

    test('returns null when there are no sessions', () {
      expect(
        selectAutoTmuxSession(const [], defaultSessionName: 'server_box'),
        isNull,
      );
    });
  });

  group('buildAutoTmuxLaunchPlan', () {
    test('attaches to the default session when it exists', () {
      final plan = buildAutoTmuxLaunchPlan([
        TmuxSessionInfo(
          id: TmuxSessionId(r'$0'),
          name: 'main',
          windows: 1,
          attached: true,
        ),
        TmuxSessionInfo(
          id: TmuxSessionId(r'$1'),
          name: 'server_box',
          windows: 2,
          attached: false,
        ),
      ], defaultSessionName: 'server_box');

      expect(plan.shouldLaunchTmux, isTrue);
      expect(plan.command, "'tmux' -u -CC attach-session -t '\$1'");
      expect(plan.sessionName, 'server_box');
      expect(plan.sessionId, TmuxSessionId(r'$1'));
    });

    test('attaches to an attached session when the default name is absent', () {
      final plan = buildAutoTmuxLaunchPlan([
        TmuxSessionInfo(
          id: TmuxSessionId(r'$0'),
          name: 'main',
          windows: 1,
          attached: false,
        ),
        TmuxSessionInfo(
          id: TmuxSessionId(r'$1'),
          name: 'work',
          windows: 1,
          attached: true,
        ),
      ], defaultSessionName: 'server_box');

      expect(plan.shouldLaunchTmux, isTrue);
      expect(plan.command, "'tmux' -u -CC attach-session -t '\$1'");
      expect(plan.sessionName, 'work');
    });

    test('attaches to the first session when none are attached', () {
      final plan = buildAutoTmuxLaunchPlan([
        TmuxSessionInfo(
          id: TmuxSessionId(r'$0'),
          name: 'main',
          windows: 1,
          attached: false,
        ),
        TmuxSessionInfo(
          id: TmuxSessionId(r'$1'),
          name: 'work',
          windows: 1,
          attached: false,
        ),
      ], defaultSessionName: 'server_box');

      expect(plan.shouldLaunchTmux, isTrue);
      expect(plan.command, "'tmux' -u -CC attach-session -t '\$0'");
      expect(plan.sessionName, 'main');
    });

    test('creates the default session when no sessions exist', () {
      final plan = buildAutoTmuxLaunchPlan(
        const [],
        defaultSessionName: 'server_box',
      );

      expect(plan.shouldLaunchTmux, isTrue);
      expect(plan.command, "'tmux' -u -CC new-session -A -s 'server_box'");
      expect(plan.sessionName, 'server_box');
      expect(plan.sessionId, isNull);
    });
  });

  group('buildChosenTmuxLaunchPlan', () {
    test('uses attach-session for existing session choice', () {
      final plan = buildChosenTmuxLaunchPlan(
        const TmuxAttachExisting(sessionName: 'dev'),
      );

      expect(plan.command, "'tmux' -u -CC attach-session -t 'dev'");
      expect(plan.sessionName, 'dev');
      expect(plan.windowIndex, isNull);
    });

    test('uses stable session ids when discovery provided one', () {
      final plan = buildChosenTmuxLaunchPlan(
        TmuxAttachExisting(
          sessionName: 'main|special',
          sessionId: TmuxSessionId(r'$3'),
        ),
      );

      expect(plan.command, "'tmux' -u -CC attach-session -t '\$3'");
      expect(plan.sessionName, 'main|special');
      expect(plan.sessionId, TmuxSessionId(r'$3'));
    });

    test('uses new-session -A for auto/new session choice', () {
      final plan = buildChosenTmuxLaunchPlan(
        const TmuxAttachNew(sessionName: 'server_box'),
      );

      expect(plan.command, "'tmux' -u -CC new-session -A -s 'server_box'");
      expect(plan.sessionName, 'server_box');
      expect(plan.windowIndex, isNull);
    });

    test('uses custom tmux binary path', () {
      const tmuxBin = '/home/linuxbrew/.linuxbrew/bin/tmux';
      final plan = buildChosenTmuxLaunchPlan(
        const TmuxAttachExisting(sessionName: 'codex', windowIndex: 0),
        tmuxBin: tmuxBin,
      );

      expect(plan.command, "'$tmuxBin' -u -CC attach-session -t 'codex:0'");
      expect(plan.sessionName, 'codex');
      expect(plan.windowIndex, 0);
    });
  });
}
