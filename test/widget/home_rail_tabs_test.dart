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

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/view/page/home.dart';
import 'package:server_box/view/widget/nav_rail.dart';

void main() {
  group('how many fit', () {
    // A destination taller than the one this rail draws, so the numbers below
    // stay about the arithmetic rather than about the current metrics: what
    // matters is that a tall window has room for six and a short one does not.
    int capacityAt(double height) =>
        railCapacity(height: height, destinationExtent: 64);

    test('a tall window holds every tab there is', () {
      expect(capacityAt(1000), greaterThanOrEqualTo(6));
    });

    test('a short one holds fewer', () {
      expect(capacityAt(400), lessThan(6));
    });

    test('and one too short for two still plans for two', () {
      // Two is the floor, and it is what makes the arithmetic below exact.
      // Below it there is no arrangement that both says which tab is open and
      // reaches the others — one slot is either a tab with the rest
      // unreachable, or a "more" with nothing saying where you are. So a rail
      // this short plans for two anyway and scrolls.
      expect(capacityAt(0), 2);
      expect(capacityAt(-100), 2);
      expect(capacityAt(150), 2);
      expect(railCapacity(height: 1000, destinationExtent: 0), 2);
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
      // Two is the smallest [railCapacity] answers, and at two the rail is one
      // tab and the way to the rest — never a lone "more", which would say
      // nothing about where you are.
      expect(railShownCount(wanted: 6, total: 6, capacity: 2), 1);
      expect(railShownCount(wanted: 1, total: 6, capacity: 2), 1);
    });

    test('and a capacity below that floor is still answered sanely', () {
      // Unreachable through [railCapacity]; here so a smaller one arriving
      // from somewhere else is one tab and a "more" the rail scrolls to,
      // rather than a zero or a negative count.
      expect(railShownCount(wanted: 6, total: 6, capacity: 1), 1);
      expect(railShownCount(wanted: 6, total: 6, capacity: 0), 1);
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
          // From two, which is the smallest [railCapacity] answers.
          for (var capacity = 2; capacity <= 10; capacity++) {
            final shown = railShownCount(
              wanted: wanted,
              total: total,
              capacity: capacity,
            );
            final reason = 'wanted $wanted of $total in $capacity';
            expect(shown, greaterThanOrEqualTo(1), reason: reason);
            expect(shown, lessThanOrEqualTo(total), reason: reason);

            final destinations = shown + (shown < total ? 1 : 0);
            // What the count is *for*. "More" is a destination too, so a rail
            // that reserves nothing for it draws one more than it measured
            // room for — which the arithmetic did at a capacity of one, until
            // [railCapacity] stopped answering one.
            expect(
              destinations,
              lessThanOrEqualTo(capacity),
              reason: '$reason drew $destinations',
            );
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

  /// The foot of the rail, which is a destination now rather than a button
  /// that pushed a page over the rail itself.
  group('the settings at the foot', () {
    Future<Color?> fillAt(WidgetTester tester, {required bool selected}) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Row(
              children: [
                AppNavRail(
                  selectedIndex: 0,
                  onSelected: (_) {},
                  items: const [
                    NavRailItem(
                      icon: Icon(Icons.circle),
                      selectedIcon: Icon(Icons.circle),
                      label: 'one',
                    ),
                  ],
                  footer: NavRailItem(
                    icon: Icon(Icons.settings),
                    selectedIcon: Icon(Icons.settings),
                    label: 'settings',
                  ),
                  footerSelected: selected,
                  onFooterTap: () {},
                ),
                const Expanded(child: SizedBox()),
              ],
            ),
          ),
        ),
      );
      await tester.pump();
      // Settled, because which item is lit is now crossed over rather than
      // switched: the fill is `Color.lerp`ed from a `TweenAnimationBuilder`.
      await tester.pump(const Duration(milliseconds: 400));
      final box = find
          .ancestor(
            of: find.byIcon(Icons.settings),
            matching: find.byType(DecoratedBox),
          )
          .first;
      final decoration =
          tester.widget<DecoratedBox>(box).decoration as ShapeDecoration;
      return decoration.color;
    }

    testWidgets('is filled in while the settings are showing', (tester) async {
      final scheme = ThemeData().colorScheme;
      expect(await fillAt(tester, selected: true), scheme.secondaryContainer);
      expect(await fillAt(tester, selected: false), Colors.transparent);
    });

    testWidgets('and nothing above it is, while they are', (tester) async {
      // What `selectedIndex: -1` is for. The tab underneath is still the one
      // that comes back, but it is not what is on screen — and two lit pills
      // in one rail say two things are.
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Row(
              children: [
                AppNavRail(
                  selectedIndex: -1,
                  onSelected: (_) {},
                  items: const [
                    NavRailItem(
                      icon: Icon(Icons.circle),
                      selectedIcon: Icon(Icons.circle),
                      label: 'one',
                    ),
                  ],
                ),
                const Expanded(child: SizedBox()),
              ],
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 400));
      final pill = tester.widget<DecoratedBox>(
        find
            .ancestor(
              of: find.byIcon(Icons.circle),
              matching: find.byType(DecoratedBox),
            )
            .first,
      );
      expect((pill.decoration as ShapeDecoration).color, Colors.transparent);
    });
  });

  /// The number against the layout it describes.
  ///
  /// The count has to be made before the destinations are built, so their
  /// height cannot be measured — it is read off [NavRailMetrics] instead.
  /// This is what says the arithmetic still describes the widget.
  ///
  /// One-sided on purpose: over-stating costs a slot, under-stating overflows
  /// the rail. The upper bound is only there so a wildly generous number does
  /// not pass as a safe one.
  group('how tall one destination is', () {
    Future<double> measure(WidgetTester tester, double textScale) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
            child: Scaffold(
              body: Row(
                children: [
                  AppNavRail(
                    selectedIndex: 0,
                    onSelected: (_) {},
                    items: const [
                      NavRailItem(
                        icon: Icon(Icons.looks_one),
                        selectedIcon: Icon(Icons.looks_one),
                        label: 'one',
                      ),
                      NavRailItem(
                        icon: Icon(Icons.looks_two),
                        selectedIcon: Icon(Icons.looks_two),
                        label: 'two',
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
      // divides by — not one destination's own painted height. Measured on the
      // icons, because a shut rail draws no names: they are its tooltips.
      final first = tester.getRect(find.byIcon(Icons.looks_one));
      final second = tester.getRect(find.byIcon(Icons.looks_two));
      return second.top - first.top;
    }

    Future<void> check(WidgetTester tester, double textScale) async {
      final real = await measure(tester, textScale);
      expect(
        railDestinationExtent,
        greaterThanOrEqualTo(real),
        reason: 'an under-estimate is a rail that overflows its box',
      );
      expect(
        railDestinationExtent,
        lessThan(real + 24),
        reason: 'and a wild over-estimate is tabs behind "more" for nothing',
      );
    }

    testWidgets('holds at the ordinary text scale', (tester) async {
      await check(tester, 1);
    });

    testWidgets('and at every scale, because nothing here is text', (
      tester,
    ) async {
      // What the shut rail bought: an item is an icon in a pill, so the pitch
      // is a constant rather than something that has to be guessed ahead of a
      // layout it cannot see.
      for (final scale in [1.1, 1.3, 1.6, 2.0, 3.0]) {
        await check(tester, scale);
      }
    });
  });

  /// The two shapes the rail has.
  group('opening', () {
    Future<double> widthAfterHover(
      WidgetTester tester, {
      required bool hover,
    }) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Row(
              children: [
                AppNavRail(
                  selectedIndex: 0,
                  onSelected: (_) {},
                  items: const [
                    NavRailItem(
                      icon: Icon(Icons.circle),
                      selectedIcon: Icon(Icons.circle),
                      label: 'one',
                    ),
                  ],
                ),
                const Expanded(child: SizedBox()),
              ],
            ),
          ),
        ),
      );
      await tester.pump();

      if (hover) {
        final pointer = TestPointer(1, PointerDeviceKind.mouse);
        await tester.sendEventToBinding(
          pointer.hover(tester.getCenter(find.byType(AppNavRail))),
        );
        // Past the whole of the opening, which is what the width is asserted
        // at — halfway through it is neither number.
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
      }

      return tester.getSize(find.byType(AppNavRail)).width;
    }

    testWidgets('is what the pointer does, and costs the tab nothing', (
      tester,
    ) async {
      expect(await widthAfterHover(tester, hover: false), NavRailMetrics.width);
      expect(
        await widthAfterHover(tester, hover: true),
        NavRailMetrics.expandedWidth,
      );
      // And the tab beside it never moved: the rail is painted over it, and
      // what the `Row` holds open is the shut width — see `_kRailWidth`.
      expect(railWidth, NavRailMetrics.width);
    });

    testWidgets('lays an item out inside the pill at every width', (
      tester,
    ) async {
      // What went wrong the first time: an `AnimatedContainer` easing the
      // pill's width towards this frame's number while the row inside was
      // already laid out for it, which is a `RenderFlex` overflow — reported,
      // with a whole widget tree, on every frame of the opening.
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Row(
              children: [
                AppNavRail(
                  selectedIndex: 0,
                  onSelected: (_) {},
                  items: [
                    NavRailItem(
                      icon: const Icon(Icons.circle),
                      selectedIcon: const Icon(Icons.circle),
                      label: 'one',
                      badge: (opacity) => NavRailBadge(
                        label: '3/3',
                        opacity: opacity,
                      ),
                    ),
                  ],
                ),
                const Expanded(child: SizedBox()),
              ],
            ),
          ),
        ),
      );
      await tester.pump();

      final pointer = TestPointer(1, PointerDeviceKind.mouse);
      await tester.sendEventToBinding(
        pointer.hover(tester.getCenter(find.byType(AppNavRail))),
      );
      // Frame by frame through the whole of it, in both directions: the
      // overflow was only ever at one end of the range.
      for (var i = 0; i < 30; i++) {
        await tester.pump(const Duration(milliseconds: 8));
        expect(tester.takeException(), isNull, reason: 'opening, frame $i');
      }
      await tester.sendEventToBinding(pointer.hover(const Offset(600, 300)));
      for (var i = 0; i < 30; i++) {
        await tester.pump(const Duration(milliseconds: 8));
        expect(tester.takeException(), isNull, reason: 'shutting, frame $i');
      }
    });

    testWidgets('keeps one element for an item all the way through', (
      tester,
    ) async {
      // Re-parenting an item mid-animation is what made it jump: the state
      // that says how far it is selected, and the one the pill's fill used to
      // be eased by, are both destroyed by it. Wrappers used to come and go at
      // the halfway mark — the `Stack` holding the corner badge, and the
      // `Tooltip` that names an item while there is no room for its name.
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Row(
              children: [
                AppNavRail(
                  selectedIndex: 0,
                  onSelected: (_) {},
                  items: [
                    NavRailItem(
                      icon: const Icon(Icons.circle),
                      selectedIcon: const Icon(Icons.circle),
                      label: 'one',
                      badge: (opacity) => NavRailBadge(
                        label: '3/3',
                        opacity: opacity,
                      ),
                    ),
                  ],
                ),
                const Expanded(child: SizedBox()),
              ],
            ),
          ),
        ),
      );
      await tester.pump();

      final pill = find
          .ancestor(
            of: find.byIcon(Icons.circle),
            matching: find.byType(DecoratedBox),
          )
          .first;
      final shut = tester.element(pill);

      final pointer = TestPointer(1, PointerDeviceKind.mouse);
      await tester.sendEventToBinding(
        pointer.hover(tester.getCenter(find.byType(AppNavRail))),
      );
      // Across the halfway mark, which is where both wrappers flipped.
      for (var i = 0; i < 30; i++) {
        await tester.pump(const Duration(milliseconds: 8));
        expect(
          tester.element(pill),
          same(shut),
          reason: 'the pill was rebuilt from scratch at frame $i',
        );
      }
    });

    testWidgets('moves nothing but the pill', (tester) async {
      // What "jitter" was. The two shapes disagreed about the pill's height,
      // its padding, the glyph's size and the gap under it — a point or three
      // each — so every frame re-rasterised the glyph a fraction smaller and
      // a fraction further along, which a filled icon on a filled pill shows
      // as crawling rather than sliding. Now the icon is the thing that
      // stands still and the pill grows out from under it.
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Row(
              children: [
                AppNavRail(
                  selectedIndex: 0,
                  onSelected: (_) {},
                  items: [
                    NavRailItem(
                      icon: const Icon(Icons.looks_one),
                      selectedIcon: const Icon(Icons.looks_one),
                      label: 'badged',
                      badge: (opacity) => NavRailBadge(
                        label: '3/3',
                        opacity: opacity,
                      ),
                    ),
                    const NavRailItem(
                      icon: Icon(Icons.looks_two),
                      selectedIcon: Icon(Icons.looks_two),
                      label: 'plain',
                    ),
                  ],
                ),
                const Expanded(child: SizedBox()),
              ],
            ),
          ),
        ),
      );
      await tester.pump();

      final pointer = TestPointer(1, PointerDeviceKind.mouse);
      await tester.sendEventToBinding(
        pointer.hover(tester.getCenter(find.byType(AppNavRail))),
      );
      final first = tester.getRect(find.byIcon(Icons.looks_one));
      // The second as well: the gap between two items used to close as the
      // rail opened, so everything below the first one drifted upwards.
      final second = tester.getRect(find.byIcon(Icons.looks_two));

      for (var i = 0; i < 30; i++) {
        await tester.pump(const Duration(milliseconds: 8));
        // To a tenth of a point, not exactly: the pill's width runs through
        // `lerpDouble` and hands its padding whatever that lands on, so the
        // glyph's box comes back a few ulps either way.
        expect(
          tester.getRect(find.byIcon(Icons.looks_one)),
          rectMoreOrLessEquals(first, epsilon: 0.1),
          reason: 'the first glyph moved, at frame $i',
        );
        expect(
          tester.getRect(find.byIcon(Icons.looks_two)),
          rectMoreOrLessEquals(second, epsilon: 0.1),
          reason: 'the second glyph moved, at frame $i',
        );
      }
    });

    testWidgets('keeps the badge on the glyph rather than the pill', (
      tester,
    ) async {
      // On the pill's own corner the badge kept station with an edge that
      // travels 124 points as the rail opens, so it flew right across the
      // name arriving under it while fading out — which read as the icon
      // beside it flashing.
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Row(
              children: [
                AppNavRail(
                  selectedIndex: 0,
                  onSelected: (_) {},
                  items: [
                    NavRailItem(
                      icon: const Icon(Icons.circle),
                      selectedIcon: const Icon(Icons.circle),
                      label: 'one',
                      badge: (opacity) => NavRailBadge(
                        label: '3/3',
                        opacity: opacity,
                      ),
                    ),
                  ],
                ),
                const Expanded(child: SizedBox()),
              ],
            ),
          ),
        ),
      );
      await tester.pump();

      Rect corner() => tester.getRect(find.byType(NavRailBadge).first);
      final shut = corner();

      final pointer = TestPointer(1, PointerDeviceKind.mouse);
      await tester.sendEventToBinding(
        pointer.hover(tester.getCenter(find.byType(AppNavRail))),
      );
      for (var i = 0; i < 30; i++) {
        await tester.pump(const Duration(milliseconds: 8));
        // The glyph itself moves three points as the pill's padding grows,
        // and the badge is allowed to go with it. Anything more is the pill's
        // far edge dragging it along.
        expect(
          (corner().right - shut.right).abs(),
          lessThan(4),
          reason: 'the badge travelled, at frame $i',
        );
      }
    });

    /// The colour the rail's own `Material` is painted with.
    Future<Color?> colorAt(
      WidgetTester tester, {
      required bool hover,
      required Color? scaffold,
    }) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(scaffoldBackgroundColor: scaffold),
          home: Scaffold(
            body: Row(
              children: [
                AppNavRail(
                  selectedIndex: 0,
                  onSelected: (_) {},
                  items: const [
                    NavRailItem(
                      icon: Icon(Icons.circle),
                      selectedIcon: Icon(Icons.circle),
                      label: 'one',
                    ),
                  ],
                ),
                const Expanded(child: SizedBox()),
              ],
            ),
          ),
        ),
      );
      await tester.pump();

      if (hover) {
        final pointer = TestPointer(1, PointerDeviceKind.mouse);
        await tester.sendEventToBinding(
          pointer.hover(tester.getCenter(find.byType(AppNavRail))),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
      }

      return tester
          .widget<Material>(
            find
                .descendant(
                  of: find.byType(AppNavRail),
                  matching: find.byType(Material),
                )
                .first,
          )
          .color;
    }

    testWidgets('takes a colour of its own once it is over a tab', (
      tester,
    ) async {
      // A background image makes the scaffold transparent on purpose, so every
      // page shows the wallpaper. The shut rail is nothing over nothing and
      // keeps that — but open it stands over the tab, and a transparent panel
      // there put two sets of names on the same pixels.
      final scheme = ThemeData().colorScheme;

      final shut = await colorAt(
        tester,
        hover: false,
        scaffold: Colors.transparent,
      );
      expect(shut!.a, 0);

      final open = await colorAt(
        tester,
        hover: true,
        scaffold: Colors.transparent,
      );
      expect(open!.a, 1);
      expect(open, scheme.surface);
    });

    testWidgets('and keeps the page\'s own while the page has one', (
      tester,
    ) async {
      // No background, so the scaffold's colour is a real one and there is
      // nothing to fix: opening the rail changes its width and nothing else.
      const page = Color(0xFF123456);

      expect(
        await colorAt(tester, hover: false, scaffold: page),
        page,
      );
      expect(
        await colorAt(tester, hover: true, scaffold: page),
        page,
      );
    });

    testWidgets('names an item with a tooltip while it is shut', (
      tester,
    ) async {
      await widthAfterHover(tester, hover: false);
      // The name is not on screen, so something has to be able to say it.
      expect(find.text('one'), findsNothing);
      expect(
        tester.widget<Tooltip>(find.byType(Tooltip)).message,
        'one',
      );
    });
  });
}
