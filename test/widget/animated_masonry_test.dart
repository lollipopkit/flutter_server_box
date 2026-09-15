import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// One card. Fills the column it lands in, so what is measured below is where
/// the grid put it rather than where a narrow child sat inside it.
Widget _card(String id, {double height = 100}) => Container(
  key: ValueKey(id),
  height: height,
  alignment: Alignment.center,
  child: Text(id, textDirection: TextDirection.ltr),
);

/// [width] decides the columns: 400 holds two of these, 200 holds one.
///
/// [height] null leaves the grid sized to its content, which is what the
/// assertions about how much room the cards take measure. Give it one where
/// the grid has to be a real viewport — a card being carried can be drawn past
/// the content's own bottom edge, and a scrollable sized to that content is
/// too short to route a tap to it.
Future<void> _pumpGrid(
  WidgetTester tester,
  List<Widget> children, {
  double width = 400,
  double? height,
}) {
  return tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: width,
            height: height,
            child: AnimatedMasonry(
              columnWidth: 150,
              padding: EdgeInsets.zero,
              spacing: 10,
              children: children,
            ),
          ),
        ),
      ),
    ),
  );
}

/// Where a card is drawn, relative to the grid.
Offset _at(WidgetTester tester, String id) {
  final card = tester.getTopLeft(find.byKey(ValueKey(id)));
  final grid = tester.getTopLeft(find.byType(AnimatedMasonry));
  return card - grid;
}

/// Runs the clock at 60fps for [frames].
///
/// Not `pumpAndSettle`, and not one long pump either. The ease closes a share
/// of the gap per *frame*, and where the gap is going is recomputed in the
/// layout after each of those — so one pump of a second is one frame's worth
/// of easing toward a target a second out of date, not a second's worth.
Future<void> _run(WidgetTester tester, {int frames = 60}) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

/// How tall the grid is, which is how much room its cards take between them.
double _gridHeight(WidgetTester tester) =>
    tester.getSize(find.byType(AnimatedMasonry)).height;

void main() {
  testWidgets('cards fall into the shortest column, left first', (
    tester,
  ) async {
    await _pumpGrid(tester, [
      _card('a', height: 100),
      _card('b', height: 40),
      _card('c'),
      _card('d'),
    ]);

    // 400 wide, two columns, 10 between them: 195 each.
    expect(_at(tester, 'a'), Offset.zero);
    expect(_at(tester, 'b'), const Offset(205, 0));
    // 'b' is the shorter column, so the next one goes under it.
    expect(_at(tester, 'c'), const Offset(205, 50));
    expect(_at(tester, 'd'), const Offset(0, 110));
  });

  testWidgets('a card that moves is carried there, not jumped', (tester) async {
    await _pumpGrid(tester, [_card('a'), _card('b'), _card('c')]);
    expect(_at(tester, 'c'), const Offset(0, 110));

    // 'a' goes, so 'c' belongs at the top of the left column now.
    await _pumpGrid(tester, [_card('b'), _card('c')]);
    // Twice: where a card belongs is settled during layout, so the frame that
    // works that out is already spoken for and the ease starts on the next.
    await tester.pump(const Duration(milliseconds: 60));
    await tester.pump(const Duration(milliseconds: 60));

    // Still on its way. The whole point of the widget is that this is not
    // already the new position.
    final midway = _at(tester, 'c');
    expect(midway.dy, greaterThan(0));
    expect(midway.dy, lessThan(110));

    // Two left, so one column each — 'c' ends up beside 'b', not under it.
    await _run(tester);
    expect(_at(tester, 'c'), const Offset(205, 0));
  });

  testWidgets('a card added grows into its place rather than appearing in it', (
    tester,
  ) async {
    await _pumpGrid(tester, [_card('a')], width: 200);
    expect(_gridHeight(tester), 100);

    await _pumpGrid(tester, [_card('a'), _card('b')], width: 200);
    await tester.pump();
    // Its slot is still nothing, so nothing under it has moved yet.
    expect(_gridHeight(tester), 100);

    await tester.pump(const Duration(milliseconds: 80));
    final growing = _gridHeight(tester);
    expect(growing, greaterThan(100));
    expect(growing, lessThan(210));

    await _run(tester);
    expect(_gridHeight(tester), 210);
    // No travel — it was never anywhere else.
    expect(_at(tester, 'b'), const Offset(0, 110));
  });

  testWidgets('a card removed stays on screen while it shrinks away', (
    tester,
  ) async {
    await _pumpGrid(tester, [_card('a'), _card('b')], width: 200);
    expect(_gridHeight(tester), 210);

    await _pumpGrid(tester, [_card('a')], width: 200);
    await tester.pump(const Duration(milliseconds: 80));

    // Still built, so the room it took closes rather than vanishing.
    expect(find.byKey(const ValueKey('b')), findsOneWidget);
    final closing = _gridHeight(tester);
    expect(closing, lessThan(210));
    expect(closing, greaterThan(100));

    await _run(tester);
    expect(find.byKey(const ValueKey('b')), findsNothing);
    expect(_gridHeight(tester), 100);
  });

  testWidgets('a card put back before it has gone turns around', (
    tester,
  ) async {
    await _pumpGrid(tester, [_card('a'), _card('b')], width: 200);
    await _pumpGrid(tester, [_card('a')], width: 200);
    await tester.pump(const Duration(milliseconds: 100));
    expect(_gridHeight(tester), lessThan(210));

    await _pumpGrid(tester, [_card('a'), _card('b')], width: 200);
    await _run(tester);

    expect(find.byKey(const ValueKey('b')), findsOneWidget);
    expect(_gridHeight(tester), 210);
  });

  testWidgets('the first build is already there, with nothing growing in', (
    tester,
  ) async {
    await _pumpGrid(tester, [_card('a'), _card('b')], width: 200);

    // One pump, no settling: a grid arriving is not two cards being added to
    // one that was already on screen.
    expect(_gridHeight(tester), 210);
  });

  testWidgets('taps land on the card where it is drawn, mid-move', (
    tester,
  ) async {
    final tapped = <String>[];
    Widget tappable(String id) => GestureDetector(
      key: ValueKey(id),
      onTap: () => tapped.add(id),
      behavior: HitTestBehavior.opaque,
      child: const SizedBox(height: 100, width: double.infinity),
    );

    const room = 600.0;
    await _pumpGrid(tester, [
      tappable('a'),
      tappable('b'),
      tappable('c'),
    ], height: room);
    await _pumpGrid(tester, [tappable('b'), tappable('c')], height: room);
    await tester.pump(const Duration(milliseconds: 60));
    await tester.pump(const Duration(milliseconds: 60));

    final midway = _at(tester, 'c');
    expect(midway.dy, greaterThan(0));
    expect(midway.dy, lessThan(110));

    // Wherever 'c' has got to, that is where it can be hit.
    await tester.tapAt(tester.getCenter(find.byKey(const ValueKey('c'))));
    await tester.pump();
    expect(tapped, ['c']);
  });
}
