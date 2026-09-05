/// Opening the benchmark page while a run is already going.
///
/// The whole point of detaching a run is that the app can be closed and come
/// back to it, so this is a first-class state — and it was the one state no
/// test covered. `build` starts polling a run it finds in storage, and doing
/// that by reading `state` threw `Tried to read the state of an uninitialized
/// provider` and took the page down with it. Nothing else exercised it: with no
/// active run, `build` never reached that line.
library;

import 'dart:convert';
import 'dart:io';

import 'package:fl_lib/fl_lib.dart';
import 'package:fl_lib/generated/l10n/lib_l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/data/model/server/benchmark/benchmark_run.dart';
import 'package:server_box/data/model/server/benchmark/yabs_options.dart';
import 'package:server_box/data/model/server/server_exec.dart';
import 'package:server_box/data/provider/server/single.dart';
import 'package:server_box/data/res/store.dart';
import 'package:server_box/data/store/benchmark.dart';
import 'package:server_box/data/store/private_key.dart';
import 'package:server_box/data/store/server.dart';
import 'package:server_box/data/store/setting.dart';
import 'package:server_box/generated/l10n/l10n.dart';
import 'package:server_box/view/page/benchmark/history_tile.dart';
import 'package:server_box/view/page/benchmark/result.dart';
import 'package:server_box/view/page/benchmark/tab.dart';

