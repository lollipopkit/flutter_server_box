import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/core/utils/coalesced.dart';

void main() {
  test('runs at once, then once more for everything asked while it ran', () async {
    var runs = 0;
    var gate = Completer<void>();
    final push = Coalesced(() async {
      runs++;
      await gate.future;
    });

    final first = push();
    await pumpEventQueue();
    expect(runs, 1);

    final second = push();
    final third = push();
    gate.complete();
    gate = Completer<void>()..complete();
    await Future.wait([first, second, third]);

    expect(runs, 2);
  });

  test('a request dropped before its run is not made', () async {
    var runs = 0;
    final gate = Completer<void>();
    final push = Coalesced(() async {
      runs++;
      await gate.future;
    });

    final first = push();
    await pumpEventQueue();
    unawaited(push());
    push.cancelPending();
    gate.complete();
    await first;

    expect(runs, 1);
  });

  test('a run that throws still lets the next one through', () async {
    var runs = 0;
    final push = Coalesced(() async {
      runs++;
      if (runs == 1) throw StateError('boom');
    });

    await expectLater(push(), throwsStateError);
    await push();

    expect(runs, 2);
  });

  test('who asked during a run that failed waits on the run made for it', () async {
    var runs = 0;
    final gate = Completer<void>();
    final push = Coalesced(() async {
      runs++;
      if (runs == 1) {
        await gate.future;
        throw StateError('boom');
      }
    });

    final first = push();
    await pumpEventQueue();
    final second = push();
    gate.complete();

    await expectLater(first, throwsStateError);
    await second;
    expect(runs, 2);
  });
}
