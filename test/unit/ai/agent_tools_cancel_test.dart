import 'dart:async';

import 'package:fl_pi_llm_ui/fl_pi_llm_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/core/llm/tools.dart';

void main() {
  group('AgentTools.cancellable', () {
    test('ends on the stop while the command is still running', () async {
      final cancel = LlmCancelToken();
      final command = Completer<String>();
      var stops = 0;
      final call = AgentTools.cancellable(cancel, () async => stops++, () {
        return command.future;
      });

      cancel.cancel();
      await expectLater(call, throwsA(isA<LlmException>()));
      expect(stops, 1);
      expect(command.isCompleted, isFalse);

      // Ending later is nobody's error.
      command.completeError(StateError('channel closed'));
      await pumpEventQueue();
    });

    test('returns the result when the command ends first', () async {
      final cancel = LlmCancelToken();
      var stops = 0;
      final r = await AgentTools.cancellable(
        cancel,
        () async => stops++,
        () async => 'done',
      );
      expect(r, 'done');

      // A stop after it ended must not reach whatever runs next.
      cancel.cancel();
      await pumpEventQueue();
      expect(stops, 0);
    });

    test('runs nothing once stopped', () async {
      final cancel = LlmCancelToken()..cancel();
      var ran = false;
      await expectLater(
        AgentTools.cancellable(cancel, () async {}, () async => ran = true),
        throwsA(isA<LlmException>()),
      );
      expect(ran, isFalse);
    });
  });
}
