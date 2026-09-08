/// A plugin repository, and what installing from one is allowed to believe.
///
/// **The digest is the whole of the integrity story, and it is worth being
/// exact about what it buys.** There are no signatures here. The index is
/// fetched over HTTPS and names, for each version, the SHA-256 of the package;
/// downloading then verifies the bytes against that. So:
///
/// - a mirror, a CDN or anything between the index and the package can be
///   swapped and the change is caught, because it did not write the index;
/// - whoever controls the **index** controls what runs, because they choose
///   both the URL and the digest. TLS and the repository's own operator are the
///   trust anchor, and nothing here is a substitute for either.
///
/// A version with no digest is therefore not an inconvenience to route around:
/// it is the case where none of the above holds. It can still be installed —
/// a private repository serving over a tunnel is a real thing — but only after
/// the user has been told, and never by default.
library;

import 'dart:convert';

import 'package:crypto/crypto.dart';

/// One version of one plugin, as an index lists it.
class PluginRelease {
  const PluginRelease({
    required this.version,
    required this.abi,
    required this.url,
    this.sha256,
    this.size,
    this.notes,
  });

  final String version;

  /// The host ABI this build needs. Compared against the app's own, which is
  /// what lets one index serve apps of different ages.
  final int abi;

  /// Where the `.sbp` is.
  final String url;

  /// SHA-256 of the package, lowercase hex. Null is a repository that did not
  /// say — see the library comment; it is not a detail.
  final String? sha256;

  /// For showing what a download will cost before it starts.
  final int? size;

  /// What changed, if the repository says.
  final String? notes;

  bool get verifiable => (sha256 ?? '').length == 64;

  static PluginRelease? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final version = raw['version'];
    final url = raw['url'];
    final abi = raw['abi'];
    if (version is! String || version.isEmpty) return null;
    if (url is! String || url.isEmpty) return null;
    if (abi is! int) return null;
    final digest = raw['sha256'];
    return PluginRelease(
      version: version,
      abi: abi,
      url: url,
      sha256: digest is String && digest.isNotEmpty
          ? digest.toLowerCase()
          : null,
      size: raw['size'] is int ? raw['size'] as int : null,
      notes: raw['notes'] is String ? raw['notes'] as String : null,
    );
  }
}

/// One plugin in an index, with every version it offers.
class PluginListing {
  const PluginListing({
    required this.id,
    required this.name,
    required this.description,
    required this.releases,
    this.homepage,
  });

  final String id;
  final String name;
  final String description;
  final String? homepage;

  /// Newest first. The order the index gave is not trusted — see
  /// [PluginVersion.compare].
  final List<PluginRelease> releases;

  /// The newest release this app can actually run.
  ///
  /// **Selected by ABI, not by taking the top of the list.** An index serves
  /// apps of different ages at once, and the newest build of a plugin is
  /// routinely one an older app would refuse. Picking here is what PLUGINS.md
  /// means by "the index keeps several versions so an older app still finds one
  /// it can run" — without it the older app sees the plugin, tries, and is told
  /// no by the manifest parser after the download.
  PluginRelease? bestFor(int abi) {
    PluginRelease? best;
    for (final release in releases) {
      if (release.abi > abi) continue;
      if (best == null || PluginVersion.compare(release.version, best.version) > 0) {
        best = release;
      }
    }
    return best;
  }

  /// Every release this app could not run, newest first — so a listing can say
  /// "there is a newer one, and this app is too old for it" rather than
  /// silently offering an old version.
  List<PluginRelease> tooNewFor(int abi) =>
      [for (final r in releases) if (r.abi > abi) r]
        ..sort((a, b) => PluginVersion.compare(b.version, a.version));

