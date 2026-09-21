/// The states the detail page has to be legible in besides "a machine that is
/// answering": before the first sample, after the answers stopped, and when
/// there is nothing to show at all.
///
/// Each of them used to be the same placeholder. What matters here is that the
/// page says which one it is in — a page waiting for its first answer must not
/// read like one whose server is gone — and that a figure nobody should act on
/// says when it was taken.
library;

import 'package:fl_chart/fl_chart.dart';
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
import 'package:server_box/data/model/server/server_private_info.dart';
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

  /// The page is a widget, not a route: choosing another server in a pane
  /// hands the same state a different one, and everything on it that belongs
  /// to a particular machine has to go with it.
  testWidgets('another server is another page, not this one with new numbers', (
    tester,
  ) async {
    const other = 'srv-states-2';
    final otherSpi = spiFixture(
      id: other,
      name: 'db',
      ip: 'h2',
      user: 'u',
      autoConnect: false,
    );
    Stores.server.put(otherSpi);

    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final shown = ValueNotifier<Spi>(spi);
    addTearDown(shown.dispose);
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
              return ValueListenableBuilder(
                valueListenable: shown,
                builder: (_, spi, _) =>
                    ServerDetailPage(args: SpiRequiredArgs(spi)),
              );
            },
          ),
        ),
      ),
    );
    addTearDown(() => tester.pumpWidget(const SizedBox.shrink()));

    final container = ProviderScope.containerOf(
      tester.element(find.byType(ServerDetailPage)),
    );

    final first = InitStatus.status;
    first.more[StatusCmdType.host] = 'first-host';
    container.read(serverProvider(sid).notifier).updateStatus(first);
    await settle(tester);
    expect(find.text('first-host'), findsOneWidget);

    // The same state, a different machine.
    final state = tester.state(find.byType(ServerDetailPage));
    shown.value = otherSpi;
    await settle(tester);

    expect(
      tester.state(find.byType(ServerDetailPage)),
      same(state),
      reason: 'the page was rebuilt rather than reused; this proves nothing',
    );
    expect(tester.takeException(), isNull);
    expect(
      find.text('first-host'),
      findsNothing,
      reason: "the previous machine's readings stayed on the new one's page",
    );
  });

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

  testWidgets('and drawn in full, says it where the chart would be', (
    tester,
  ) async {
    // It was the machine's words in grey monospace, centred in a box the
    // height of the chart they replaced — 216 points with one line in the
    // middle, which reads as a chart that has not loaded rather than as
    // something having gone wrong. That it failed, what was said, what to do
    // and the way to all of it, from the left and as tall as they are.
    final notifier = await pump(tester);

    Rect focus() => tester.getRect(
      find
          .ancestor(
            of: find.text(libL10n.memory).first,
            matching: find.byType(CardX),
          )
          .first,
    );

    final working = InitStatus.status;
    working.more[StatusCmdType.host] = 'test-host';
    working.mem = const Memory(total: 134217728, free: 8388608, avail: 16777216);
    notifier.updateStatus(working);
    await settle(tester);
    await tester.tap(find.text(libL10n.memory).first);
    await settle(tester);
    final whole = focus().height;

    Future<void> fail(String said) async {
      final failed = InitStatus.status;
      failed.more[StatusCmdType.host] = 'test-host';
      failed.sectionErrs['mem'] = said;
      notifier.updateStatus(failed);
      await settle(tester);
      await settle(tester);
    }

    // What a missing command says is one line, and the card is shorter for it
    // than it is round a chart.
    await fail('cat: /proc/meminfo: Permission denied');
    expect(focus().height, lessThan(whole));

    const said = 'Traceback (most recent call last):\n'
        '  File "status.py", line 12, in mem\n'
        '  File "status.py", line 40, in read\n'
        '  File "status.py", line 44, in open\n'
        'PermissionError: /proc/meminfo';
    await fail(said);

    expect(tester.takeException(), isNull);
    final title = find.text(libL10n.fail);
    expect(title, findsOneWidget);
    expect(
      tester.widget<Text>(title).style?.color,
      Theme.of(tester.element(title)).colorScheme.error,
    );
    // From the left, under the number — not centred in a chart's worth.
    expect(
      tester.getRect(title).left,
      lessThan(tester.getRect(find.byType(ServerDetailPage)).width / 3),
    );
    expect(find.text(app_locale.l10n.metricUnavailableTip), findsOneWidget);
    // Cut to a few lines on the card, whatever it ran to.
    expect(tester.widget<Text>(find.text(said).first).maxLines, 4);

    // All of what was said is a press away, where it can be copied: the card
    // cuts it to a few lines, and the last of a traceback is the useful one.
    await tester.tap(find.text(app_locale.l10n.viewError));
    await settle(tester);
    expect(find.byType(SelectableText), findsOneWidget);
    expect(
      tester.widget<SelectableText>(find.byType(SelectableText)).data,
      said,
    );
    await tester.tap(find.text(libL10n.close));
    await settle(tester);
    expect(find.byType(SelectableText), findsNothing);
    // The page under the dialog is still the page.
    expect(find.byType(ServerDetailPage), findsOneWidget);
  });

  /// A row that vanishes says this machine has no memory. The five every
  /// machine has stay where they are and say what happened to the reading.
  testWidgets('a failed section keeps its row even with no reading', (
    tester,
  ) async {
    final notifier = await pump(tester);

    final status = InitStatus.status;
    status.more[StatusCmdType.host] = 'test-host';
    status.sectionErrs['mem'] = 'cat: /proc/meminfo: Permission denied';
    notifier.updateStatus(status);
    await settle(tester);

    expect(tester.takeException(), isNull);
    expect(find.text(libL10n.memory), findsWidgets);
    expect(find.text(app_locale.l10n.unavailable), findsWidgets);
    expect(find.text('cat: /proc/meminfo: Permission denied'), findsWidgets);
  });

  /// A card that hides when it is empty answers "this machine has none of
  /// these", which is the wrong answer when the command is simply not there.
  testWidgets('a card whose command failed is drawn, saying why', (
    tester,
  ) async {
    final notifier = await pump(tester);

    final status = InitStatus.status;
    status.more[StatusCmdType.host] = 'test-host';
    status.sectionErrs['sensors'] = 'sh: 1: sensors: not found';
    notifier.updateStatus(status);
    await settle(tester);

    expect(tester.takeException(), isNull);
    expect(find.text(libL10n.sensors), findsOneWidget);
    expect(find.text('sh: 1: sensors: not found'), findsWidgets);
    expect(find.text(app_locale.l10n.metricUnavailableTip), findsOneWidget);
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
    final said = find.textContaining(RegExp(r'Everything below is from'));
    expect(said, findsOneWidget);
    expect(find.text(libL10n.refresh), findsOneWidget);
    // In a card about as tall as the way to ask again, which is the tallest
    // thing in it. That was a `TextButton`, held to 48 on a phone, with 9
    // more over and under it: 66 points of card round one line of text.
    final card = tester.getRect(
      find.ancestor(of: said, matching: find.byType(CardX)).first,
    );
    final line = tester.getRect(said);
    // Its own margin included, which is 4 on each side.
    expect(card.height, lessThan(56));
    // And the sentence is in the middle of it, not over a gap.
    expect(
      line.center.dy,
      moreOrLessEquals(card.center.dy, epsilon: 1),
    );
    // And in the rows, where the note is the timestamp rather than what the
    // figure is of.
    expect(find.textContaining(RegExp(r'^at \d')), findsWidgets);
    // The chart stops where the samples do, and says so.
    final band = find.text(app_locale.l10n.noData);
    expect(band, findsOneWidget);

    // And the band is where the gap is. The samples span a couple of seconds
    // nine minutes ago, so the window is nine minutes of which all but the
    // first moments are empty: a band drawn from the samples' own extent, or
    // across the whole plot, lands somewhere else entirely.
    final chart = find.byType(LineChart);
    final plot = tester.getRect(chart.first);
    // The band itself, not its label: the label is centred in it and says
    // nothing about where it starts.
    final rect = tester.getRect(
      find.ancestor(of: band, matching: find.byType(DecoratedBox)).first,
    );
    expect(
      rect.left,
      lessThan(plot.left + plot.width * 0.25),
      reason: 'the band should start where the samples stop, near the left',
    );
    expect(
      rect.right,
      closeTo(plot.right, plot.width * 0.2),
      reason: 'the band should run to the end of the window',
    );
  });
}
