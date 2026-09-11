import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/view/widget/edge_fade_scroll.dart';

/// The mask over a row that runs off its window, shared by the settings tabs
/// and a server's function buttons.
void main() {
  Finder mask() => find.descendant(
    of: find.byType(EdgeFadeScroll),
    matching: find.byType(ShaderMask),
  );

  Future<void> pumpRow(WidgetTester tester, {required double itemWidth}) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(400, 200);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              height: 60,
              child: EdgeFadeScroll(
                builder: (context, controller) => ListView.builder(
                  controller: controller,
                  scrollDirection: Axis.horizontal,
                  itemCount: 4,
                  itemBuilder: (_, index) =>
                      SizedBox(width: itemWidth, child: Text('item $index')),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    // One for the layout, one for the frame that reads the position it
    // produced — there is nothing to measure before the first.
    await tester.pump();
    await tester.pump();
  }

  testWidgets('a row that fits is not masked at all', (tester) async {
    await pumpRow(tester, itemWidth: 60);

    // Not a mask that happens to be transparent: the mask is a `saveLayer`,
    // and a row with nothing off either end should not pay for one.
    expect(mask(), findsNothing);
  });

  testWidgets('a row wider than its window is masked', (tester) async {
    await pumpRow(tester, itemWidth: 300);

    expect(mask(), findsOneWidget);
  });

  testWidgets('the mask stays at the far end, where the other side is hidden', (
    tester,
  ) async {
    await pumpRow(tester, itemWidth: 300);

    await tester.drag(find.byType(ListView), const Offset(-2000, 0));
    await tester.pump();
    await tester.pump();

    expect(mask(), findsOneWidget);
  });

  testWidgets('a row that grows past its window picks the mask up', (
    tester,
  ) async {
    // Metrics can change without anyone scrolling — a settings level is as
    // wide as the tabs on it, and moving between levels resizes the bar.
    await pumpRow(tester, itemWidth: 60);
    expect(mask(), findsNothing);

    await pumpRow(tester, itemWidth: 300);
    expect(mask(), findsOneWidget);
  });
}
