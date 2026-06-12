import 'package:server_box/data/ssh/tmux/tmux_restore_state.dart';
import 'package:test/test.dart';

void main() {
  group('resolveTmuxRestoreState', () {
    test('prefers args state over restorable state', () {
      final state = resolveTmuxRestoreState(
        argsSession: 'restored-from-tab',
        argsWindow: 3,
        restorableSession: 'stale-page-state',
        restorableWindow: 1,
      );

      expect(state.sessionName, 'restored-from-tab');
      expect(state.windowIndex, 3);
      expect(state.hasSession, isTrue);
    });

    test('falls back to restorable state when args are absent', () {
      final state = resolveTmuxRestoreState(
        restorableSession: 'page-bucket',
        restorableWindow: 2,
      );

      expect(state.sessionName, 'page-bucket');
      expect(state.windowIndex, 2);
      expect(state.hasSession, isTrue);
    });

    test('drops window when no session exists', () {
      final state = resolveTmuxRestoreState(restorableWindow: 7);

      expect(state.sessionName, isNull);
      expect(state.windowIndex, isNull);
      expect(state.hasSession, isFalse);
    });
  });
}
