import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/core/utils/cancel_scope.dart';
import 'package:server_box/core/utils/pending_ops.dart';

void main() {
  group('CancelScope', () {
    test('separates immediate local teardown from background remote reclaim', () async {
      final scope = CancelScope();
      final remoteGate = Completer<void>();
      var localClosed = false;
      var remoteStarted = false;
      var remoteFinished = false;

      scope.onLocalDispose(() => localClosed = true);
      scope.onRemoteDispose(() async {
        remoteStarted = true;
        await remoteGate.future;
        remoteFinished = true;
      });

      await scope.cancel(waitRemote: false).timeout(const Duration(seconds: 1));
      expect(scope.isCanceled, isTrue);
      expect(localClosed, isTrue);
      expect(remoteStarted, isTrue);
      expect(remoteFinished, isFalse);

      remoteGate.complete();
      await scope.remoteDone.timeout(const Duration(seconds: 1));
      expect(remoteFinished, isTrue);
    });

    test('runs registrations immediately when already canceled', () async {
      final scope = CancelScope();
      await scope.cancel();

      var localRan = false;
      var remoteRan = false;
      scope.onLocalDispose(() => localRan = true);
      scope.onRemoteDispose(() async => remoteRan = true);
      await scope.remoteDone.timeout(const Duration(seconds: 1));

      expect(localRan, isTrue);
      expect(remoteRan, isTrue);
    });
  });

  group('PendingOps', () {
    test('prevents re-entry per key and aggregates loading across keys', () async {
      final ops = PendingOps();
      addTearDown(ops.dispose);

      final gateA = Completer<void>();
      final gateB = Completer<void>();
      var runsA = 0;

      final fA = ops.run('a', () async {
        runsA++;
        await gateA.future;
        return 'ok-a';
      });
      expect(ops.loading.value, isTrue);
      expect(ops.isRunning('a'), isTrue);

      // Re-entry on same key is ignored.
      final dupA = await ops.run('a', () async {
        runsA++;
        return 'dup';
      });
      expect(dupA, isNull);
      expect(runsA, 1);

      // Different key runs concurrently and keeps loading true after A finishes.
      final fB = ops.run('b', () async {
        await gateB.future;
        return 'ok-b';
      });

      gateA.complete();
      expect(await fA, 'ok-a');
      expect(ops.loading.value, isTrue);
      expect(ops.isRunning('a'), isFalse);
      expect(ops.isRunning('b'), isTrue);

      gateB.complete();
      expect(await fB, 'ok-b');
      expect(ops.loading.value, isFalse);
    });

    test('stops notifying and rejects new work after dispose', () async {
      final ops = PendingOps();
      final gate = Completer<void>();
      var notifications = 0;
      ops.loading.addListener(() => notifications++);

      final running = ops.run('a', () => gate.future);
      expect(notifications, 1);

      ops.dispose();
      gate.complete();
      await running;

      // No notification after dispose, and new runs are ignored.
      expect(notifications, 1);
      var ran = false;
      expect(
        await ops.run('b', () async {
          ran = true;
          return 1;
        }),
        isNull,
      );
      expect(ran, isFalse);
    });
  });
}
