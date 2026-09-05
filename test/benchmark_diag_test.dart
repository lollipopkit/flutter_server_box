/// What a benchmark run records, and what it must never record.
///
/// This feature is the one measured in quarter hours, and everything about how
/// it is built — detached under `setsid`, watched by polling a directory, the
/// record written at start so a reopened page finds it — is there so a run
/// survives the app being closed. None of that is worth anything if runs do not
/// finish, and a run that does not is the case nobody reports: by the time it
/// has failed the user has moved on. So the pair is what is recorded, and the
/// gap between the two counts is the only measure of it there is.
///
/// The other half is which phases were chosen, because three of
/// [YabsOptions]' defaults deliberately disagree with yabs' own — each guessing
/// the user would rather spend less or disclose less — and a guess nothing
/// measures stays a guess.
///
/// **A yabs result describes the user's machine in detail**: CPU model, disk
/// and network throughput, and with Geekbench on a public URL naming it. None
/// of it, and nothing naming the server, may reach a crumb — see [Breadcrumb],
/// which is written on the assumption that it will be published.
library;

import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/material.dart';
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

/// What the overridden server provider hands out, set per test.
///
/// A library-level slot because `overrideWith` takes a factory of no arguments
/// — the same shape `benchmark_resume_test.dart`'s offline notifier uses.
ServerExec? _exec;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const sid = 'srv-diag-1';
  // Deliberately identifiable: every one of these strings is something a crumb
  // must not carry, and the last group checks for them by value.
  const name = 'prod-web-01';
  const host = 'benchmark.example.com';
  final spi = spiFixture(
    id: sid,
    name: name,
    ip: host,
    user: 'ops',
    autoConnect: false,
  );

  late _RecordingSink sink;

  setUp(() async {
    await openTestDb();
    getIt.registerSingleton<SettingStore>(SettingStore('setting_test'));
    getIt.registerSingleton<ServerStore>(ServerStore());
    getIt.registerSingleton<PrivateKeyStore>(PrivateKeyStore());
    Stores.setting.serverStatusUpdateInterval.put(0);
    Stores.server.put(spi);
    _exec = null;
    sink = _RecordingSink();
    Diag.install(sink);
  });

  tearDown(() async {
    Diag.uninstall();
    _exec = null;
    await getIt.reset();
    await SqliteDb.close();
  });

  List<Breadcrumb> of(String message) =>
      sink.crumbs.where((c) => c.message == message).toList();

  /// The runner, mounted in a tree so its timers run in the fake-async zone.
  ///
  /// `testWidgets` rather than `test`: the poll is a `Timer`, and counting out
  /// three real seconds per retry is a test that takes longer than the thing it
  /// tests. The widget is a `SizedBox` — nothing here is about a page.
  Future<BenchmarkNotifier> mount(WidgetTester tester) async {
    late BenchmarkNotifier notifier;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          serverProvider(sid).overrideWith(_ScriptedServerNotifier.new),
        ],
        child: Consumer(
          builder: (_, ref, _) {
            notifier = ref.watch(benchmarkProvider(spi).notifier);
            return const SizedBox();
          },
        ),
      ),
    );
    await tester.pump();
    return notifier;
  }

  /// Tears the tree down inside the body: the binding checks for pending
  /// timers before `addTearDown` runs, and the runner re-arms a poll.
  Future<void> close(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  }

  group('a run that goes through', () {
    testWidgets('records the start and the finish, as a pair', (tester) async {
      _exec = _ScriptedExec(exit: 0);
      final runner = await mount(tester);

      await runner.start(const YabsOptions());
      // The first poll is armed with `Duration.zero`, so one pump reaches it,
      // and this one answers with an exit code — the run is over.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 10));

      expect(of('start'), hasLength(1));
      expect(of('finished'), hasLength(1));
      expect(of('start failed'), isEmpty);
      expect(of('finished').single.data?['status'], 'completed');
      await close(tester);
    });

    testWidgets('and says which phases were asked for', (tester) async {
      // The three that disagree with yabs' own defaults, all flipped: this is
      // the answer that says the defaults were wrong for somebody.
      _exec = _ScriptedExec(exit: 0);
      final runner = await mount(tester);

      await runner.start(
        const YabsOptions(
          cpu: true,
          geekbenchVersion: GeekbenchVersion.v5,
          reducedNetwork: false,
          ipInfo: true,
          workDir: '/mnt/nvme',
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 10));

      final data = of('start').single.data!;
      expect(data['cpu'], 'true');
      expect(data['geekbench'], 'v5');
      expect(data['reduced'], 'false');
      expect(data['ip'], 'true');
      // Whether the working directory was changed, never what it was set to:
      // it is a path the user typed.
      expect(data['workdir'], 'true');
      expect(data.values, isNot(contains('/mnt/nvme')));
      // Which side carried it. The claim the feature rests on is that the
      // transport does not matter, and that is a claim until both are seen.
      expect(data['transport'], 'ssh');
      await close(tester);
    });

    testWidgets('a failure is recorded as one, and is not a start', (
      tester,
    ) async {
      // The script would not install. Nothing is running on the far side, so
      // counting this as a start would put a run in the numerator of a funnel
      // that never had a chance to finish.
      _exec = _ScriptedExec(exit: 0, installFails: true);
      final runner = await mount(tester);

      await runner.start(const YabsOptions());
      await tester.pump();

      expect(of('start'), isEmpty);
      expect(of('finished'), isEmpty);
      expect(of('start failed'), hasLength(1));
      expect(of('start failed').single.level, DiagLevel.warning);
      await close(tester);
    });
  });

  group('a run this device stops hearing from', () {
    testWidgets('is recorded once, however many polls fail', (tester) async {
      // A run is polled every three to twenty seconds for up to twenty
      // minutes. One crumb a poll would be a hundred of them, and would push
      // everything else out of the buffer a crash report is read from.
      _exec = _UnreachableExec();
      BenchmarkStore.instance.put(
        BenchmarkRun(
          id: 'bench_lost',
          serverId: sid,
          startedAt: DateTime.now(),
          status: BenchmarkStatus.running,
          options: const YabsOptions(),
          runDir: '/tmp/x/.server_box_bench',
        ),
      );

      await mount(tester);
      // Past several retries: the interval is three seconds for the first
      // half-minute.
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(seconds: 3));
      }

      expect(of('poll lost'), hasLength(1));
      expect(of('poll lost').single.data?['why'], 'unreachable');
      expect(of('poll lost').single.level, DiagLevel.warning);
      await close(tester);
    });

    testWidgets('and an answer it cannot read is told apart from that', (
      tester,
    ) async {
      // What a monitor agent hitting its own timeout looks like: a command
      // that returned, with nothing in it this app recognises. Reading that as
      // "the run is gone" failed runs that were going fine.
      _exec = _ScriptedExec(exit: 0, pollAnswer: '');
      BenchmarkStore.instance.put(
        BenchmarkRun(
          id: 'bench_mute',
          serverId: sid,
          startedAt: DateTime.now(),
          status: BenchmarkStatus.running,
          options: const YabsOptions(),
          runDir: '/tmp/x/.server_box_bench',
        ),
      );

      await mount(tester);
      await tester.pump();
      await tester.pump(const Duration(seconds: 3));

      expect(of('poll lost').single.data?['why'], 'unanswered');
      await close(tester);
    });
  });

  testWidgets('nothing recorded names the machine or what it measured', (
    tester,
  ) async {
    // The rule [Breadcrumb] is written under: a crumb is published, so it
    // carries what a thing *was* rather than the thing. A yabs result is the
    // user's infrastructure described in detail.
    const result =
        '{"cpu":{"model":"AMD EPYC 7502P"},"geekbench":'
        '[{"url":"https://browser.geekbench.com/v6/cpu/1234"}]}';
    _exec = _ScriptedExec(exit: 0, resultJson: result);
    final runner = await mount(tester);

    await runner.start(const YabsOptions(workDir: '/srv/data'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 10));

    expect(sink.crumbs, isNotEmpty, reason: 'nothing to check otherwise');
    for (final crumb in sink.crumbs) {
      final text = crumb.toString();
      for (final secret in [
        sid,
        name,
        host,
        'ops',
        '/srv/data',
        'EPYC',
        'geekbench.com',
      ]) {
        expect(
          text,
          isNot(contains(secret)),
          reason: '${crumb.message} carried "$secret"',
        );
      }
    }
    await close(tester);
  });
}

