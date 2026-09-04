import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/data/model/server/geo.dart';
import 'package:server_box/view/widget/globe/land.dart';
import 'package:server_box/view/widget/globe/painter.dart';
import 'package:server_box/view/widget/globe/projection.dart';

/// What actually reaches the screen.
///
/// Rasterised rather than only run: a painter that draws nothing throws
/// nothing either, so "it did not crash" is most of the way to no test at all.
/// Every case below paints into a picture, turns it into pixels, and asks
/// about a specific one.
///
/// The shader is null throughout, which is not a shortcut — it is the path a
/// driver that will not compile `globe.frag` takes, and the one no device in
/// front of a developer exercises. The shader's own path is covered too, by
/// `globe_view_test.dart`: `FragmentProgram.fromAsset` does load under
/// `flutter test`, since the shader is compiled into the test bundle like any
/// other asset.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const size = Size(400, 400);
  const center = Offset(200, 200);
  const radius = 120.0;

  const palette = GlobePalette(
    lit: Color(0xFF4080C0),
    shadow: Color(0xFF102030),
    glow: Color(0x8060A0FF),
    land: Color(0xFFE0E0E0),
    graticule: Color(0x22FFFFFF),
    leader: Color(0x88FFFFFF),
  );

  GlobeProjection facing(double lat, double lon, {double r = radius}) =>
      GlobeProjection(
        GlobeCamera(lat: lat, lon: lon, center: center, radius: r),
      );

  GlobePainter painter({
    GlobeProjection? projection,
    GlobeLand? land,
    List<GlobeMarker> markers = const [],
    List<GlobeLeader> leaders = const [],
    double opacity = 1,
  }) => GlobePainter(
    projection: projection ?? facing(0, 0),
    land: land,
    markers: markers,
    leaders: leaders,
    palette: palette,
    shader: null,
    opacity: opacity,
  );

  /// Paints [p] and hands back the pixels, ARGB-per-int at 1x.
  Future<_Pixels> render(GlobePainter p, {Size at = size}) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, Offset.zero & at);
    p.paint(canvas, at);
    final picture = recorder.endRecording();
    final image = await picture.toImage(at.width.round(), at.height.round());
    final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    picture.dispose();
    image.dispose();
    return _Pixels(data!.buffer.asUint8List(), at.width.round());
  }

  GeoCoord at(double lat, double lon) => GeoCoord.tryNew(lat, lon)!;

  group('the sphere', () {
    test('the middle of the disc is drawn', () async {
      final pixels = await render(painter());
      expect(
        pixels.alphaAt(200, 200),
        greaterThan(200),
        reason: 'the globe has to be opaque where it faces the viewer',
      );
    });

    test('a corner outside the halo is left alone', () async {
      final pixels = await render(painter());
      expect(pixels.alphaAt(2, 2), 0);
    });

    test('the lit side is brighter than the shadowed side', () async {
      // The fallback shades with a radial gradient offset toward the light. If
      // that offset were dropped the sphere would be a flat disc, which is the
      // failure this catches — and it is a picture, so nothing else would.
      final pixels = await render(painter());
      // The light comes from up and to the left.
      final lit = pixels.luminanceAt(160, 160);
      final shadow = pixels.luminanceAt(250, 250);
      expect(lit, greaterThan(shadow));
    });

    test('opacity fades the whole thing', () async {
      final full = await render(painter());
      final half = await render(painter(opacity: 0.4));
      expect(half.alphaAt(200, 200), lessThan(full.alphaAt(200, 200)));
      expect(half.alphaAt(200, 200), greaterThan(0));
    });

    test('nothing is painted at zero opacity', () async {
      final pixels = await render(painter(opacity: 0));
      expect(pixels.alphaAt(200, 200), 0);
    });

    test('a globe with no radius paints nothing rather than dividing by it', () async {
      final pixels = await render(painter(projection: facing(0, 0, r: 0)));
      expect(pixels.alphaAt(200, 200), 0);
    });
  });

  group('the coastlines', () {
    /// A ring around the point the camera faces, well inside the limb.
    GlobeLand ringAt(double lat, double lon) => _land([
      [
        at(lat + 8, lon - 8),
        at(lat + 8, lon + 8),
        at(lat - 8, lon + 8),
        at(lat - 8, lon - 8),
      ],
    ]);

    test('a ring on the near side is drawn', () async {
      final without = await render(painter());
      final with_ = await render(painter(land: ringAt(0, 0)));
      // Somewhere on the ring's top edge.
      expect(
        with_.differsFrom(without, 200, 200 - (radius * 0.139).round()),
        isTrue,
        reason: 'the outline has to change the picture',
      );
    });

    test('a ring on the far side is not', () async {
      final without = await render(painter());
      // Written out rather than via `ringAt`: 180 +/- 8 is not a longitude,
      // and `GeoCoord` refuses it — which is the type doing its job.
      final behind = await render(
        painter(
          land: _land([
            [at(8, 172), at(8, -172), at(-8, -172), at(-8, 172)],
          ]),
        ),
      );
      expect(
        without.sameAs(behind),
        isTrue,
        reason: 'a coastline on the far side would be drawn folded over',
      );
    });

    test('no land at all is not an error', () async {
      final pixels = await render(painter(land: null));
      expect(pixels.alphaAt(200, 200), greaterThan(0));
    });

    test('an empty land set is not an error', () async {
      final pixels = await render(painter(land: _land(const [])));
      expect(pixels.alphaAt(200, 200), greaterThan(0));
    });
  });

  group('the markers', () {
    test('a server on the near side gets a dot', () async {
      final without = await render(painter());
      final with_ = await render(
        painter(
          markers: [(id: 'a', coord: at(0, 0), color: const Color(0xFFFF0000))],
        ),
      );
      expect(with_.differsFrom(without, 200, 200), isTrue);
      // Its own colour, not the sphere's.
      expect(with_.redAt(200, 200), greaterThan(with_.blueAt(200, 200)));
    });

    test('a server on the far side does not', () async {
      final without = await render(painter());
      final behind = await render(
        painter(
          markers: [
            (id: 'a', coord: at(0, 180), color: const Color(0xFFFF0000)),
          ],
        ),
      );
      expect(without.sameAs(behind), isTrue);
    });

    test('a server near the limb is faded rather than cut off', () async {
      // The fade is over the last stretch before the horizon, so a server
      // rotating out of view goes rather than blinks.
      final middle = await render(
        painter(
          markers: [(id: 'a', coord: at(0, 0), color: const Color(0xFFFF0000))],
        ),
      );
      final edge = await render(
        painter(
          markers: [
            (id: 'a', coord: at(0, 89), color: const Color(0xFFFF0000)),
          ],
        ),
      );
      final middleRed = middle.redAt(200, 200);
      final edgeX = (center.dx + radius * 0.9998).round();
      expect(edge.redAt(edgeX.clamp(0, 399), 200), lessThan(middleRed));
    });

    test('opacity reaches the markers too', () async {
      final full = await render(
        painter(
          markers: [(id: 'a', coord: at(0, 0), color: const Color(0xFFFF0000))],
        ),
      );
      final faded = await render(
        painter(
          markers: [(id: 'a', coord: at(0, 0), color: const Color(0xFFFF0000))],
          opacity: 0.3,
        ),
      );
      expect(faded.redAt(200, 200), lessThan(full.redAt(200, 200)));
    });
  });

  group('the leader lines', () {
    test('a leader is drawn between a card and its point', () async {
      final without = await render(painter());
      final with_ = await render(
        painter(
          leaders: [
            (
              card: const Rect.fromLTWH(20, 20, 100, 40),
              anchor: const Offset(200, 200),
              fade: 1.0,
            ),
          ],
        ),
      );
      expect(with_.sameAs(without), isFalse);
    });

    test('it leaves the card at its edge, not from under its text', () async {
      // Drawn from the centre, the line would cross the card's own label on
      // the way out. Asserted as "nothing inside the card changed" rather
      // than by naming a pixel on the curve, which the bezier's bulge moves.
      final pixels = await render(
        painter(
          leaders: [
            (
              card: const Rect.fromLTWH(20, 180, 100, 40),
              anchor: const Offset(340, 200),
              fade: 1.0,
            ),
          ],
        ),
      );
      final plain = await render(painter());
      expect(pixels.sameAs(plain), isFalse, reason: 'a line was drawn');
      for (var x = 25; x < 115; x += 10) {
        for (var y = 185; y < 215; y += 10) {
          expect(
            pixels.sameAs(plain, x: x, y: y),
            isTrue,
            reason: 'the leader crosses the card at $x,$y',
          );
        }
      }
    });

    test('a card sitting exactly on its anchor is not a divide by zero', () async {
      final pixels = await render(
        painter(
          leaders: [
            (
              card: Rect.fromCenter(
                center: const Offset(200, 200),
                width: 80,
                height: 30,
              ),
              anchor: const Offset(200, 200),
              fade: 1.0,
            ),
          ],
        ),
      );
      expect(pixels.alphaAt(200, 200), greaterThan(0));
    });

    test('no leaders is not an error', () async {
      final pixels = await render(painter(leaders: const []));
      expect(pixels.alphaAt(200, 200), greaterThan(0));
    });
  });

  group('shouldRepaint', () {
    GlobePainter base() => painter();

    test('says no when nothing changed', () {
      // The camera is rebuilt every frame, so without value equality on it
      // every frame reprojects five thousand vertices to draw what is already
      // there.
      expect(base().shouldRepaint(base()), isFalse);
    });

    test('says yes when the globe turned', () {
      expect(
        painter(projection: facing(0, 1)).shouldRepaint(base()),
        isTrue,
      );
    });

    test('says yes when a marker changed colour', () {
      // Records compare by value, which is what makes this work without a
      // hand-written `==` on every element.
      final a = painter(
        markers: [(id: 'a', coord: at(0, 0), color: const Color(0xFF00FF00))],
      );
      final b = painter(
        markers: [(id: 'a', coord: at(0, 0), color: const Color(0xFFFF0000))],
      );
      expect(a.shouldRepaint(b), isTrue);
      final c = painter(
        markers: [(id: 'a', coord: at(0, 0), color: const Color(0xFF00FF00))],
      );
      expect(a.shouldRepaint(c), isFalse);
    });

    test('says yes when the cards moved', () {
      final a = painter(
        leaders: [
          (
            card: const Rect.fromLTWH(0, 0, 10, 10),
            anchor: Offset.zero,
            fade: 1.0,
          ),
        ],
      );
      expect(a.shouldRepaint(base()), isTrue);
    });

    test('says yes when the theme changed', () {
      final other = GlobePainter(
        projection: facing(0, 0),
        land: null,
        markers: const [],
        leaders: const [],
        palette: const GlobePalette(
          lit: Color(0xFF000000),
          shadow: Color(0xFF102030),
          glow: Color(0x8060A0FF),
          land: Color(0xFFE0E0E0),
          graticule: Color(0x22FFFFFF),
          leader: Color(0x88FFFFFF),
        ),
        shader: null,
        opacity: 1,
      );
      expect(other.shouldRepaint(base()), isTrue);
    });

    test('says yes while the entrance is running', () {
      expect(painter(opacity: 0.5).shouldRepaint(base()), isTrue);
    });

    test('says yes when the land arrives', () {
      expect(painter(land: _land(const [])).shouldRepaint(base()), isTrue);
    });
  });

  group('the palette', () {
    test('is a value, so shouldRepaint can compare it', () {
      const a = GlobePalette(
        lit: Color(0xFF000001),
        shadow: Color(0xFF000002),
        glow: Color(0xFF000003),
        land: Color(0xFF000004),
        graticule: Color(0xFF000005),
        leader: Color(0xFF000006),
      );
      const b = GlobePalette(
        lit: Color(0xFF000001),
        shadow: Color(0xFF000002),
        glow: Color(0xFF000003),
        land: Color(0xFF000004),
        graticule: Color(0xFF000005),
        leader: Color(0xFF000006),
      );
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(palette));
    });

    testWidgets('is taken from the theme, and differs by brightness', (
      tester,
    ) async {
      late GlobePalette light;
      late GlobePalette dark;

      // Keyed, and that is not decoration: without it the second `pumpWidget`
      // updates the same `MaterialApp` in place and the builder is not run
      // again, so both variables end up holding the first theme's answer and
      // the test passes for the wrong reason. It did.
      Future<void> under(ThemeData theme, void Function(GlobePalette) hold) {
        return tester.pumpWidget(
          MaterialApp(
            key: ValueKey(theme.brightness),
            theme: theme,
            home: Builder(
              builder: (context) {
                hold(GlobePalette.of(context));
                return const SizedBox();
              },
            ),
          ),
        );
      }

      await under(ThemeData.light(), (p) => light = p);
      await under(ThemeData.dark(), (p) => dark = p);
      expect(light, isNot(dark));
      // The globe is meant to sit in the theme rather than on top of it, so
      // the shadow side follows the surface colour rather than going to black.
      expect(light.shadow, isNot(const Color(0xFF000000)));
      expect(dark.shadow, isNot(const Color(0xFF000000)));
    });
  });

  test('everything at once still paints', () async {
    // The order matters — sphere, graticule, land, leaders, markers — and a
    // marker hidden under the land would be a bug nothing else here catches.
    final pixels = await render(
      painter(
        land: _land([
          [at(20, -20), at(20, 20), at(-20, 20), at(-20, -20)],
        ]),
        markers: [
          (id: 'a', coord: at(0, 0), color: const Color(0xFFFF0000)),
          (id: 'b', coord: at(30, 30), color: const Color(0xFF00FF00)),
          (id: 'c', coord: at(0, 179), color: const Color(0xFF0000FF)),
        ],
        leaders: [
          (
            card: const Rect.fromLTWH(10, 10, 100, 40),
            anchor: const Offset(200, 200),
            fade: 1.0,
          ),
        ],
      ),
    );
    expect(pixels.redAt(200, 200), greaterThan(pixels.blueAt(200, 200)));
    expect(pixels.alphaAt(2, 2), 0);
  });
}

