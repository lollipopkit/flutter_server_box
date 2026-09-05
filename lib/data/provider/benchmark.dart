import 'dart:async';

import 'package:fl_lib/fl_lib.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:server_box/core/diag.dart';
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
    if (active != null) _schedule(active, immediate: true);
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

  /// Arms the next poll for [active], or disarms when there is nothing to poll.
  ///
  /// The run is a parameter rather than read from `state`. `build` has to start
  /// polling a run that was already going when this page opened, and at that
  /// moment `state` does not exist yet — reading it there threw
  /// `Tried to read the state of an uninitialized provider` and took the page
  /// down with it. Passing the run makes the dependency explicit and removes
  /// the only reason this had to care when it was called.
  void _schedule(BenchmarkRun? active, {bool immediate = false}) {
    _timer?.cancel();
    _timer = null;
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
      // Here rather than at the top of this method: what is worth counting is a
      // run that is actually going, and everything above can refuse — no
      // credentials, no shell, a script that would not install. Those are
      // `start failed` below, which is a different thing from a run that never
      // finished.
      Diag.crumb(SbDiag.benchmark, 'start', data: _asked(options));
      state = state.copyWith(
        active: run,
        history: _store.forServer(_spi.id),
        isBusy: false,
      );
      _schedule(run, immediate: true);
    } catch (e, s) {
      Loggers.app.warning('Benchmark start failed', e, s);
      Diag.crumb(
        SbDiag.benchmark,
        'start failed',
        level: DiagLevel.warning,
        data: {..._asked(options), 'error': Redact.error(e)},
      );
      state = state.copyWith(isBusy: false, error: '$e');
    }
  }

  /// What the user asked for, in the shape the defaults can be judged against.
  ///
  /// Every field of [YabsOptions] that costs something — time, egress, disk, or
  /// a disclosure to a third party — and nothing that identifies the machine.
  /// The working directory is a path the user typed, so only whether they
  /// changed it is recorded.
  Map<String, String> _asked(YabsOptions options) => {
    'disk': '${options.disk}',
    'network': '${options.network}',
    'reduced': '${options.reducedNetwork}',
    'cpu': '${options.cpu}',
    if (options.cpu) 'geekbench': options.geekbenchVersion.name,
    'ip': '${options.ipInfo}',
    'binaries': '${options.preferPrecompiledBinaries}',
    'workdir': '${options.workDir.isNotEmpty}',
    // Which side carried it. The claim this feature rests on is that the
    // transport does not matter — every command is short, so it works over
    // sshd and over an agent's `/exec` with neither knowing about the other —
    // and that is only a claim until both are seen to happen.
    'transport': _spi.transport.name,
  };

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
      _reportPollLost(active, 'unreachable', Redact.error(e));
      // Recorded on the run rather than swallowed. The retry is right — the
      // benchmark is not this device's connection — but a page that shows a
      // spinner while every poll fails is telling the user the run is fine.
      final noted = active.copyWith(pollError: '$e');
      state = state.copyWith(active: noted);
      _schedule(noted);
      return;
    }

    if (!poll.answered) {
      // The command produced nothing this app recognises: a monitor agent hit
      // its own timeout, a shell was killed, a proxy answered instead. None of
      // those says anything about the benchmark, which is in its own session on
      // the far side.
      Loggers.app.info('Benchmark poll produced no state, will retry');
      _reportPollLost(active, 'unanswered', '-');
      final noted = active.copyWith(
        pollError: 'The server did not answer the poll',
      );
      state = state.copyWith(active: noted);
      _schedule(noted);
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
        _schedule(active);
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
      processes: poll.processes,
      // This poll answered, so whatever the last one could not do is history.
      pollError: '',
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
      _schedule(updated);
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
    // The other half of `start`. A run that never reaches here is one this
    // device stopped watching — the page was left and never reopened, the app
    // was replaced, the record was pruned — and the gap between the two counts
    // is the only measure of that there is.
    Diag.crumb(
      SbDiag.benchmark,
      'finished',
      level: run.status == BenchmarkStatus.failed
          ? DiagLevel.warning
          : DiagLevel.info,
      data: {
        ..._asked(run.options),
        'status': run.status.name,
        // Bucketed, not exact. What the number answers is whether a run took
        // the quarter of an hour this feature is built around, and minutes to
        // the second is a measurement of the user's hardware.
        'ran': _ranFor(run.elapsed),
      },
    );
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
      _schedule(active);
      return;
    }

    // The exit file the cancel command wrote is what turns the record
    // terminal, so the state comes from a poll like any other rather than
    // being assumed here.
    state = state.copyWith(isBusy: false);
    await _poll();
  }

  /// The run whose polling has already been reported as lost.
  String? _pollLostFor;

  /// Says once per run that this device stopped hearing from it.
  ///
  /// **Once**, because a run is polled every three to twenty seconds for up to
  /// twenty minutes: one crumb a poll would be a hundred of them, and would
  /// push everything else out of the buffer a crash report is read from.
  ///
  /// Worth recording at all because both cases were bugs and neither is a
  /// failure the user can report usefully — the page goes on saying the run is
  /// going. [why] separates them: `unreachable` is this device's own network,
  /// while `unanswered` is a command that returned something unrecognisable,
  /// which is what a monitor agent hitting its own timeout looks like.
  void _reportPollLost(BenchmarkRun run, String why, String error) {
    if (_pollLostFor == run.id) return;
    _pollLostFor = run.id;
    Diag.crumb(
      SbDiag.benchmark,
      'poll lost',
      level: DiagLevel.warning,
      data: {
        'why': why,
        'error': error,
        'transport': _spi.transport.name,
        'ran': _ranFor(run.elapsed),
      },
    );
  }

  /// How long a run went, to the bucket rather than to the second.
  static String _ranFor(Duration elapsed) {
    final minutes = elapsed.inMinutes;
    if (minutes < 1) return '<1m';
    if (minutes < 5) return '1-5m';
    if (minutes < 15) return '5-15m';
    if (minutes < 30) return '15-30m';
    return '>30m';
  }

  /// Forgets one stored run.
  void remove(String id) {
    _store.remove(id);
    state = state.copyWith(history: _store.forServer(_spi.id));
  }

  void clearError() => state = state.copyWith(error: null);
}
