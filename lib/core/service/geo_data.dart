import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/foundation.dart' show ValueNotifier, visibleForTesting;
import 'package:server_box/core/service/geo_bundle.dart';
import 'package:server_box/data/model/app/geo_manifest.dart';
import 'package:server_box/data/res/url.dart';

/// The city-level data as something installed, rather than something fetched.
///
/// **The whole thing is downloaded once and every lookup after that is local.**
/// That is the difference from what this replaced: the old arrangement fetched
/// one shard per /8, which disclosed eight bits of every address looked up.
/// Downloading the lot discloses nothing at all — not which addresses, not how
/// many, not when — which is a property of having the file rather than a
/// promise about whoever served it.
///
/// It costs about 25 MB to fetch and 52 MB on disk, which is why it is opt-in
/// and why the dialog that asks quotes both numbers from the manifest rather
/// than from a constant that would go stale every month.
abstract final class GeoData {
  /// Where the unpacked bundles live.
  static String get dir => Paths.doc.joinPath('geo');

  static String get _stagingDir => '$dir.installing';
  static String get _backupDir => '$dir.previous';
  static const _endpoints = [Urls.geoData, Urls.geoDataFallback];

  static String _manifestAt(String root) => root.joinPath('installed.json');

  /// Replaced in tests. Nothing here should reach the network in a test run,
  /// and a seam is how that is enforced rather than hoped for.
  @visibleForTesting
  static Dio Function() clientFactory = _defaultClient;