/// A server whose `ensureExec` hands out whatever the test put in [_exec].
class _ScriptedServerNotifier extends ServerNotifier {
  @override
  Future<ServerExec> ensureExec() async {
    final exec = _exec;
    if (exec == null) throw StateError('no exec configured for this test');
    return exec;
  }
}

/// Answers each of the runner's commands by the marker it carries.
///
/// Keyed on the markers rather than on call order, because the runner's order
/// is what is under test: a probe that answers "present" skips the install, and
/// a test that counted calls would pass whichever branch ran.
class _ScriptedExec implements ServerExec {
  _ScriptedExec({
    required this.exit,
    this.installFails = false,
    this.resultJson,
    this.pollAnswer,
  });

  /// The exit code the run reports on its first poll.
  final int exit;
  final bool installFails;
  final String? resultJson;

  /// Overrides the whole poll answer — `''` is a command that returned nothing
  /// this app recognises.
  final String? pollAnswer;

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
    final whole = '$script ${entry ?? ''}';
    String out;
    if (whole.contains(YabsScript.scriptPresent)) {
      out = installFails ? YabsScript.scriptMissing : YabsScript.scriptPresent;
    } else if (whole.contains(YabsScript.scriptInstalled)) {
      out = installFails ? 'permission denied' : YabsScript.scriptInstalled;
    } else if (whole.contains(YabsScript.started)) {
      out = YabsScript.started;
    } else if (whole.contains(YabsScript.stateMarker)) {
      out =
          pollAnswer ??
          '${YabsScript.stateMarker} exit=$exit alive=0 started=1 pid=1\n'
              '${YabsScript.jsonMarker}\n${resultJson ?? ''}\n'
              '${YabsScript.psMarker}\n'
              '${YabsScript.logMarker}\nyabs output';
    } else {
      // Cleanup, and anything else.
      out = '';
    }
    return ExecResult(exitCode: 0, stdout: out, stderr: '');
  }
}

/// A server this device cannot reach, which is what a poll meets on a phone
/// that has moved between networks.
class _UnreachableExec implements ServerExec {
  @override
  Future<ExecResult> run(
    String script, {
    String? entry,
    Map<String, String>? env,
    String? stdin,
    OnExecOutput? onStdout,
    OnExecOutput? onStderr,
    Future<void>? cancel,
  }) async => throw const SocketExceptionStub();
}

/// Stands in for a network failure without dragging `dart:io` in, and without
/// a message a crumb could accidentally pass through.
class SocketExceptionStub implements Exception {
  const SocketExceptionStub();

  @override
  String toString() => 'connection refused';
}

/// Remembers every crumb, so what the runner publishes can be asserted.
final class _RecordingSink extends DiagnosticsSink {
  final crumbs = <Breadcrumb>[];

  @override
  void breadcrumb(Breadcrumb crumb) => crumbs.add(crumb);
}
