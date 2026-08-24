import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/core/utils/rootfs_lifecycle.dart';

void main() {
  test('rootfs mutations run one at a time', () async {
    final lifecycle = RootfsLifecycle();
    final releaseFirst = Completer<void>();
    final order = <String>[];

    final first = lifecycle.run(() async {
      order.add('first-start');
      await releaseFirst.future;
      order.add('first-end');
    });
    final second = lifecycle.run(() async {
      order.add('second');
    });

    await Future<void>.delayed(Duration.zero);
    expect(order, ['first-start']);
    releaseFirst.complete();
    await Future.wait([first, second]);
    expect(order, ['first-start', 'first-end', 'second']);
  });

  test('a failed mutation does not block the queue', () async {
    final lifecycle = RootfsLifecycle();
    final failed = lifecycle.run<void>(() => throw StateError('failed'));
    final next = lifecycle.run(() async => 7);

    await expectLater(failed, throwsA(isA<StateError>()));
    expect(await next, 7);
  });
}
