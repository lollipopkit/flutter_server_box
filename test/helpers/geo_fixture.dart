import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:server_box/core/service/geo_data.dart';
import 'package:server_box/data/model/app/geo_manifest.dart';

import 'local_http.dart';

/// Puts the shared vectors on disk as if they had been downloaded.
///
/// The vectors are what `ipgeo-shards` writes and are checked into both
/// repositories, so a test that installs them is exercising the real format
/// rather than one this repository invented for itself. They are tiny — four
/// records each — which is the point: every case in them is one a reader can
/// get wrong on its own.
///
/// What is in them, and what tests can therefore rely on:
///
/// | address | answer |
/// |---|---|
/// | `8.0.0.0` – `8.8.8.7` | 10.5, 20.25 |
/// | `8.8.8.8` – `8.8.255.255` | 37.4233, -122.0838 |
/// | `8.9.0.0` and above in 8/8 | a gap, so nothing |
/// | `10.0.0.1` | -33.8691, 151.2094 |
/// | anything else IPv4 | an empty bucket, so nothing |
/// | `2620:fe::/48` | 37.8793, -122.2706 |
/// | `2606::/48` | 51.5072, -0.1276 |
///
/// [Paths.doc] must already point somewhere disposable — it is `late final`,
/// so a test file sets it once in `setUpAll`.
Future<void> installGeoVectors({GeoData? data}) async {
  data ??= GeoData.shared;
  final bodies = <String, List<int>>{};
  final assets = <Map<String, Object?>>[];
  for (final (name, family) in [('ip4', 4), ('ip6', 6)]) {
    final raw = await File(
      'test/fixtures/geo/bundle_${name}_v1.bin',
    ).readAsBytes();
    final packed = gzip.encode(raw);
    final filename = '${name}_city_v1.bin.gz';
    bodies[filename] = packed;
    assets.add({
      'name': filename,
      'family': family,
      'bytes': packed.length,
      'unpackedBytes': raw.length,
      'sha256': sha256.convert(packed).toString(),
    });
  }
  final document = {
    'version': 1,
    'generated': '2026-09',
    'attribution': 'IP geolocation by DB-IP (https://db-ip.com), CC BY 4.0',
    'assets': assets,
  };
  bodies['manifest.json'] = utf8.encode(jsonEncode(document));
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  server.listen((request) async {
    final bytes = bodies[request.uri.pathSegments.last];
    if (bytes == null) {
      request.response.statusCode = 404;
    } else {
      request.response.add(bytes);
    }
    await request.response.close();
  });
  try {
    final service = data;
    final installed = await HttpOverrides.runWithHttpOverrides(
      () => service.install(GeoManifest.tryFromJson(document)!),
      LocalHttp(server),
    );
    if (!installed) throw StateError('Fixture installation failed');
  } finally {
    await server.close(force: true);
  }
}

Future<void> removeGeoVectors({GeoData? data}) =>
    (data ?? GeoData.shared).remove();
