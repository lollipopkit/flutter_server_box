/// What the navigation rail does with more tabs than it can hold.
///
/// The bar's split is a setting — the tabs the user put in it, and the rest
/// behind "more". The rail has that split *and* a second one the bar never
/// needs: it runs vertically, so a short window or a large text scale can leave
/// it without room for the tabs the user did keep.
///
/// Both ends up as one number. The rail draws the first `shown` of every tab
/// there is and the sheet takes the remainder, which is exactly what the bar
/// does — so nothing downstream has to know which of the two reasons put a tab
/// behind "more".
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/view/page/home.dart';

void main() {
  group('how many fit', () {
    // 6 tabs at the shipped estimate is 384pt of destinations, plus the rail's
    // own chrome. A laptop window has room; a short one does not.
    int capacityAt(double height) =>
        railCapacity(height: height, destinationExtent: 64);

    test('a tall window holds every tab there is', () {
      expect(capacityAt(1000), greaterThanOrEqualTo(6));
    });

    test('a short one holds fewer', () {
      expect(capacityAt(400), lessThan(6));
    });

    test('and one too short for even one still says one', () {
      // The rail is drawn either way — it is the navigation — so a count of
      // zero would be a rail of nothing, or a range error where the arithmetic
      // below subtracts the "more" slot.
      expect(capacityAt(0), 1);
      expect(capacityAt(-100), 1);
      expect(railCapacity(height: 1000, destinationExtent: 0), 1);
    });
  });

  group('what the rail draws', () {
    test('every tab, when they all fit and none is hidden', () {
      expect(railShownCount(wanted: 6, total: 6, capacity: 6), 6);
      expect(railShownCount(wanted: 6, total: 6, capacity: 9), 6);
    });

    test('one fewer than it has room for, when something is behind "more"', () {
      // "More" is a destination itself, so a rail with six slots and something
      // to hide draws five tabs and the way to the sixth.
      expect(railShownCount(wanted: 4, total: 6, capacity: 6), 4);
      expect(railShownCount(wanted: 6, total: 6, capacity: 4), 3);
      expect(railShownCount(wanted: 5, total: 6, capacity: 4), 3);
    });

    test('and at least one tab whatever the height', () {
      // A rail holding nothing but "more" says less than one holding a tab.
      expect(railShownCount(wanted: 6, total: 6, capacity: 1), 1);
      expect(railShownCount(wanted: 1, total: 6, capacity: 1), 1);
    });

    /// The property the rail's `selectedIndex` rests on.
    ///
    /// `NavigationRail` asserts `selectedIndex < destinations.length`, and the
    /// rail clamps anything past its own tabs onto the "more" slot. That is
    /// only in range if there *is* such a slot whenever a tab is missing from
    /// the rail — which is this, for every shape the home page can be in.
    test('never leaves a tab out without a slot standing for it', () {
      for (var total = 1; total <= 6; total++) {
        for (var wanted = 1; wanted <= total; wanted++) {
          for (var capacity = 1; capacity <= 10; capacity++) {
            final shown = railShownCount(
              wanted: wanted,
              total: total,
              capacity: capacity,
            );
            final reason = 'wanted $wanted of $total in $capacity';
            expect(shown, greaterThanOrEqualTo(1), reason: reason);
            expect(shown, lessThanOrEqualTo(total), reason: reason);

            final destinations = shown + (shown < total ? 1 : 0);
            // Every tab index the home page can hold, clamped the way the rail
            // clamps it.
            for (var selected = 0; selected < total; selected++) {
              final at = selected < shown ? selected : shown;
              expect(at, lessThan(destinations), reason: '$reason, at $at');
            }
          }
        }
      }
    });
  });

  /// The estimate against the layout it is an estimate of.
  ///
  /// The count has to be made before the destinations are built, so their
  /// height cannot be measured — it is worked out from the M3 rail's own
  /// numbers instead. This is what says those numbers are still Flutter's.
  ///
  /// One-sided on purpose: over-estimating costs a slot, under-estimating
  /// overflows the rail. The upper bound is only there so a wildly generous
  /// estimate does not pass as a safe one.
  group('the estimate', () {
    Future<double> measure(WidgetTester tester, double textScale) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
            child: Scaffold(
              body: Row(
                children: [
                  NavigationRail(
                    selectedIndex: 0,
                    labelType: NavigationRailLabelType.all,
                    destinations: const [
                      NavigationRailDestination(
                        icon: Icon(Icons.circle),
                        label: Text('one'),
                      ),
                      NavigationRailDestination(
                        icon: Icon(Icons.circle),
                        label: Text('two'),
                      ),
                    ],
                  ),
                  const Expanded(child: SizedBox()),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      // Top to top of consecutive destinations, which is the pitch the count
      // divides by — not one destination's own painted height.
      final first = tester.getRect(find.text('one'));
      final second = tester.getRect(find.text('two'));
      return second.top - first.top;
    }

    Future<void> check(WidgetTester tester, double textScale) async {
      final real = await measure(tester, textScale);
      final estimated = railDestinationExtent(
        tester.element(find.byType(NavigationRail)),
      );
      expect(
        estimated,
        greaterThanOrEqualTo(real),
        reason: 'an under-estimate is a rail that overflows its box',
      );
      expect(
        estimated,
        lessThan(real + 24),
        reason: 'and a wild over-estimate is tabs behind "more" for nothing',
      );
    }

    testWidgets('holds at the ordinary text scale', (tester) async {
      await check(tester, 1);
    });

    testWidgets('and at the ones this app lets the user set', (tester) async {
      // `textFactor` is a setting, so the label — the only part of a
      // destination that moves — is not a constant. The fractional scales are
      // the ones that matter: a line is laid out to a whole pixel, so the real
      // height is `round(16 × scale)` and the plain product is *under* it at
      // 1.1, 1.3, 1.6 and 1.8.
      for (final scale in [1.1, 1.2, 1.3, 1.4, 1.5, 1.6, 1.8, 2.0, 2.5, 3.0]) {
        await check(tester, scale);
      }
    });
  });
}
