import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';

import 'package:server_box/data/model/server/geo.dart';
import 'package:server_box/view/widget/globe/land.dart';

/// Which way the globe is facing, and how big it is drawn.
///
/// Orthographic, which is the projection a globe *is*: parallel rays, a
/// circular outline, and exactly one hemisphere visible at a time. A
/// perspective projection would be more nearly what an eye sees and would cost
/// a near-plane, a field of view and a distance to argue about, none of which
/// changes what the picture is for.
final class GlobeCamera {
  const GlobeCamera({
    required this.lat,
    required this.lon,
    required this.center,
    required this.radius,
  });

  /// The latitude at the middle of the disc, in degrees, clamped to the poles.
  final double lat;

  /// The longitude at the middle of the disc, in degrees. Not clamped: it
  /// wraps, and a globe that stopped spinning at the antimeridian would be a
  /// globe with an edge.
  final double lon;

  /// Where the middle of the disc is, in the painter's coordinates.
  final Offset center;

  /// Half the width of the disc, in pixels.
  final double radius;

  GlobeCamera copyWith({
    double? lat,
    double? lon,
    Offset? center,
    double? radius,
  }) => GlobeCamera(
    lat: lat ?? this.lat,
    lon: lon ?? this.lon,
    center: center ?? this.center,
    radius: radius ?? this.radius,
  );

  /// The camera after a drag of [delta] pixels.
  ///
  /// The mapping is "the surface follows the finger": a point near the middle
  /// of the disc moves by roughly [delta], which is what makes the globe feel
  /// grabbed rather than steered. It is only *roughly* — the true rate falls
  /// off as `cos(lat)` toward the limb, and matching that exactly would make
  /// the globe accelerate away from the pointer near the edge.
  ///
  /// Latitude is clamped at the poles. Longitude is not: it wraps, and
  /// stopping it would put an edge on a sphere.
  GlobeCamera drag(Offset delta) {
    if (radius <= 0) return this;
    const perRadian = 180 / math.pi;
    return copyWith(
      // Dragging right moves the surface right, which means looking further
      // *west* — hence the minus.
      lon: _wrapLon(lon - delta.dx / radius * perRadian),
      lat: (lat + delta.dy / radius * perRadian).clamp(-90.0, 90.0),
    );
  }

  static double _wrapLon(double lon) {
    var wrapped = (lon + 180) % 360;
    if (wrapped < 0) wrapped += 360;
    return wrapped - 180;
  }

  /// By value, because it is what `shouldRepaint` asks about.
  ///
  /// Without it a camera rebuilt to the same numbers is a different object and
  /// every frame repaints — which for a globe that is not moving is five
  /// thousand vertices projected to draw what is already on screen.
  @override
  bool operator ==(Object other) =>
      other is GlobeCamera &&
      other.lat == lat &&
      other.lon == lon &&
      other.center == center &&
      other.radius == radius;

  @override
  int get hashCode => Object.hash(lat, lon, center, radius);

  @override
  String toString() =>
      'GlobeCamera($lat, $lon, r=$radius @ ${center.dx},${center.dy})';
}

/// A coordinate's place on the disc, and which side of the sphere it is on.
final class GlobePoint {
  const GlobePoint(this.offset, this.depth);

  /// Where it lands, in the painter's coordinates.
  final Offset offset;

  /// The z of the unit vector: 1 at the middle of the disc, 0 at the limb,
  /// negative on the far side.
  final double depth;

  /// Whether this is on the side of the sphere facing the viewer.
  ///
  /// Exactly at the limb counts as hidden. The alternative is a point drawn on
  /// the outline itself, which is where the far side starts and where a marker
  /// reads as being on the wrong continent.
  ///
  /// Against a threshold rather than against zero, because zero is not
  /// reachable: a point ninety degrees from the camera has a depth of
  /// `cos(pi/2)`, which is 6e-17 and not 0, so a bare `> 0` calls the limb
  /// visible. The value is far below a pixel's worth of depth on any globe
  /// that fits on a screen — it exists to name the boundary, not to move it.
  bool get visible => depth > 1e-9;

