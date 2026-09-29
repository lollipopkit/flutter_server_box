/// A server's name flies from its card to the detail page's bar when opening
/// the card pushes a page — the narrow layout — and does not exist as a hero
/// where the card grows in place.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:server_box/view/page/server/card/name_hero.dart';

void main() {
  testWidgets('the name flies between the card and the pushed page', (
    tester,
  ) async {
    final nav = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: nav,
        home: const Scaffold(
          body: ServerNameHero(
            id: 'a',
            enabled: true,
            child: Text('web-01', style: TextStyle(fontSize: 15)),
          ),
        ),
      ),
    );
    nav.currentState!.push(
      MaterialPageRoute<void>(
        builder: (_) => Scaffold(
          appBar: AppBar(
            title: const ServerNameHero(
              id: 'a',
              enabled: true,
              child: Text('web-01', style: TextStyle(fontSize: 20)),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    // In flight: the shuttle, and only the shuttle, scales the two names it
    // crossfades — one FittedBox each.
    expect(find.byType(FittedBox), findsNWidgets(2));
    expect(tester.takeException(), isNull);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byType(FittedBox), findsNothing, reason: 'landed');

    nav.currentState!.pop();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(FittedBox), findsNWidgets(2), reason: 'flying back');
    expect(tester.takeException(), isNull);
    await tester.pumpAndSettle();
    expect(find.text('web-01'), findsOneWidget);
  });

  testWidgets('disabled, there is no hero', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: ServerNameHero(id: 'a', enabled: false, child: Text('web-01')),
      ),
    );
    expect(find.byType(Hero), findsNothing);
  });

  testWidgets('with less motion asked for, there is no hero', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(disableAnimations: true),
          child: ServerNameHero(id: 'a', enabled: true, child: Text('web-01')),
        ),
      ),
    );
    expect(find.byType(Hero), findsNothing);
    expect(find.text('web-01'), findsOneWidget);
  });
}
