import 'dart:async';

import 'package:fl_lib/fl_lib.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:server_box/data/model/server/benchmark/benchmark_run.dart';
import 'package:server_box/data/model/server/benchmark/yabs_options.dart';
import 'package:server_box/data/model/server/benchmark/yabs_script.dart';
import 'package:server_box/data/model/server/server_exec.dart';
import 'package:server_box/data/model/server/server_private_info.dart';
import 'package:server_box/data/provider/server/single.dart';
import 'package:server_box/data/store/benchmark.dart';

part 'benchmark.freezed.dart';
part 'benchmark.g.dart';

@freezed
abstract class BenchmarkState with _$BenchmarkState {
  const factory BenchmarkState({
    /// The run in flight, picked back up from storage when the page opens.
    BenchmarkRun? active,
    @Default(<BenchmarkRun>[]) List<BenchmarkRun> history,

    /// A start or a cancel is in progress. Not true while a run is going —
    /// that is [active], and the difference is whether a button should spin.
    @Default(false) bool isBusy,

    /// Why this app could not drive the run. Never yabs' own diagnostics.
    String? error,
  }) = _BenchmarkState;
}

/// Drives one server's benchmark: install, start, poll, finish.
///
/// **The run is detached and this only watches it.** yabs takes ten to twenty
/// minutes, which is longer than a phone keeps a connection, longer than the OS
/// leaves a backgrounded app running, and longer than anyone stares at a
/// screen. So the far side is asked to start the work in its own session and
/// this polls a directory — which means closing the page, locking the phone or
/// losing the network costs nothing, and reopening the page finds the run still
/// going. It also means the transport is not special: everything here is one
/// short command, so it works over SSH and over a monitor agent's `/exec`
/// without either knowing about the other.
@riverpod
class BenchmarkNotifier extends _$BenchmarkNotifier {
  late final Spi _spi;
  Timer? _timer;

  BenchmarkStore get _store => BenchmarkStore.instance;

  @override
  BenchmarkState build(Spi spi) {
    _spi = spi;
    ref.onDispose(() => _timer?.cancel());

    final active = _store.activeFor(spi.id);
    // Polling starts on its own when there is something to poll: the run has
    // been going since before this page existed.
    if (active != null) _schedule(immediate: true);
    return BenchmarkState(
      active: active,
      history: _store.forServer(spi.id),
    );
  }

  /// How often to ask, by how long the run has been going.
  ///
  /// Close together at the start, when the user is watching to see it take, and
  /// further apart later, when nothing happens for minutes at a time. Each poll
  /// carries the whole log — a few KB — so a fixed short interval would spend
  /// megabytes of someone's mobile data to watch a progress bar.
  static Duration _interval(Duration elapsed) {
    if (elapsed < const Duration(seconds: 30)) return const Duration(seconds: 3);
    if (elapsed < const Duration(minutes: 5)) return const Duration(seconds: 10);
    return const Duration(seconds: 20);
  }

  /// How long the launcher is given to record its pid before the run is
  /// called a failure. Generous: it writes it as its first act, so this only
  /// bounds the case where it never ran.
  static const _launchGrace = Duration(seconds: 30);

  void _schedule({bool immediate = false}) {
    _timer?.cancel();
    final active = state.active;
    if (active == null) return;
    _timer = Timer(
      immediate ? Duration.zero : _interval(active.elapsed),
      _poll,
    );
  }

  /// Starts a run with exactly [options].
  ///
  /// Refuses when one is already going rather than starting a second: they
  /// would share a working directory, and two benchmarks on one machine measure
  /// each other.
  Future<void> start(YabsOptions options) async {
    if (state.active != null) return;
    state = state.copyWith(isBusy: true, error: null);

    try {
      final exec = await ref.read(serverProvider(_spi.id).notifier).ensureExec();
      await _ensureScript(exec);

      final run = BenchmarkRun(
        id: 'bench_${DateTime.now().microsecondsSinceEpoch}',
        serverId: _spi.id,
        startedAt: DateTime.now(),
        status: BenchmarkStatus.running,
        options: options,
        runDir: YabsScript.runDir(options),
      );

      final res = await exec.run(
        YabsScript.launcher(options),
        entry: YabsScript.startEntry(options, run.id),
      );
      if (!res.combined.contains(YabsScript.started)) {
        throw StateError(
          'The server did not confirm the run started: '
          '${res.exitCode} ${res.combined.trim()}',
        );
      }

      // Written only once the far side has confirmed. A row claiming a run that
      // was never started would be picked back up on every later open of this
      // page and polled forever.
      _store.put(run);
      state = state.copyWith(
        active: run,
        history: _store.forServer(_spi.id),
        isBusy: false,
      );
      _schedule(immediate: true);
    } catch (e, s) {
      Loggers.app.warning('Benchmark start failed', e, s);
      state = state.copyWith(isBusy: false, error: '$e');
    }
  }

  /// Uploads the script unless this version is already there.
  ///
  /// The probe is a separate round trip on purpose: the script is 50 KB, and
  /// over a monitor agent that is 50 KB of request body every time somebody
  /// runs a benchmark. The filename carries the version, so "present" means
  /// "the right one".
  Future<void> _ensureScript(ServerExec exec) async {
    final probe = await exec.run(YabsScript.probeCommand());
    if (probe.combined.contains(YabsScript.scriptPresent)) return;

    final res = await exec.run(
      await YabsScript.load(),
      entry: YabsScript.installEntry(),
    );
    if (!res.combined.contains(YabsScript.scriptInstalled)) {
      throw StateError(
        'Could not install the benchmark script: '
        '${res.exitCode} ${res.combined.trim()}',
      );
    }
  }

