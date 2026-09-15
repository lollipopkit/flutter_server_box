import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/data/model/server/geo.dart';
import 'package:server_box/data/model/server/geo_source.dart';

/// Where a coordinate came from, and what it is for.
///
/// Much smaller than it was, because this type is much smaller than it was.
/// `beats`, `isExact`, `fromName` and `ResolvedGeo`'s two JSON members all
/// existed for the store that held where each host was; the store is gone —
/// see `IpGeo.resolve` — and they went with it rather than staying as API a
/// test file was the only caller of.
void main() {
  final coord = GeoCoord.tryNew(39.9042, 116.4074)!;
  final other = GeoCoord.tryNew(1, 2)!;

  test('the case order is the chain, best first', () {
    // Nothing compares it any more — `IpGeo.locate` asks each link in turn and
    // stops at the first that answers — so this pins the declaration against
    // the code it is meant to read alongside. A `country` case sat under
    // `city` until the bundled database it named was replaced by a download.
    expect(GeoSource.values, [
      GeoSource.manual,
      GeoSource.selfReported,
      GeoSource.city,
    ]);
  });

  group('ResolvedGeo', () {
    test('is a value', () {
      final a = ResolvedGeo(coord: coord, source: GeoSource.city);
      final b = ResolvedGeo(coord: coord, source: GeoSource.city);
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(ResolvedGeo(coord: other, source: GeoSource.city)));
      expect(a, isNot(ResolvedGeo(coord: coord, source: GeoSource.manual)));
    });

    test('reads as itself in a log line', () {
      expect(
        ResolvedGeo(coord: other, source: GeoSource.selfReported).toString(),
        'ResolvedGeo(1.0, 2.0, selfReported)',
      );
    });
  });
}
