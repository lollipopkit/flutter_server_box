import 'package:fl_lib/generated/l10n/lib_l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/data/model/app/menu/server_func.dart';
import 'package:server_box/generated/l10n/l10n.dart';
import 'package:server_box/view/widget/server_func_btns.dart';

import '../helpers/spi_fixture.dart';

/// The function row is a list, not a picture of one.
///
/// It outlives the machine it acts on — the server tab floats one over every
/// machine it opens — so a machine that cannot serve one of the entries takes
/// that entry out of the row and puts it back at the end. What that has to
/// look like is a list being taken from and added to: the place closes, the
/// entries after it slide up, and a place opens where it lands.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final spi = spiFixture(id: 'srv', name: 'web', ip: 'h', user: 'u');

  List<ServerFuncEntry> entries(List<ServerFuncBtn> btns, {Set<ServerFuncBtn> off = const {}}) => [
    for (final btn in btns) (btn: btn, available: !off.contains(btn)),
  ];

  Future<void> pump(WidgetTester tester, List<ServerFuncEntry> btns) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          localizationsDelegates: const [
            LibLocalizations.delegate,
            ...AppLocalizations.localizationsDelegates,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: 600,
                height: kFuncBarHeight,
                child: ServerFuncBtns(spi: spi, btns: btns),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// The place one entry holds in the row, which is what opens and closes.
  /// The icon inside it keeps its own size and is clipped, so measuring that
  /// says nothing about how far along the movement is.
  Rect slot(WidgetTester tester, ServerFuncBtn btn) => tester.getRect(
    find.ancestor(
      of: find.byIcon(btn.icon),
      matching: find.byType(SizeTransition),
    ),
  );

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  const all = [
    ServerFuncBtn.terminal,
    ServerFuncBtn.files,
    ServerFuncBtn.process,
  ];

  testWidgets('the row does not deal itself out when it first appears', (
    tester,
  ) async {
    await pump(tester, entries(all));
    await tester.pump();

    // Every entry at its full width on the first frame. A list animation on
    // arrival would mean the bar playing itself in once per machine opened.
    final first = [for (final btn in all) slot(tester, btn)];
    await settle(tester);
    expect([for (final btn in all) slot(tester, btn)], first);
  });

  testWidgets('an entry that goes closes its place, and the rest slide up', (
    tester,
  ) async {
    await pump(tester, entries(all));
    await settle(tester);

    final full = slot(tester, ServerFuncBtn.files);
    final before = tester.getRect(find.byIcon(ServerFuncBtn.process.icon)).left;

    // The middle one is taken out.
    await pump(tester, entries(const [
      ServerFuncBtn.terminal,
      ServerFuncBtn.process,
    ]));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // Still there, part way closed rather than gone between two frames.
    final closing = slot(tester, ServerFuncBtn.files);
    expect(closing.width, greaterThan(0));
    expect(closing.width, lessThan(full.width));
    // And what was after it has started moving into the room it is giving up.
    final moving = tester.getRect(find.byIcon(ServerFuncBtn.process.icon)).left;
    expect(moving, lessThan(before));

    await settle(tester);
    expect(find.byIcon(ServerFuncBtn.files.icon), findsNothing);
    expect(
      tester.getRect(find.byIcon(ServerFuncBtn.process.icon)).left,
      lessThan(moving),
    );
  });

  testWidgets('and one that arrives opens a place for itself', (tester) async {
    await pump(tester, entries(const [ServerFuncBtn.terminal]));
    await settle(tester);

    await pump(tester, entries(all));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    final opening = slot(tester, ServerFuncBtn.files);
    expect(opening.width, greaterThan(0));
    await settle(tester);
    expect(slot(tester, ServerFuncBtn.files).width, greaterThan(opening.width));
    expect(find.byIcon(ServerFuncBtn.process.icon), findsOneWidget);
  });

  testWidgets('an entry asked for again while it is going turns around', (
    tester,
  ) async {
    await pump(tester, entries(all));
    await settle(tester);

    await pump(tester, entries(const [
      ServerFuncBtn.terminal,
      ServerFuncBtn.process,
    ]));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byIcon(ServerFuncBtn.files.icon), findsOneWidget);

    // Back before it finished leaving: it opens back up from where it had got
    // to rather than being built afresh at nothing.
    await pump(tester, entries(all));
    await settle(tester);
    expect(find.byIcon(ServerFuncBtn.files.icon), findsOneWidget);
    expect(
      tester.getRect(find.byIcon(ServerFuncBtn.files.icon)).left,
      lessThan(tester.getRect(find.byIcon(ServerFuncBtn.process.icon)).left),
    );
  });

  testWidgets('an entry that only loses what it can do keeps its place', (
    tester,
  ) async {
    await pump(tester, entries(all));
    await settle(tester);
    final at = slot(tester, ServerFuncBtn.files);

    await pump(tester, entries(all, off: const {ServerFuncBtn.files}));
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 40));
      expect(slot(tester, ServerFuncBtn.files), at);
    }
  });
}
