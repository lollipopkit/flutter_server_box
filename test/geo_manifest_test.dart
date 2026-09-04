import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/data/model/app/geo_manifest.dart';

void main() {
  Map<String, Object?> asset(int family) => {
    'name': 'ip${family}_city_v1.bin.gz',
    'family': family,
    'bytes': 1024,
    'unpackedBytes': 2048,
    'sha256': '0' * 64,
  };

  Map<String, Object?> manifest({
    String generated = '2026-09',
    Object? attribution = 'DB-IP, CC BY 4.0',
    List<Object?>? assets,
  }) => {
    'version': 1,
    'generated': generated,
    'attribution': attribution,
    'assets': assets ?? [asset(4), asset(6)],
  };

  test('accepts one valid bundle for each address family', () {
    final parsed = GeoManifest.tryFromJson(manifest());

    expect(parsed, isNotNull);
    expect(parsed!.year, 2026);
    expect(parsed.month, 9);
    expect(parsed.assets.map((asset) => asset.family), [4, 6]);
  });

  test('rejects a calendar month outside 1 through 12', () {
    expect(GeoManifest.tryFromJson(manifest(generated: '2026-00')), isNull);
    expect(GeoManifest.tryFromJson(manifest(generated: '2026-13')), isNull);
  });

  test('requires both IPv4 and IPv6 exactly once', () {
    expect(GeoManifest.tryFromJson(manifest(assets: [asset(4)])), isNull);
    expect(
      GeoManifest.tryFromJson(manifest(assets: [asset(4), asset(4)])),
      isNull,
    );
  });

  test('rejects a non-text attribution instead of throwing', () {
    expect(
      GeoManifest.tryFromJson(manifest(attribution: {'unexpected': true})),
      isNull,
    );
  });
}
