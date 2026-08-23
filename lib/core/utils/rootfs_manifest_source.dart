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

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/foundation.dart';
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

  /// The fetch in flight, if there is one.
  ///
  /// Two overlapping refreshes are two fetches racing to commit, and the one
  /// that finishes last wins — which need not be the one that started last. A
  /// slower fetch of an *older* manifest would then be adopted over a newer
  /// one and, worse, would write its lower serial over the high-water mark
  /// that the replay guard is. Reached from the settings page, so entering it
  /// twice in quick succession is all it takes.
  ///
  /// Joined rather than queued: a second caller wants a fresh manifest, and
  /// the one already being fetched is that.
  static Future<bool>? _inFlight;

  /// Fetches, verifies and adopts if it is newer. Answers whether it changed.
  ///
  /// Every failure is the same failure as far as the caller is concerned —
  /// what was in force stays in force. They are logged apart because "no
  /// network" and "a signature that did not verify" want very different
  /// reactions from whoever reads the log.
  static Future<bool> refresh({Dio? dio}) {
    final running = _inFlight;
    if (running != null) return running;
    final started = _refresh(dio: dio);
    _inFlight = started;
    return started.whenComplete(() {
      // Only if it is still ours. A caller that started the next one already
      // owns the slot by then.
      if (identical(_inFlight, started)) _inFlight = null;
    });
  }

  static Future<bool> _refresh({Dio? dio}) async {
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

    // The cache first and the serial last, because these are three writes and
    // the app can be killed between them. In this order an interruption
    // leaves a cache newer than the recorded high-water mark, which is
    // harmless — it still verifies, and it is still something this device
    // accepted. The other order leaves the mark ahead of the cache, so the
    // next launch reads a manifest the guard would now refuse.
    //
    // The serial is recorded even when the bundled copy is newer, because it
    // is the highest *accepted* serial that a replay has to beat, not the one
    // in force.
    Stores.setting.rootfsManifestCache.put(base64Encode(source));
    Stores.setting.rootfsManifestCacheSig.put(base64Encode(signature));
    Stores.setting.rootfsManifestSerial.put(fetched.serial);

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

  /// Visible so a test can point it at a server of its own. [manifestUrl] is
  /// absolute, so a `baseUrl` on the Dio handed to [refresh] does not redirect
  /// it — a test written that way fetches GitHub and proves nothing.
  @visibleForTesting
  static Future<Uint8List> getForTest(Dio dio, String url) => _get(dio, url);

  /// At most [_maxBytes] of [url], and never more held than that.
  ///
  /// Read as a stream and counted as it arrives, so a server answering with a
  /// gigabyte is stopped at the limit rather than after it. Buffering first
  /// and checking the length afterwards meant whoever served the manifest
  /// decided how much memory this app used — and that is a URL a device
  /// fetches on its own, with no one watching.
  static Future<Uint8List> _get(Dio dio, String url) async {
    final res = await dio.get<ResponseBody>(
      url,
      options: Options(
        responseType: ResponseType.stream,
        // Anything but 200 is not a manifest, including the redirects GitHub
        // uses for `releases/latest` — dio follows those itself.
        validateStatus: (code) => code == 200,
        receiveTimeout: const Duration(seconds: 20),
        sendTimeout: const Duration(seconds: 20),
      ),
    );
    final body = res.data;
    if (body == null) throw StateError('$url answered nothing');

    final builder = BytesBuilder(copy: false);
    final chunks = StreamIterator(body.stream);
    try {
      while (await chunks.moveNext()) {
        // Measured before it is kept, not after. Adding first bounds this at
        // the cap plus whatever one chunk happens to be — which is the
        // server's choice, not ours, and the whole point of having a cap is
        // that it is not.
        if (builder.length + chunks.current.length > _maxBytes) {
          throw StateError(
            '$url answered more than $_maxBytes bytes, which is not one',
          );
        }
        builder.add(chunks.current);
      }
    } finally {
      // Whatever ended the loop, the connection is done with. Left open, a
      // refused oversize response goes on being received.
      await chunks.cancel();
    }
    if (builder.isEmpty) throw StateError('$url answered nothing');
    return builder.takeBytes();
  }
}
