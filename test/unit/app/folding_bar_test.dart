import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/view/widget/folding_bar.dart';

/// [FoldingBar]: the label keeps its width, the buttons fold into a menu,
/// and nothing overflows down to the narrowest list column.
void main() {
  final taps = <String>[];
  final actions = [
    for (final (icon, label) in [
      (Icons.search, 'Search'),
      (Icons.refresh, 'Refresh'),
      (Icons.add, 'New'),
    ])
      BarAction(icon: icon, label: label, onTap: () => taps.add(label)),
  ];

  Future<void> pump(WidgetTester tester, double width) => tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: width,
            height: 40,
            child: FoldingBar(
              label: const SessionSwitcherLabel(
                name: 'pve',
                position: 1,
                total: 2,
                onTap: _noop,
              ),
              actions: actions,
            ),
          ),
        ),
      ),
    ),
  );

  setUp(taps.clear);

  testWidgets('a button is as wide as the slot it is counted as', (tester) async {
    await pump(tester, 600);
    expect(tester.getSize(find.byType(Btn).first).width, FoldingBar.slot);
  });

  testWidgets('with room, every button; narrow, the rest behind a menu', (
    tester,
  ) async {
    await pump(tester, 600);
    expect(find.byType(Btn), findsNWidgets(3));
    expect(find.byIcon(Icons.more_vert), findsNothing);

    // Just enough for all three beside the label.
    await pump(tester, 104 + 3 * FoldingBar.slot);
    expect(find.byType(Btn), findsNWidgets(3));
    expect(find.byIcon(Icons.more_vert), findsNothing);

    // Short of the third slot: the menu takes the second, so one button and
    // the menu for the other two.
    await pump(tester, 104 + 3 * FoldingBar.slot - 1);
    expect(find.byType(Btn), findsOneWidget);
    expect(find.byIcon(Icons.more_vert), findsOneWidget);

    // The narrowest the list column drags to (`minListWidth`): room for one
    // slot, which the menu takes.
    await pump(tester, 160);
    expect(tester.takeException(), isNull);
    expect(find.byType(Btn), findsNothing);
    expect(find.byIcon(Icons.more_vert), findsOneWidget);
    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.text('New'));
    await tester.pumpAndSettle();
    expect(taps, ['New']);
  });
}

void _noop() {}