  static PluginListing? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final id = raw['id'];
    if (id is! String || id.isEmpty) return null;
    final releases = <PluginRelease>[
      for (final v in (raw['versions'] as List? ?? const []))
        ?PluginRelease.fromJson(v),
    ];
    // A listing with nothing installable is not a listing. Dropped rather than
    // shown as an entry that cannot be acted on.
    if (releases.isEmpty) return null;
    return PluginListing(
      id: id,
      name: raw['name'] is String ? raw['name'] as String : id,
      description: raw['description'] is String
          ? raw['description'] as String
          : '',
      homepage: raw['homepage'] is String ? raw['homepage'] as String : null,
      releases: releases,
    );
  }
}

/// What a repository's `index.json` says.
class PluginIndex {
  const PluginIndex({required this.plugins});

  final List<PluginListing> plugins;

  /// The schema this build reads. An index announcing a higher one is refused
  /// rather than half-read: the fields this build does not know about might be
  /// the ones that decide something.
  static const schema = 1;

  /// Parses [text], or throws [PluginRepoError].
  ///
  /// One bad listing costs that listing. One bad *index* costs the repository:
  /// the difference is that a listing this build cannot read is a plugin it
  /// cannot offer, while an index it cannot read is a repository it cannot
  /// describe at all.
  static PluginIndex parse(String text) {
    final Object? raw;
    try {
      raw = jsonDecode(text);
    } catch (e) {
      throw const PluginRepoError('the index is not JSON');
    }
    if (raw is! Map) throw const PluginRepoError('the index is not an object');

    final announced = raw['schema'];
    if (announced is! int) {
      throw const PluginRepoError('the index names no schema version');
    }
    if (announced > schema) {
      throw PluginRepoError(
        'the index is schema v$announced and this app reads v$schema',
      );
    }

    return PluginIndex(
      plugins: [
        for (final p in (raw['plugins'] as List? ?? const []))
          ?PluginListing.fromJson(p),
      ],
    );
  }
}

/// Comparing `1.10.0` against `1.9.0`.
///
/// Field by field and numerically, because a string comparison puts `1.10`
/// before `1.9` — which would pin every install to whichever version happens to
/// sort last.
abstract final class PluginVersion {
  static int compare(String a, String b) {
    final left = _parts(a);
    final right = _parts(b);
    for (var i = 0; i < 3; i++) {
      final d = (left.length > i ? left[i] : 0) - (right.length > i ? right[i] : 0);
      if (d != 0) return d < 0 ? -1 : 1;
    }
    // Same numbers. A build with a suffix (`1.0.0-beta`) sorts *below* the one
    // without, which is what a pre-release is.
    final sa = _suffix(a);
    final sb = _suffix(b);
    if (sa.isEmpty && sb.isEmpty) return 0;
    if (sa.isEmpty) return 1;
    if (sb.isEmpty) return -1;
    return sa.compareTo(sb);
  }

  static List<int> _parts(String v) => [
    for (final p in v.split('-').first.split('.'))
      int.tryParse(p.trim()) ?? 0,
  ];

  static String _suffix(String v) {
    final at = v.indexOf('-');
    return at < 0 ? '' : v.substring(at + 1);
  }
}

/// Whether downloaded bytes are the ones the index named.
abstract final class PluginDigest {
  /// Lowercase hex SHA-256.
  static String of(List<int> bytes) => sha256.convert(bytes).toString();

  /// Compared without an early exit.
  ///
  /// A digest is public and guards no secret, so this protects nothing on its
  /// own — it costs nothing and keeps the habit where the subject is whether to
  /// trust something.
  static bool matches(String expected, List<int> bytes) {
    final actual = of(bytes);
    final want = expected.toLowerCase();
    if (want.length != actual.length) return false;
    var diff = 0;
    for (var i = 0; i < actual.length; i++) {
      diff |= actual.codeUnitAt(i) ^ want.codeUnitAt(i);
    }
    return diff == 0;
  }
}

class PluginRepoError implements Exception {
  const PluginRepoError(this.message);
  final String message;

  @override
  String toString() => message;
}
