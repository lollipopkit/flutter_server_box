import 'package:fl_lib/fl_lib.dart';
import 'package:fl_lib/generated/l10n/lib_l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/core/route.dart';
import 'package:server_box/data/model/app/error.dart';
import 'package:server_box/data/model/app/scripts/cmd_types.dart';
import 'package:server_box/data/model/server/memory.dart';
import 'package:server_box/data/model/server/server.dart';
import 'package:server_box/data/model/server/server_private_info.dart';
import 'package:server_box/data/model/server/ssh_credential.dart';
import 'package:server_box/data/provider/server/single.dart';
import 'package:server_box/data/res/status.dart';
import 'package:server_box/data/res/store.dart';
import 'package:server_box/data/store/connection_stats.dart';
import 'package:server_box/data/store/private_key.dart';
import 'package:server_box/data/store/pve.dart';
import 'package:server_box/data/store/server.dart';
import 'package:server_box/data/store/setting.dart';
import 'package:server_box/generated/l10n/l10n.dart';
import 'package:server_box/view/page/server/detail/view.dart';
import 'package:server_box/view/page/server/tab/tab.dart';

import '../helpers/spi_fixture.dart';
import '../helpers/test_db.dart';

/// How long the last status read took, where it is shown and when it is not.
///
/// Three things here are invisible in the code that produces the number:
/// adding a row to the About card decides whether that card starts open, the
/// server card's status line is deliberately not one of the places it is
/// shown, and a reading nothing clears outlives the machine it was taken
/// from.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const sid = 'srv-latency';
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
    getIt.registerSingleton<PveStore>(PveStore());
    // The list draws what has happened to these machines lately, which is
    // the one thing in the app that records a time.
    getIt.registerSingleton<ConnectionStatsStore>(ConnectionStatsStore.instance);
    getIt.registerSingleton<PrivateKeyStore>(PrivateKeyStore());
    // 0 is off: a periodic refresh outliving the tree fails the run, and
    // nothing here should reach for a socket.
    Stores.setting.serverStatusUpdateInterval.put(0);
    Stores.server.put(spi);
  });

  tearDown(() async {
    await getIt.reset();
    await SqliteDb.close();
  });

  /// A status with as much to say as a connected machine has: exactly the
  /// three keys anything writes into `more`.
  ServerStatus fullStatus() {
    final status = InitStatus.status;
    status.more[StatusCmdType.host] = 'test-host';
    status.more[StatusCmdType.sys] = 'Ubuntu 24.04';
    status.more[StatusCmdType.uptime] = 'up 12 days';
    return status;
  }

  Widget wrap(Widget home) => ProviderScope(
    child: MaterialApp(
      localizationsDelegates: const [
        LibLocalizations.delegate,
        ...AppLocalizations.localizationsDelegates,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      builder: ResponsivePoints.builder,
      home: home,
    ),
  );

  ServerNotifier notifierOf(WidgetTester tester, Type pageType) {
    final container = ProviderScope.containerOf(tester.element(find.byType(pageType)));
    return container.read(serverProvider(sid).notifier);
  }

  group('the About card', () {
    Future<ServerNotifier> pumpDetail(
      WidgetTester tester, {
      required Size size,
    }) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(wrap(ServerDetailPage(args: SpiRequiredArgs(spi))));
      addTearDown(() => tester.pumpWidget(const SizedBox.shrink()));
      return notifierOf(tester, ServerDetailPage);
    }

    testWidgets('carries the reading, and nothing when there is none', (
      tester,
    ) async {
      final notifier = await pumpDetail(tester, size: const Size(1200, 900));

      notifier.updateStatus(fullStatus());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('test-host'), findsOneWidget);
      // The connection row is always there — it says how the app reaches the
      // machine. The reading joins it once there is one.
      expect(
        find.textContaining('41ms'),
        findsNothing,
        reason: 'a reading appeared before anything was measured',
      );

      notifier.updateStatus(fullStatus(), latencyMs: 41);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.textContaining('41ms'), findsOneWidget);
    });

    testWidgets('still starts open on a phone once a reading arrives', (
      tester,
    ) async {
      // The regression this guards: `_getInitExpand` answers yes for three
      // rows or fewer, `more` holds exactly three, and counting a row this
      // card adds on its own took every phone from open to collapsed.
      // Narrower than `UIs.columnWidth`, which is the other way
      // `_getInitExpand` short-circuits to yes — a 400pt "phone" exercises the
      // desktop answer and the regression is invisible.
      Stores.setting.collapseUIDefault.put(true);
      final notifier = await pumpDetail(tester, size: const Size(320, 900));

      notifier.updateStatus(fullStatus(), latencyMs: 41);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(
        find.text('test-host'),
        findsOneWidget,
        reason: 'the latency row collapsed a card that used to start open',
      );
      expect(find.textContaining('41ms'), findsOneWidget);
    });

    testWidgets('and a real memory total still fits the memory card', (
      tester,
    ) async {
      // A `ListTile` gives its title what the trailing does not take, which on
      // a 320pt phone is 77pt for the 27pt figure and the `of <total>` line
      // together. `InitStatus.status` reports 1 KB of memory, which fits
      // anything — so without a machine-sized total here, removing the
      // memory card's ellipsis leaves the whole suite green.
      final notifier = await pumpDetail(tester, size: const Size(320, 900));

      final status = fullStatus()
        ..mem = const Memory(
          total: 134217728,
          free: 8388608,
          avail: 16777216,
        );
      notifier.updateStatus(status, latencyMs: 41);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(
        tester.takeException(),
        isNull,
        reason: 'the memory card title overflowed',
      );
    });
  });

  group('the server card', () {
    Future<ServerNotifier> pumpTab(WidgetTester tester, {required Size size}) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(wrap(const ServerPage()));
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      addTearDown(() => tester.pumpWidget(const SizedBox.shrink()));
      return notifierOf(tester, ServerPage);
    }

    testWidgets('keeps the reading out of the status line', (tester) async {
      // The status line is temperature and uptime. It is read while scanning a
      // list of machines, and the latency is a detail-page figure.
      final notifier = await pumpTab(tester, size: const Size(1200, 900));

      notifier.updateStatus(fullStatus(), latencyMs: 41);
      notifier.updateConnection(ServerConn.finished);
      await tester.pump();

      expect(find.textContaining('up 12 days'), findsOneWidget);
      expect(
        find.textContaining('41ms'),
        findsNothing,
        reason: 'the reading is back on the server card',
      );
      expect(find.textContaining(libL10n.delay), findsNothing);
    });

    testWidgets('elides rather than overflowing beside a long name', (
      tester,
    ) async {
      // The card title is one Row: the name is `Expanded` and the status takes
      // its intrinsic width, so an unbounded status pushes the row past the
      // card. A long uptime alone is enough to reach it.
      const longName =
          'production-database-replica-eu-central-1b-standby-node-07';
      Stores.server.put(
        const Spi(
          id: sid,
          name: longName,
          ssh: SshCredential(ip: 'h', user: 'u'),
          autoConnect: false,
        ),
      );
      final notifier = await pumpTab(tester, size: const Size(320, 900));

      final status = fullStatus();
      status.more[StatusCmdType.uptime] = 'up 1 year, 2 months, 3 days';
      notifier.updateStatus(status, latencyMs: 1247);
      notifier.updateConnection(ServerConn.finished);
      await tester.pump();

      expect(
        tester.takeException(),
        isNull,
        reason: 'the title row overflowed its card',
      );
    });
  });

  group('the reading is dropped', () {
    /// No tree: this is about what the notifier keeps, and building one would
    /// only add a way for the test to fail.
    ServerNotifier notifier(ProviderContainer container) =>
        container.read(serverProvider(sid).notifier);

    test('when the connection is closed', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final n = notifier(container);

      n.updateStatus(fullStatus(), latencyMs: 41);
      expect(container.read(serverProvider(sid)).latencyMs, 41);

      n.closeConnection();
      expect(
        container.read(serverProvider(sid)).latencyMs,
        isNull,
        reason: 'a disconnected server still shows a latency',
      );
    });

    test('when the server is edited to point at another machine', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final n = notifier(container);

      n.updateStatus(fullStatus(), latencyMs: 41);
      expect(container.read(serverProvider(sid)).latencyMs, 41);

      n.updateSpi(
        const Spi(
          id: sid,
          name: 'web',
          ssh: SshCredential(ip: '10.0.0.9', user: 'u'),
          autoConnect: false,
        ),
      );
      expect(
        container.read(serverProvider(sid)).latencyMs,
        isNull,
        reason: 'the new host was given the old one\'s latency',
      );
    });

    test('when the status that arrives carries an error', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final n = notifier(container);

      n.updateStatus(fullStatus(), latencyMs: 41);

      // What a status read that timed out publishes. It leaves the session up
      // on purpose, so none of the paths that clear a connection runs, and the
      // last good figure used to sit in the About card beside the error that
      // replaced the status it was taken from.
      n.updateStatus(
        fullStatus()
          ..err = SSHErr(type: SSHErrType.getStatus, message: 'timed out'),
      );

      expect(
        container.read(serverProvider(sid)).latencyMs,
        isNull,
        reason: 'an errored read is still reported as a reading',
      );
    });

    test('but a status with no reading leaves the last one alone', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final n = notifier(container);

      n.updateStatus(fullStatus(), latencyMs: 41);
      // What every error-clearing caller does, and none of them measured
      // anything.
      n.updateStatus(fullStatus());

      expect(container.read(serverProvider(sid)).latencyMs, 41);
    });
  });
}
