/// Getting a manifest, and deciding which of the ones on hand to believe.
///
/// Three, in the order they can fail:
///
///   bundled  ships in the binary, so it is always there and always readable.
///            Unsigned, and correctly so — anyone who could alter it could
///            alter the public key beside it.
///   cached   the last fetched one that verified. Re-verified when it is read
///            rather than trusted for having once been verified: it sits in
///            app storage, and re-checking sixty-four bytes costs nothing next
///            to believing whatever is there.
///   fetched  from `shellbox-rootfs`. Signed, and refused unless it verifies,
///            is not older than what this device has already accepted, and has
///            not expired.
///
/// The highest serial among those that pass wins. Not "the newest thing that
/// arrived": a build shipping a bundled manifest newer than a cached one has
/// to win, or updating the app would move a device backwards.
///
/// Nothing here blocks anything. `loadLocal` is on the startup path and never
/// touches the network; [refresh] is the part that does, and a device that is
/// offline, behind a blocked GitHub, or being fed a bad manifest carries on
/// with what it had.
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:fl_lib/fl_lib.dart';
import 'package:server_box/data/model/app/linux_distros.dart';
import 'package:server_box/data/model/app/rootfs_manifest.dart';
import 'package:server_box/data/model/app/rootfs_manifest_trust.dart';
import 'package:server_box/data/res/store.dart';

abstract final class RootfsManifestSource {
  /// The release asset, always the latest one that repository published.
  ///
  /// `releases/latest` rather than a pinned tag, since the whole point is that
  /// a device gets a newer pin without a new build. What stops that being a
  /// blank cheque is the signature and the serial, not the URL.
  static const manifestUrl =
      'https://github.com/lollipopkit/shellbox-rootfs/releases/latest/download/manifest.json';
  static const signatureUrl = '$manifestUrl.sig';

  /// A manifest is a couple of kilobytes. Anything much larger is not one, and
  /// reading it into memory to find that out is what this avoids.
  static const _maxBytes = 256 * 1024;

  /// Adopts the best manifest available without the network.
  ///
  /// Called from `Rootfs.prepare`, so it must not throw: a device whose cache
  /// is corrupt still has to reach a working app, with the bundled copy.
  static Future<void> loadLocal() async {
    await LinuxDistros.loadBundled();
    final cached = _readCache();
    if (cached != null && cached.serial > LinuxDistros.current.serial) {
      LinuxDistros.adopt(cached);
    }
  }

  /// Fetches, verifies and adopts if it is newer. Answers whether it changed.
  ///
  /// Every failure is the same failure as far as the caller is concerned —
  /// what was in force stays in force. They are logged apart because "no
  /// network" and "a signature that did not verify" want very different
  /// reactions from whoever reads the log.
  static Future<bool> refresh({Dio? dio}) async {
    final client = dio ?? Dio();
    final Uint8List source;
    final Uint8List signature;
    try {
      source = await _get(client, manifestUrl);
      signature = await _get(client, signatureUrl);
    } catch (e) {
      Loggers.app.info('rootfs manifest: not fetched ($e)');
      return false;
    }

    final RootfsManifest fetched;
    try {
      fetched = RootfsManifestTrust.verify(
        source,
        signature,
        previousSerial: Stores.setting.rootfsManifestSerial.fetch(),
        now: DateTime.now(),
      );
    } catch (e) {
      // Worth a warning rather than a note. A manifest that fails here is
      // either damaged in transit or is somebody trying to choose what this
      // device downloads and runs, and the two look alike from here.
      Loggers.app.warning('rootfs manifest: refused ($e)');
      return false;
    }

    // Recorded even when the bundled copy is newer, because it is the highest
    // *accepted* serial that a replay has to beat, not the one in force.
    Stores.setting.rootfsManifestSerial.put(fetched.serial);
    Stores.setting.rootfsManifestCache.put(base64Encode(source));
    Stores.setting.rootfsManifestCacheSig.put(base64Encode(signature));

    if (fetched.serial <= LinuxDistros.current.serial) return false;
    LinuxDistros.adopt(fetched);
    Loggers.app.info('rootfs manifest: adopted serial ${fetched.serial}');
    return true;
  }

  /// The cached manifest, if there is one and it still verifies.
  ///
  /// A cache that no longer verifies is dropped rather than kept: the only
  /// ways to get one are damage and tampering, and neither is worth carrying
  /// forward past the next fetch.
  static RootfsManifest? _readCache() {
    final raw = Stores.setting.rootfsManifestCache.fetch();
    final sig = Stores.setting.rootfsManifestCacheSig.fetch();
    if (raw.isEmpty || sig.isEmpty) return null;
    try {
      return RootfsManifestTrust.verify(
        base64Decode(raw),
        base64Decode(sig),
        // Not compared against itself. The serial guard is about a *fetch*
        // being older than what was accepted; the cache is what was accepted.
        previousSerial: null,
        now: DateTime.now(),
      );
    } catch (e) {
      Loggers.app.warning('rootfs manifest: cache dropped ($e)');
      Stores.setting.rootfsManifestCache.put('');
      Stores.setting.rootfsManifestCacheSig.put('');
      return null;
    }
  }

  static Future<Uint8List> _get(Dio dio, String url) async {
    final res = await dio.get<List<int>>(
      url,
      options: Options(
        responseType: ResponseType.bytes,
        // Anything but 200 is not a manifest, including the redirects GitHub
        // uses for `releases/latest` — dio follows those itself.
        validateStatus: (code) => code == 200,
        receiveTimeout: const Duration(seconds: 20),
        sendTimeout: const Duration(seconds: 20),
      ),
    );
    final bytes = res.data;
    if (bytes == null || bytes.isEmpty) {
      throw StateError('$url answered nothing');
    }
    if (bytes.length > _maxBytes) {
      throw StateError('$url answered ${bytes.length} bytes, which is not one');
    }
    return Uint8List.fromList(bytes);
  }
}
