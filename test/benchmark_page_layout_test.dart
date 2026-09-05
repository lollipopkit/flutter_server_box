/// Where the benchmark configuration's rows start on the left.
///
/// The column mixes three kinds of row — a `SwitchListTile`, a `ListTile` with
/// a dropdown, and a text field that is neither — and each of them derives its
/// text position differently. `ListTile` takes its from `minLeadingWidth` and
/// `horizontalTitleGap`, both of which fall back to theme values; `Input` wraps
/// itself in a `CardX` with padding of its own unless told not to. So three
/// left edges appeared where there should be one, and nothing in the type
/// system or the analyzer had anything to say about it.
///
/// Asserted by measuring what was rendered rather than by comparing against the
/// constants the page uses, which would only prove the page agrees with itself.
library;

import 'dart:io';

import 'package:fl_lib/fl_lib.dart';
import 'package:fl_lib/generated/l10n/lib_l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/data/res/store.dart';
import 'package:server_box/data/store/private_key.dart';
import 'package:server_box/data/store/server.dart';
import 'package:server_box/data/store/setting.dart';
import 'package:server_box/generated/l10n/l10n.dart';
import 'package:server_box/view/page/benchmark/tab.dart';

import 'helpers/spi_fixture.dart';
import 'helpers/test_db.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const sid = 'srv-bench-1';
  final spi = spiFixture(
    id: sid,
    name: 'web',
    ip: 'h',
    user: 'u',
    autoConnect: false,
  );
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('server-box-bench-');
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

  Future<void> pumpPage(WidgetTester tester) async {
    // Tall enough that every row is built: a `ListView` only lays out what is
    // on screen, and the rows this is about are the ones at the bottom.
    //
    // The view, not `setSurfaceSize` — that changes layout without changing
    // what `MediaQuery` reports.
    tester.view.physicalSize = const Size(1200, 2400);
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
          home: const BenchmarkTabPage(),
        ),
      ),
    );
    // Never `pumpAndSettle`: the page keeps a one-second timer for the elapsed
    // clock and holds text fields with blinking cursors, so nothing ever
    // settles and it would only give up after its ten-minute default.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    // Pumped away so the timer is cancelled before the binding checks for
    // pending ones.
    addTearDown(() => tester.pumpWidget(const SizedBox.shrink()));
  }

  /// The leftmost edge of anything rendering [text].
  ///
  /// Leftmost because a row can render its label twice — the Geekbench version
  /// appears as the row's title and again inside the dropdown that sits at its
  /// trailing edge — and it is the title whose position is the subject here.
  double leftEdgeOf(WidgetTester tester, String text) {
    final finder = find.text(text);
    expect(finder, findsWidgets, reason: 'no row rendered "$text"');
    return tester
        .widgetList<Text>(finder)
        .map((w) => tester.getTopLeft(find.byWidget(w)).dx)
        .reduce((a, b) => a < b ? a : b);
  }

  testWidgets('every option starts on one left edge', (tester) async {
    await pumpPage(tester);

    // Geekbench is off by default, so its version row is not in the tree.
    // Switched on here because a sub-option that only exists in one state is
    // exactly the kind that gets left behind by a layout change.
    await tester.tap(find.text('CPU'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    final rows = {
      // Top level, each with an icon.
      'disk': libL10n.disk,
      'network': libL10n.network,
      'cpu': 'CPU',
      'ipInfo': l10n.benchmarkIpInfo,
      'preferBin': l10n.benchmarkPreferBin,
      'workDir': l10n.benchmarkWorkDir,
      // Sub-options, which reserve the icon column instead of filling it.
      'reducedNetwork': l10n.benchmarkReducedNetwork,
      'geekbenchVersion': 'Geekbench 6',
      'customIperf': l10n.benchmarkCustomIperf,
    };

    final edges = {
      for (final entry in rows.entries)
        entry.key: leftEdgeOf(tester, entry.value),
    };

    final expected = edges['disk']!;
    for (final entry in edges.entries) {
      expect(
        entry.value,
        moreOrLessEquals(expected, epsilon: 0.5),
        reason:
            '"${rows[entry.key]}" starts at ${entry.value}, but the first row '
            'starts at $expected. Every row in this column shares one text '
            'edge; see the geometry constants on the page.',
      );
    }
  });

  testWidgets('an icon sits left of the text, in its own column', (
    tester,
  ) async {
    await pumpPage(tester);

    final textEdge = leftEdgeOf(tester, libL10n.disk);
    final iconEdge = tester.getTopLeft(find.byIcon(Icons.storage)).dx;

    expect(
      iconEdge,
      lessThan(textEdge),
      reason: 'the icon column is to the left of the text column',
    );
    // The gap is the icon plus the space after it. A sub-option reserves
    // exactly this much and draws nothing in it, which is what keeps its text
    // on the same edge as a row that has an icon.
    expect(textEdge - iconEdge, moreOrLessEquals(40, epsilon: 0.5));
  });

  testWidgets('a text field is not a card inside the card', (tester) async {
    await pumpPage(tester);

    // `Input` wraps itself in a `CardX` unless told not to, which is what put
    // the two text fields on a left edge of their own. One card for the whole
    // options column, and no others inside it.
    final field = find.ancestor(
      of: find.text(l10n.benchmarkWorkDir),
      matching: find.byType(CardX),
    );
    expect(
      tester.widgetList(field),
      hasLength(1),
      reason: 'the field is wrapped in a card of its own',
    );
  });
}
