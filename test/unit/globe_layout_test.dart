import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/view/widget/globe/layout.dart';

void main() {
  const bounds = Rect.fromLTWH(0, 0, 400, 400);
  const globeCenter = Offset(200, 200);
  const size = Size(90, 40);

  GlobeAnchor anchor(String id, Offset at, [double depth = 1]) =>
      (id: id, at: at, depth: depth, size: size);

  List<GlobePlacement> run(List<GlobeAnchor> anchors) => layoutGlobeCards(
    anchors: anchors,
    bounds: bounds,
    globeCenter: globeCenter,
  );

  bool anyOverlap(List<GlobePlacement> placed) {
    for (var i = 0; i < placed.length; i++) {
      for (var j = i + 1; j < placed.length; j++) {
        if (placed[i].rect.overlaps(placed[j].rect)) return true;
      }
    }
    return false;
  }

  test('nothing in, nothing out', () {
    expect(run(const []), isEmpty);
  });

  test('one card sits beside its point, not on top of it', () {
    final placed = run([anchor('a', const Offset(200, 120))]).single;
    expect(placed.id, 'a');
    expect(placed.anchor, const Offset(200, 120));
    expect(
      placed.rect.contains(const Offset(200, 120)),
      isFalse,
      reason: 'the point it names must stay visible',
    );
    // Outward from the middle of the disc, which for a point above the middle
    // is further up. That keeps cards off the globe's face.
    expect(placed.rect.center.dy, lessThan(120));
  });

  test('a card at the very middle still gets a direction', () {
    // There is no outward direction at the centre, and dividing by a zero
    // distance would put the card at NaN — which lays out as nothing at all.
    final placed = run([anchor('a', globeCenter)]).single;
    expect(placed.rect.center.dx.isFinite, isTrue);
    expect(placed.rect.center.dy.isFinite, isTrue);
  });

  test('two cards on the same point end up apart', () {
    final placed = run([
      anchor('a', const Offset(200, 120)),
      anchor('b', const Offset(200, 120)),
    ]);
    expect(placed, hasLength(2));
    expect(anyOverlap(placed), isFalse);
  });

  test('a crowd is separated', () {
    // Ten servers in one city, which is what a rack looks like from orbit.
    final placed = run([
      for (var i = 0; i < 10; i++) anchor('s$i', const Offset(200, 140), 1 - i / 20),
    ]);
    expect(placed, hasLength(10));
    expect(anyOverlap(placed), isFalse);
  });

  test('the same input gives the same output', () {
    // The one property this has to have. It runs on every frame of a drag, so
    // anything carried between calls — a jitter, a hash-ordered map, a
    // "settle until stable" loop — is a shiver rather than a rotation.
    final anchors = [
      anchor('c', const Offset(210, 150), 0.4),
      anchor('a', const Offset(200, 140), 0.9),
      anchor('b', const Offset(205, 145), 0.9),
    ];
    final first = run(anchors);
    for (var i = 0; i < 5; i++) {
      final again = run(anchors);
      for (var k = 0; k < first.length; k++) {
        expect(again[k].id, first[k].id);
        expect(again[k].rect, first[k].rect);
      }
    }
  });

  test('the order of the input does not change the result', () {
    // Two cards at one depth are ordered by id, so the caller's list order —
    // which comes from a provider's map — cannot decide who gives way.
    final a = anchor('a', const Offset(200, 140));
    final b = anchor('b', const Offset(202, 142));
    final forwards = run([a, b]);
    final backwards = run([b, a]);
    expect(backwards.map((p) => p.id), forwards.map((p) => p.id));
    expect(backwards.map((p) => p.rect), forwards.map((p) => p.rect));
  });

  test('the card nearest the viewer moves least', () {
    final placed = run([
      anchor('front', const Offset(200, 140), 0.95),
      anchor('back', const Offset(200, 140), 0.10),
    ]);
    final front = placed.firstWhere((p) => p.id == 'front');
    final back = placed.firstWhere((p) => p.id == 'back');
    final solo = run([anchor('front', const Offset(200, 140), 0.95)]).single;
    expect(
      (front.rect.center - solo.rect.center).distance,
      lessThan((back.rect.center - solo.rect.center).distance),
      reason: 'what gives way should be what is about to rotate out of view',
    );
  });

  test('everything stays inside the bounds', () {
    // Anchored in a corner, where separation and clamping fight each other.
    final placed = run([
      for (var i = 0; i < 6; i++) anchor('s$i', const Offset(6, 6), 1 - i / 10),
    ]);
    for (final p in placed) {
      expect(bounds.contains(p.rect.topLeft), isTrue, reason: p.id);
      expect(
        bounds.contains(p.rect.bottomRight - const Offset(0.001, 0.001)),
        isTrue,
        reason: p.id,
      );
    }
  });

  test('a card wider than the space is pinned, not pushed off screen', () {
    final placed = layoutGlobeCards(
      anchors: [(id: 'a', at: const Offset(50, 50), depth: 1, size: const Size(500, 40))],
      bounds: bounds,
      globeCenter: globeCenter,
    ).single;
    // It cannot fit, so its own text has to at least start on screen.
    expect(placed.rect.left, bounds.left);
    expect(placed.rect.top, greaterThanOrEqualTo(bounds.top));
  });

  test('a card taller than the space is pinned to the top', () {
    // The other half of the oversize case. Both axes are clamped
    // independently, so a card that fits horizontally and not vertically has
    // to be handled on its own.
    final placed = layoutGlobeCards(
      anchors: [
        (id: 'a', at: const Offset(200, 50), depth: 1, size: const Size(80, 900)),
      ],
      bounds: bounds,
      globeCenter: globeCenter,
    ).single;
    expect(placed.rect.top, bounds.top);
    expect(placed.rect.left, greaterThanOrEqualTo(bounds.left));
  });

  /// A control floating over the globe — the way out, when the globe is the
  /// whole page and nothing else on screen leaves it.
  ///
  /// It has to be given to the layout rather than stacked over the result: a
  /// card goes wherever there is room, and the corner the control sits in is
  /// room. A card laid out under it is unreadable and its own taps go to the
  /// control, which is drawn on top.
  group('a reserved rectangle', () {
    // The top right corner, where the server tab puts its way back to the list.
    const corner = Rect.fromLTWH(344, 8, 48, 48);

    List<GlobePlacement> withCorner(List<GlobeAnchor> anchors) =>
        layoutGlobeCards(
          anchors: anchors,
          bounds: bounds,
          globeCenter: globeCenter,
          reserved: const [corner],
        );

    test('is not something a card is placed under', () {
      // Anchored into the corner itself, so the ideal spot is the one taken.
      final placed = withCorner([anchor('a', const Offset(370, 30))]).single;
      expect(placed.rect.overlaps(corner), isFalse);
    });

    test('and a crowd is pushed clear of it as well', () {
      final placed = withCorner([
        for (var i = 0; i < 6; i++)
          anchor('s$i', const Offset(370, 30), 1 - i / 10),
      ]);
      expect(placed, hasLength(6));
      expect(anyOverlap(placed), isFalse);
      for (final p in placed) {
        expect(p.rect.overlaps(corner), isFalse, reason: p.id);
      }
    });

    test('is not itself a placement', () {
      // It belongs to the caller. Returning it would draw a leader line from
      // the globe to a button.
      expect(withCorner([anchor('a', const Offset(200, 120))]), hasLength(1));
    });

    test('and none of it changes anything when there is none', () {
      final anchors = [
        anchor('a', const Offset(200, 140), 0.9),
        anchor('b', const Offset(205, 145), 0.4),
      ];
      final without = layoutGlobeCards(
        anchors: anchors,
        bounds: bounds,
        globeCenter: globeCenter,
        reserved: const [],
      );
      expect(without.map((p) => p.rect), run(anchors).map((p) => p.rect));
    });
  });

  test('the anchor is carried through untouched', () {
    // The leader line is drawn from the card to this, so a layout that moved
    // it would draw a line to where the card already is.
    final placed = run([
      anchor('a', const Offset(120, 160)),
      anchor('b', const Offset(124, 164)),
    ]);
    expect(
      placed.map((p) => p.anchor).toSet(),
      {const Offset(120, 160), const Offset(124, 164)},
    );
  });
}
