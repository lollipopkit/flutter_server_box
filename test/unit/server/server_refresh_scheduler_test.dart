import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/data/provider/server/refresh_scheduler.dart';

void main() {
  test('applies one concurrency cap across overlapping requests', () async {
    final release = Completer<void>();
    final calls = <String, int>{};
    var active = 0;
    var maxActive = 0;

    final scheduler = ServerRefreshScheduler(
      maxConcurrent: 2,
      refresh: (serverId) async {
        calls.update(serverId, (count) => count + 1, ifAbsent: () => 1);
        active++;
        if (active > maxActive) maxActive = active;
        await release.future;
        active--;
      },
    );

    final first = scheduler.refresh(['a', 'b', 'c', 'd']);
    final second = scheduler.refresh(['a', 'b', 'c', 'd', 'e']);

    await Future<void>.delayed(Duration.zero);
    expect(calls.keys, unorderedEquals(['a', 'b']));
    expect(maxActive, 2);

    release.complete();
    await Future.wait([first, second]);

    expect(calls, {'a': 1, 'b': 1, 'c': 1, 'd': 1, 'e': 1});
    expect(maxActive, 2);
  });

  test('deduplicates repeated ids within one request', () async {
    final calls = <String, int>{};
    final scheduler = ServerRefreshScheduler(
      maxConcurrent: 2,
      refresh: (serverId) async {
        calls.update(serverId, (count) => count + 1, ifAbsent: () => 1);
      },
    );

    await scheduler.refresh(['a', 'a', 'b', 'a', 'b']);

    expect(calls, {'a': 1, 'b': 1});
  });

  test('continues draining after a task fails', () async {
    final calls = <String>[];
    final scheduler = ServerRefreshScheduler(
      maxConcurrent: 1,
      refresh: (serverId) async {
        calls.add(serverId);
        if (serverId == 'bad') throw StateError('failed');
      },
    );

    await expectLater(
      scheduler.refresh(['bad', 'good']),
      throwsA(isA<StateError>()),
    );
    expect(calls, ['bad', 'good']);

    await expectLater(scheduler.refresh(['bad']), throwsA(isA<StateError>()));
    expect(calls, ['bad', 'good', 'bad']);
  });
}
