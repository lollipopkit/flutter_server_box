/// A plugin repository, and what installing from one is allowed to believe.
///
/// **A repository is a git repository of TOML files, read by fetching its tree
/// — shaped after a Homebrew tap.** One file per plugin under two directory
/// levels taken from its id, the packages beside them, and no release to attach
/// anything to. What the app fetches is one tarball of the latest tree, so a
/// repository that carries its own packages hands over everything it offers in
/// a single request.
///
/// ```
/// repo.toml                                     schema, name
/// plugins/app/serverbox/diskusage.toml          one file per plugin
/// packages/app.serverbox.diskusage-1.0.0.sbp    the package it names
/// ```
///
/// **What a digest buys here is worth being exact about.** There are no
/// signatures. Each version names the SHA-256 of its package and the app
/// verifies the bytes against it. For a package inside the repository that is a
/// consistency check rather than a trust boundary — the file and the digest
/// arrive in the same tarball, so whoever can change one can change the other.
/// It is load-bearing in the other case: a version whose package is served from
/// somewhere else, where the digest is the only thing binding that address to
/// these bytes. Either way:
///
/// - a mirror or a CDN between the repository and a package can be swapped and
///   the change is caught, because it did not write the file;
/// - whoever controls the **repository** controls what runs, because they
///   choose both the address and the digest. TLS and the repository's operator
///   are the trust anchor, and nothing here is a substitute for either.
///
/// A version with no digest is therefore not an inconvenience to route around:
/// it is the case where none of the above holds. It can still be installed — a
/// private repository served over a tunnel is a real thing — but only after the
/// user has been told, and never by default.
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:fl_lib/fl_lib.dart';
import 'package:toml/toml.dart';

/// Where a plugin's file lives, and which plugin a path is for.
///
/// **Two directory levels, taken from the id.** An id is reverse-DNS, so its
/// first two parts are the publisher and the rest is the plugin:
/// `app.serverbox.diskusage` is `plugins/app/serverbox/diskusage.toml`. That
/// shards a growing repository the way Homebrew's `Formula/a/…` does while
/// keeping one publisher's plugins together, which a first-letter shard would
/// not.
///
/// Derived rather than declared, and checked against the `id` inside the file:
/// a file whose path and id disagree is one copied into the wrong folder, and
/// without the check the app would offer something the repository does not
/// think it is serving.
abstract final class PluginRepoLayout {
  static const dir = 'plugins/';
  static const packagesDir = 'packages/';

  /// The file [id] belongs in, or null when it cannot have one.
  static String? pathOf(String id) {
    final parts = id.split('.');
    if (parts.length < 3) return null;
    if (parts.any((p) => p.isEmpty || !_segment.hasMatch(p))) return null;
    return '$dir${parts[0]}/${parts[1]}/${parts.skip(2).join('.')}.toml';
  }

  /// The id a file at [path] must declare, or null if that is not one.
  static String? idOf(String path) {
    final match = _layout.firstMatch(path);
    if (match == null) return null;
    return '${match.group(1)}.${match.group(2)}.${match.group(3)}';
  }

  static final _layout = RegExp('^$dir([^/]+)/([^/]+)/(.+)\\.toml\$');
  static final _segment = RegExp(r'^[A-Za-z0-9_-]+$');
}

/// One version of one plugin, as a repository lists it.
class PluginRelease {
  const PluginRelease({
    required this.version,
    required this.abi,
    this.url,
    this.path,
    this.sha256,
    this.size,
    this.notes,
  });

  final String version;

  /// The host ABI this build needs. Compared against the app's own, which is
  /// what lets one repository serve apps of different ages.
  final int abi;

  /// Where the `.sbp` is, for a package served from outside the repository.
  /// Exactly one of this and [path].
  final String? url;

  /// Where the `.sbp` is *inside* the repository. The common case, and the one
  /// that costs no second request: the tarball already carried it.
  final String? path;

  /// SHA-256 of the package, lowercase hex. Null is a repository that did not
  /// say — see the library comment; it is not a detail.
  final String? sha256;

  /// For showing what an install will cost before it starts.
  final int? size;

  /// What changed, if the repository says.
  final String? notes;

  bool get verifiable => (sha256 ?? '').length == 64;

  /// Reads one `[[version]]` table, or null when it is not usable.
  ///
  /// Null rather than throwing: one unreadable version costs that version,
  /// where a throw would cost the plugin — and a repository serving five
  /// versions of something should not become unusable because the sixth is
  /// malformed.
  static PluginRelease? fromToml(Object? raw) {
    if (raw is! Map) return null;
    final version = raw['version'];
    final abi = raw['abi'];
    if (version is! String || version.isEmpty) return null;
    if (abi is! int) return null;

    final url = raw['url'];
    final path = raw['path'];
    final hasUrl = url is String && url.isNotEmpty;
    final hasPath = path is String && path.isNotEmpty;
    // Exactly one. Both would leave the reader choosing, and the two can
    // disagree about which bytes this version is.
    if (hasUrl == hasPath) return null;
    // A path that climbs out of the repository, which is the archive attack in
    // its other clothes: the entry it would name is not one the tarball put
    // there.
    if (hasPath && (path.startsWith('/') || path.split('/').contains('..'))) {
      return null;
    }

    final digest = raw['sha256'];
    return PluginRelease(
      version: version,
      abi: abi,
      url: hasUrl ? url : null,
      path: hasPath ? path : null,
      sha256: digest is String && digest.isNotEmpty ? digest.toLowerCase() : null,
      size: raw['size'] is int ? raw['size'] as int : null,
      notes: raw['notes'] is String ? raw['notes'] as String : null,
    );
  }
}

