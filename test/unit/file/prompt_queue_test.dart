import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/data/model/file/prompt_queue.dart';

/// One question on screen at a time, whatever the transfers are doing.
///
/// The manual check this replaces — "two host-key prompts raised by one
/// transfer queue rather than stack" — cannot be reached through the app at
/// all. Browsing a server to pick the file accepts its key, and picking the
/// destination accepts that one, so by the time a transfer is queued both are
/// known; the fingerprints are then snapshotted into the job, so the worker
/// has nothing left to ask. What the queue defends is the case where a key
/// changed between queuing and connecting, which is the moment the question
/// matters most and the hardest one to stage by hand.
///
/// So it is checked here, where it is exact: the ordering primitive itself.
void main() {
  test('the second question waits for the first to be answered', () {
    // The whole point. Stacked dialogs put one host's fingerprint under
    // another host's text.
    final queue = PromptQueue();
    final order = <String>[];
    final first = Completer<bool>();

    final a = queue.add(() async {
      order.add('a started');
      final answer = await first.future;
      order.add('a answered');
      return answer;
    });
    final b = queue.add(() async {
      order.add('b started');
      return false;
    });

    return Future(() async {
      await pumpEventQueue();
      expect(order, ['a started'], reason: 'b did not wait');

      first.complete(true);
      expect(await a, isTrue);
      expect(await b, isFalse);
      expect(order, ['a started', 'a answered', 'b started']);
    });
  });

  test('answers go back to whoever asked', () async {
    // The queue orders the questions and does not otherwise get between a
    // caller and its own answer.
    final queue = PromptQueue();

    final results = await Future.wait([
      queue.add(() async => 1),
      queue.add(() async => 2),
      queue.add(() async => 3),
    ]);

    expect(results, [1, 2, 3]);
  });

  test('one that throws does not block the rest', () async {
    // A refusal, or a dialog that failed to build. Chained off the error for
    // this reason: otherwise the first thing to go wrong leaves every later
    // question waiting for ever, and a transfer that needed one hangs.
    final queue = PromptQueue();

    final failed = queue.add<bool>(() async => throw StateError('refused'));
    final after = queue.add(() async => true);

    await expectLater(failed, throwsStateError);
    expect(await after, isTrue);
  });

  test('they do not overlap, and run in the order they were asked', () async {
    // Start *and* end, because recording only the starts proves nothing: each
    // question's first line runs synchronously, so five that never waited for
    // each other would still have started in order. What has to hold is that
    // one ends before the next begins.
    final queue = PromptQueue();
    final log = <String>[];

    await Future.wait([
      for (var i = 0; i < 5; i++)
        queue.add(() async {
          log.add('start $i');
          await Future<void>.delayed(Duration.zero);
          log.add('end $i');
          return i;
        }),
    ]);

    expect(log, [
      for (var i = 0; i < 5; i++) ...['start $i', 'end $i'],
    ]);
  });

  test('the shared one is shared', () {
    // Every transfer uses it, because the screen they would draw on is one.
    expect(PromptQueue.shared, same(PromptQueue.shared));
  });
}
