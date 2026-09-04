import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/data/model/server/geo.dart';
import 'package:server_box/view/widget/globe/land.dart';

/// The land asset, and the file the build script actually produced.
///
/// The parser is checked against bytes built here, and then against the real
/// thing — because a format that round-trips through its own test says nothing
/// about whether `scripts/build_land_asset.py` writes it.
Uint8List buildLand(List<List<(double lat, double lon)>> rings) {
  final out = BytesBuilder();
  out.add(const [0x53, 0x42, 0x47, 0x4c]); // "SBGL"
  out.addByte(1);
  out.add(_u16(rings.length));
  for (final ring in rings) {
    out.add(_u16(ring.length));
    for (final (lat, lon) in ring) {
      out.add(_i16((lat / 90 * 32767).round()));
      out.add(_i16((lon / 180 * 32767).round()));
    }
  }
  return out.toBytes();
}

Uint8List _u16(int v) => Uint8List(2)..buffer.asByteData().setUint16(0, v);
Uint8List _i16(int v) => Uint8List(2)..buffer.asByteData().setInt16(0, v);

void main() {
  test('a ring comes back as unit vectors', () {
    final land = GlobeLand.tryParse(
      buildLand([
        [(0, 0), (0, 90), (90, 0)],
      ]),
    )!;
    expect(land.rings, hasLength(1));
    expect(land.pointCount, 3);

    final ring = land.rings.single;
    // 0,0 is (1, 0, 0); 0,90 is (0, 1, 0); the north pole is (0, 0, 1).
    expect(ring[0], closeTo(1, 1e-3));
    expect(ring[1], closeTo(0, 1e-3));
    expect(ring[2], closeTo(0, 1e-3));
    expect(ring[4], closeTo(1, 1e-3));
    expect(ring[8], closeTo(1, 1e-3));
  });

  test('every vector is on the unit sphere', () {
    final land = GlobeLand.tryParse(
      buildLand([
        [for (var lat = -90; lat <= 90; lat += 15) (lat.toDouble(), 37.0)],
        [for (var lon = -180; lon < 180; lon += 15) (12.0, lon.toDouble())],
      ]),
    )!;
    for (final ring in land.rings) {
      for (var i = 0; i < ring.length; i += 3) {
        final length = math.sqrt(
          ring[i] * ring[i] + ring[i + 1] * ring[i + 1] + ring[i + 2] * ring[i + 2],
        );
        expect(length, closeTo(1, 1e-4));
      }
    }
  });

  test('the packed form matches what the parser builds', () {
    // `vectorsOf` is what a test or a graticule uses to build a ring by hand,
    // and it has to produce exactly what a parsed ring is or the two would
    // drift apart silently.
    final byHand = GlobeLand.vectorsOf([
      GeoCoord.tryNew(35, -120)!,
      GeoCoord.tryNew(-14, 77)!,
    ]);
    final parsed = GlobeLand.tryParse(
      buildLand([
        [(35, -120), (-14, 77)],
      ]),
    )!.rings.single;
    for (var i = 0; i < byHand.length; i++) {
      expect(parsed[i], closeTo(byHand[i], 1e-3), reason: 'component $i');
    }
  });

  group('a file that is not one', () {
    test('wrong magic, short header, unknown format', () {
      expect(GlobeLand.tryParse(Uint8List(0)), isNull);
      expect(GlobeLand.tryParse(Uint8List(6)), isNull);
      final wrongMagic = buildLand([
        [(0, 0), (1, 1)],
      ])..[0] = 0x00;
      expect(GlobeLand.tryParse(wrongMagic), isNull);
      final wrongFormat = buildLand([
        [(0, 0), (1, 1)],
      ])..[4] = 9;
      expect(GlobeLand.tryParse(wrongFormat), isNull);
    });

    test('truncated partway through a ring', () {
      // Checked as it goes rather than trusted, so a short file is a globe
      // with no coastlines instead of a RangeError thrown mid-frame.
      final bytes = buildLand([
        [for (var i = 0; i < 20; i++) (i.toDouble(), i.toDouble())],
      ]);
      expect(GlobeLand.tryParse(bytes.sublist(0, bytes.length - 5)), isNull);
    });

    test('a ring count larger than the file', () {
      final bytes = buildLand([
        [(0, 0), (1, 1)],
      ]);
      bytes.buffer.asByteData().setUint16(5, 500);
      expect(GlobeLand.tryParse(bytes), isNull);
    });
  });

  test('an empty file parses to no rings', () {
    expect(GlobeLand.tryParse(buildLand(const []))!.rings, isEmpty);
  });

  group('the loader', () {
    setUpAll(TestWidgetsFlutterBinding.ensureInitialized);
    setUp(() => BundledLand.resetForTest());
    tearDown(() => BundledLand.resetForTest());

    test('reads the asset, and answers before it has', () async {
      expect(BundledLand.loaded, isNull);
      final land = await BundledLand.load();
      expect(land, isNotNull);
      expect(land!.rings.length, greaterThan(50));
      expect(BundledLand.loaded, same(land));
    });

    test('is loaded once', () async {
      // Five thousand vertices converted to unit vectors; doing it twice is
      // work nobody asked for.
      final first = await BundledLand.load();
      expect(identical(first, await BundledLand.load()), isTrue);
    });

    test('a test can hand it one directly', () async {
      final made = GlobeLand.tryParse(buildLand([
        [(0, 0), (1, 1), (2, 2), (3, 3)],
      ]))!;
      BundledLand.resetForTest(made);
      expect(BundledLand.loaded, same(made));
      expect(await BundledLand.load(), same(made));
    });
  });

  group('the asset the build script wrote', () {
    // Read off disk rather than through `rootBundle`, which needs a binding
    // and the asset manifest. What is under test is the file.
    final file = File('assets/geo/land_110m.bin');

    test('is present, and is what the parser expects', () {
      expect(
        file.existsSync(),
        isTrue,
        reason: 'run scripts/build_land_asset.py',
      );
      final land = GlobeLand.tryParse(file.readAsBytesSync())!;
      // Natural Earth 110m land: the continents and the larger islands.
      expect(land.rings.length, greaterThan(50));
      expect(land.pointCount, greaterThan(3000));
    });

    test('is small enough to ship', () {
      // It is read on every launch of the globe and lives in the app bundle.
      // Well under this today; the limit is here to catch someone swapping in
      // the 50m dataset, which is six times the data for detail a few hundred
      // pixels cannot show.
      expect(file.lengthSync(), lessThan(64 * 1024));
    });

    test('has a vertex somewhere on every continent', () {
      final land = GlobeLand.tryParse(file.readAsBytesSync())!;
      // Sanity that the coordinates were not written swapped or with the sign
      // of latitude flipped — the kind of mistake that still draws a plausible
      // scatter of shapes.
      var northern = 0;
      var southern = 0;
      var eastern = 0;
      var western = 0;
      for (final ring in land.rings) {
        for (var i = 0; i < ring.length; i += 3) {
          if (ring[i + 2] > 0.5) northern++; // above 30 N
          if (ring[i + 2] < -0.5) southern++;
          if (ring[i + 1] > 0.5) eastern++;
          if (ring[i + 1] < -0.5) western++;
        }
      }
      for (final (name, count) in [
        ('northern', northern),
        ('southern', southern),
        ('eastern', eastern),
        ('western', western),
      ]) {
        expect(count, greaterThan(100), reason: name);
      }
    });
  });
}
