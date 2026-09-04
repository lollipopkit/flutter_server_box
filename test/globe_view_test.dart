import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/data/model/server/geo.dart';
import 'package:server_box/view/widget/globe/painter.dart';
import 'package:server_box/view/widget/globe/view.dart';

/// The globe as a widget: what it labels, what it hides, and what happens when
/// it is tapped.
///
/// **`pumpAndSettle` is unusable here.** The entrance runs an animation and a
/// flick starts a ticker, so a frame in which nothing is scheduled may not
/// arrive — and `pumpAndSettle` waits ten minutes for one before giving up.
/// Frames are counted out with `pump(duration)` instead.
void main() {
  const cardSize = Size(120, 44);

  GlobeItem item(String id, double lat, double lon) => GlobeItem(
    id: id,
    coord: GeoCoord.tryNew(lat, lon)!,
    color: Colors.green,
    card: Text(id, key: ValueKey('card-$id')),
  );

  Future<void> show(
    WidgetTester tester,
    List<GlobeItem> items, {
    void Function(String)? onTap,
    int labelLimit = 14,
    GeoCoord? initial,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 400,
            height: 600,
            child: GlobeView(
              items: items,
              cardSize: cardSize,
              onTapItem: onTap,
              labelLimit: labelLimit,
              initialCoord: initial ?? GeoCoord.tryNew(0, 0),
            ),
          ),
        ),
      ),
    );
    // Past the entrance, without waiting for a quiet frame.
    await tester.pump(const Duration(milliseconds: 600));
  }

  testWidgets('a server on the near side gets a card', (tester) async {
    await show(tester, [item('a', 0, 0)]);
    expect(find.byKey(const ValueKey('card-a')), findsOneWidget);
  });

  testWidgets('a server on the far side does not', (tester) async {
    // Its card would sit over the globe pointing at nothing. It comes back
    // when the server rotates into view.
    await show(tester, [item('behind', 0, 180)]);
    expect(find.byKey(const ValueKey('card-behind')), findsNothing);
  });

  testWidgets('cards do not overlap each other', (tester) async {
    await show(tester, [
      for (var i = 0; i < 8; i++) item('s$i', 0, 0),
    ]);
    final rects = [
      for (var i = 0; i < 8; i++)
        tester.getRect(find.byKey(ValueKey('card-s$i'))),
    ];
    for (var i = 0; i < rects.length; i++) {
      for (var j = i + 1; j < rects.length; j++) {
        expect(
          rects[i].overlaps(rects[j]),
          isFalse,
          reason: 'cards $i and $j are on top of each other',
        );
      }
    }
  });

  testWidgets('past the limit, nothing is labelled until something is tapped', (
    tester,
  ) async {
    final items = [for (var i = 0; i < 6; i++) item('s$i', i * 3.0, i * 3.0)];
    await show(tester, items, labelLimit: 3);
    for (var i = 0; i < 6; i++) {
      expect(find.byKey(ValueKey('card-s$i')), findsNothing);
    }
  });

  testWidgets('under the limit, everything is labelled', (tester) async {
    final items = [for (var i = 0; i < 3; i++) item('s$i', i * 8.0, i * 8.0)];
    await show(tester, items, labelLimit: 3);
    for (var i = 0; i < 3; i++) {
      expect(find.byKey(ValueKey('card-s$i')), findsOneWidget);
    }
  });

  testWidgets('tapping a dot opens the server when everything is labelled', (
    tester,
  ) async {
    String? opened;
    await show(tester, [item('a', 0, 0)], onTap: (id) => opened = id);
    // The middle of the disc is where a server at the camera's own coordinate
    // projects to.
    await tester.tapAt(tester.getCenter(find.byType(GlobeView)));
    await tester.pump();
    expect(opened, 'a');
  });

  testWidgets('past the limit a tap labels first and opens second', (
    tester,
  ) async {
    String? opened;
    // `s0` sits at the camera's own coordinate, so it is what the middle of
    // the disc hits; the rest are far enough away not to be nearer.
    final items = [
      item('s0', 0, 0),
      for (var i = 1; i < 6; i++) item('s$i', 0, i * 25.0),
    ];
    await show(tester, items, onTap: (id) => opened = id, labelLimit: 3);

    final center = tester.getCenter(find.byType(GlobeView));
    await tester.tapAt(center);
    await tester.pump(const Duration(milliseconds: 50));
    expect(opened, isNull, reason: 'the first tap names it');
    expect(find.byKey(const ValueKey('card-s0')), findsOneWidget);

    await tester.tapAt(center);
    await tester.pump(const Duration(milliseconds: 50));
    expect(opened, 's0', reason: 'the second opens it');
  });

  testWidgets('tapping nothing clears the selection rather than opening', (
    tester,
  ) async {
    String? opened;
    final items = [
      item('s0', 0, 0),
      for (var i = 1; i < 6; i++) item('s$i', 0, i * 25.0),
    ];
    await show(tester, items, onTap: (id) => opened = id, labelLimit: 3);

    final center = tester.getCenter(find.byType(GlobeView));
    await tester.tapAt(center);
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.byKey(const ValueKey('card-s0')), findsOneWidget);

    // A corner, which is outside the disc entirely.
    await tester.tapAt(tester.getTopLeft(find.byType(GlobeView)) + const Offset(4, 4));
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.byKey(const ValueKey('card-s0')), findsNothing);
    expect(opened, isNull);
  });

  testWidgets('dragging turns the globe', (tester) async {
    // A server at the antimeridian is hidden; half a turn brings it round.
    await show(tester, [item('far', 0, 180)]);
    expect(find.byKey(const ValueKey('card-far')), findsNothing);

    final center = tester.getCenter(find.byType(GlobeView));
    // The disc's radius here is 400 * 0.62 / 2 = 124, so half a turn is about
    // pi * 124 pixels. Done in steps so it reads as a drag rather than a jump.
    final gesture = await tester.startGesture(center);
    for (var i = 0; i < 40; i++) {
      await gesture.moveBy(const Offset(10, 0));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await gesture.up();
    await tester.pump();

    expect(find.byKey(const ValueKey('card-far')), findsOneWidget);
  });

  /// A flick: fast enough that letting go leaves the globe coasting.
  ///
  /// `tester.fling` rather than a loop of `moveBy` and `pump`. That loop
  /// reports a velocity of **zero** to `onScaleEnd` — the events carry no
  /// usable timestamps for the velocity tracker — so a coasting test written
  /// that way asserts against a globe that never started moving, and passes.
  /// This one did, until it was asked to check that the ticker had started.
  Future<void> flick(
    WidgetTester tester, {
    Offset by = const Offset(200, 0),
    double speed = 1200,
  }) async {
    await tester.fling(find.byType(GlobeView), by, speed);
    await tester.pump();
  }

  testWidgets('letting go of a flick leaves the globe coasting', (
    tester,
  ) async {
    // Asserted before the test below it, because that one — "the ticker
    // stops" — passes trivially if the ticker never started, and did.
    await show(tester, [item('a', 0, 0)]);
    expect(tester.binding.transientCallbackCount, 0, reason: 'idle to start');

    await flick(tester);
    expect(
      tester.binding.transientCallbackCount,
      greaterThan(0),
      reason: 'a flick has to keep turning after the finger leaves',
    );
  });

  testWidgets('coasting keeps turning the globe after the finger leaves', (
    tester,
  ) async {
    // Asserted as "it moved again between two pumps with no input", rather
    // than by naming a server that should come into view: how far a flick
    // travels is a decay integral, and the first attempt at this spun a full
    // turn and landed back where it started.
    await show(tester, [item('a', 20, 20)]);
    await flick(tester, by: const Offset(40, 0), speed: 900);

    final atRelease = tester.getRect(find.byKey(const ValueKey('card-a')));
    await tester.pump(const Duration(milliseconds: 250));
    final later = tester.getRect(find.byKey(const ValueKey('card-a')));

    expect(
      later.center,
      isNot(atRelease.center),
      reason: 'the globe kept turning on its own',
    );
  });

  testWidgets('the globe stops coasting rather than spinning forever', (
    tester,
  ) async {
    // A ticker that never stops holds a frame callback and the screen awake
    // for the life of the page.
    await show(tester, [item('a', 0, 0)]);
    await flick(tester);
    expect(tester.binding.transientCallbackCount, greaterThan(0));

    // Long enough for the friction to bring it under a degree a second.
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(seconds: 1));
    }
    expect(tester.binding.transientCallbackCount, 0);
  });

  testWidgets('a slow release does not coast at all', (tester) async {
    // Below the threshold the globe is being let go rather than thrown, and
    // coasting from it reads as the globe drifting on its own.
    await show(tester, [item('a', 0, 0)]);
    await flick(tester, by: const Offset(20, 0), speed: 40);
    expect(tester.binding.transientCallbackCount, 0);
  });

  testWidgets('spinning past the antimeridian wraps rather than stopping', (
    tester,
  ) async {
    // A sphere has no edge. The coasting path keeps its own longitude, so it
    // needs its own wrap — the camera's is not reached from there.
    await show(tester, [item('a', 0, 0)], initial: GeoCoord.tryNew(0, 179));
    await flick(tester, by: const Offset(-200, 0));
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
    // Still on screen and still where it should be: a longitude that ran away
    // to 200 would project the same, so what this catches is a crash or a
    // `GeoCoord` refusing the value.
    expect(tester.takeException(), isNull);
    expect(find.byType(GlobeView), findsOneWidget);
  });

  testWidgets('pinching zooms, and a card moves with it', (tester) async {
    // Not a server at the camera's own coordinate: that one projects to the
    // middle of the disc whatever the radius is, so it would not move and the
    // test would fail for a reason that is not about zoom.
    await show(tester, [item('a', 30, 30)]);
    final before = tester.getRect(find.byKey(const ValueKey('card-a')));

    final centre = tester.getCenter(find.byType(GlobeView));
    final one = await tester.startGesture(centre - const Offset(20, 0));
    final two = await tester.startGesture(centre + const Offset(20, 0));
    for (var i = 0; i < 8; i++) {
      await one.moveBy(const Offset(-6, 0));
      await two.moveBy(const Offset(6, 0));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await one.up();
    await two.up();
    await tester.pump(const Duration(milliseconds: 50));

    final after = tester.getRect(find.byKey(const ValueKey('card-a')));
    expect(
      after.center,
      isNot(before.center),
      reason: 'a bigger globe puts the card further from the middle',
    );
  });

  /// A mouse, which `onScaleUpdate` never sees.
  ///
  /// `ScaleGestureRecognizer` is fed by pointers and trackpad pan-zoom events;
  /// a wheel is a `PointerSignalEvent` and goes through neither. So the globe
  /// zoomed on a phone and on a trackpad and did nothing at all on a desktop
  /// with a mouse, which no gesture test would have noticed.
  group('the wheel', () {
    /// One notch, as macOS reports it. Negative is up, which is in.
    Future<void> scroll(WidgetTester tester, double dy) async {
      final centre = tester.getCenter(find.byType(GlobeView));
      final pointer = TestPointer(1, PointerDeviceKind.mouse);
      pointer.hover(centre);
      await tester.sendEventToBinding(pointer.scroll(Offset(0, dy)));
      await tester.pump(const Duration(milliseconds: 16));
    }

    testWidgets('up zooms in, and a card moves out with the globe', (
      tester,
    ) async {
      // Not a server at the camera's own coordinate: that one projects to the
      // middle of the disc whatever the radius is, so it would not move.
      await show(tester, [item('a', 30, 30)]);
      final before = tester.getRect(find.byKey(const ValueKey('card-a')));

      await scroll(tester, -40);
      final after = tester.getRect(find.byKey(const ValueKey('card-a')));
      expect(after.center, isNot(before.center));
    });

    testWidgets('down is the way back out', (tester) async {
      await show(tester, [item('a', 30, 30)]);
      final start = tester.getRect(find.byKey(const ValueKey('card-a')));

      await scroll(tester, -40);
      final zoomed = tester.getRect(find.byKey(const ValueKey('card-a')));
      expect(zoomed.center, isNot(start.center));

      await scroll(tester, 40);
      final back = tester.getRect(find.byKey(const ValueKey('card-a')));
      // The same exponent in both directions, so one notch each way is where
      // it started — which is what makes a wheel feel like a wheel.
      expect(back.center.dx, closeTo(start.center.dx, 0.5));
      expect(back.center.dy, closeTo(start.center.dy, 0.5));
    });

    testWidgets('it stops rather than running away', (tester) async {
      // The clamp. Without it a wheel someone leans on takes the globe to a
      // radius the projection cannot draw anything useful at.
      await show(tester, [item('a', 30, 30)]);
      for (var i = 0; i < 40; i++) {
        await scroll(tester, -40);
      }
      final farIn = tester.getRect(find.byKey(const ValueKey('card-a')));
      await scroll(tester, -40);
      expect(
        tester.getRect(find.byKey(const ValueKey('card-a'))).center,
        farIn.center,
        reason: 'already at maxZoom',
      );

      for (var i = 0; i < 80; i++) {
        await scroll(tester, 40);
      }
      final farOut = tester.getRect(find.byKey(const ValueKey('card-a')));
      await scroll(tester, 40);
      expect(
        tester.getRect(find.byKey(const ValueKey('card-a'))).center,
        farOut.center,
        reason: 'already at minZoom',
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('a horizontal wheel does nothing', (tester) async {
      // A tilt wheel and a trackpad's sideways scroll both arrive here, and
      // neither means zoom.
      await show(tester, [item('a', 30, 30)]);
      final before = tester.getRect(find.byKey(const ValueKey('card-a')));
      final centre = tester.getCenter(find.byType(GlobeView));
      final pointer = TestPointer(1, PointerDeviceKind.mouse);
      pointer.hover(centre);
      await tester.sendEventToBinding(pointer.scroll(const Offset(40, 0)));
      await tester.pump(const Duration(milliseconds: 16));
      expect(
        tester.getRect(find.byKey(const ValueKey('card-a'))).center,
        before.center,
      );
    });
  });

  /// Crossing the horizon, which used to be a cut.
  ///
  /// The dots already faded on their own ramp while the cards and their leader
  /// lines appeared at full strength the instant the point cleared the
  /// outline. So the three pieces of one server disagreed about whether it was
  /// there — the worst of both choices rather than either made consistently.
  group('the horizon', () {
    /// The `Opacity` a card is wrapped in, which is what carries the fade.
    double cardOpacity(WidgetTester tester, String id) {
      return tester
          .widget<Opacity>(
            find
                .ancestor(
                  of: find.byKey(ValueKey('card-$id')),
                  matching: find.byType(Opacity),
                )
                .first,
          )
          .opacity;
    }

    testWidgets('a card at the limb is part drawn, not all or nothing', (
      tester,
    ) async {
      // `kHorizonFade` is a depth of 0.12, and depth is the cosine of the
      // angle from the camera — so a server about 86 degrees away sits inside
      // the band. Facing 0,0 puts it at longitude 86.
      await show(tester, [
        item('mid', 0, 0),
        item('edge', 0, 86),
      ], initial: GeoCoord.tryNew(0, 0));

      final edge = cardOpacity(tester, 'edge');
      expect(edge, greaterThan(0.0));
      expect(
        edge,
        lessThan(1.0),
        reason: 'inside the band, so on its way out rather than gone',
      );
      expect(
        cardOpacity(tester, 'mid'),
        1.0,
        reason: 'facing the camera, so nothing to fade',
      );
    });

    testWidgets('the leader line carries the same number', (tester) async {
      // Not a second ramp of its own: a line that outlived its card would be
      // a thread to nothing, and one that went first would leave the card
      // unattached.
      await show(tester, [
        item('mid', 0, 0),
        item('edge', 0, 86),
      ], initial: GeoCoord.tryNew(0, 0));

      final painter =
          tester
                  .widget<CustomPaint>(
                    find
                        .descendant(
                          of: find.byType(GlobeView),
                          matching: find.byType(CustomPaint),
                        )
                        .first,
                  )
                  .painter!
              as GlobePainter;
      final fades = painter.leaders.map((l) => l.fade).toList()..sort();
      expect(fades.first, closeTo(cardOpacity(tester, 'edge'), 0.001));
      expect(fades.last, 1.0);
    });
  });

  /// Turning on its own while a server is round the back.
  ///
  /// Half the sphere faces away at any moment, and a server there is not small
  /// — it is absent: no dot, no card, nothing saying it exists. A globe that
  /// never moves silently omits servers, and the only way to find them was to
  /// guess and drag.
  group('idle rotation', () {
    /// Long enough for several ticks, counted out rather than settled: a
    /// turning globe never gives `pumpAndSettle` the quiet frame it waits for.
    Future<void> turn(WidgetTester tester, [int ms = 1200]) async {
      for (var i = 0; i < ms ~/ 50; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
    }

    testWidgets('a server round the back sets the globe turning', (
      tester,
    ) async {
      // Facing 0,0 with a server at 0,180 — the far side exactly.
      await show(tester, [
        item('near', 0, 0),
        item('far', 0, 180),
      ], initial: GeoCoord.tryNew(0, 0));
      expect(
        find.byKey(const ValueKey('card-far')),
        findsNothing,
        reason: 'nothing is drawn for the far hemisphere',
      );

      // A server directly behind needs a quarter turn to reach the limb, so
      // this waits the ~8s that implies at the documented rate rather than
      // guessing at a shorter one.
      await turn(tester, 10000);
      expect(
        find.byKey(const ValueKey('card-far')),
        findsOneWidget,
        reason: 'it turned far enough to bring the hidden one round',
      );
    });

    testWidgets('with everything already in view it stays still', (
      tester,
    ) async {
      await show(tester, [item('a', 0, 0)], initial: GeoCoord.tryNew(0, 0));
      final before = tester.getRect(find.byKey(const ValueKey('card-a')));
      await turn(tester);
      expect(
        tester.getRect(find.byKey(const ValueKey('card-a'))),
        before,
        reason: 'nothing is hidden, so there is nothing to reveal',
      );
    });

    testWidgets('a drag ends it, and it does not come back', (tester) async {
      await show(tester, [
        item('near', 0, 0),
        item('far', 0, 180),
      ], initial: GeoCoord.tryNew(0, 0));

      // Far enough past the slop to be a drag rather than a tap, and slow
      // enough not to be a flick — a flick would coast, and this is about the
      // rotation not resuming once everything has stopped.
      final centre = tester.getCenter(find.byType(GlobeView));
      final drag = await tester.startGesture(centre);
      for (var i = 0; i < 8; i++) {
        await drag.moveBy(const Offset(5, 0));
        await tester.pump(const Duration(milliseconds: 60));
      }
      await drag.up();
      await tester.pump(const Duration(milliseconds: 400));

      final after = tester.getRect(find.byKey(const ValueKey('card-near')));
      await turn(tester, 2000);
      expect(
        tester.getRect(find.byKey(const ValueKey('card-near'))),
        after,
        reason: 'aimed by hand, and a globe that resumes fights the person',
      );
    });

    testWidgets('a tap ends it too', (tester) async {
      // Selecting a server means looking at it. Rotating it out of view next
      // would be the app taking back what the tap just did.
      await show(tester, [
        item('near', 0, 0),
        item('far', 0, 180),
      ], initial: GeoCoord.tryNew(0, 0));
      await tester.tapAt(tester.getCenter(find.byType(GlobeView)));
      await tester.pump(const Duration(milliseconds: 100));

      final after = tester.getRect(find.byKey(const ValueKey('card-near')));
      await turn(tester, 2000);
      expect(
        tester.getRect(find.byKey(const ValueKey('card-near'))),
        after,
      );
    });

    testWidgets('it stops the ticker rather than turning forever', (
      tester,
    ) async {
      // Two servers a quarter turn apart: once the globe has swung round,
      // both are on the near side and there is nothing left to reveal. A
      // ticker that kept running would hold a frame callback and the screen
      // awake for the life of the page.
      await show(tester, [
        item('a', 0, 0),
        item('b', 0, 60),
      ], initial: GeoCoord.tryNew(0, 0));
      await turn(tester, 6000);
      expect(
        tester.binding.transientCallbackCount,
        0,
        reason: 'nothing hidden any more, so nothing scheduled',
      );
      await tester.pumpWidget(const SizedBox.shrink());
    });
  });

  testWidgets('an empty globe is still a globe', (tester) async {
    await show(tester, const []);
    expect(find.byType(GlobeView), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a server nothing could place is still on screen', (
    tester,
  ) async {
    // A server that is simply absent reads as the globe having lost it.
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 400,
            height: 600,
            child: GlobeView(
              items: [item('placed', 0, 0)],
              cardSize: cardSize,
              initialCoord: GeoCoord.tryNew(0, 0),
              unplaced: const [Text('nat-box', key: ValueKey('unplaced'))],
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.byKey(const ValueKey('unplaced')), findsOneWidget);
    expect(find.byKey(const ValueKey('card-placed')), findsOneWidget);
  });

  /// That the globe was moved by hand, which is what says whether turning it
  /// on its own is enough.
  ///
  /// Once per mount rather than once per gesture, because a drag is a stream of
  /// them and this is a question about people rather than about frames.
  group('what is recorded', () {
    late _RecordingSink sink;

    setUp(() {
      sink = _RecordingSink();
      Diag.install(sink);
    });

    tearDown(Diag.uninstall);

    List<Map<String, String>?> turned() => [
      for (final crumb in sink.crumbs)
        if (crumb.message == 'turned') crumb.data,
    ];

    testWidgets('a drag says so once, however long it goes on', (tester) async {
      await show(tester, [item('a', 0, 0)]);
      final centre = tester.getCenter(find.byType(GlobeView));
      for (var pass = 0; pass < 2; pass++) {
        final gesture = await tester.startGesture(centre);
        for (var i = 0; i < 10; i++) {
          await gesture.moveBy(const Offset(10, 0));
          await tester.pump(const Duration(milliseconds: 16));
        }
        await gesture.up();
        await tester.pump();
      }
      expect(turned(), [
        {'how': 'gesture'},
      ]);
    });

    testWidgets('a wheel is the other path and is named as one', (tester) async {
      // It reaches none of the gesture code — see the group above — so a globe
      // that reported only gestures would report nothing at all on a desktop.
      await show(tester, [item('a', 30, 30)]);
      final pointer = TestPointer(1, PointerDeviceKind.mouse);
      pointer.hover(tester.getCenter(find.byType(GlobeView)));
      await tester.sendEventToBinding(pointer.scroll(const Offset(0, -40)));
      await tester.pump(const Duration(milliseconds: 16));
      expect(turned(), [
        {'how': 'scroll'},
      ]);
    });

    testWidgets('a globe nobody touches says nothing', (tester) async {
      await show(tester, [item('a', 0, 0)]);
      await tester.pump(const Duration(seconds: 2));
      expect(turned(), isEmpty);
    });
  });
}

/// Remembers every crumb, so what the globe publishes can be asserted.
final class _RecordingSink extends DiagnosticsSink {
  final crumbs = <Breadcrumb>[];

  @override
  void breadcrumb(Breadcrumb crumb) => crumbs.add(crumb);
}
