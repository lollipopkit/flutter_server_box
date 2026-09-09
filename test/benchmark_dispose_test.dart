/// A poll that lands after the page has gone.
///
/// Closing the tab disposes `benchmarkProvider` mid-poll. Two different things
/// must happen in that window, which is why the guards here are per-write
/// rather than one at the top:
///
/// - Nothing may write `state`, which throws on a disposed provider.
/// - The *record* must still be written. A benchmark takes fifteen minutes, and
///   its last poll is the one carrying the exit code and the result JSON. A
///   blanket guard threw that away and left a row still saying `running`.
library;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/data/model/server/benchmark/benchmark_run.dart';
import 'package:server_box/data/model/server/benchmark/yabs_options.dart';
import 'package:server_box/data/model/server/benchmark/yabs_script.dart';
import 'package:server_box/data/model/server/server_exec.dart';
import 'package:server_box/data/provider/benchmark.dart';
import 'package:server_box/data/provider/server/single.dart';
import 'package:server_box/data/res/store.dart';
import 'package:server_box/data/store/benchmark.dart';
import 'package:server_box/data/store/private_key.dart';
import 'package:server_box/data/store/server.dart';
import 'package:server_box/data/store/setting.dart';

import 'helpers/spi_fixture.dart';
import 'helpers/test_db.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const sid = 'srv-bench-dispose';
  final spi = spiFixture(
    id: sid,
    name: 'web',
    ip: 'h',
    user: 'u',
    autoConnect: false,
  );

  setUp(() async {
    await openTestDb();
    getIt.registerSingleton<SettingStore>(SettingStore('setting_test'));
    getIt.registerSingleton<ServerStore>(ServerStore());
    getIt.registerSingleton<PrivateKeyStore>(PrivateKeyStore());
    Stores.server.put(spi);
  });

  tearDown(() async {
    await getIt.reset();
    await closeTestDb();
  });

  BenchmarkRun seedRunning() {
    final run = BenchmarkRun(
      id: 'bench_dispose',
      serverId: sid,
      startedAt: DateTime.now(),
      status: BenchmarkStatus.running,
      options: const YabsOptions(),
      runDir: '/tmp/x/.server_box_bench',
    );
    BenchmarkStore.instance.put(run);
    return run;
  }

  /// What the far side prints for a run that has just exited cleanly.
  const finished =
      '${YabsScript.stateMarker} exit=0 alive=0 started=1 pid=4321\n'
      '${YabsScript.jsonMarker}\n'
      '{"version":"v1"}\n'
      '${YabsScript.psMarker}\n'
      '${YabsScript.logMarker}\n'
      'YABS completed';

  /// Opens the provider, which finds the seeded run and polls it at once.
  ProviderContainer pollWith(ServerExec exec) {
    final container = ProviderContainer(
      overrides: [
        serverProvider(sid).overrideWith(() => _FakeServerNotifier(exec)),
      ],
    );
    container.read(benchmarkProvider(sid).notifier);
    return container;
  }

  test('a run that ends as the page closes is still recorded', () async {
    seedRunning();
    final gate = Completer<void>();
    final container = pollWith(_GatedExec(gate.future, finished));

    // Far enough in for the poll to be waiting on the server.
    await pumpEventQueue();
    container.dispose();
    gate.complete();
    await pumpEventQueue();

    final stored = BenchmarkStore.instance.forServer(sid).single;
    expect(stored.status, BenchmarkStatus.completed);
    expect(stored.exitCode, 0);
    expect(stored.resultJson, contains('"version"'));
    expect(
      BenchmarkStore.instance.activeFor(sid),
      isNull,
      reason: 'a row left `running` is polled forever by every later open',
    );
  });

  test('and it throws nothing on the way', () async {
    // The other half of the same window: the record is written, and the state
    // write that would have followed it does not happen.
    seedRunning();
    final gate = Completer<void>();
    final container = pollWith(_GatedExec(gate.future, finished));

    await pumpEventQueue();
    container.dispose();
    gate.complete();

    await expectLater(pumpEventQueue(), completes);
  });

  test('an unfinished poll still records the log it fetched', () async {
    // Not terminal, but the log has grown, and the next open of the page reads
    // it from the store rather than from a server it has yet to reach.
    seedRunning();
    final gate = Completer<void>();
    final container = pollWith(
      _GatedExec(
        gate.future,
        '${YabsScript.stateMarker} exit= alive=1 started=1 pid=4321\n'
        '${YabsScript.logMarker}\n'
        'fio Disk Speed Tests',
      ),
    );

    await pumpEventQueue();
    container.dispose();
    gate.complete();
    await pumpEventQueue();

    final stored = BenchmarkStore.instance.forServer(sid).single;
    expect(stored.status, BenchmarkStatus.running);
    expect(stored.log, contains('fio Disk Speed Tests'));
  });
}

/// Hands out one prepared [ServerExec].
class _FakeServerNotifier extends ServerNotifier {
  _FakeServerNotifier(this.exec);

  final ServerExec exec;

  @override
  Future<ServerExec> ensureExec() async => exec;
}

/// Answers [output], and only once [gate] has completed.
///
/// The gate is what puts the dispose *between* the poll and its answer.
class _GatedExec implements ServerExec {
  const _GatedExec(this.gate, this.output);

  final Future<void> gate;
  final String output;

  @override
  Future<ExecResult> run(
    String script, {
    String? entry,
    Map<String, String>? env,
    String? stdin,
    OnExecOutput? onStdout,
    OnExecOutput? onStderr,
    Future<void>? cancel,
  }) async {
    await gate;
    return ExecResult(exitCode: 0, stdout: output, stderr: '');
  }
}
