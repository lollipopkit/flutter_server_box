import 'dart:math' as math;
import 'dart:typed_data';

import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:server_box/data/model/server/geo.dart';

/// The coastlines, as unit vectors ready to be rotated.
///
/// Built by `scripts/build_land_asset.py` from Natural Earth 110m land —
/// public domain, and the same project the country capitals come from. Around
/// 20 KB for 127 rings and 4,953 points, which at the size a globe is drawn
/// already puts several vertices inside a pixel.
///
/// **Stored as vectors rather than as coordinates, and that is the whole
/// point.** A latitude and longitude have to go through four trigonometric
/// calls before they can be projected, and these five thousand points are
/// projected on every frame of a drag. Converting them once at load turns the
/// per-frame cost into nine multiplies each — see `GlobeProjection
/// .projectVector`, which is a rotation matrix and nothing else.
///
/// ## Format
///
/// Big-endian, and the contract with the script:
///
/// ```text
/// magic "SBGL"     4 B
/// format           1 B   == 1
/// ringCount        2 B   u16
/// per ring:
///   pointCount     2 B   u16
///   points         pointCount x 4 B: lat i16 + lon i16
/// ```
///
/// Each ring is a closed outline stored open — the reader closes it, so the
/// repeated first vertex GeoJSON carries is not in the file.
final class GlobeLand {
  const GlobeLand._(this.rings);

  /// One packed `[x, y, z, x, y, z, ...]` per ring.
  final List<Float32List> rings;

  static const _magic = [0x53, 0x42, 0x47, 0x4c]; // "SBGL"
  static const _format = 1;
  static const _quantum = 32767;

  int get pointCount {
    var total = 0;
    for (final ring in rings) {
      total += ring.length ~/ 3;
    }
    return total;
  }

  /// Null for anything that is not this format.
  ///
  /// The caller is a lazy load of an asset during a build, so there is no user
  /// action to fail and nothing to tell. Without land the globe is a shaded
  /// sphere with the servers still on it, which is degraded rather than
  /// broken.
  static GlobeLand? tryParse(Uint8List bytes) {
    try {
      return _parse(bytes);
    } catch (e, s) {
      Loggers.app.warning('Land outline asset is unreadable', e, s);
      return null;
    }
  }

  static GlobeLand? _parse(Uint8List bytes) {
    if (bytes.length < 7) return null;
    for (var i = 0; i < _magic.length; i++) {
      if (bytes[i] != _magic[i]) return null;
    }
    final data = ByteData.sublistView(bytes);
    if (data.getUint8(4) != _format) return null;

    final ringCount = data.getUint16(5);
    var at = 7;
    final rings = <Float32List>[];
    for (var r = 0; r < ringCount; r++) {
      if (at + 2 > bytes.length) return null;
      final points = data.getUint16(at);
      at += 2;
      if (at + points * 4 > bytes.length) return null;
      final vectors = Float32List(points * 3);
      for (var p = 0; p < points; p++) {
        final lat = data.getInt16(at) / _quantum * 90 * _rad;
        final lon = data.getInt16(at + 2) / _quantum * 180 * _rad;
        at += 4;
        final cosLat = math.cos(lat);
        vectors[p * 3] = cosLat * math.cos(lon);
        vectors[p * 3 + 1] = cosLat * math.sin(lon);
        vectors[p * 3 + 2] = math.sin(lat);
      }
      rings.add(vectors);
    }
    return GlobeLand._(rings);
  }

  static const _rad = math.pi / 180;

  /// Coordinates as the packed vectors a ring is made of.
  ///
  /// The same conversion the parser does, exposed because a test that builds a
  /// ring by hand has to build the shape the drawing code actually reads.
  static Float32List vectorsOf(List<GeoCoord> coords) {
    final out = Float32List(coords.length * 3);
    for (var i = 0; i < coords.length; i++) {
      final lat = coords[i].lat * _rad;
      final lon = coords[i].lon * _rad;
      final cosLat = math.cos(lat);
      out[i * 3] = cosLat * math.cos(lon);
      out[i * 3 + 1] = cosLat * math.sin(lon);
      out[i * 3 + 2] = math.sin(lat);
    }
    return out;
  }
}

/// Loads the outlines once, and remembers the answer including a failure.
abstract final class BundledLand {
  static const assetKey = 'assets/geo/land_110m.bin';

  static Future<GlobeLand?>? _pending;
  static GlobeLand? _loaded;
  static bool _tried = false;

  /// Null until [load] has finished, so a painter can ask without awaiting.
  static GlobeLand? get loaded => _loaded;

  static Future<GlobeLand?> load() {
    if (_tried) return Future.value(_loaded);
    return _pending ??= _load();
  }

  static Future<GlobeLand?> _load() async {
    try {
      final data = await rootBundle.load(assetKey);
      _loaded = GlobeLand.tryParse(data.buffer.asUint8List());
    } catch (e, s) {
      Loggers.app.warning('No land outline asset ($assetKey)', e, s);
      _loaded = null;
    }
    _tried = true;
    _pending = null;
    return _loaded;
  }

  /// For tests, which need each case to start from nothing.
  static void resetForTest([GlobeLand? land]) {
    _loaded = land;
    _tried = land != null;
    _pending = null;
  }
}
