import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/data/model/server/geo.dart';
import 'package:server_box/view/widget/globe/land.dart';
import 'package:server_box/view/widget/globe/projection.dart';

GeoCoord at(double lat, double lon) => GeoCoord.tryNew(lat, lon)!;

void main() {
  const center = Offset(200, 200);
  const radius = 100.0;

  GlobeProjection facing(double lat, double lon) => GlobeProjection(
    GlobeCamera(lat: lat, lon: lon, center: center, radius: radius),
  );

  group('projection', () {
    test('what the camera faces lands in the middle, at full depth', () {
      for (final (lat, lon) in const [(0.0, 0.0), (45.0, 120.0), (-30.0, -75.0)]) {
        final point = facing(lat, lon).project(at(lat, lon));
        expect(point.offset.dx, closeTo(center.dx, 1e-9), reason: '$lat,$lon');
        expect(point.offset.dy, closeTo(center.dy, 1e-9), reason: '$lat,$lon');
        expect(point.depth, closeTo(1, 1e-9));
      }
    });

    test('the antipode is at depth -1', () {
      expect(facing(0, 0).project(at(0, 180)).depth, closeTo(-1, 1e-9));
      expect(facing(40, 20).project(at(-40, -160)).depth, closeTo(-1, 1e-9));
    });

    test('north is up, which a canvas counting downward has to be told', () {
      final point = facing(0, 0).project(at(45, 0));
      expect(point.offset.dx, closeTo(center.dx, 1e-9));
      expect(
        point.offset.dy,
        lessThan(center.dy),
        reason: 'a northern point must be above the middle',
      );
    });

    test('east is right', () {
      expect(facing(0, 0).project(at(0, 45)).offset.dx, greaterThan(center.dx));
      expect(facing(0, 0).project(at(0, -45)).offset.dx, lessThan(center.dx));
    });

    test('90 degrees away is exactly on the limb, and hidden', () {
      final point = facing(0, 0).project(at(0, 90));
      expect((point.offset - center).distance, closeTo(radius, 1e-9));
      expect(point.depth, closeTo(0, 1e-9));
      // Not `>=`: a point drawn on the outline is where the far side begins,
      // and a marker there reads as being on the wrong continent.
      expect(point.visible, isFalse);
    });

    test('nothing ever lands outside the disc', () {
      final projection = facing(23, -140);
      for (var lat = -90; lat <= 90; lat += 7) {
        for (var lon = -180; lon < 180; lon += 11) {
          final point = projection.project(at(lat.toDouble(), lon.toDouble()));
          expect(
            (point.offset - center).distance,
            lessThanOrEqualTo(radius + 1e-9),
            reason: '$lat,$lon',
          );
        }
      }
    });

    test('the poles are where the camera puts them', () {
      // Facing the equator, the north pole is straight up at the limb.
      final fromEquator = facing(0, 0).project(at(90, 0));
      expect(fromEquator.offset.dy, closeTo(center.dy - radius, 1e-9));
      // Facing the north pole, it is the middle.
      final fromPole = facing(90, 0).project(at(90, 0));
      expect(fromPole.offset, within(distance: 1e-9, from: center));
      // A meridian's longitude is meaningless at the pole itself, and the
      // formula has to agree.
      expect(
        facing(0, 0).project(at(90, 137)).offset,
        within(distance: 1e-9, from: fromEquator.offset),
      );
    });
  });

  group('unproject', () {
    test('round-trips every point on the near side', () {
      final projection = facing(17, 64);
      for (var lat = -80; lat <= 80; lat += 13) {
        for (var lon = -180; lon < 180; lon += 17) {
          final coord = at(lat.toDouble(), lon.toDouble());
          final point = projection.project(coord);
          if (!point.visible) continue;
          final back = projection.unproject(point.offset)!;
          expect(back.lat, closeTo(coord.lat, 1e-6), reason: '$lat,$lon');
          // Longitude is degenerate at the poles and wraps at 180, so compare
          // where the two land rather than the numbers.
          final again = projection.project(back);
          expect(
            (again.offset - point.offset).distance,
            lessThan(1e-6),
            reason: '$lat,$lon',
          );
        }
      }
    });

    test('outside the disc is nowhere', () {
      final projection = facing(0, 0);
      expect(projection.unproject(center + const Offset(radius + 1, 0)), isNull);
      expect(projection.unproject(Offset.zero), isNull);
    });

    test('a zero-radius globe answers nothing rather than dividing by it', () {
      final flat = GlobeProjection(
        const GlobeCamera(lat: 0, lon: 0, center: center, radius: 0),
      );
      expect(flat.unproject(center), isNull);
    });
  });

  group('dragging', () {
    test('the surface follows the finger', () {
      // A point under the pointer near the middle should move with it. Not
      // exactly — the rate falls off toward the limb — so this asks for the
      // direction and the rough magnitude.
      const start = GlobeCamera(
        lat: 0,
        lon: 0,
        center: center,
        radius: radius,
      );
      final coord = at(0, 0);
      final before = GlobeProjection(start).project(coord).offset;
      final after = GlobeProjection(
        start.drag(const Offset(20, 10)),
      ).project(coord).offset;
      expect(after.dx - before.dx, closeTo(20, 1.5));
      expect(after.dy - before.dy, closeTo(10, 1.5));
    });

    test('latitude stops at the poles', () {
      const start = GlobeCamera(
        lat: 0,
        lon: 0,
        center: center,
        radius: radius,
      );
      expect(start.drag(const Offset(0, 10000)).lat, 90);
      expect(start.drag(const Offset(0, -10000)).lat, -90);
    });

    test('longitude wraps instead of stopping', () {
      // A sphere has no edge, so neither does this. Half a turn each way from
      // the antimeridian has to land somewhere valid.
      const start = GlobeCamera(
        lat: 0,
        lon: 179,
        center: center,
        radius: radius,
      );
      final spun = start.drag(const Offset(-1000, 0));
      expect(spun.lon, inInclusiveRange(-180, 180));
      // And spinning all the way round comes back.
      var camera = start;
      final full = (2 * math.pi * radius).round();
      for (var i = 0; i < full; i++) {
        camera = camera.drag(const Offset(-1, 0));
      }
      expect(camera.lon, closeTo(179, 1));
    });

    test('a zero-radius globe cannot be spun', () {
      const flat = GlobeCamera(lat: 10, lon: 20, center: center, radius: 0);
      expect(flat.drag(const Offset(50, 50)).lon, 20);
    });
  });

  group('the camera as a value', () {
    const base = GlobeCamera(
      lat: 10,
      lon: 20,
      center: center,
      radius: radius,
    );

    test('copyWith changes one thing and keeps the rest', () {
      expect(base.copyWith(lat: 30).lat, 30);
      expect(base.copyWith(lat: 30).lon, 20);
      expect(base.copyWith(radius: 5).radius, 5);
      expect(base.copyWith(center: Offset.zero).center, Offset.zero);
      expect(base.copyWith(), base);
    });

    test('equality is by value, which is what shouldRepaint asks', () {
      // Without it a camera rebuilt to the same numbers is a different object,
      // and every frame reprojects five thousand vertices to draw what is
      // already on screen.
      const same = GlobeCamera(
        lat: 10,
        lon: 20,
        center: center,
        radius: radius,
      );
      expect(base, same);
      expect(base.hashCode, same.hashCode);
      expect(base, isNot(base.copyWith(lon: 21)));
      expect(base, isNot(base.copyWith(radius: 99)));
      expect(base, isNot(base.copyWith(center: Offset.zero)));
    });

    test('reads as itself in a log line', () {
      expect(base.toString(), contains('10'));
      expect(base.toString(), contains('20'));
      expect(base.toString(), startsWith('GlobeCamera('));
    });
  });

  group('rings', () {
    test('a ring wholly on the near side comes back closed', () {
      final ring = [at(0, -10), at(10, 0), at(0, 10), at(-10, 0)];
      final runs = facing(0, 0).projectRing(GlobeLand.vectorsOf(ring));
      expect(runs, hasLength(1));
      // One more point than the ring has: the last segment back to the start
      // is a real edge of the coastline, and nothing else would add it.
      expect(runs.single, hasLength(ring.length + 1));
      expect(runs.single.last, runs.single.first);
    });

    test('a ring crossing the horizon comes back in pieces', () {
      // Without splitting, the two visible stretches would be joined by a
      // straight line drawn across the face of the globe.
      final ring = [
        at(0, -20),
        at(0, 0),
        at(0, 20),
        at(0, 160),
        at(0, 180),
        at(0, -160),
      ];
      final runs = facing(0, 0).projectRing(GlobeLand.vectorsOf(ring));
      expect(runs, hasLength(1));
      expect(runs.single, hasLength(3));
    });

    test('a ring straddling the horizon still closes its seam', () {
      // A ring is stored open and the reader closes it. Closing only when the
      // *whole* ring is visible left a notch in the outline of any landmass
      // rotating out of view whose stored seam happened to be on the near
      // side — and the notch travelled as the globe turned.
      //
      // Two visible vertices at each end and two behind the limb between
      // them. Two at each end because a single visible vertex is not a line
      // and is dropped — so a four-vertex ring produces no runs at all.
      final ring = [
        at(10, -30),
        at(20, -10),
        at(0, 120),
        at(0, -120),
        at(-20, -10),
        at(-10, -30),
      ];
      final runs = facing(0, 0).projectRing(GlobeLand.vectorsOf(ring));
      expect(runs, hasLength(2), reason: 'two visible stretches');
      expect(
        runs.last.last,
        runs.first.first,
        reason: 'the seam from the last vertex back to the first',
      );
    });

    test('a lone visible first vertex does not become a seam', () {
      // The bug this replaced: closing was decided by re-projecting vertex 0
      // and the last vertex and asking whether each was *visible*, which is
      // not the same question as whether the run holding it survived. A run of
      // one point is dropped — there is nothing to draw — so here vertex 0 is
      // visible and no run contains it, and `runs.first.first` was some other
      // run's start. The seam was then drawn from the last vertex to an
      // unrelated point on the disc, and it moved as the globe turned.
      //
      // Vertex 0 visible, vertex 1 behind the limb, then a stretch of two on
      // the near side, then back behind, then the last two visible.
      final ring = [
        at(0, -5), // visible, and alone
        at(0, 150), // behind
        at(30, -20),
        at(35, -25), // a run of two
        at(0, 160), // behind
        at(-35, -25),
        at(-30, -20), // the run that owns the last vertex
      ];
      final runs = facing(0, 0).projectRing(GlobeLand.vectorsOf(ring));

      expect(runs, hasLength(2), reason: 'the single-point run is dropped');
      expect(
        runs.last.last,
        isNot(runs.first.first),
        reason: 'no seam, because nothing kept the vertex it would start from',
      );
    });

    test('a lone visible last vertex does not become one either', () {
      // The mirror case. The final run is dropped, so `runs.last` ends at a
      // vertex that went over the horizon rather than at the ring's end.
      final ring = [
        at(30, -20),
        at(35, -25), // the run that owns vertex 0
        at(0, 150), // behind
        at(-35, -25),
        at(-30, -20), // another visible stretch
        at(0, 160), // behind
        at(0, -5), // visible, and alone
      ];
      final runs = facing(0, 0).projectRing(GlobeLand.vectorsOf(ring));

      expect(runs, hasLength(2));
      expect(runs.last.last, isNot(runs.first.first));
    });

    test('a ring whose seam is hidden is not closed across the disc', () {
      // The other half: vertex 0 is behind the limb, so there is no seam to
      // draw and joining the runs would put a line across the globe's face.
      final ring = [at(0, 180), at(10, -10), at(-10, -10), at(0, 170)];
      final runs = facing(0, 0).projectRing(GlobeLand.vectorsOf(ring));
      expect(runs, hasLength(1));
      expect(runs.single.last, isNot(runs.single.first));
    });

    test('a ring entirely on the far side draws nothing', () {
      final ring = [at(0, 160), at(10, 170), at(0, 180), at(-10, -170)];
      expect(facing(0, 0).projectRing(GlobeLand.vectorsOf(ring)), isEmpty);
    });

    test('a single visible vertex is not a line', () {
      final ring = [at(0, 0), at(0, 120), at(0, -120)];
      expect(facing(0, 0).projectRing(GlobeLand.vectorsOf(ring)), isEmpty);
    });

    test('an empty ring is not a crash', () {
      expect(facing(0, 0).projectRing(GlobeLand.vectorsOf(const [])), isEmpty);
    });
  });
}