/// One plugin in a repository, with every version it offers.
class PluginListing {
  const PluginListing({
    required this.id,
    required this.name,
    required this.description,
    required this.releases,
    this.homepage,
    this.license,
  });

  final String id;
  final String name;
  final String description;
  final String? homepage;
  final String? license;

  /// The order the file gave is not trusted — see [PluginVersion.compare].
  final List<PluginRelease> releases;

  /// The newest release this app can actually run.
  ///
  /// **Selected by ABI, not by taking the top of the list.** A repository
  /// serves apps of different ages at once, and the newest build of a plugin is
  /// routinely one an older app would refuse. Picking here is what PLUGINS.md
  /// means by "a repository keeps several versions so an older app still finds
  /// one it can run" — without it the older app sees the plugin, tries, and is
  /// told no by the manifest parser after the download.
  PluginRelease? bestFor(int abi) {
    PluginRelease? best;
    for (final release in releases) {
      if (release.abi > abi) continue;
      if (best == null ||
          PluginVersion.compare(release.version, best.version) > 0) {
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

  /// Parses one plugin's file, or throws [PluginRepoError].
  ///
  /// [path] is where it was found, and it is checked: a file declaring an id
  /// its path does not agree with is refused.
  static PluginListing parse(String text, String path) {
    final Map<String, dynamic> raw;
    try {
      raw = TomlDocument.parse(text).toMap();
    } catch (e) {
      throw PluginRepoError('$path is not readable TOML: $e');
    }

    final id = raw['id'];
    if (id is! String || id.isEmpty) throw PluginRepoError('$path names no id');
    final expected = PluginRepoLayout.idOf(path);
    if (expected != null && expected != id) {
      throw PluginRepoError(
        '$path says it is $id, and its path says $expected',
      );
    }

    final releases = <PluginRelease>[
      for (final v in (raw['version'] as List? ?? const []))
        ?PluginRelease.fromToml(v),
    ];
    // A listing with nothing installable is not a listing.
    if (releases.isEmpty) {
      throw PluginRepoError('$path offers no readable version');
    }

    return PluginListing(
      id: id,
      name: raw['name'] is String ? raw['name'] as String : id,
      description: raw['description'] is String
          ? raw['description'] as String
          : '',
      homepage: raw['homepage'] is String ? raw['homepage'] as String : null,
      license: raw['license'] is String ? raw['license'] as String : null,
      releases: releases,
    );
  }
}

/// A repository's tree, read.
///
/// Named an index because that is what it is for, and because everything above
/// it asks "what does this repository offer". What it holds is one file's worth
/// of answer per plugin, plus the packages the tree carried.
class PluginIndex {
  const PluginIndex({
    required this.plugins,
    this.name,
    this.packages = const {},
  });

  final List<PluginListing> plugins;

  /// What the repository calls itself, for the list of repositories.
  final String? name;

  /// The `.sbp` files the tree carried, by repository path.
  ///
  /// Kept in memory on purpose: the fetch already brought them, they are tens
  /// of kilobytes each, and the alternative is asking for the same bytes a
  /// second time over the same connection. Bounded by the caps in
  /// [PluginRepoSource] — an archive this app will not read is refused before
  /// anything here sees it.
  final Map<String, Uint8List> packages;

  /// The schema this build reads. A repository announcing a higher one is
  /// refused rather than half-read: the fields this build does not know about
  /// might be the ones that decide something.
  static const schema = 1;

  static const repoFile = 'repo.toml';

  /// Reads a repository's files, or throws [PluginRepoError].
  ///
  /// One bad plugin file costs that plugin; a bad [repoFile] costs the
  /// repository. The difference is that a file this build cannot read is a
  /// plugin it cannot offer, while a repository it cannot identify is one it
  /// cannot describe at all.
  static PluginIndex fromFiles(Map<String, Uint8List> files) {
    final repo = files[repoFile];
    if (repo == null) {
      throw const PluginRepoError(
        'no repo.toml, so this is not a plugin repository',
      );
    }

    final Map<String, dynamic> raw;
    try {
      raw = TomlDocument.parse(utf8.decode(repo)).toMap();
    } catch (e) {
      throw PluginRepoError('repo.toml is not readable TOML: $e');
    }
    final announced = raw['schema'];
    if (announced is! int) {
      throw const PluginRepoError('repo.toml names no schema version');
    }
    if (announced > schema) {
      throw PluginRepoError(
        'this repository is schema v$announced and this app reads v$schema',
      );
    }

    final plugins = <PluginListing>[];
    for (final path in files.keys.toList()..sort()) {
      if (PluginRepoLayout.idOf(path) == null) continue;
      try {
        plugins.add(PluginListing.parse(utf8.decode(files[path]!), path));
      } catch (e) {
        Loggers.app.warning('Reading the plugin file $path', e);
      }
    }

    return PluginIndex(
      plugins: plugins,
      name: raw['name'] is String ? raw['name'] as String : null,
      packages: {
        for (final e in files.entries)
          if (e.key.startsWith(PluginRepoLayout.packagesDir)) e.key: e.value,
      },
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
      final d =
          (left.length > i ? left[i] : 0) - (right.length > i ? right[i] : 0);
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
    for (final p in v.split('-').first.split('.')) int.tryParse(p.trim()) ?? 0,
  ];

  static String _suffix(String v) {
    final at = v.indexOf('-');
    return at < 0 ? '' : v.substring(at + 1);
  }
}

/// Whether bytes are the ones a repository named.
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
