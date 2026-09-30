import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:server_box/view/widget/nav_bar.dart';
import 'package:server_box/view/widget/nav_rail.dart';

NavRailItem _item(String label) => NavRailItem(
  icon: const Icon(Icons.circle_outlined),
  selectedIcon: const Icon(Icons.circle),
  label: label,
);

void main() {
  late int tapped;
  late int trailingTaps;

  Future<void> pump(WidgetTester tester, {required int selected}) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          bottomNavigationBar: AppNavBar(
            selectedIndex: selected,
            onSelected: (i) => tapped = i,
            items: [_item('a'), _item('b'), _item('c')],
            trailing: _item('more'),
            onTrailingTap: () => trailingTaps++,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  setUp(() {
    tapped = -1;
    trailingTaps = 0;
  });

  testWidgets('the trailing button sits against the right edge', (
    tester,
  ) async {
    await pump(tester, selected: 0);
    // At the default text size, the height it has always had.
    expect(
      tester.getSize(find.byType(AppNavBar)).height,
      NavBarMetrics.height,
    );
    final more = tester.getRect(find.bySemanticsLabel('more'));
    expect(more.right, 400);
    expect(more.width, NavBarMetrics.trailingWidth);
    // The tabs share what is left, rather than the button taking a share.
    final a = tester.getRect(find.bySemanticsLabel('a'));
    expect(a.width, closeTo((400 - NavBarMetrics.trailingWidth) / 3, 0.01));
  });

  testWidgets('only the selected tab shows its name', (tester) async {
    await pump(tester, selected: 1);
    expect(find.text('b').hitTestable(), findsOneWidget);
    expect(find.text('a').hitTestable(), findsNothing);
  });

  testWidgets('a selection past the tabs lights none of them', (tester) async {
    // What is open is behind "more", which is a button and not a place.
    await pump(tester, selected: 3);
    for (final label in ['a', 'b', 'c', 'more']) {
      expect(find.text(label).hitTestable(), findsNothing, reason: label);
    }
    expect(
      tester.getSemantics(find.bySemanticsLabel('a')),
      isSemantics(isSelected: false),
    );
  });

  testWidgets('grows with large text rather than overflowing', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(400, 800),
            textScaler: TextScaler.linear(2.5),
          ),
          child: Scaffold(
            bottomNavigationBar: AppNavBar(
              selectedIndex: 0,
              onSelected: (_) {},
              items: [_item('a'), _item('b')],
              trailing: _item('more'),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    // An overflow is an exception in a test, so the pump is most of this.
    expect(tester.takeException(), isNull);
    final bar = tester.getSize(find.byType(AppNavBar)).height;
    expect(bar, greaterThan(NavBarMetrics.height));
    // The selected label is laid out whole, inside the bar.
    final label = tester.getRect(find.text('a'));
    expect(label.bottom, lessThanOrEqualTo(800));
  });

  testWidgets('taps reach the tab and the button', (tester) async {
    await pump(tester, selected: 0);
    await tester.tap(find.bySemanticsLabel('c'));
    expect(tapped, 2);
    await tester.tap(find.bySemanticsLabel('more'));
    expect(trailingTaps, 1);
    expect(tapped, 2);
  });
}
