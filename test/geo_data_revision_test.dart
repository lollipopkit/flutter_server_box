import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

import 'package:dio/dio.dart';
import 'package:fl_lib/fl_lib.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/core/service/geo_data.dart';
import 'package:server_box/data/model/app/geo_manifest.dart';
import 'package:server_box/data/res/url.dart';

import 'helpers/geo_fixture.dart';

/// An endpoint that is not there, so an install fails without a network.
class _DeadAdapter implements HttpClientAdapter {
  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) => throw const SocketException('no network in tests');
}

/// An endpoint whose response is selected by the requested filename.
class _RouteAdapter implements HttpClientAdapter {
  _RouteAdapter(this.bodies, {this.requests});

  final Map<String, Uint8List> bodies;
  final List<String>? requests;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final url = options.uri.toString();
    requests?.add(url);
    final body = bodies[url] ?? bodies[options.uri.pathSegments.last];
    return body == null
        ? ResponseBody.fromBytes(const [], 404)
        : ResponseBody.fromBytes(body, 200);
  }
}

/// **When listeners are told the installed data changed.**
///
/// `GeoData.revision` is the only thing keeping the settings row, the switch
/// and the globe in step, and each of them acts on it: the globe throws away
/// everything it has resolved and runs a full pass. So *when* it fires is a
/// behaviour, not an implementation detail — one announcement too many is a
/// screenful of servers dropping into the unplaced strip and a burst of name
/// lookups for an answer that cannot exist yet.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tmp;
  late int seen;
  late void Function() listener;

  setUpAll(() async {
    tmp = await Directory.systemTemp.createTemp('geo-revision-');
    Paths.doc = tmp.path;
  });

  tearDownAll(() => tmp.delete(recursive: true));

  setUp(() async {
    await installGeoVectors();
    seen = 0;
    listener = () => seen++;
    GeoData.revision.addListener(listener);
  });

  tearDown(() async {
    GeoData.revision.removeListener(listener);
    GeoData.clientFactory = _defaultForTest;
    await removeGeoVectors();
  });

  /// A manifest naming files the dead endpoint will never serve.
  GeoManifest manifestOf(String month) => GeoManifest.tryFromJson({
    'version': 1,
    'generated': month,
    'attribution': 'test',
    'assets': [
      for (final (name, family) in [('ip4', 4), ('ip6', 6)])
        {
          'name': '${name}_city_v1.bin.gz',
          'family': family,
          'bytes': 1024,
          'unpackedBytes': 4096,
          'sha256': '0' * 64,
        },
    ],
  })!;

  Future<({GeoManifest manifest, Map<String, Uint8List> bodies})> offerOf(
    String generated, {
    String attribution = 'test',
    int gzipMarker = 0,
  }) async {
    final year = int.parse(generated.substring(0, 4));
    final month = int.parse(generated.substring(5, 7));
    final assets = <Map<String, Object?>>[];
    final bodies = <String, Uint8List>{};
    for (final (name, family) in [('ip4', 4), ('ip6', 6)]) {
      final raw = Uint8List.fromList(
        await File('test/fixtures/geo/bundle_${name}_v1.bin').readAsBytes(),
      );
      raw[6] = year >> 8;
      raw[7] = year & 0xff;
      raw[8] = month;
      final packed = Uint8List.fromList(gzip.encode(raw));
      // The gzip mtime is metadata, not part of the unpacked bundle or its CRC.
      // Changing it models two builders producing equally sized, equivalent
      // archives with different packed hashes.
      packed[4] = gzipMarker;
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
    final manifest = GeoManifest.tryFromJson({
      'version': 1,
      'generated': generated,
      'attribution': attribution,
      'assets': assets,
    })!;
    bodies['manifest.json'] = Uint8List.fromList(
      utf8.encode(jsonEncode(manifest.toJson())),
    );
    return (manifest: manifest, bodies: bodies);
  }

  Map<String, Uint8List> routesFor(
    String endpoint,
    Map<String, Uint8List> bodies,
  ) => {
    for (final entry in bodies.entries) '$endpoint/${entry.key}': entry.value,
  };

  ({GeoManifest manifest, Map<String, Uint8List> bodies}) withPackedSizeDelta(
    ({GeoManifest manifest, Map<String, Uint8List> bodies}) offer,
  ) {
    final json = offer.manifest.toJson();
    final assets = json['assets']! as List<Map<String, Object?>>;
    assets.first['bytes'] = (assets.first['bytes']! as int) + 1;
    final manifest = GeoManifest.tryFromJson(json)!;
    return (
      manifest: manifest,
      bodies: {
        ...offer.bodies,
        'manifest.json': Uint8List.fromList(
          utf8.encode(jsonEncode(manifest.toJson())),
        ),
      },
    );
  }

  Future<void> expectIncompatibleFallbackRejected(
    ({GeoManifest manifest, Map<String, Uint8List> bodies}) confirmed,
    ({GeoManifest manifest, Map<String, Uint8List> bodies}) fallback,
  ) async {
    final requests = <String>[];
    GeoData.clientFactory = () => Dio()
      ..httpClientAdapter = _RouteAdapter({
        // The primary offer is still the one the user confirmed, but its
        // assets are unavailable so installation reaches the fallback.
        '${Urls.geoData}/manifest.json': confirmed.bodies['manifest.json']!,
        ...routesFor(Urls.geoDataFallback, fallback.bodies),
      }, requests: requests);

    expect(await GeoData.install(confirmed.manifest), isFalse);
    expect(GeoData.installed()?.generated, '2026-09');
    expect(seen, 0);
    expect(requests.where((url) => url.startsWith(Urls.geoDataFallback)), [
      '${Urls.geoDataFallback}/manifest.json',
    ], reason: 'incompatible fallback assets must not be downloaded');
  }

  /// An archive whose declared size is a lie.
  ///
  /// The manifest and the bytes come from the same endpoint, so neither is
  /// evidence about the other. **What matters is that the refusal happens
  /// during the decode**, which is why this asserts the message: the old code
  /// materialised the whole output and then compared lengths, so it refused
  /// the same archives — after allocating them. The two are told apart by
  /// which sentence they refuse with, since telling them apart by memory
  /// would need an archive big enough to actually exhaust it.
  test('decoding stops at the declared size rather than after it', () {
    final bomb = Uint8List.fromList(gzip.encode(Uint8List(64 * 1024)));

    expect(
      () => GeoData.gunzipCapped(bomb, 640, 'ip4_city_v1.bin.gz'),
      throwsA(
        isA<StateError>().having(
          (e) => e.message,
          'message',
          contains('past the 640 bytes it declares'),
        ),
      ),
    );
  });

  test('and an archive of the declared size decodes', () {
    final honest = Uint8List.fromList(gzip.encode(Uint8List(640)));
    expect(GeoData.gunzipCapped(honest, 640, 'x').length, 640);
  });

  test('a truncated one is refused too, from the other side', () {
    // Short cannot be caught while decoding — a truncated archive simply
    // stops — so the length is still compared once it is done.
    final short = Uint8List.fromList(gzip.encode(Uint8List(320)));
    expect(
      () => GeoData.gunzipCapped(short, 640, 'x'),
      throwsA(isA<StateError>()),
    );
  });

  test('an asset that unpacks past what it declares is refused', () async {
    final bomb = Uint8List.fromList(gzip.encode(Uint8List(64 * 1024)));
    final manifest = GeoManifest.tryFromJson({
      'version': 1,
      'generated': '2026-10',
      'attribution': 'test',
      'assets': [
        for (final (name, family) in [('ip4', 4), ('ip6', 6)])
          {
            'name': '${name}_city_v1.bin.gz',
            'family': family,
            'bytes': bomb.length,
            // A hundredth of what it really unpacks to.
            'unpackedBytes': 640,
            'sha256': sha256.convert(bomb).toString(),
          },
      ],
    })!;
    final bodies = {
      'manifest.json': Uint8List.fromList(
        utf8.encode(jsonEncode(manifest.toJson())),
      ),
      for (final asset in manifest.assets) asset.name: bomb,
    };
    GeoData.clientFactory = () =>
        Dio()..httpClientAdapter = _RouteAdapter(bodies);

    expect(await GeoData.install(manifest), isFalse);
    expect(GeoData.installed()?.generated, '2026-09');
    expect(seen, 0);
  });

  test('a manifest without both readable bundles is not installed', () async {
    await File(GeoData.dir.joinPath('ip6_city_v1.bin')).delete();
    await GeoData.resetForTest();

    expect(GeoData.installed(), isNull);
  });

  test('a structurally corrupt bundle is not installed', () async {
    final file = File(GeoData.dir.joinPath('ip4_city_v1.bin'));
    await file.writeAsBytes(Uint8List(await file.length()), flush: true);
    await GeoData.resetForTest();

    expect(GeoData.installed(), isNull);
  });

  test(
    'a previous installation is restored after an interrupted swap',
    () async {
      await GeoData.resetForTest();
      final backupPath = '${GeoData.dir}.previous';
      await Directory(GeoData.dir).rename(backupPath);

      expect(GeoData.installed()?.generated, '2026-09');
      expect(await Directory(GeoData.dir).exists(), isTrue);
      expect(await Directory(backupPath).exists(), isFalse);
    },
  );

  test('a removal is announced once', () async {
    expect(await GeoData.remove(), isTrue);
    expect(seen, 1);
  });

  test('a failed update keeps the previous installation', () async {
    GeoData.clientFactory = () => Dio()..httpClientAdapter = _DeadAdapter();

    expect(await GeoData.install(manifestOf('2026-10')), isFalse);

    expect(seen, 0, reason: 'the installed data did not change');
    expect(GeoData.installed()?.generated, '2026-09');
  });

  test('and nothing is announced before the download is attempted', () async {
    // The half that matters on screen: whatever a listener does with the
    // announcement must not happen while the download is still running.
    var seenBeforeFetch = -1;
    GeoData.clientFactory = () {
      seenBeforeFetch = seen;
      return Dio()..httpClientAdapter = _DeadAdapter();
    };

    await GeoData.install(manifestOf('2026-10'));

    expect(
      seenBeforeFetch,
      0,
      reason: 'the old data remains live while staging is downloaded',
    );
  });

  test(
    'a partial staged update is discarded without touching the old one',
    () async {
      final offer = await offerOf('2026-10');
      GeoData.clientFactory = () => Dio()
        ..httpClientAdapter = _RouteAdapter({
          'ip4_city_v1.bin.gz': offer.bodies['ip4_city_v1.bin.gz']!,
        });

      expect(await GeoData.install(offer.manifest), isFalse);

      expect(GeoData.installed()?.generated, '2026-09');
      expect(await Directory('${GeoData.dir}.installing').exists(), isFalse);
      expect(seen, 0);
    },
  );

  test('a complete staged update replaces the old data once', () async {
    final offer = await offerOf('2026-10');
    GeoData.clientFactory = () =>
        Dio()..httpClientAdapter = _RouteAdapter(offer.bodies);

    expect(await GeoData.install(offer.manifest), isTrue);

    expect(GeoData.installed()?.generated, '2026-10');
    expect(await Directory('${GeoData.dir}.installing').exists(), isFalse);
    expect(await Directory('${GeoData.dir}.previous').exists(), isFalse);
    expect(seen, 1);
  });

  test('an invalid primary manifest falls back to a readable one', () async {
    final fallback = await offerOf('2026-10');
    GeoData.clientFactory = () => Dio()
      ..httpClientAdapter = _RouteAdapter({
        '${Urls.geoData}/manifest.json': Uint8List.fromList(utf8.encode('{')),
        '${Urls.geoDataFallback}/manifest.json':
            fallback.bodies['manifest.json']!,
      });

    expect((await GeoData.fetchManifest())?.generated, '2026-10');
  });

  test(
    'fallback uses its own manifest and restarts a partial primary download',
    () async {
      final primary = await offerOf('2026-10', gzipMarker: 1);
      final fallback = await offerOf('2026-10', gzipMarker: 2);
      final primaryV4 = primary.manifest.assets.firstWhere(
        (asset) => asset.family == 4,
      );
      final fallbackV4 = fallback.manifest.assets.firstWhere(
        (asset) => asset.family == 4,
      );
      expect(primaryV4.bytes, fallbackV4.bytes);
      expect(primaryV4.sha256, isNot(fallbackV4.sha256));

      final requests = <String>[];
      GeoData.clientFactory = () => Dio()
        ..httpClientAdapter = _RouteAdapter({
          '${Urls.geoData}/manifest.json': primary.bodies['manifest.json']!,
          '${Urls.geoData}/${primaryV4.name}': primary.bodies[primaryV4.name]!,
          ...routesFor(Urls.geoDataFallback, fallback.bodies),
        }, requests: requests);

      expect(await GeoData.install(primary.manifest), isTrue);

      final installedV4 = GeoData.installed()!.assets.firstWhere(
        (asset) => asset.family == 4,
      );
      expect(installedV4.sha256, fallbackV4.sha256);
      expect(
        requests,
        containsAllInOrder([
          '${Urls.geoData}/${primaryV4.name}',
          '${Urls.geoDataFallback}/${fallbackV4.name}',
        ]),
        reason: 'fallback must restart the first asset after staging is reset',
      );
      expect(seen, 1);
    },
  );

  test('a fallback from another month is rejected', () async {
    await expectIncompatibleFallbackRejected(
      await offerOf('2026-10'),
      await offerOf('2026-11'),
    );
  });

  test('a fallback with different attribution is rejected', () async {
    await expectIncompatibleFallbackRejected(
      await offerOf('2026-10'),
      await offerOf('2026-10', attribution: 'somebody else'),
    );
  });

  test('a fallback with different sizes is rejected', () async {
    final fallback = await offerOf('2026-10');
    await expectIncompatibleFallbackRejected(
      await offerOf('2026-10'),
      withPackedSizeDelta(fallback),
    );
  });
}

Dio _defaultForTest() => Dio();
