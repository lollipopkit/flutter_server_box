/// `TermSessionManager`'s drain: what reaches the platforms, and when. The
/// push is swapped for a recorder of the sessions it would send.
library;

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/data/terminal/session_manager.dart';

void main() {
  late List<List<String>> pushed;
  Completer<void>? hold;

  setUp(() {
    TermSessionManager.reset();
    pushed = [];
    hold = null;
    TermSessionManager.push = () async {
      pushed.add([...TermSessionManager.registry.entries.keys]);
      await hold?.future;
    };
  });

  tearDown(TermSessionManager.reset);

  void add(String id) => TermSessionManager.add(
    id: id,
    title: id,
    startTimeMs: 0,
    disconnect: () {},
  );

  test('the first change goes at once; the ones behind it go together', () async {
    add('a');
    add('b');
    TermSessionManager.updateStatus('a', TermSessionStatus.connected);
    await pumpEventQueue();

    expect(pushed, [
      ['a'],
      ['a', 'b'],
    ]);
  });

  test('a change made while a push runs is sent once more after it', () async {
    hold = Completer<void>();
    add('a');
    await pumpEventQueue();
    expect(pushed, hasLength(1));

    add('b');
    TermSessionManager.remove('a');
    await pumpEventQueue();
    expect(pushed, hasLength(1), reason: 'not while the first is running');

    hold!.complete();
    await pumpEventQueue();
    expect(pushed, [
      ['a'],
      ['b'],
    ]);
  });

  test('a change that changes nothing is not sent', () async {
    add('a');
    await pumpEventQueue();
    pushed.clear();

    TermSessionManager.updateStatus('a', TermSessionStatus.connecting);
    TermSessionManager.updateProgram('missing', null, null);
    await pumpEventQueue();

    expect(pushed, isEmpty);
  });
}
