/// Stepping from one machine to the next slides the pages the way the list
/// went — and with less motion asked for, only crossfades them.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:server_box/view/page/server/card/swap.dart';

Widget _swap(String id, {required bool reduce}) => MaterialApp(
  home: MediaQuery(
    data: MediaQueryData(disableAnimations: reduce),
    child: DirectionalSwap(
      id: id,
      direction: 1,
      duration: const Duration(milliseconds: 300),
      child: Text(id),
    ),
  ),
);

Finder _inSwap(Type type) => find.descendant(
  of: find.byType(DirectionalSwap),
  matching: find.byType(type),
);

List<Offset> _shifts(WidgetTester tester) => tester
    .widgetList<FractionalTranslation>(_inSwap(FractionalTranslation))
    .map((w) => w.translation)
    .toList();

void main() {
  testWidgets('the pages travel the way the list went', (tester) async {
    await tester.pumpWidget(_swap('a', reduce: false));
    await tester.pumpWidget(_swap('b', reduce: false));
    await tester.pump(const Duration(milliseconds: 50));
    final shifts = _shifts(tester);
    expect(shifts, hasLength(2));
    expect(shifts.any((o) => o.dx != 0), isTrue);
    await tester.pumpAndSettle();
    expect(find.text('a'), findsNothing);
  });

  testWidgets('with less motion asked for, they only fade', (tester) async {
    await tester.pumpWidget(_swap('a', reduce: true));
    await tester.pumpWidget(_swap('b', reduce: true));
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('a'), findsOneWidget, reason: 'still fading out');
    final shifts = _shifts(tester);
    expect(shifts, hasLength(2));
    expect(shifts, everyElement(Offset.zero));
    for (final t in tester.widgetList<Transform>(_inSwap(Transform))) {
      expect(t.transform.getMaxScaleOnAxis(), 1.0);
    }
    await tester.pumpAndSettle();
    expect(find.text('a'), findsNothing);
  });
}
