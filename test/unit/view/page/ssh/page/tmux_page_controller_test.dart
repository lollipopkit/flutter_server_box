import 'dart:async';
import 'dart:typed_data';

import 'package:server_box/data/model/server/shell_backend.dart';
import 'package:server_box/data/ssh/tmux/tmux_control_client.dart';
import 'package:server_box/view/page/ssh/page/tmux_page_controller.dart';
import 'package:test/test.dart';

void main() {
  group('TmuxPageController', () {
    test('moves through attach, detach, clear, and dispose phases', () async {
      final shell = _FakeShellSession();
      final client = TmuxControlClient(shell);
      final phases = <TmuxPageLifecyclePhase>[];
      final controller = TmuxPageController(
        onSnapshot: (_) {},
        onPhaseChanged: phases.add,
      );

      controller.attach(client);
      expect(controller.phase, TmuxPageLifecyclePhase.attached);
      expect(controller.client, same(client));

      controller.detach();
      expect(controller.phase, TmuxPageLifecyclePhase.detached);
      expect(controller.client, isNull);

      controller.saveState(sessionName: 'main', windowIndex: 2);
      expect(controller.currentSessionName, 'main');
      expect(controller.currentWindowIndex, 2);

      controller.clear();
      expect(controller.phase, TmuxPageLifecyclePhase.detached);
      expect(controller.currentSessionName, isNull);
      expect(controller.currentWindowIndex, isNull);

      await controller.dispose();
      expect(controller.phase, TmuxPageLifecyclePhase.disposed);
      expect(controller.client, isNull);
      expect(phases.contains(TmuxPageLifecyclePhase.disposed), isFalse);

      shell.close();
    });
  });
}

final class _FakeShellSession implements ShellSession {
  final _stdout = StreamController<Uint8List>.broadcast(sync: true);
  final _done = Completer<void>();

  @override
  Stream<Uint8List>? get stdout => _stdout.stream;

  @override
  Stream<Uint8List>? get stderr => null;

  @override
  Future<void> get done => _done.future;

  @override
  void write(List<int> data) {}

  @override
  void resizeTerminal(int width, int height) {}

  @override
  void close() {
    if (!_done.isCompleted) _done.complete();
    unawaited(_stdout.close());
  }
}