  static Dio _defaultClient() => Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 15),
      // Two files of a dozen megabytes each, possibly on a phone network.
      receiveTimeout: const Duration(minutes: 10),
      responseType: ResponseType.bytes,
      validateStatus: (_) => true,
    ),
  );

  static GeoManifest? _installed;
  static bool _readInstalled = false;
  static final _open = <int, GeoBundle>{};

  /// Bumped whenever what is installed changes.
  ///
  /// Three places show or depend on it — the settings tile, the switch that
  /// turns the globe on, and the globe itself — and they are in different
  /// subtrees, so none of them can be told by whichever one caused the change.
  /// A counter rather than the manifest: the question every listener asks is
  /// "is what I drew still true", and a value that always differs answers it
  /// without anyone comparing manifests.
  static final revision = ValueNotifier(0);

  /// What is completely and readably installed, or null when nothing is.
  ///
  /// Read once and remembered, including the miss: the answer only changes
  /// when this class changes it.
  /// Synchronous for [GeoBundle.open]'s reason: validation reads two headers,
  /// their bucket tables and file lengths, and an `await` on the lookup path is
  /// a future a widget test's fake-async zone never completes.
  ///
  /// A manifest by itself is not an installation. Both bundles must exist,
  /// have the declared length, open as this format, and agree with the manifest
  /// on family and month. That makes a damaged installation look absent to all
  /// three download entry points, so the user can repair it by installing the
  /// same month again.
  static GeoManifest? installed() {
    if (_readInstalled) return _installed;
    _readInstalled = true;
    _installed = _readInstalledAt(dir);
    if (_installed != null) {
      // A crash after promoting the staging directory but before removing the
      // old one leaves a harmless duplicate. Once the new copy is known good,
      // finish that cleanup on the next launch.
      _discardDirectorySync(_backupDir);
      return _installed;
    }

    // The swap moves the old installation aside before promoting the new one.
    // If the process stopped between those two renames, restore the copy that
    // was already known good instead of presenting an empty installation.
    final backup = _readInstalledAt(_backupDir);
    if (backup == null) return null;
    try {
      final active = Directory(dir);
      if (active.existsSync()) active.deleteSync(recursive: true);
      Directory(_backupDir).renameSync(dir);
      _installed = backup;
    } catch (e, s) {
      Loggers.app.warning('Could not restore the previous geo data', e, s);
      _installed = null;
    }
    return _installed;
  }

  /// Reads and validates one complete installation directory.
  static GeoManifest? _readInstalledAt(String root) {
    try {
      final file = File(_manifestAt(root));
      if (!file.existsSync()) return null;
      final manifest = GeoManifest.tryFromJson(
        jsonDecode(file.readAsStringSync()),
      );
      if (manifest == null) return null;
      for (final asset in manifest.assets) {
        final handle = File(root.joinPath(asset.unpackedName));
        if (!handle.existsSync() ||
            handle.lengthSync() != asset.unpackedBytes) {
          return null;
        }
        final bundle = GeoBundle.open(handle.path);
        if (bundle == null) return null;
        final valid =
            bundle.family == asset.family &&
            bundle.year == manifest.year &&
            bundle.month == manifest.month;
        bundle.close();
        if (!valid) return null;
      }
      return manifest;
    } catch (e) {
      Loggers.app.fine('No usable geo data at $root: $e');
      return null;
    }
  }

  static void _discardDirectorySync(String path) {
    try {
      final handle = Directory(path);
      if (handle.existsSync()) handle.deleteSync(recursive: true);
    } catch (e, s) {
      Loggers.app.warning('Could not clean up geo directory $path', e, s);
    }
  }

  /// The bundle for [family], opened on first use and kept open.
  ///
  /// Kept open because a lookup is a handful of small reads into it — see
  /// [GeoBundle] for why it is not read into memory — and reopening per
  /// lookup would make the syscall count the cost rather than the reads.
  static GeoBundle? bundle(int family) {
    final held = _open[family];
    if (held != null) return held;
    final manifest = installed();
    if (manifest == null) return null;
    GeoAsset? asset;
    for (final a in manifest.assets) {
      if (a.family == family) asset = a;
    }
    if (asset == null) return null;
    final opened = GeoBundle.open(dir.joinPath(asset.unpackedName));
    if (opened == null) return null;
    // The header is checked against the manifest rather than assumed: a file
    // renamed or half-replaced would otherwise be read as the other family.
    if (opened.family != family ||
        opened.year != manifest.year ||
        opened.month != manifest.month) {
      opened.close();
      return null;
    }
    _open[family] = opened;
    return opened;
  }

  /// What the endpoint is offering, without downloading any of it.
  ///
  /// This is the one request made before consent, and it is a couple hundred
  /// bytes — it exists so the dialog can say what the download actually costs
  /// this month instead of quoting a number compiled into the app.
  static Future<GeoManifest?> fetchManifest() async {
    for (final endpoint in _endpoints) {
      final manifest = await _fetchManifestFrom(endpoint);
      if (manifest != null) return manifest;
    }
    return null;
  }

  static Future<GeoManifest?> _fetchManifestFrom(String endpoint) async {
    final bytes = await _fetchFrom(endpoint, 'manifest.json', 64 * 1024);
    if (bytes == null) return null;
    try {
      final manifest = GeoManifest.tryFromJson(jsonDecode(utf8.decode(bytes)));
      if (manifest == null) {
        Loggers.app.warning('Geo manifest from $endpoint is invalid');
      }
      return manifest;
    } catch (e) {
      Loggers.app.warning('Geo manifest from $endpoint is unreadable: $e');
      return null;
    }
  }

  /// Whether [offered] still describes what the user agreed to download.
  ///
  /// A fallback may gzip the same raw bundle differently, so its packed digest
  /// is deliberately absent from this comparison. Everything visible in the
  /// consent dialog or needed to identify the data remains fixed, including
  /// both packed and unpacked sizes. The successful endpoint's own digest is
  /// then used to verify its bytes.
  static bool _matchesConfirmedOffer(
    GeoManifest confirmed,
    GeoManifest offered,
  ) {
    if (offered.version != confirmed.version ||
        offered.generated != confirmed.generated ||
        offered.attribution != confirmed.attribution ||
        offered.assets.length != confirmed.assets.length) {
      return false;
    }
    for (final expected in confirmed.assets) {
      GeoAsset? actual;
      for (final candidate in offered.assets) {
        if (candidate.family == expected.family) {
          actual = candidate;
          break;
        }
      }
      if (actual == null ||
          actual.name != expected.name ||
          actual.bytes != expected.bytes ||
          actual.unpackedBytes != expected.unpackedBytes) {
        return false;
      }
    }
    return true;
  }

  /// Downloads and unpacks everything [manifest] names.
  ///
  /// Everything is first written to a staging directory beside the live one.
  /// Only after both families and the manifest validate is that directory
  /// promoted, so a failed update leaves the previous month usable.
  ///
  /// [onProgress] is called with bytes received and the total from the
  /// manifest, so a progress bar has a denominator before the first byte.
  ///
  /// Returns whether everything arrived, verified and unpacked. A failure
  /// discards only the staging directory: one family is never published on its
  /// own, and an installation that was working before the attempt stays so.
  static Future<bool> install(
    GeoManifest manifest, {
    void Function(int received, int total)? onProgress,
  }) async {
    for (final endpoint in _endpoints) {
      if (!await _discardDirectory(_stagingDir)) return false;
      try {
        // Re-read the manifest from the endpoint whose assets will be used.
        // Otherwise a primary manifest can be paired with a fallback archive,
        // even though independently produced gzip files need not share a hash.
        final offered = await _fetchManifestFrom(endpoint);
        if (offered == null) continue;
        if (!_matchesConfirmedOffer(manifest, offered)) {
          Loggers.app.warning(
            'Geo offer from $endpoint changed after it was confirmed',
          );
          continue;
        }
        if (await _installFromEndpoint(endpoint, offered, onProgress)) {
          return true;
        }
      } catch (e, s) {
        Loggers.app.warning('Could not install geo data from $endpoint', e, s);
      }
    }
    await _discardDirectory(_stagingDir);
    return false;
  }

  static Future<bool> _installFromEndpoint(
    String endpoint,
    GeoManifest manifest,
    void Function(int received, int total)? onProgress,
  ) async {
    final total = manifest.downloadBytes;
    var done = 0;
    await Directory(_stagingDir).create(recursive: true);
    for (final asset in manifest.assets) {
      final packed = await _fetchFrom(
        endpoint,
        asset.name,
        asset.bytes + 1024,
        // `done` is whole assets already here. It restarts at zero when an
        // endpoint fails and the next complete source is attempted, because
        // all bytes in the abandoned staging directory are discarded.
        onReceive: (got) => onProgress?.call(done + got, total),
      );
      if (packed == null) throw StateError('${asset.name} did not arrive');
      if (packed.length != asset.bytes) {
        throw StateError(
          '${asset.name} is ${packed.length} bytes, manifest says '
          '${asset.bytes}',
        );
      }
      // Before it is unpacked, and against the *packed* bytes, so what is
      // checked is what was received. Not a signature: the manifest comes
      // from the same place as the files, so this catches a corrupted or
      // truncated transfer rather than a hostile endpoint. What limits the
      // damage a hostile one could do is that a bundle is coordinates —
      // there is nothing in it that this app executes.
      final digest = sha256.convert(packed).toString();
      if (digest != asset.sha256) {
        throw StateError('${asset.name} hashes to $digest');
      }
      // Decoded against a ceiling rather than decoded and then measured.
      // `gzip.decode` materialises the whole output first, so a 64 MB
      // download declaring 4 MB and expanding to 8 GB was out of memory
      // before the length check on the next line could refuse it — and the
      // manifest naming both numbers comes from the same endpoint as the
      // bytes, so neither is a reason to trust the other.
      final raw = gunzipCapped(packed, asset.unpackedBytes, asset.name);
      final output = _stagingDir.joinPath(asset.unpackedName);
      await File(output).writeAsBytes(raw, flush: true);
      final bundle = GeoBundle.open(output);
      final valid =
          bundle != null &&
          bundle.family == asset.family &&
          bundle.year == manifest.year &&
          bundle.month == manifest.month;
      bundle?.close();
      if (!valid) {
        throw StateError('${asset.name} is not the bundle in the manifest');
      }
      done += packed.length;
      onProgress?.call(done, total);
    }

    await File(
      _manifestAt(_stagingDir),
    ).writeAsString(jsonEncode(manifest.toJson()), flush: true);
    if (_readInstalledAt(_stagingDir) == null) {
      throw StateError('the staged geo installation is incomplete');
    }
    return _activateStaging(manifest);
  }

  /// Swaps a validated staging directory into place, rolling the old one back
  /// if the promotion fails.
  static Future<bool> _activateStaging(GeoManifest manifest) async {
    final active = Directory(dir);
    final staging = Directory(_stagingDir);
    final backup = Directory(_backupDir);
    var movedActive = false;

    _closeBundles();
    try {
      if (await backup.exists()) await backup.delete(recursive: true);
      if (await active.exists()) {
        await active.rename(_backupDir);
        movedActive = true;
      }
      await staging.rename(dir);
    } catch (e, s) {
      Loggers.app.warning('Could not activate the staged geo data', e, s);
      if (movedActive) {
        try {
          if (await active.exists()) await active.delete(recursive: true);
          if (await backup.exists()) await backup.rename(dir);
        } catch (rollbackError, rollbackStack) {
          Loggers.app.warning(
            'Could not roll back the previous geo data',
            rollbackError,
            rollbackStack,
          );
        }
      }
      // The disk decides what survived. Do not keep an in-memory answer from
      // before handles were closed and directories were moved.
      _installed = null;
      _readInstalled = false;
      return false;
    }

    _installed = manifest;
    _readInstalled = true;
    revision.value++;
    try {
      if (await backup.exists()) await backup.delete(recursive: true);
    } catch (e, s) {
      // The active copy is already complete. A leftover backup is recovered or
      // cleaned by [installed] on the next launch and does not make this update
      // a failure.
      Loggers.app.warning('Could not remove the previous geo data', e, s);
    }
    return true;
  }

  /// Takes it all off the device.
  ///
  /// Offered because 52 MB is worth being able to reclaim, and because it is
  /// data this app went and got — somebody who turns the feature off should be
  /// able to take it back rather than be told it will expire eventually.
  static Future<bool> remove() async {
    try {
      return await _erase();
    } finally {
      // A failed recursive delete can still remove part of the installation,
      // and all open bundles were closed before it started. Every dependent
      // view must therefore re-check the disk on either outcome.
      revision.value++;
    }
  }

  /// The deletion itself, without telling anybody it happened.
  ///
  /// Includes interrupted staging and backup directories so the explicit
  /// remove action reclaims every byte this service may have written.
  static Future<bool> _erase() async {
    _closeBundles();
    _installed = null;
    _readInstalled = false;
    var removed = true;
    for (final path in [dir, _stagingDir, _backupDir]) {
      if (!await _discardDirectory(path)) removed = false;
    }
    if (removed) {
      _readInstalled = true;
    } else {
      // Let the next read inspect what remains instead of claiming success
      // from an in-memory null while installed.json is still on disk.
    }
    return removed;
  }

  static void _closeBundles() {
    for (final open in _open.values) {
      open.close();
    }
    _open.clear();
  }

  static Future<bool> _discardDirectory(String path) async {
    try {
      final handle = Directory(path);
      if (await handle.exists()) await handle.delete(recursive: true);
      return true;
    } catch (e, s) {
      Loggers.app.warning('Could not remove geo directory $path', e, s);
      return false;
    }
  }

  /// Gunzips [packed], refusing as soon as the output passes [expected].
  ///
  /// **The refusal has to happen while decoding, not after.** The size a
  /// manifest declares is not evidence — it arrives from the same place as the
  /// bytes it describes — so the only thing standing between a hostile or
  /// corrupt archive and this device's memory is that nothing is allowed to
  /// accumulate past the declared size. Chunk by chunk through the converter's
  /// own sink, the answer comes on the first chunk that goes over.
  ///
  /// Exact, not a bound: a bundle that unpacks to anything other than what the
  /// manifest says is not the bundle the manifest describes.
  @visibleForTesting
  static Uint8List gunzipCapped(Uint8List packed, int expected, String name) {
    final out = _CappedBytes(expected, name);
    final sink = gzip.decoder.startChunkedConversion(out);
    sink.add(packed);
    sink.close();
    final raw = out.builder.takeBytes();
    // Short is the other direction and cannot be caught above: a truncated
    // archive simply stops.
    if (raw.length != expected) {
      throw StateError(
        '$name unpacks to ${raw.length}, manifest says $expected',
      );
    }
    return raw;
  }

  /// How much is on disk, in bytes.
  static Future<int> sizeOnDisk() async {
    final handle = Directory(dir);
    if (!await handle.exists()) return 0;
    var total = 0;
    await for (final entry in handle.list(recursive: true)) {
      if (entry is File) total += await entry.length();
    }
    return total;
  }

  /// [path] from exactly one [endpoint].
  ///
  /// Source selection belongs to the manifest/install transaction, so this
  /// method must never switch endpoints independently. Null for every failure,
  /// since there is nothing a caller would do differently.
  static Future<Uint8List?> _fetchFrom(
    String endpoint,
    String path,
    int maxBytes, {
    void Function(int received)? onReceive,
  }) async {
    final url = '$endpoint/$path';
    final dio = clientFactory();
    try {
      try {
        // A `cancel` future was threaded through here and through `install`
        // and never passed by anyone. It also registered a derived future per
        // URL attempt with no `onError`, so a caller handing it a future that
        // completed with an error would have produced an unhandled one — which
        // reaches the zone handler in `main.dart` and leaves a crash marker.
        // Offering a Cancel button is a product decision, not this parameter.
        final token = CancelToken();
        final response = await dio.get<List<int>>(
          url,
          options: Options(responseType: ResponseType.bytes),
          cancelToken: token,
          onReceiveProgress: (got, _) {
            onReceive?.call(got);
            // Cancelled as it arrives rather than measured once it has: a
            // check after the body is already a `List<int>` cannot prevent
            // the allocation it exists to prevent.
            if (got > maxBytes && !token.isCancelled) {
              token.cancel(StateError('$url is over $maxBytes bytes'));
            }
          },
        );
        if (response.statusCode != 200) return null;
        final body = response.data;
        if (body == null || body.isEmpty) return null;
        // The progress callback is not guaranteed to fire — a response with
        // no `Content-Length` streamed in one chunk arrives whole — so the
        // size is checked here as well.
        if (body.length > maxBytes) {
          Loggers.app.warning('$url is ${body.length} bytes, refusing it');
          return null;
        }
        return Uint8List.fromList(body);
      } catch (e) {
        Loggers.app.fine('Geo endpoint $url did not answer: $e');
        return null;
      }
    } finally {
      dio.close();
    }
  }

  /// For tests, which need each case to start from nothing.
  @visibleForTesting
  static Future<void> resetForTest() async {
    _closeBundles();
    _installed = null;
    _readInstalled = false;
    clientFactory = _defaultClient;
  }
}

/// Collects gunzipped bytes and stops the moment there are too many.
///
/// The whole point is that it refuses *during* the decode. `gzip.decode`
/// materialises its output first and would be out of memory before any length
/// check could run, and the size to check against comes from the same endpoint
/// as the archive — so the ceiling is enforced where the bytes appear rather
/// than believed after the fact.
class _CappedBytes implements Sink<List<int>> {
  _CappedBytes(this.limit, this.name);

  final int limit;
  final String name;
  final builder = BytesBuilder(copy: false);

  @override
  void add(List<int> chunk) {
    if (builder.length + chunk.length > limit) {
      throw StateError('$name unpacks past the $limit bytes it declares');
    }
    builder.add(chunk);
  }

  @override
  void close() {}
}