  /// How solid something at this point should be drawn, 0 at the limb to 1.
  ///
  /// The horizon is not an edge anything crosses instantly: a server rotating
  /// out of view should *go*, not blink. Without it a card and its leader line
  /// appear at full strength the moment the point clears the outline, which
  /// reads as the globe spitting them out.
  ///
  /// One definition rather than three. The dots already faded on their own
  /// ramp while the cards and lines popped, which is a worse effect than
  /// either choice made consistently — the pieces of one server disagreed
  /// about whether it was there.
  ///
  /// [kHorizonFade] is a depth, not an angle: depth is `cos` of the angle from
  /// the camera, so the band is wide near the limb where things move fastest
  /// across the screen and narrow in the middle where they barely move. That
  /// is the right way round — it is time on screen that the eye reads, and
  /// this spends about the same amount of it whatever the rotation rate.
  double get horizonFade => horizonFadeAt(depth);
}

/// [GlobePoint.horizonFade] for a depth on its own.
///
/// The cards and the leader lines are placed by `layout.dart`, which carries
/// a depth and no point — so the curve has to be reachable without one, or
/// each caller would invent its own and the pieces of one server would
/// disagree again.
double horizonFadeAt(double depth) => (depth / kHorizonFade).clamp(0.0, 1.0);

/// Where [GlobePoint.horizonFade] reaches full strength.
///
/// About seven degrees in from the limb. Long enough to read as a fade and
/// short enough that a card is legible for nearly all of its time on screen.
const kHorizonFade = 0.12;

/// The camera with its trigonometry done once.
///
/// Every land vertex and every server goes through [project], thousands of
/// times per frame, and the camera's own sine and cosine do not change between
/// them.
final class GlobeProjection {
  factory GlobeProjection(GlobeCamera camera) {
    final sinLat = math.sin(camera.lat * _rad);
    final cosLat = math.cos(camera.lat * _rad);
    final sinLon = math.sin(camera.lon * _rad);
    final cosLon = math.cos(camera.lon * _rad);
    return GlobeProjection._(
      camera: camera,
      sinLat: sinLat,
      cosLat: cosLat,
      lon: camera.lon * _rad,
      // The three rows of the rotation that takes a point on the unit sphere
      // to (right, up, toward the viewer). Written out rather than kept as a
      // matrix type because the x row's third term is always zero, and this is
      // the inner loop of every frame.
      xa: -sinLon,
      xb: cosLon,
      ya: -sinLat * cosLon,
      yb: -sinLat * sinLon,
      yc: cosLat,
      za: cosLat * cosLon,
      zb: cosLat * sinLon,
      zc: sinLat,
    );
  }

  const GlobeProjection._({
    required this.camera,
    required double sinLat,
    required double cosLat,
    required double lon,
    required double xa,
    required double xb,
    required double ya,
    required double yb,
    required double yc,
    required double za,
    required double zb,
    required double zc,
  }) : _sinLat = sinLat,
       _cosLat = cosLat,
       _lon = lon,
       _xa = xa,
       _xb = xb,
       _ya = ya,
       _yb = yb,
       _yc = yc,
       _za = za,
       _zb = zb,
       _zc = zc;

  final GlobeCamera camera;
  final double _sinLat;
  final double _cosLat;
  final double _lon;
  final double _xa;
  final double _xb;
  final double _ya;
  final double _yb;
  final double _yc;
  final double _za;
  final double _zb;
  final double _zc;

  static const _rad = math.pi / 180;

  /// Where a point already on the unit sphere lands.
  ///
  /// Nine multiplies and no trigonometry, which is why the land outlines are
  /// stored as vectors — see [GlobeLand]. Screen y is negated because north is
  /// up and a canvas counts downward.
  GlobePoint projectVector(double vx, double vy, double vz) {
    final x = _xa * vx + _xb * vy;
    final y = _ya * vx + _yb * vy + _yc * vz;
    final z = _za * vx + _zb * vy + _zc * vz;
    return GlobePoint(
      Offset(
        camera.center.dx + x * camera.radius,
        camera.center.dy - y * camera.radius,
      ),
      z,
    );
  }

