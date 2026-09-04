import 'dart:convert';
import 'dart:io';

import 'package:fl_lib/fl_lib.dart';
import 'package:server_box/core/service/geo_data.dart';

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
Future<void> installGeoVectors() async {
  await GeoData.remove();
  await Directory(GeoData.dir).create(recursive: true);

  final assets = <Map<String, Object?>>[];
  for (final (name, family) in [('ip4', 4), ('ip6', 6)]) {
    final bytes = await File(
      'test/fixtures/geo/bundle_${name}_v1.bin',
    ).readAsBytes();
    await File(GeoData.dir.joinPath('${name}_city_v1.bin')).writeAsBytes(bytes);
    assets.add({
      'name': '${name}_city_v1.bin.gz',
      'family': family,
      // The manifest's sizes describe the *packed* download, which nothing
      // reads once the files are here. A digest of the unpacked bytes would
      // be wrong and a digest of nothing would be refused, so these are the
      // shapes the model requires and no test depends on their values.
      'bytes': bytes.length,
      'unpackedBytes': bytes.length,
      'sha256': '0' * 64,
    });
  }

  await File(GeoData.dir.joinPath('installed.json')).writeAsString(
    jsonEncode({
      'version': 1,
      'generated': '2026-09',
      'attribution': 'IP geolocation by DB-IP (https://db-ip.com), CC BY 4.0',
      'assets': assets,
    }),
  );
  await GeoData.resetForTest();
  // What a finished `GeoData.install` does, and what anything watching for the
  // data to arrive is listening to. Bumped here rather than left to the caller
  // so a test installing mid-body behaves the way the download does.
  GeoData.revision.value++;
}

/// Takes it back off, for the cases about the data not being installed.
Future<void> removeGeoVectors() => GeoData.remove();
