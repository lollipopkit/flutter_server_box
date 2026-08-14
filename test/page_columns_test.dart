import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/view/widget/page_columns.dart';

void main() {
  // The window itself, not a `SizedBox` inside it: a box wider than the test
  // surface is clamped to it, so the layout under test would never see the
  // width the test claims to be giving it.
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
              for (var i = 0; i < count; i++)
                SizedBox(key: ValueKey(i), height: 40, child: Text('$i')),
            ],
          ),
        ),
      ),
    );
  }

  Offset at(WidgetTester tester, int i) =>
      tester.getTopLeft(find.byKey(ValueKey(i)));

  testWidgets('children fill columns in the order they were given', (
    tester,
  ) async {
    await pump(tester, width: 1400, count: 4);

    // The first child belongs in the first column. Packing by height put it
    // wherever there happened to be room, which on the server edit page meant
    // the name field appeared at the top of the second column.
    expect(at(tester, 0).dx, lessThan(at(tester, 1).dx));
    expect(at(tester, 2).dx, at(tester, 0).dx);
    expect(at(tester, 3).dx, at(tester, 1).dx);
    expect(at(tester, 2).dy, greaterThan(at(tester, 0).dy));
  });

  testWidgets('content starts at the top, not in the middle', (tester) async {
    await pump(tester, width: 1400, count: 2);

    // Two short cards in an 800pt-tall page: they belong at the top of it.
    // A scroll view given loose constraints sizes itself to its content, and
    // the centring around it then floated the whole page.
    expect(at(tester, 0).dy, lessThan(100));
  });

  testWidgets('a narrow window is one column, still in order', (tester) async {
    await pump(tester, width: 320, count: 3);

    expect(at(tester, 0).dx, at(tester, 1).dx);
    expect(at(tester, 1).dy, greaterThan(at(tester, 0).dy));
    expect(at(tester, 2).dy, greaterThan(at(tester, 1).dy));
  });
}