GlobeLand _land(List<List<GeoCoord>> rings) {
  // Through the parser, so the test builds the shape the drawing code reads
  // rather than one that happens to work.
  final out = <int>[0x53, 0x42, 0x47, 0x4c, 1, 0, rings.length];
  for (final ring in rings) {
    out.addAll([ring.length >> 8, ring.length & 0xff]);
    for (final c in ring) {
      final lat = (c.lat / 90 * 32767).round();
      final lon = (c.lon / 180 * 32767).round();
      out.addAll([
        (lat >> 8) & 0xff,
        lat & 0xff,
        (lon >> 8) & 0xff,
        lon & 0xff,
      ]);
    }
  }
  return GlobeLand.tryParse(Uint8List.fromList(out))!;
}

/// Raw RGBA, with the questions a picture is worth asking.
class _Pixels {
  _Pixels(this.bytes, this.width);

  final Uint8List bytes;
  final int width;

  int _at(int x, int y, int channel) => bytes[(y * width + x) * 4 + channel];

  int redAt(int x, int y) => _at(x, y, 0);
  int blueAt(int x, int y) => _at(x, y, 2);
  int alphaAt(int x, int y) => _at(x, y, 3);

  double luminanceAt(int x, int y) =>
      _at(x, y, 0) * 0.2126 + _at(x, y, 1) * 0.7152 + _at(x, y, 2) * 0.0722;

  bool differsFrom(_Pixels other, int x, int y) => !sameAs(other, x: x, y: y);

  /// Whole-image comparison when no coordinate is given.
  bool sameAs(_Pixels other, {int? x, int? y}) {
    if (x == null || y == null) {
      for (var i = 0; i < bytes.length; i++) {
        if (bytes[i] != other.bytes[i]) return false;
      }
      return true;
    }
    final base = (y * width + x) * 4;
    for (var c = 0; c < 4; c++) {
      if (bytes[base + c] != other.bytes[base + c]) return false;
    }
    return true;
  }
}
