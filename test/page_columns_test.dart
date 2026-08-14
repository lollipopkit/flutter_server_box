import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/view/widget/page_columns.dart';

void main() {
  Future<void> pump(
    WidgetTester tester, {
    required double width,
    required int count,
  }) async {
    await tester.binding.setSurfaceSize(Size(width, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PageColumns(
            children: [
              for (var index = 0; index < count; index++)
                SizedBox(
                  key: ValueKey(index),
                  height: 40,
                  child: Text('$index'),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Offset positionOf(WidgetTester tester, int index) =>
      tester.getTopLeft(find.byKey(ValueKey(index)));

  test('caps the calculated layout at three columns', () {
    expect(PageColumns.columnsFor(400), 1);
    expect(PageColumns.columnsFor(1400), 2);
    expect(PageColumns.columnsFor(3000), 3);
  });

  testWidgets('lays out children in reading order', (tester) async {
    await pump(tester, width: 1400, count: 4);

    expect(positionOf(tester, 0).dx, lessThan(positionOf(tester, 1).dx));
    expect(positionOf(tester, 2).dx, positionOf(tester, 0).dx);
    expect(positionOf(tester, 3).dx, positionOf(tester, 1).dx);
    expect(positionOf(tester, 2).dy, greaterThan(positionOf(tester, 0).dy));
  });

  testWidgets('uses one ordered column on narrow screens', (tester) async {
    await pump(tester, width: 320, count: 3);

    expect(positionOf(tester, 0).dx, positionOf(tester, 1).dx);
    expect(positionOf(tester, 1).dy, greaterThan(positionOf(tester, 0).dy));
    expect(positionOf(tester, 2).dy, greaterThan(positionOf(tester, 1).dy));
  });
}
