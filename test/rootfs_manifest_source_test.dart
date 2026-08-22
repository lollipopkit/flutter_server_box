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
