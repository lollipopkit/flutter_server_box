import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

import 'package:dio/dio.dart';
import 'package:fl_lib/fl_lib.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/core/service/geo_data.dart';
import 'package:server_box/data/model/app/geo_manifest.dart';

import 'helpers/geo_fixture.dart';

/// An endpoint that serves the same bytes for every request.
class _ServingAdapter implements HttpClientAdapter {
  _ServingAdapter(this.body);

  final Uint8List body;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async => ResponseBody.fromBytes(body, 200);
}

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
    GeoData.clientFactory = () => Dio()
      ..httpClientAdapter = _ServingAdapter(bomb);

    expect(await GeoData.install(manifest), isFalse);
    expect(GeoData.installed(), isNull);
  });

  test('a removal is announced once', () async {
    expect(await GeoData.remove(), isTrue);
    expect(seen, 1);
  });

  test('a failed install is announced once, not twice', () async {
    // The bug: `install` began with `remove()`, which announces. Listeners
    // heard the data was gone before a single byte had been fetched, and heard
    // it again when the attempt collapsed — so the globe cleared and
    // re-resolved everything twice for one failed download.
    GeoData.clientFactory = () => Dio()..httpClientAdapter = _DeadAdapter();

    expect(await GeoData.install(manifestOf('2026-10')), isFalse);

    expect(seen, 1, reason: 'one attempt, one change');
    expect(GeoData.installed(), isNull);
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
      reason: 'the old data was deleted, and nobody was told yet',
    );
  });
}

Dio _defaultForTest() => Dio();
