import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/view/widget/progress_line.dart';

/// Two states, one picture: the bar fills from the same edge whether or not
/// the length is known, so a download that stops reporting a fraction does not
/// look like a different thing happening.
void main() {
  Future<void> pumpBar(WidgetTester tester, double? value) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(width: 200, child: ProgressLine(value: value)),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  double barWidth(WidgetTester tester) =>
      tester.getSize(find.byType(FractionallySizedBox)).width;

  testWidgets('a measured value is the width of the bar', (tester) async {
    await pumpBar(tester, 0.5);
    // Animated to, so settle the tween before measuring.
    await tester.pump(const Duration(milliseconds: 400));

    expect(barWidth(tester), closeTo(100, 1));
  });

  testWidgets('a value outside the range is clamped, not asserted', (
    tester,
  ) async {
    // A server that reports a length and then sends more is a real thing.
    await pumpBar(tester, 1.4);
    await tester.pump(const Duration(milliseconds: 400));
    expect(barWidth(tester), closeTo(200, 1));

    await pumpBar(tester, -1);
    await tester.pump(const Duration(milliseconds: 400));
    expect(barWidth(tester), lessThanOrEqualTo(200));
  });

  testWidgets('without a value the length changes on its own', (tester) async {
    await pumpBar(tester, null);

    final samples = <double>[];
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 120));
      samples.add(barWidth(tester));
    }

    expect(samples.toSet().length, greaterThan(1));
    // Never empty: a bar at zero looks like it stopped.
    expect(samples.every((width) => width > 0), isTrue);
    expect(samples.every((width) => width <= 200), isTrue);
  });

  testWidgets('a measured value stops the loop rather than racing it', (
    tester,
  ) async {
    await pumpBar(tester, null);
    await tester.pump(const Duration(milliseconds: 200));

    await pumpBar(tester, 0.25);
    await tester.pump(const Duration(milliseconds: 400));
    final settled = barWidth(tester);

    // Still animating would move this; it is the measured width and stays.
    await tester.pump(const Duration(milliseconds: 600));
    expect(barWidth(tester), closeTo(settled, 0.5));
    expect(settled, closeTo(50, 1));
  });
}
