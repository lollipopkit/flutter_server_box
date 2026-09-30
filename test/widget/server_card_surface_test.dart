import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:server_box/view/page/server/card/chart_hero.dart';
import 'package:server_box/view/page/server/metric_row.dart';

const _side = BorderSide(color: Color(0xFFFF0000), width: 2);

void main() {
  group('FadingCard', () {
    // A theme whose cards are outlined, as some store themes are.
    Future<BorderSide> sideAt(
      WidgetTester tester,
      double outline, {
      BorderRadius? radius,
    }) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(
            cardTheme: const CardThemeData(
              shape: RoundedRectangleBorder(side: _side),
            ),
          ),
          home: FadingCard(
            outline: outline,
            radius: radius,
            child: const SizedBox(width: 10, height: 10),
          ),
        ),
      );
      final material = tester.widget<Material>(
        find.descendant(
          of: find.byType(FadingCard),
          matching: find.byType(Material),
        ),
      );
      // Drawn as asked, with no easing of its own behind the movement.
      expect(material.animationDuration, Duration.zero);
      return (material.shape! as RoundedRectangleBorder).side;
    }

    testWidgets('has no outline while it has no surface', (tester) async {
      // The card on its way to being the page: its colour has gone, and its
      // frame used to stay round the whole content area.
      expect((await sideAt(tester, 0)).color.a, 0);
      expect((await sideAt(tester, 0, radius: BorderRadius.zero)).color.a, 0);
    });

    testWidgets("has the theme's whole outline with its whole surface", (
      tester,
    ) async {
      expect(await sideAt(tester, 1), _side);
      expect(await sideAt(tester, 1, radius: BorderRadius.zero), _side);
      expect((await sideAt(tester, 0.5)).color.a, closeTo(0.5, 0.01));
    });
  });

  group('ServerChartHero', () {
    Widget chart({required bool enabled}) => ServerChartHero(
      id: 's',
      enabled: enabled,
      child: const SizedBox(width: 100, height: 40),
    );

    testWidgets('is a hero only on a push, and only with motion', (
      tester,
    ) async {
      await tester.pumpWidget(MaterialApp(home: chart(enabled: false)));
      expect(find.byType(Hero), findsNothing);

      await tester.pumpWidget(MaterialApp(home: chart(enabled: true)));
      expect(find.byType(Hero), findsOneWidget);

      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(disableAnimations: true),
            child: chart(enabled: true),
          ),
        ),
      );
      expect(find.byType(Hero), findsNothing);
    });

    testWidgets('flies from the card to the page', (tester) async {
      final nav = GlobalKey<NavigatorState>();
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: nav,
          home: Scaffold(body: Center(child: chart(enabled: true))),
        ),
      );
      nav.currentState!.push(
        MaterialPageRoute<void>(
          builder: (_) => const Scaffold(
            body: Align(
              alignment: Alignment.topCenter,
              child: ServerChartHero(
                id: 's',
                enabled: true,
                child: SizedBox(width: 300, height: 180),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      // Mid-flight, the two ends crossfade in one box between their sizes.
      final flight = tester.getSize(find.byType(FittedBox).first);
      expect(flight.width, inExclusiveRange(100, 300));
      expect(flight.height, inExclusiveRange(40, 180));
      await tester.pumpAndSettle();
      expect(find.byType(FittedBox), findsNothing);
    });
  });
}
