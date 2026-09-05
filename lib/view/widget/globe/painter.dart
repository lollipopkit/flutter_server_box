import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:server_box/data/model/server/geo.dart';
import 'package:server_box/view/widget/globe/land.dart';
import 'package:server_box/view/widget/globe/projection.dart';

/// One server, on the globe.
typedef GlobeMarker = ({String id, GeoCoord coord, Color color});

/// A line from a card to the point it names.
/// [fade] is [GlobePoint.horizonFade] for the server this line points at, so
/// the line goes with its card and its dot rather than outliving them.
typedef GlobeLeader = ({Rect card, Offset anchor, double fade});

/// The colours the globe borrows from the theme.
///
/// Passed in rather than read from a `BuildContext` inside the painter, so the
/// painter is a pure function of its inputs and `shouldRepaint` can answer by
/// comparing them.
final class GlobePalette {
  const GlobePalette({
    required this.lit,
    required this.shadow,
    required this.glow,
    required this.land,
    required this.graticule,
    required this.leader,
  });

  /// The sphere where it faces the light, and where it does not.
  final Color lit;
  final Color shadow;

  /// The haze outside the outline. Its alpha is the strength at the edge.
  final Color glow;

  final Color land;
  final Color graticule;
  final Color leader;

  factory GlobePalette.of(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return GlobePalette(
      // The shadow side tends toward the page's own background rather than
      // toward black, so the globe sits in the theme instead of on top of it.
      lit: Color.alphaBlend(
        scheme.primary.withValues(alpha: dark ? 0.55 : 0.35),
        scheme.surfaceContainerHighest,
      ),
      shadow: Color.alphaBlend(
        scheme.surface.withValues(alpha: 0.85),
        scheme.surfaceContainerLowest,
      ),
      glow: scheme.primary.withValues(alpha: dark ? 0.30 : 0.18),
      land: scheme.onSurface.withValues(alpha: dark ? 0.55 : 0.45),
      graticule: scheme.onSurface.withValues(alpha: 0.08),
      leader: scheme.onSurface.withValues(alpha: 0.35),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is GlobePalette &&
      other.lit == lit &&
      other.shadow == shadow &&
      other.glow == glow &&
      other.land == land &&
      other.graticule == graticule &&
      other.leader == leader;

  @override
  int get hashCode => Object.hash(lit, shadow, glow, land, graticule, leader);
}

/// The globe: the sphere, the coastlines, and a dot per server.
///
/// Not the cards. Those are real widgets in a `Stack` above this, because they
/// carry live readings and are tapped to open a server — everything a painted
/// rectangle would have to reimplement. What is painted is what is geometry.
class GlobePainter extends CustomPainter {
  GlobePainter({
    required this.projection,
    required this.land,
    required this.markers,
    required this.leaders,
    required this.palette,
    required this.shader,
    required this.opacity,
  });

  final GlobeProjection projection;
  final GlobeLand? land;
  final List<GlobeMarker> markers;
  final List<GlobeLeader> leaders;
  final GlobePalette palette;

  /// Null when the program would not load, which is not an error — see
  /// [_paintSphereFallback].
  final ui.FragmentShader? shader;

  final double opacity;

  /// Where the light comes from, in the projection's own frame: x right, y up,
  /// z toward the viewer.
  ///
  /// Fixed rather than following the sun. A globe lit by real daylight is
  /// mostly a dark globe, and this one is a background for reading server
  /// names off.
  static const _light = (x: -0.35, y: 0.45, z: 0.82);

  @override
  void paint(Canvas canvas, Size size) {
    if (opacity <= 0.001) return;
    final camera = projection.camera;
    if (camera.radius <= 0) return;

    _paintSphere(canvas, size);
    _paintGraticule(canvas);
    _paintLand(canvas);
    _paintLeaders(canvas);
    _paintMarkers(canvas);
  }

  void _paintSphere(Canvas canvas, Size size) {
    final program = shader;
    if (program == null) return _paintSphereFallback(canvas);

    final camera = projection.camera;
    var i = 0;
    void put(double v) => program.setFloat(i++, v);
    void putColor(Color c) {
      put(c.r);
      put(c.g);
      put(c.b);
      put(c.a);
    }

    // The order here is the declaration order in `assets/shaders/globe.frag`, and
    // there is nothing that checks it: `setFloat` writes into a flat buffer,
    // so a uniform added there and not here shifts every value after it and
    // the globe simply comes out wrong.
    put(camera.center.dx);
    put(camera.center.dy);
    put(camera.radius);
    put(_light.x);
    put(_light.y);
    put(_light.z);
    put(0); // uLight.w, padding
    putColor(palette.lit);
    putColor(palette.shadow);
    putColor(palette.glow);
    put(opacity);

    // The whole surface rather than a circle: the atmosphere reaches past the
    // outline, and the shader already answers transparent everywhere else.
    canvas.drawRect(Offset.zero & size, Paint()..shader = program);
  }

  /// What the globe looks like with no shader.
  ///
  /// Reached when `FragmentProgram.fromAsset` fails, which is a driver or a
  /// build problem rather than anything the user did. A flat-lit sphere is a
  /// worse picture and a working feature.
  void _paintSphereFallback(Canvas canvas) {
    final camera = projection.camera;
    canvas.drawCircle(
      camera.center,
      camera.radius,
      Paint()
        ..shader = ui.Gradient.radial(
          // Offset toward the light, so the sphere still has a direction.
          camera.center +
              Offset(_light.x, -_light.y) * camera.radius * 0.5,
          camera.radius * 1.35,
          [
            palette.lit.withValues(alpha: palette.lit.a * opacity),
            palette.shadow.withValues(alpha: palette.shadow.a * opacity),
          ],
          const [0, 1],
        )
        ..isAntiAlias = true,
    );
    canvas.drawCircle(
      camera.center,
      camera.radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = palette.glow.withValues(alpha: palette.glow.a * opacity)
        ..isAntiAlias = true,
    );
  }

  void _paintGraticule(Canvas canvas) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.7
      ..isAntiAlias = true
      ..color = palette.graticule.withValues(
        alpha: palette.graticule.a * opacity,
      );
    _strokeRings(canvas, _graticule, paint);
  }

  void _paintLand(Canvas canvas) {
    final rings = land?.rings;
    if (rings == null) return;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round
      ..isAntiAlias = true
      ..color = palette.land.withValues(alpha: palette.land.a * opacity);
    _strokeRings(canvas, rings, paint);
  }

  /// Every ring as one path and one draw call.
  ///
  /// Five thousand vertices in a hundred and twenty-seven rings; a draw call
  /// per ring is a hundred and twenty-seven of them per frame, and the cost is
  /// in the calls rather than the vertices.
  void _strokeRings(Canvas canvas, List<Float32List> rings, Paint paint) {
    final path = Path();
    for (final ring in rings) {
      for (final run in projection.projectRing(ring)) {
        path.moveTo(run.first.dx, run.first.dy);
        for (var i = 1; i < run.length; i++) {
          path.lineTo(run[i].dx, run[i].dy);
        }
      }
    }
    canvas.drawPath(path, paint);
  }

  void _paintLeaders(Canvas canvas) {
    if (leaders.isEmpty) return;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..isAntiAlias = true;

    // One draw per leader rather than one path for all of them, because each
    // now carries its own opacity. At most a dozen are ever on screen — the
    // land outline is 127 rings and *that* is the one worth batching.
    for (final leader in leaders) {
      final alpha = palette.leader.a * opacity * leader.fade;
      if (alpha <= 0.004) continue;
      paint.color = palette.leader.withValues(alpha: alpha);
      final path = Path();
      final from = _edgeToward(leader.card, leader.anchor);
      // A quadratic with the control point pushed off the straight line, so
      // several leaders leaving the same crowd of cards stay told apart. The
      // bulge is a fraction of the length, so a short leader is nearly
      // straight and a long one curves.
      final mid = (from + leader.anchor) / 2;
      final along = leader.anchor - from;
      final normal = Offset(-along.dy, along.dx);
      final length = along.distance;
      final control = length < 1
          ? mid
          : mid + normal / length * (length * 0.16);
      path.moveTo(from.dx, from.dy);
      path.quadraticBezierTo(
        control.dx,
        control.dy,
        leader.anchor.dx,
        leader.anchor.dy,
      );
      canvas.drawPath(path, paint);
    }
  }

  /// Where a line to [target] leaves [card].
  ///
  /// From the edge rather than from the centre, so the leader does not run
  /// under the card's own text on its way out.
  static Offset _edgeToward(Rect card, Offset target) {
    final d = target - card.center;
    if (d == Offset.zero) return card.center;
    // The scale at which the ray first crosses one of the card's two axes.
    final sx = d.dx == 0 ? double.infinity : (card.width / 2) / d.dx.abs();
    final sy = d.dy == 0 ? double.infinity : (card.height / 2) / d.dy.abs();
    final s = math.min(sx, sy);
    // `s > 1` means the target is *inside* the card: the layout pushed the card
    // outward and the clamp to `bounds` pulled it back over its own anchor.
    // Scaling to the edge anyway put the start of the leader past the anchor,
    // so the curve ran backwards across the card's name and readings to reach
    // the dot underneath it. There is no edge to leave from in that case.
    if (s > 1) return card.center;
    return card.center + d * s;
  }

  void _paintMarkers(Canvas canvas) {
    if (markers.isEmpty) return;
    final halo = Paint()..isAntiAlias = true;
    final dot = Paint()..isAntiAlias = true;

    for (final marker in markers) {
      final point = projection.project(marker.coord);
      if (!point.visible) continue;
      // Fade over the last stretch before the horizon, so a server rotating
      // out of view goes rather than blinks.
      final fade = point.horizonFade * opacity;
      if (fade <= 0.01) continue;

      halo.color = marker.color.withValues(alpha: 0.22 * fade);
      canvas.drawCircle(point.offset, 7, halo);
      dot.color = marker.color.withValues(alpha: fade);
      canvas.drawCircle(point.offset, 3.2, dot);
    }
  }

  /// The meridians and parallels, as unit vectors, built once.
  ///
  /// Every thirty degrees of longitude and every thirty of latitude. They are
  /// what makes the sphere read as *turning* over the stretches of ocean where
  /// there is no coastline to watch.
  static final List<Float32List> _graticule = _buildGraticule();

  static List<Float32List> _buildGraticule() {
    final rings = <Float32List>[];
    for (var lon = -180; lon < 180; lon += 30) {
      rings.add(
        GlobeLand.vectorsOf([
          for (var lat = -90; lat <= 90; lat += 3)
            GeoCoord.tryNew(lat.toDouble(), lon.toDouble())!,
        ]),
      );
    }
    for (var lat = -60; lat <= 60; lat += 30) {
      rings.add(
        GlobeLand.vectorsOf([
          for (var lon = -180; lon <= 180; lon += 3)
            GeoCoord.tryNew(lat.toDouble(), lon.toDouble())!,
        ]),
      );
    }
    return rings;
  }

  @override
  bool shouldRepaint(GlobePainter old) =>
      old.projection.camera != projection.camera ||
      !identical(old.land, land) ||
      old.palette != palette ||
      !identical(old.shader, shader) ||
      old.opacity != opacity ||
      !listEquals(old.markers, markers) ||
      !listEquals(old.leaders, leaders);
}