import 'helpers/spi_fixture.dart';
import 'helpers/test_db.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const sid = 'srv-resume-1';
  final spi = spiFixture(
    id: sid,
    name: 'web',
    ip: 'h',
    user: 'u',
    autoConnect: false,
  );
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('server-box-resume-');
    await openTestDb();
    getIt.registerSingleton<SettingStore>(SettingStore('setting_test'));
    getIt.registerSingleton<ServerStore>(ServerStore());
    getIt.registerSingleton<PrivateKeyStore>(PrivateKeyStore());
    Stores.setting.serverStatusUpdateInterval.put(0);
    Stores.server.put(spi);
  });

  tearDown(() async {
    await getIt.reset();
    await SqliteDb.close();
    await tempDir.delete(recursive: true);
  });

  /// A run in flight, as one left behind by an earlier launch of the app.
  BenchmarkRun seedRunning({String log = '', DateTime? startedAt}) {
    final run = BenchmarkRun(
      id: 'bench_resume',
      serverId: sid,
      startedAt: startedAt ?? DateTime.now(),
      status: BenchmarkStatus.running,
      options: const YabsOptions(),
      runDir: '/tmp/x/.server_box_bench',
      log: log,
    );
    BenchmarkStore.instance.put(run);
    return run;
  }

  /// A server that refuses to hand out a connection.
  ///
  /// Opening the page starts a poll — that is the behaviour under test — and a
  /// poll asks for one. Left alone, `ensureExec` opens a real socket, and a
  /// `testWidgets` body runs in a fake-async zone where real I/O completes on a
  /// callback that zone never pumps: the connect timeout then sits pending and
  /// the test fails with "a Timer is still pending" for a reason that has
  /// nothing to do with the page.
  ///
  /// Refusing is also the honest shape. A resumed run polls a server that may
  /// well be unreachable, and the runner is supposed to keep the record and try
  /// again rather than fail the benchmark.
  Future<void> pump(WidgetTester tester, Widget home) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          serverProvider(sid).overrideWith(_OfflineServerNotifier.new),
        ],
        child: MaterialApp(
          localizationsDelegates: const [
            LibLocalizations.delegate,
            ...AppLocalizations.localizationsDelegates,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          builder: ResponsivePoints.builder,
          home: home,
        ),
      ),
    );
    // Never `pumpAndSettle`: the page holds a one-second clock and the runner
    // re-arms a poll timer, so nothing here ever settles.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  /// Tears the tree down inside the test body, not from `addTearDown`.
  ///
  /// The binding checks for pending timers at the end of the body, and
  /// `addTearDown` callbacks run after that — so disposing there leaves the
  /// runner's poll timer and the page's clock still armed when the check runs.
  /// Both are cancelled on dispose; this is what makes dispose happen in time.
  Future<void> close(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  }

  testWidgets('the page opens on a run that was already going', (tester) async {
    seedRunning();

    await pump(tester, const BenchmarkTabPage());

    expect(
      tester.takeException(),
      isNull,
      reason: 'building the page threw with a run in flight',
    );
    // The running card, not the configuration form: there is a run to show.
    expect(find.text(libL10n.stop), findsOneWidget);
    expect(find.text(libL10n.start), findsNothing);
    await close(tester);
  });

  testWidgets('an empty log does not claim a phase it cannot know', (
    tester,
  ) async {
    // The label came from the log's section headers, and an empty log fell
    // through to the first of them — so a run that had printed nothing at all
    // announced that it was reading system information.
    seedRunning();

    await pump(tester, const BenchmarkTabPage());

    expect(find.text(l10n.benchmarkPhaseStarting), findsOneWidget);
    expect(find.text(l10n.benchmarkPhaseSystem), findsNothing);
    await close(tester);
  });

  testWidgets('once there is output, the phase comes from it', (tester) async {
    seedRunning(log: 'Basic System Information:\nfio Disk Speed Tests (...):\n');

    await pump(tester, const BenchmarkTabPage());

    expect(find.text(l10n.benchmarkPhaseDisk), findsOneWidget);
    await close(tester);
  });

  testWidgets('a long silence is explained rather than left blank', (
    tester,
  ) async {
    seedRunning(
      startedAt: DateTime.now().subtract(const Duration(minutes: 5)),
    );

    await pump(tester, const BenchmarkTabPage());

    expect(find.text(l10n.benchmarkNoOutputYet), findsOneWidget);
    await close(tester);
  });

  testWidgets('a poll that cannot reach the server says so', (tester) async {
    // The override makes every poll fail, which is the situation this is about:
    // the run is untouched — it is in its own session on the far side — so the
    // record stays `running` forever and the card would otherwise show nothing
    // but a spinner, however long the server had been unreachable.
    seedRunning();

    await pump(tester, const BenchmarkTabPage());
    // Past the first poll and its retry.
    await tester.pump(const Duration(seconds: 4));

    expect(find.textContaining('offline'), findsOneWidget);
    // Still running, and still stoppable: a failed poll is not a failed run.
    expect(find.text(libL10n.stop), findsOneWidget);
    await close(tester);
  });

  testWidgets('both columns are drawn, and neither throws', (tester) async {
    // The tab is a two-column layout, and its detail is built inside the pane's
    // own `Builder` — a different element from the page's. `ref.watch` and
    // `ref.listen` are illegal there, and illegal loudly: the first version
    // threw on every frame that had a detail to draw, which is every frame.
    seedRunning();

    await pump(tester, const BenchmarkTabPage());

    expect(tester.takeException(), isNull);
    // Left: the history, naming the machine. Right: that machine's run.
    expect(find.text('web'), findsWidgets);
    expect(find.text(libL10n.stop), findsOneWidget);
    await close(tester);
  });

  testWidgets('tapping a past run shows it beside the list', (tester) async {
    final run = seedRunning();
    BenchmarkStore.instance.put(
      run.copyWith(status: BenchmarkStatus.completed, exitCode: 0),
    );

    await pump(tester, const BenchmarkTabPage());
    await tester.tap(find.byType(BenchmarkHistoryTile).first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(tester.takeException(), isNull);
    // The result took the right column; the list is still there beside it.
    expect(find.byType(BenchmarkHistoryTile), findsWidgets);
    expect(find.text(l10n.benchmarkRawLog), findsWidgets);
    await close(tester);
  });

  testWidgets('the result page shows a running run its elapsed time', (
    tester,
  ) async {
    // Reached from the history, which lists a run from the moment it starts.
    // The record handed to that page is a snapshot, so before this it had no
    // duration, no log and a status that could never change.
    final run = seedRunning(
      startedAt: DateTime.now().subtract(const Duration(minutes: 2)),
    );

    await pump(tester, BenchmarkResultPage(args: run));

    expect(tester.takeException(), isNull);
    expect(find.text(l10n.benchmarkRunning), findsOneWidget);
    expect(find.textContaining('2m'), findsWidgets);
    await close(tester);
  });

  testWidgets('the result page picks up what the poll has written since', (
    tester,
  ) async {
    final run = seedRunning();
    await pump(tester, BenchmarkResultPage(args: run));

    // What a poll does: it writes through the store rather than through the
    // page, so a page that only redrew would tick a clock over a log that never
    // filled in.
    BenchmarkStore.instance.put(
      run.copyWith(
        status: BenchmarkStatus.completed,
        exitCode: 0,
        resultJson: json.encode({
          'version': 'v1',
          'cpu': {'model': 'Test CPU', 'cores': 4},
        }),
      ),
    );
    await tester.pump(const Duration(seconds: 1));
    await tester.pump();

    expect(find.text('Test CPU'), findsOneWidget);
    expect(find.text(l10n.benchmarkRunning), findsNothing);
    await close(tester);
  });
}

/// See the note on `pump`: this exists so a poll cannot reach the network.
class _OfflineServerNotifier extends ServerNotifier {
  @override
  Future<ServerExec> ensureExec() async =>
      throw StateError('offline: this test does not connect');
}
