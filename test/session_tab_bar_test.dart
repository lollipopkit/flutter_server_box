import 'package:fl_lib/fl_lib.dart';
import 'package:fl_lib/generated/l10n/lib_l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The line above the terminal and file tabs, and the sheet behind it.
///
/// It replaced a strip of fixed-width tabs that gave each name about six
/// characters, so what is asserted here is the opposite of what that strip
/// did: the whole current name is on screen, and everything else is one tap
/// away rather than crushed beside it.
void main() {
  const names = ['Add', 'prod-db-01', 'staging', 'nas'];

  Future<void> pump(
    WidgetTester tester, {
    required int index,
    void Function(int)? onTap,
    void Function(int)? onClose,
    String? Function(int)? detailOf,
    List<Widget> sessionActions = const [],
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 800);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: const [LibLocalizations.delegate],
        supportedLocales: LibLocalizations.supportedLocales,
        home: Scaffold(
          appBar: SessionTabBar(
            names: names,
            index: index,
            onTap: onTap ?? (_) {},
            onClose: onClose ?? (_) {},
            detailOf: detailOf,
            sessionActions: sessionActions,
            leadingActions: const [],
          ),
          body: const SizedBox.shrink(),
        ),
      ),
    );
    addTearDown(() => tester.pumpWidget(const SizedBox.shrink()));
  }

  /// Counted out rather than settled — a sheet animating in is a frame always
  /// scheduled until it lands, and `pumpAndSettle` waits ten minutes on a tree
  /// that never goes quiet.
  Future<void> settle(WidgetTester tester, [int frames = 8]) async {
    for (var i = 0; i < frames; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  testWidgets('the whole name is on the line, with its position', (
    tester,
  ) async {
    await pump(tester, index: 1);

    // Not "prod-d…", which is all the strip before it had room for.
    expect(find.text('prod-db-01'), findsOneWidget);
    // Three sessions, and the leading tab is not one of them. Rich, because
    // the total is set lighter than the position — one fact, not two numbers.
    expect(find.text('1/3', findRichText: true), findsOneWidget);
    // The others are in the sheet, not on the line.
    expect(find.text('staging'), findsNothing);
    expect(find.text('nas'), findsNothing);
  });

  testWidgets('the line is shorter than the strip it replaced', (tester) async {
    await pump(tester, index: 1);

    expect(SessionTabBar.height, lessThan(48));
    expect(tester.getSize(find.byType(SessionTabBar)).height, SessionTabBar.height);
  });

  testWidgets('the ripple is the name, not the row', (tester) async {
    // The shortest name there is, so a row left at `MainAxisSize.max` — which
    // would take everything the actions had not claimed, around 350 — is
    // unmistakable next to one that hugs its contents.
    await pump(tester, index: 3, sessionActions: const [Icon(Icons.abc)]);

    final ink = tester.getSize(find.byType(InkWell).first);
    expect(ink.width, lessThan(200));
  });

  testWidgets('the sheet lists every session, with where it is', (
    tester,
  ) async {
    await pump(
      tester,
      index: 1,
      detailOf: (i) => switch (i) {
        1 => '10.0.0.4',
        2 => '10.0.0.5',
        _ => null,
      },
    );

    await tester.tap(find.text('prod-db-01'));
    await settle(tester);

    for (final name in ['prod-db-01', 'staging', 'nas']) {
      expect(find.text(name), findsWidgets, reason: name);
    }
    expect(find.text('10.0.0.4'), findsOneWidget);
    expect(find.text('10.0.0.5'), findsOneWidget);
    // And the way to a new one, last: a list of what is open opens on what is
    // open.
    expect(find.text('Add'), findsOneWidget);
  });

  testWidgets('picking a row selects it, by position', (tester) async {
    final picked = <int>[];
    await pump(tester, index: 1, onTap: picked.add);

    await tester.tap(find.text('prod-db-01'));
    await settle(tester);
    await tester.tap(find.text('nas'));
    await settle(tester);

    // 3, not 2: the leading tab is index 0 and the page indexes it the same
    // way.
    expect(picked, [3]);
    // Acted on with the sheet gone — it drew a snapshot, and closing a session
    // renumbers what it drew.
    expect(find.text('staging'), findsNothing);
  });

  testWidgets('picking the one already showing does nothing', (tester) async {
    final picked = <int>[];
    await pump(tester, index: 1, onTap: picked.add);

    await tester.tap(find.text('prod-db-01'));
    await settle(tester);
    await tester.tap(find.text('prod-db-01').last);
    await settle(tester);

    expect(picked, isEmpty);
  });

  testWidgets('closing is the row\'s own button, and asks the page', (
    tester,
  ) async {
    final closed = <int>[];
    final picked = <int>[];
    await pump(tester, index: 1, onTap: picked.add, onClose: closed.add);

    await tester.tap(find.text('prod-db-01'));
    await settle(tester);
    await tester.tap(find.byTooltip(libL10n.close).at(1));
    await settle(tester);

    // The second session's row, and only a close — a tap on the ✕ is not also
    // a tap on the row it sits in.
    expect(closed, [2]);
    expect(picked, isEmpty);
  });
}