  /// Where [coord] lands.
  ///
  /// For the handful of points that are servers. Everything drawn in bulk goes
  /// through [projectVector] with the trigonometry already done.
  GlobePoint project(GeoCoord coord) {
    final lat = coord.lat * _rad;
    final lon = coord.lon * _rad;
    final cosLat = math.cos(lat);
    return projectVector(
      cosLat * math.cos(lon),
      cosLat * math.sin(lon),
      math.sin(lat),
    );
  }

  /// The coordinate under a point on the disc, or null outside it.
  ///
  /// Only the near hemisphere has an answer: every point on the disc is two
  /// places on the sphere, and the one facing the viewer is the one that was
  /// tapped.
  GeoCoord? unproject(Offset point) {
    if (camera.radius <= 0) return null;
    final x = (point.dx - camera.center.dx) / camera.radius;
    final y = (camera.center.dy - point.dy) / camera.radius;
    final rho2 = x * x + y * y;
    if (rho2 > 1) return null;
    final z = math.sqrt(1 - rho2);

    final lat = math.asin(z * _sinLat + y * _cosLat);
    final lon = _lon + math.atan2(x, z * _cosLat - y * _sinLat);
    return GeoCoord.tryNew(lat / _rad, GlobeCamera._wrapLon(lon / _rad));
  }

  /// The runs of a ring that are on the near side, already projected.
  ///
  /// [ring] is packed `[x, y, z, ...]` unit vectors — what [GlobeLand] holds.
  ///
  /// Split into runs rather than drawn as one path, because a ring that
  /// crosses to the far side and back would otherwise be joined by a straight
  /// line across the face of the disc. Each run is a polyline to stroke on its
  /// own.
  ///
  /// A run ends at the last vertex before the horizon rather than at the
  /// horizon itself. At 110 m resolution consecutive vertices are about a
  /// degree apart, so the gap is well under a pixel on any globe that fits on
  /// a screen — and closing it would mean solving for where the great-circle
  /// arc between two vertices crosses `z = 0`, per edge, per frame.
  List<List<Offset>> projectRing(Float32List ring) {
    final count = ring.length ~/ 3;
    final runs = <List<Offset>>[];
    var current = <Offset>[];

    /// Whether the run being built began at vertex 0.
    var buildingFromFirst = false;

    /// Whether the run that began at vertex 0 was **kept**, and whether the one
    /// that ends at the last vertex was.
    ///
    /// Both are the question the closing segment below actually needs, and
    /// asking whether the *vertex* is visible is not the same one: a run of a
    /// single point is dropped — there is nothing to draw — so a ring whose
    /// vertex 0 is visible while vertex 1 is not has a visible first vertex and
    /// no run holding it. `runs.first.first` was then some other run's start,
    /// and the closing segment was drawn from the last vertex to an unrelated
    /// point on the disc, appearing and disappearing as the globe turned.
    var keptFirst = false;
    var keptLast = false;

    for (var i = 0; i < count; i++) {
      final point = projectVector(ring[i * 3], ring[i * 3 + 1], ring[i * 3 + 2]);
      if (point.visible) {
        if (i == 0) buildingFromFirst = true;
        current.add(point.offset);
      } else if (current.isNotEmpty) {
        if (current.length > 1) {
          runs.add(current);
          if (buildingFromFirst) keptFirst = true;
        }
        buildingFromFirst = false;
        current = <Offset>[];
      }
    }
    // Whatever is still open owns the last vertex, if it owns anything.
    if (current.length > 1) {
      runs.add(current);
      if (buildingFromFirst) keptFirst = true;
      keptLast = true;
    }

    // The segment from the last vertex back to the first is a real edge of the
    // coastline — the file stores rings open, so nothing else adds it.
    //
    // It has to be drawn whenever *both* ends are on screen, not only when the
    // whole ring is. A landmass rotating out of view whose stored seam happens
    // to sit on the near side comes back as two runs, and closing only the
    // one-run case left a notch in the outline that travelled as the globe
    // turned. When the whole ring is one run these are the same run, and this
    // closes it onto itself — which is what a closed ring is.
    if (keptFirst && keptLast) runs.last.add(runs.first.first);
    return runs;
  }
}
