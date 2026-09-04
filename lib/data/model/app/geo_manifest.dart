/// What `manifest.json` says: which files there are and how big they are.
///
/// Read before anything is downloaded, because it is what the size in the
/// consent dialog comes from. A number written into the app would be a number
/// that goes stale every month while the dialog kept quoting it.
///
/// Every field is read rather than assumed, and anything unreadable makes the
/// whole manifest null — a partial one would let a download start against
/// sizes and digests that do not describe the files.
final class GeoManifest {
  const GeoManifest._({
    required this.version,
    required this.generated,
    required this.attribution,
    required this.assets,
  });

  static const _supportedVersion = 1;

  /// The format version, not the month. This build reads 1.
  final int version;

  /// The month the data was built from, `YYYY-MM`.
  ///
  /// What decides whether what is installed is still current. Also in each
  /// bundle's own header, so a file can say what it is without this — the two
  /// are compared rather than one trusted.
  final String generated;

  int get year => int.parse(generated.substring(0, 4));
  int get month => int.parse(generated.substring(5, 7));

  /// DB-IP's, which CC BY 4.0 requires be carried with the data.
  final String attribution;

  final List<GeoAsset> assets;

  /// What someone is being asked to agree to downloading.
  int get downloadBytes => assets.fold(0, (sum, a) => sum + a.bytes);

  /// What it then costs on their device, which is more than double the
  /// download and is the number a size prompt would understate by leaving out.
  int get diskBytes => assets.fold(0, (sum, a) => sum + a.unpackedBytes);

  /// Null for anything this build cannot read, a *newer* version included: the
  /// fields would still parse and the meanings would not.
  static GeoManifest? tryFromJson(Object? json) {
    if (json is! Map) return null;
    if (json['version'] != _supportedVersion) return null;
    final generated = json['generated'];
    if (generated is! String || !RegExp(r'^\d{4}-\d{2}$').hasMatch(generated)) {
      return null;
    }
    final year = int.parse(generated.substring(0, 4));
    final month = int.parse(generated.substring(5, 7));
    if (year == 0 || month < 1 || month > 12) return null;

    final attribution = json['attribution'];
    if (attribution != null && attribution is! String) return null;

    final listed = json['assets'];
    if (listed is! List || listed.isEmpty) return null;

    final assets = <GeoAsset>[];
    for (final entry in listed) {
      final asset = GeoAsset.tryFromJson(entry);
      // One bad entry invalidates the manifest rather than being skipped.
      // Skipping would leave a family silently missing, and a globe that
      // places IPv4 and nothing else looks like a data problem for months.
      if (asset == null) return null;
      assets.add(asset);
    }
    final families = assets.map((a) => a.family).toSet();
    if (families.length != assets.length ||
        !families.contains(4) ||
        !families.contains(6)) {
      return null;
    }

    return GeoManifest._(
      version: _supportedVersion,
      generated: generated,
      attribution: attribution as String? ?? '',
      assets: assets,
    );
  }

  Map<String, Object?> toJson() => {
    'version': version,
    'generated': generated,
    'attribution': attribution,
    'assets': [for (final a in assets) a.toJson()],
  };
}

/// One published file.
final class GeoAsset {
  const GeoAsset._({
    required this.name,
    required this.family,
    required this.bytes,
    required this.unpackedBytes,
    required this.sha256,
  });

  /// The filename at the endpoint, and on disk once unpacked (without `.gz`).
  ///
  /// **This is the security check in this file.** It is concatenated into a
  /// URL and into a path under the app's own directory, and that path is
  /// written to and deleted. A name of `../../Library/Preferences/x` would put
  /// both outside the directory entirely — so it is an allow-list rather than
  /// a search for `..`, which has too many spellings to enumerate.
  final String name;

  /// 4 or 6. Checked against the bundle's own header once the file is here.
  final int family;

  final int bytes;
  final int unpackedBytes;

  /// Of the *packed* file, so it is checkable the moment the download ends and
  /// before anything is unpacked.
  final String sha256;

  /// The file this becomes on disk: the same name without `.gz`.
  String get unpackedName =>
      name.endsWith('.gz') ? name.substring(0, name.length - 3) : name;

  static final _safeName = RegExp(r'^[A-Za-z0-9][A-Za-z0-9._-]{0,63}$');
  static final _digest = RegExp(r'^[0-9a-f]{64}$');

  static GeoAsset? tryFromJson(Object? json) {
    if (json is! Map) return null;
    final name = json['name'];
    final family = json['family'];
    final bytes = json['bytes'];
    final unpacked = json['unpackedBytes'];
    final sha = json['sha256'];
    if (name is! String || !_safeName.hasMatch(name)) return null;
    if (name.contains('..')) return null;
    if (family is! int || (family != 4 && family != 6)) return null;
    if (bytes is! int || bytes <= 0) return null;
    if (unpacked is! int || unpacked <= 0) return null;
    if (sha is! String || !_digest.hasMatch(sha)) return null;
    // Bounds rather than trust. These come off the network and decide how much
    // is read into memory and written to disk; a manifest claiming a gigabyte
    // is one this app should refuse rather than obey.
    if (bytes > 64 * 1024 * 1024 || unpacked > 256 * 1024 * 1024) return null;
    return GeoAsset._(
      name: name,
      family: family,
      bytes: bytes,
      unpackedBytes: unpacked,
      sha256: sha,
    );
  }

  Map<String, Object?> toJson() => {
    'name': name,
    'family': family,
    'bytes': bytes,
    'unpackedBytes': unpackedBytes,
    'sha256': sha256,
  };
}
