import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:fl_lib/fl_lib.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/core/utils/rootfs_manifest_source.dart';
import 'package:server_box/data/model/app/linux_distros.dart';
import 'package:server_box/data/model/app/rootfs_manifest.dart';
import 'package:server_box/data/res/store.dart';
import 'package:server_box/data/store/setting.dart';

import 'helpers/test_db.dart';

/// Which of the manifests on hand gets believed.
///
/// The interesting cases are all failures, and they are all silent: a refused
/// fetch, a dropped cache and a successful one that happened to be older than
/// what shipped look identical from the outside — the app carries on either
/// way. What separates them is which manifest is in force afterwards, so that
/// is what these assert.
///
/// The signed fixture is real, from the key that signs `shellbox-rootfs`. Its
/// serial is 1, the same as the bundled asset's, which makes it useful twice:
/// as something that verifies, and as something that must not displace an
/// equally new bundled copy.
void main() {
  late Uint8List signed;
  late Uint8List signature;
  late String bundledJson;

  setUpAll(() {
    // loadLocal reads the bundled asset through rootBundle, which needs one.
    TestWidgetsFlutterBinding.ensureInitialized();
    signed = File(
      'test/fixtures/rootfs_manifest/signed.json',
    ).readAsBytesSync();
    signature = File(
      'test/fixtures/rootfs_manifest/signed.json.sig',
    ).readAsBytesSync();
    bundledJson = File('assets/rootfs_manifest.json').readAsStringSync();
  });

  setUp(() async {
    await openTestDb();
    await getIt.reset();
    getIt.registerSingleton<SettingStore>(SettingStore.forTest());
    // What `Rootfs.prepare` would have adopted before any of this runs.
    LinuxDistros.adoptForTest(RootfsManifest.parse(bundledJson));
  });

  tearDown(SqliteDb.close);

  /// A Dio that answers the manifest URL with [body] and the signature URL
  /// with [sig], or fails with [error] for everything.
  Dio fakeDio({List<int>? body, List<int>? sig, Object? error}) {
    final dio = Dio();
    dio.httpClientAdapter = _Adapter(body: body, sig: sig, error: error);
    return dio;
  }

  group('refresh', () {
    test('a body far larger than a manifest is refused while it arrives', () async {
      // Over a real socket, because a fake adapter cannot express the thing
      // under test: its stream ignores backpressure, so the producer runs to
      // completion whatever the consumer does, and a chunk count measures the
      // fake rather than the code.
      //
      // A refusal on its own proves nothing either — megabytes of zeros fail
      // the signature check just as well, so a test that looked only at the
      // result passed happily while the whole body was read into memory
      // first. What separates the two is *when*: this server sends more than
      // the cap and then stalls, so a reader that stops at the cap answers at
      // once and one that waits for the end waits for the receive timeout.
      // `ensureInitialized` above installs Flutter's HttpOverrides, which
      // answers every request 400 without a socket being opened. A real one
      // is the whole point here, so this test asks for the real client back.
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));
      unawaited(() async {
        await for (final request in server) {
          try {
            for (var i = 0; i < 6; i++) {
              request.response.add(Uint8List(64 * 1024));
              await request.response.flush();
            }
            // And then nothing, for as long as anyone is listening.
            await Completer<void>().future;
          } catch (_) {
            // The client hung up, which is the point.
          }
        }
      }());

      final watch = Stopwatch()..start();
      await HttpOverrides.runWithHttpOverrides(() async {
        await expectLater(
          RootfsManifestSource.getForTest(
            Dio(),
            'http://${server.address.address}:${server.port}/manifest.json',
          ),
          throwsStateError,
        );
      }, _RealHttp());
      watch.stop();

      // The receive timeout is 20s. Anything near it means the read ran on
      // waiting for the end of a body that never ends.
      expect(
        watch.elapsed,
        lessThan(const Duration(seconds: 5)),
        reason: 'refused while the body was still arriving',
      );
    });

    test('two overlapping refreshes are one fetch', () async {
      // Two racing to commit, and the one finishing last wins — which need not
      // be the one that started last. A slower fetch of an older manifest
      // would be adopted over a newer one, and would write its lower serial
      // over the high-water mark the replay guard is. Entering the Linux
      // settings page twice in quick succession is all it takes.
      final dio = _Counting(fakeDio(body: signed, sig: signature));

      final results = await Future.wait([
        RootfsManifestSource.refresh(dio: dio),
        RootfsManifestSource.refresh(dio: dio),
      ]);

      expect(results, [false, false]);
      // Two requests — the manifest and its signature — not four.
      expect(dio.requests, 2);
      expect(Stores.setting.rootfsManifestSerial.fetch(), 1);
    });

    test('and a later one still fetches', () async {
      // Joined while it is running, not memoised. A page entered again
      // tomorrow has to be able to see a newer manifest.
      final dio = _Counting(fakeDio(body: signed, sig: signature));

      await RootfsManifestSource.refresh(dio: dio);
      await RootfsManifestSource.refresh(dio: dio);

      expect(dio.requests, 4);
    });

    test('a fetch that cannot happen leaves what was in force', () async {
      final before = LinuxDistros.current.serial;
      final changed = await RootfsManifestSource.refresh(
        dio: fakeDio(error: 'no network'),
      );
      expect(changed, isFalse);
      expect(LinuxDistros.current.serial, before);
      // Nothing was cached, so a later launch does not read a half-fetch.
      expect(Stores.setting.rootfsManifestCache.fetch(), isEmpty);
    });

    test('a tampered manifest is refused and not cached', () async {
      final tampered = Uint8List.fromList(signed);
      tampered[tampered.length ~/ 2] ^= 0x01;

      final changed = await RootfsManifestSource.refresh(
        dio: fakeDio(body: tampered, sig: signature),
      );
      expect(changed, isFalse);
      expect(Stores.setting.rootfsManifestCache.fetch(), isEmpty);
      // And it must not count as accepted, or a later genuine manifest with a
      // lower serial would be refused on its account.
      expect(Stores.setting.rootfsManifestSerial.fetch(), 0);
    });

    test('a verified manifest is cached and its serial recorded', () async {
      final changed = await RootfsManifestSource.refresh(
        dio: fakeDio(body: signed, sig: signature),
      );
      // Same serial as the bundled copy, so nothing is displaced...
      expect(changed, isFalse);
      // ...but it verified, so it is kept and counted.
      expect(
        base64Decode(Stores.setting.rootfsManifestCache.fetch()),
        signed,
      );
      expect(Stores.setting.rootfsManifestSerial.fetch(), 1);
    });

    test('a replay below the accepted serial is refused', () async {
      // The device has already seen something newer.
      Stores.setting.rootfsManifestSerial.put(99);

      final changed = await RootfsManifestSource.refresh(
        dio: fakeDio(body: signed, sig: signature),
      );
      expect(changed, isFalse);
      expect(Stores.setting.rootfsManifestCache.fetch(), isEmpty);
      // The high-water mark does not move down.
      expect(Stores.setting.rootfsManifestSerial.fetch(), 99);
    });

    test('something far too large is not read as a manifest', () async {
      final changed = await RootfsManifestSource.refresh(
        dio: fakeDio(body: List.filled(512 * 1024, 0x20), sig: signature),
      );
      expect(changed, isFalse);
    });
  });

  group('loadLocal', () {
    test('with no cache, the bundled copy is what is in force', () async {
      await RootfsManifestSource.loadLocal();
      expect(LinuxDistros.current.serial, 1);
      expect(LinuxDistros.installable, isNotEmpty);
    });

    test('a cache that no longer verifies is dropped, not used', () async {
      final tampered = Uint8List.fromList(signed);
      tampered[10] ^= 0x01;
      Stores.setting.rootfsManifestCache.put(base64Encode(tampered));
      Stores.setting.rootfsManifestCacheSig.put(base64Encode(signature));

      await RootfsManifestSource.loadLocal();

      // Fell back rather than carried on with it, and cleared it so the next
      // launch does not repeat the work.
      expect(LinuxDistros.current.serial, 1);
      expect(Stores.setting.rootfsManifestCache.fetch(), isEmpty);
    });

    test('a cache no newer than the bundled copy does not displace it', () async {
      // What happens after an app update ships a manifest as new as the last
      // fetched one: the two are equal, and the bundled one stays. Believing
      // the cache here would be harmless today and wrong in principle — an
      // update must never move a device backwards.
      Stores.setting.rootfsManifestCache.put(base64Encode(signed));
      Stores.setting.rootfsManifestCacheSig.put(base64Encode(signature));

      await RootfsManifestSource.loadLocal();

      expect(LinuxDistros.current.serial, 1);
      // Still there: it verified, so there is no reason to throw it away.
      expect(Stores.setting.rootfsManifestCache.fetch(), isNotEmpty);
    });

    test('it does not throw when the cache is nonsense', () async {
      // It runs on the startup path. A device with a corrupt cache still has
      // to reach a working app.
      Stores.setting.rootfsManifestCache.put('not base64 !!');
      Stores.setting.rootfsManifestCacheSig.put('nor this');

      await RootfsManifestSource.loadLocal();
      expect(LinuxDistros.current.serial, 1);
    });
  });
}

