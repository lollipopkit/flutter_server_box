/// [AgentPoll]: one read at a time, the first after the provider's state
/// exists, a refresh during one read again after it, none after dispose.
library;

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/data/model/server/monitor_http_credential.dart';
import 'package:server_box/data/provider/server/agent_poll.dart';

void main() {
  test('reads once at a time, after build, and not after dispose', () async {
    var reads = 0;
    var gate = Completer<void>();
    final current = <bool Function()>[];
    final poll = AgentPoll(
      const MonitorHttpCredential(addr: 'http://127.0.0.1:9'),
      every: const Duration(hours: 1),
      read: (_, isCurrent) async {
        reads++;
        current.add(isCurrent);
        await gate.future;
      },
    );
    // Not during construction: the provider has no state yet.
    expect(reads, 0);
    await Future<void>.delayed(Duration.zero);
    expect(reads, 1);

    // Refreshes while one runs (asked after a change it was sent before):
    // one more read after it, shared by both, never two at once.
    final first = poll.refresh();
    final second = poll.refresh();
    expect(reads, 1);
    final running = gate;
    gate = Completer<void>();
    running.complete();
    await Future<void>.delayed(Duration.zero);
    expect(reads, 2);
    gate.complete();
    await Future.wait([first, second]);
    expect(reads, 2);

    // Nothing in flight: one read.
    await poll.refresh();
    expect(reads, 3);

    poll.dispose();
    await poll.refresh();
    expect(reads, 3);
    expect(current.every((c) => !c()), isTrue);
  });
}
