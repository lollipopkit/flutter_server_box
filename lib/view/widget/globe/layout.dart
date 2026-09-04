import 'dart:math' as math;
import 'dart:ui';

/// A card that wants to sit near a point on the globe.
typedef GlobeAnchor = ({String id, Offset at, double depth, Size size});

/// Where it ended up, and the point it still belongs to.
/// [depth] rides along from the anchor so the caller can fade a card and its
/// leader with the same curve the dot uses — see [GlobePoint.horizonFade].
/// Layout itself has no opinion about it.
typedef GlobePlacement = ({String id, Rect rect, Offset anchor, double depth});

/// Places cards near their points without letting them cover each other.
///
/// **The result has to be a function of the input and nothing else.** This
/// runs on every frame of a drag, so anything carried over from the previous
/// call — a random jitter, an iteration count that depends on how long the
/// last one took, a hash-ordered map — turns a smooth rotation into a shiver.
/// Every list here is sorted before it is walked, and every candidate position
/// is generated from an integer.
///
/// Cards are placed one at a time, nearest the viewer first, and each takes
/// the first free spot on a spiral out from where it would ideally sit. So the
/// front card gets what it wants and what gives way is what is furthest back —
/// which is what is about to rotate out of view anyway.
///
/// This replaced a relaxation pass — push every overlapping pair apart, repeat
/// — and the case that ruled that out is the ordinary one: ten servers in one
/// city project to *exactly* the same point, so every card starts at the same
/// rectangle, every pair pushes along the same axis by the same amount, and
/// the whole stack shuffles into the bounds and jams there. Placing one at a
/// time has no such state to get stuck in.
///
/// [bounds] is the area cards must stay inside; a candidate is clamped into it
/// before it is scored, so a spot that only fits by hanging off the edge is
/// correctly judged as still overlapping.
List<GlobePlacement> layoutGlobeCards({
  required List<GlobeAnchor> anchors,
  required Rect bounds,
  required Offset globeCenter,
  double gap = 6,
  int maxCandidates = 96,
}) {
  if (anchors.isEmpty) return const [];

  // Front to back, and by id where two are at the same depth. Two servers in
  // one city are at the same depth, so the tie-break is not a formality —
  // without it the order comes from wherever the caller's list came from,
  // which is a provider's map.
  final ordered = [...anchors]
    ..sort((a, b) {
      final byDepth = b.depth.compareTo(a.depth);
      return byDepth != 0 ? byDepth : a.id.compareTo(b.id);
    });

  final placed = <Rect>[];
  final result = <GlobePlacement>[];

  for (final anchor in ordered) {
    final ideal = _idealRect(anchor, globeCenter, gap);
    final stride = anchor.size.shortestSide + gap;

    var best = _clamp(ideal, bounds);
    var bestScore = double.infinity;

    for (var step = 0; step < maxCandidates; step++) {
      final candidate = _clamp(_spiral(ideal, step, stride), bounds);
      final score = _overlapArea(candidate, placed, gap);
      if (score <= 0) {
        best = candidate;
        bestScore = 0;
        break;
      }
      if (score < bestScore) {
        bestScore = score;
        best = candidate;
      }
    }

    placed.add(best);
    result.add((
      id: anchor.id,
      rect: best,
      anchor: anchor.at,
      depth: anchor.depth,
    ));
  }

  return result;
}

/// The card's ideal place: just outside its own point, away from the globe.
///
/// Outward rather than in a fixed direction so cards stay off the globe's
/// face, where the coastlines are — and so the point itself is not underneath
/// the card that names it, which is what the leader line connects to.
Rect _idealRect(GlobeAnchor anchor, Offset globeCenter, double gap) {
  final away = anchor.at - globeCenter;
  final distance = away.distance;
  // A point exactly at the middle of the disc has no outward direction, and
  // dividing by a zero distance gives NaN — which lays out as nothing at all
  // and is invisible in a way no test of the drawn result would catch. Up is
  // as good as any direction, and it is the same answer every time.
  final direction = distance < 0.001 ? const Offset(0, -1) : away / distance;
  final reach = anchor.size.longestSide / 2 + gap * 2;
  return Rect.fromCenter(
    center: anchor.at + direction * reach,
    width: anchor.size.width,
    height: anchor.size.height,
  );
}

/// The [step]-th candidate position, on a spiral out from [ideal].
///
/// The golden angle with a square-root radius — the arrangement seeds take on
/// a sunflower — because it spaces successive points evenly instead of laying
/// them along spokes the way a rational fraction of a turn does. Which matters
/// here for one reason: with cards on identical points, spokes would put the
/// second, third and fourth candidate in a line and the first free spot would
/// be much further out than it needs to be.
Rect _spiral(Rect ideal, int step, double stride) {
  if (step == 0) return ideal;
  const goldenAngle = 2.39996322972865332; // pi * (3 - sqrt(5))
  final angle = step * goldenAngle;
  final radius = stride * math.sqrt(step.toDouble()) * 0.9;
  return ideal.shift(
    Offset(math.cos(angle) * radius, math.sin(angle) * radius),
  );
}

/// How much of [candidate] is covered by something already placed.
///
/// An area rather than a boolean, so that when nothing fits — twenty servers
/// in one city on a phone — the least bad spot is still a choice rather than
/// whatever the loop happened to end on.
double _overlapArea(Rect candidate, List<Rect> placed, double gap) {
  var total = 0.0;
  final inflated = candidate.inflate(gap / 2);
  for (final other in placed) {
    final intersection = inflated.intersect(other.inflate(gap / 2));
    if (intersection.width <= 0 || intersection.height <= 0) continue;
    total += intersection.width * intersection.height;
  }
  return total;
}

Rect _clamp(Rect rect, Rect bounds) {
  // A card larger than the area it is clamped into has no position that fits.
  // Pinning it to the top left is at least somewhere its own text starts on
  // screen.
  var dx = 0.0;
  var dy = 0.0;
  if (rect.width <= bounds.width) {
    if (rect.left < bounds.left) dx = bounds.left - rect.left;
    if (rect.right > bounds.right) dx = bounds.right - rect.right;
  } else {
    dx = bounds.left - rect.left;
  }
  if (rect.height <= bounds.height) {
    if (rect.top < bounds.top) dy = bounds.top - rect.top;
    if (rect.bottom > bounds.bottom) dy = bounds.bottom - rect.bottom;
  } else {
    dy = bounds.top - rect.top;
  }
  return rect.shift(Offset(dx, dy));
}
