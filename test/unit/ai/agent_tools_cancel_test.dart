import 'dart:async';

import 'package:fl_pi_llm_ui/fl_pi_llm_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/core/llm/tools.dart';

void main() {
  group('AgentTools.cancellable', () {
    test('ends on the stop while the command is still running', () async {
      final cancel = LlmCancelToken();
      final command = Completer<String>();
      final call = AgentTools.cancellable(cancel, () => command.future);

      cancel.cancel();
      await expectLater(call, throwsA(isA<LlmException>()));
      expect(command.isCompleted, isFalse);

      // Ending later is nobody's error.
      command.completeError(StateError('channel closed'));
      await pumpEventQueue();
    });

    test('returns the result when the command ends first', () async {
      final cancel = LlmCancelToken();
      final r = await AgentTools.cancellable(cancel, () async => 'done');
      expect(r, 'done');
    });

    test('runs nothing once stopped', () async {
      final cancel = LlmCancelToken()..cancel();
      var ran = false;
      await expectLater(
        AgentTools.cancellable(cancel, () async => ran = true),
        throwsA(isA<LlmException>()),
      );
      expect(ran, isFalse);
    });
  });
}