/// Answers the two URLs the source asks for, and nothing else.
/// A Dio that counts what it was asked for, wrapping [inner]'s adapter.
class _Counting with DioMixin implements Dio {
  _Counting(Dio inner) {
    options = inner.options;
    httpClientAdapter = _Counter(inner.httpClientAdapter, this);
  }

  int requests = 0;
}

class _Counter implements HttpClientAdapter {
  _Counter(this.inner, this.owner);

  final HttpClientAdapter inner;
  final _Counting owner;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) {
    owner.requests++;
    return inner.fetch(options, requestStream, cancelFuture);
  }

  @override
  void close({bool force = false}) => inner.close(force: force);
}

/// The default `HttpOverrides`, which is to say none at all: its inherited
/// `createHttpClient` builds a real client. Overriding the method to call
/// `HttpClient()` instead would re-enter whichever override is in force and
/// recurse until the stack ran out — which is what it did.
class _RealHttp extends HttpOverrides {}

class _Adapter implements HttpClientAdapter {
  _Adapter({this.body, this.sig, this.error});

  final List<int>? body;
  final List<int>? sig;
  final Object? error;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (error != null) {
      throw DioException(requestOptions: options, error: error);
    }
    final isSig = options.uri.path.endsWith('.sig');
    final payload = isSig ? sig : body;
    if (payload == null) {
      throw DioException(requestOptions: options, error: 'nothing to answer');
    }
    return ResponseBody.fromBytes(payload, 200);
  }

  @override
  void close({bool force = false}) {}
}