  Future<void> _poll() async {
    final active = state.active;
    if (active == null) return;

    final YabsPollState poll;
    try {
      final exec = await ref.read(serverProvider(_spi.id).notifier).ensureExec();
      final res = await exec.run(YabsScript.pollCommand(active.runDir));
      poll = YabsPollState.parse(res.combined);
    } catch (e) {
      // Not a failure of the run. The benchmark is in its own session on the
      // far side and does not care that this device briefly could not reach it,
      // so the record is left alone and the next tick tries again.
      Loggers.app.info('Benchmark poll failed, will retry: $e');
      _schedule();
      return;
    }

    if (!poll.answered) {
      // The command produced nothing this app recognises: a monitor agent hit
      // its own timeout, a shell was killed, a proxy answered instead. None of
      // those says anything about the benchmark, which is in its own session on
      // the far side.
      Loggers.app.info('Benchmark poll produced no state, will retry');
      _schedule();
      return;
    }

    if (!poll.launcherStarted) {
      // The start command creates the directory and returns the moment it has
      // backgrounded the launcher, so this poll can beat the launcher to its
      // first line. That is not a dead run, and treating it as one failed
      // benchmarks before they began.
      //
      // Bounded, because a launcher that never runs at all looks the same:
      // past the grace period there is nothing left to wait for.
      if (active.elapsed < _launchGrace) {
        _schedule();
        return;
      }
      _finish(
        active.copyWith(
          status: BenchmarkStatus.failed,
          finishedAt: DateTime.now(),
          error: 'The run never started',
        ),
      );
      return;
    }

    if (!poll.dirExists) {
      // The directory is gone: something removed it, or the options were
      // edited so this is now looking somewhere the run never was. Either way
      // there is nothing left to watch.
      _finish(
        active.copyWith(
          status: BenchmarkStatus.failed,
          finishedAt: DateTime.now(),
          error: 'The run directory is gone',
        ),
      );
      return;
    }

    var updated = active.copyWith(
      log: poll.log.isEmpty ? active.log : poll.log,
      resultJson: poll.resultJson,
    );

    if (poll.diedWithoutReporting) {
      // No exit file and no process. A Geekbench run on a small VPS gets killed
      // by the OOM killer exactly like this, and it is worth naming because the
      // log stops mid-phase with nothing explaining why.
      _finish(
        updated.copyWith(
          status: BenchmarkStatus.failed,
          finishedAt: DateTime.now(),
          error: 'The run stopped without reporting an exit code',
        ),
      );
      return;
    }

    if (!poll.finished) {
      _store.put(updated);
      state = state.copyWith(active: updated);
      _schedule();
      return;
    }

    final code = poll.exitCode!;
    updated = updated.copyWith(
      exitCode: code,
      finishedAt: DateTime.now(),
      status: switch (code) {
        0 => BenchmarkStatus.completed,
        YabsScript.cancelledExitCode => BenchmarkStatus.cancelled,
        _ => BenchmarkStatus.failed,
      },
    );
    _finish(updated);
  }

  /// Records a terminal state and clears the far side.
  ///
  /// Cleanup is best effort and never blocks the result: the bytes are already
  /// here, and a benchmark the user waited fifteen minutes for must not be
  /// withheld because a `rm` failed.
  void _finish(BenchmarkRun run) {
    _timer?.cancel();
    _timer = null;
    _store.put(run);
    state = state.copyWith(
      active: null,
      history: _store.forServer(_spi.id),
      isBusy: false,
    );
    unawaited(_cleanup(run));
  }

  Future<void> _cleanup(BenchmarkRun run) async {
    try {
      final exec = await ref.read(serverProvider(_spi.id).notifier).ensureExec();
      await exec.run(YabsScript.cleanupCommand(run.runDir, run.id));
    } catch (e) {
      // Worth a line: what is left behind is a 2 GB fio file when the run was
      // cancelled mid-disk-test, and the user has no other way to learn it is
      // there.
      Loggers.app.warning('Benchmark cleanup failed for ${run.runDir}: $e');
    }
  }

  /// Stops the run and waits to see it stop.
  Future<void> cancel() async {
    final active = state.active;
    if (active == null) return;
    state = state.copyWith(isBusy: true);
    _timer?.cancel();

    try {
      final exec = await ref.read(serverProvider(_spi.id).notifier).ensureExec();
      await exec.run(YabsScript.cancelCommand(active.runDir));
    } catch (e, s) {
      Loggers.app.warning('Benchmark cancel failed', e, s);
      state = state.copyWith(isBusy: false, error: '$e');
      _schedule();
      return;
    }

    // The exit file the cancel command wrote is what turns the record
    // terminal, so the state comes from a poll like any other rather than
    // being assumed here.
    state = state.copyWith(isBusy: false);
    await _poll();
  }

  /// Forgets one stored run.
  void remove(String id) {
    _store.remove(id);
    state = state.copyWith(history: _store.forServer(_spi.id));
  }

  void clearError() => state = state.copyWith(error: null);
}
