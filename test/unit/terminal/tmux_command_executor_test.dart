import 'dart:async';

import 'package:server_box/data/ssh/tmux/tmux_command_executor.dart';
import 'package:server_box/data/ssh/tmux/tmux_control_protocol.dart';
import 'package:test/test.dart';

void main() {
  group('TmuxCommandExecutor', () {
    test('writes commands and completes them in FIFO order', () async {
      final written = <String>[];
      final executor = TmuxCommandExecutor(writeCommand: written.add);
      executor.complete(
        const TmuxControlCommandResult(lines: [], error: false),
      );

      final first = executor.run('first');
      final second = executor.run('second');
      expect(written, ['first', 'second']);
      expect(executor.pendingCount, 2);

      executor.complete(
        const TmuxControlCommandResult(lines: ['one'], error: false),
      );
      executor.complete(
        const TmuxControlCommandResult(lines: ['two'], error: false),
      );

      final firstResult = await first;
      final secondResult = await second;
      expect(firstResult.output, 'one');
      expect(secondResult.output, 'two');
      expect(executor.pendingCount, 0);
    });

    test(
      'the first result completes startup without consuming a command',
      () async {
        final executor = TmuxCommandExecutor(writeCommand: (_) {});
        final startup = executor.startup;
        unawaited(executor.run('attach'));

        executor.complete(
          const TmuxControlCommandResult(lines: ['ready'], error: false),
        );

        expect((await startup).output, 'ready');
        expect(executor.pendingCount, 1);
      },
    );

    test('failure fails every pending command', () async {
      final executor = TmuxCommandExecutor(writeCommand: (_) {});
      executor.complete(
        const TmuxControlCommandResult(lines: [], error: false),
      );
      final first = executor.run('first');
      final second = executor.run('second');
      final error = StateError('transport ended');

      executor.fail(error);

      await expectLater(first, throwsA(same(error)));
      await expectLater(second, throwsA(same(error)));
      expect(executor.pendingCount, 0);
    });

    test('closing fails pending commands and rejects new commands', () async {
      final executor = TmuxCommandExecutor(writeCommand: (_) {});
      executor.complete(
        const TmuxControlCommandResult(lines: [], error: false),
      );
      final pending = executor.run('pending');

      executor.close();

      await expectLater(pending, throwsA(isA<StateError>()));
      await expectLater(
        executor.run('after-close'),
        throwsA(isA<StateError>()),
      );
      expect(executor.isClosed, isTrue);
    });
  });
}
