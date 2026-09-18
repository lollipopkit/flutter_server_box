/// The states the detail page has to be legible in besides "a machine that is
/// answering": before the first sample, after the answers stopped, and when
/// there is nothing to show at all.
///
/// Each of them used to be the same placeholder. What matters here is that the
/// page says which one it is in — a page waiting for its first answer must not
/// read like one whose server is gone — and that a figure nobody should act on
/// says when it was taken.
library;

import 'package:fl_lib/fl_lib.dart';
import 'package:fl_lib/generated/l10n/lib_l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/core/extension/context/locale.dart' as app_locale;
import 'package:server_box/core/route.dart';
import 'package:server_box/data/model/app/scripts/cmd_types.dart';
import 'package:server_box/data/model/server/memory.dart';
import 'package:server_box/data/model/server/server.dart';
import 'package:server_box/data/provider/server/single.dart';
import 'package:server_box/data/res/status.dart';
import 'package:server_box/data/res/store.dart';
import 'package:server_box/data/store/private_key.dart';
import 'package:server_box/data/store/server.dart';
import 'package:server_box/data/store/setting.dart';
import 'package:server_box/generated/l10n/l10n.dart';
import 'package:server_box/view/page/server/detail/view.dart';
import 'package:server_box/view/widget/server_func_btns.dart';

import '../helpers/spi_fixture.dart';
import '../helpers/test_db.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const sid = 'srv-states';
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
    Stores.setting.serverStatusUpdateInterval.put(0);
    Stores.server.put(spi);
  });

  tearDown(() async {
    await getIt.reset();
    await SqliteDb.close();
  });

  Future<ServerNotifier> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          localizationsDelegates: const [
            LibLocalizations.delegate,
            ...AppLocalizations.localizationsDelegates,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          builder: ResponsivePoints.builder,
          home: Builder(
            builder: (context) {
              app_locale.l10n = AppLocalizations.of(context)!;
              context.setLibL10n();
              return ServerDetailPage(args: SpiRequiredArgs(spi));
            },
          ),
        ),
      ),
    );
    addTearDown(() => tester.pumpWidget(const SizedBox.shrink()));

    return ProviderScope.containerOf(
      tester.element(find.byType(ServerDetailPage)),
    ).read(serverProvider(sid).notifier);
  }

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  testWidgets('connecting draws the rows it is waiting for', (tester) async {
    final notifier = await pump(tester);
    notifier.updateConnection(ServerConn.connecting);
    await settle(tester);

    expect(tester.takeException(), isNull);
    // The five every machine has, with no values yet — not a spinner in place
    // of the page.
    expect(find.text('CPU'), findsWidgets);
    expect(find.text(libL10n.memory), findsWidgets);
    expect(find.text('Swap'), findsWidgets);
    expect(find.text(libL10n.net), findsWidgets);
    expect(find.text(app_locale.l10n.waitingFirstSample), findsOneWidget);
    // And a progress line saying the first answer is on its way.
    expect(find.byType(LinearProgressIndicator), findsWidgets);
  });

  testWidgets('a disconnected server says so and keeps its row of tools', (
    tester,
  ) async {
    await pump(tester);
    await settle(tester);

    expect(tester.takeException(), isNull);
    expect(find.text(libL10n.empty), findsOneWidget);
    expect(find.text(libL10n.retry), findsOneWidget);
    // The entries stay where they are, all of them unusable: what cannot be
    // done through a connection that is not there is all of it.
    final bar = tester.widget<ServerFuncBtns>(find.byType(ServerFuncBtns));
    expect(bar.btns, isNotEmpty);
    expect(bar.btns.every((e) => !e.available), isTrue);
  });

  /// One reading failing is not the page failing. The row that has no number
  /// says why it has none, in the machine's own words, and the nine that
  /// worked are untouched.
  testWidgets('a section that failed to parse says so in its own row', (
    tester,
  ) async {
    final notifier = await pump(tester);

    final status = InitStatus.status;
    status.more[StatusCmdType.host] = 'test-host';
    status.mem = const Memory(total: 134217728, free: 8388608, avail: 16777216);
    status.sectionErrs['mem'] = 'sensors: command not found';
    notifier.updateStatus(status);
    await settle(tester);

    expect(tester.takeException(), isNull);
    expect(find.text(app_locale.l10n.unavailable), findsOneWidget);
    expect(find.text('sensors: command not found'), findsOneWidget);
    // The CPU row still has its reading.
    expect(find.text('CPU'), findsWidgets);
    expect(find.textContaining('%'), findsWidgets);
  });

  testWidgets('readings nobody should act on say when they were taken', (
    tester,
  ) async {
    final notifier = await pump(tester);

    final status = InitStatus.status;
    status.more[StatusCmdType.host] = 'test-host';
    status.mem = const Memory(total: 134217728, free: 8388608, avail: 16777216);
    // Two samples, both from long enough ago that nothing on this page is
    // current — what a backgrounded app comes back to.
    final old = DateTime.now().subtract(const Duration(minutes: 9));
    for (var i = 0; i < 2; i++) {
      status.history.add(
        timeMs: old.add(Duration(seconds: i)).millisecondsSinceEpoch,
        cpu: 2 + i.toDouble(),
        mem: 30 + i.toDouble(),
      );
    }
    notifier.updateStatus(status);
    await settle(tester);

    expect(tester.takeException(), isNull);
    // Said at the top of the page, once, with the way to ask again.
    expect(find.textContaining(RegExp(r'Everything below is from')), findsOneWidget);
    expect(find.text(libL10n.refresh), findsOneWidget);
    // And in the rows, where the note is the timestamp rather than what the
    // figure is of.
    expect(find.textContaining(RegExp(r'^at \d')), findsWidgets);
    // The chart stops where the samples do, and says so.
    expect(find.text(app_locale.l10n.noData), findsOneWidget);
  });
}
