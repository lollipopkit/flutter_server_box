/// The catalog of theme repositories, and one repository's own index.
///
/// **Two levels, and only the second carries versions.**
///
/// The catalog is a TOML file in this app's own repository, and this build
/// ships a copy of it as the floor for a first run with no network. It lists
/// repositories, one line each, and names no theme and no version: a theme
/// author publishes by releasing in their own repository and opening a pull
/// request that adds a line here.
///
/// A repository is a git repository of TOML files, read by fetching its tree —
/// `repo.toml` for the schema, then one file per theme under `themes/`. That is
/// the shape the plugin repository uses, deliberately: **one repository can
/// serve both kinds**, and what it offers is whatever its tree holds. This
/// build reads `themes/`; a `plugins/` section beside it is skipped rather than
/// refused, because a section this build does not know is not a reason to throw
/// away one it does.
///
/// A version is a release of the repository that lists it, one tag per theme
/// per version, so a version is withdrawn by deleting one release and a
/// repository can keep several so an older app still finds one it can run.
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter/services.dart' show AssetBundle, rootBundle;
import 'package:server_box/core/service/theme_package.dart';
import 'package:toml/toml.dart';

/// Where a theme's file lives, and which theme a path is for.
///
/// **The path is the id**, and it is the same id the package inside carries —
/// [ThemePackages.idPattern], which is why `themes/serverbox.aurora.toml`
/// describes the theme whose manifest says `id = "serverbox.aurora"`. Two
/// repositories may offer a theme by the same id, which costs nothing — what is
/// installed is content-addressed, so they are two packages and not one
/// shadowing the other.
///
/// Derived rather than declared, and checked against the `id` inside the file:
/// a file whose path and id disagree is one copied into the wrong folder.
abstract final class ThemeRepoLayout {
  static const dir = 'themes/';

  /// Where a `.fsbt` carried inside the repository lives. Shared with the
  /// plugin layout on purpose — a repository offering both keeps one place for
  /// the packages its files name.
  static const packagesDir = 'packages/';

  static String? pathOf(String id) =>
      ThemePackages.idPattern.hasMatch(id) ? '$dir$id.toml' : null;

  static String? idOf(String path) => _file.firstMatch(path)?.group(1);

  static final _file = RegExp(
    '^$dir([a-z0-9][a-z0-9._-]{0,63})\\.toml\$',
  );
}

/// One repository the catalog lists.
final class ThemeRepoRef {
  const ThemeRepoRef(this.url);

  /// The repository itself, not an archive of it — see
  /// [ThemeRepos.archiveUrlOf], which is where an address becomes a fetch.
  final Uri url;

  /// What to call it before it has answered, and often after: its own
  /// `repo.toml` name wins where there is one.
  ///
  /// `owner/repo`, not the host: nearly every repository is on github.com, so
  /// the host is the part of an address that tells two of them apart least.
  String get label {
    final segments = [
      for (final s in url.pathSegments)
        if (s.isNotEmpty) s.replaceFirst(RegExp(r'\.git$'), ''),
    ];
    if (segments.isEmpty) return url.host;
    if (segments.length == 1) return '${url.host}/${segments.single}';
    return '${segments[segments.length - 2]}/${segments.last}';
  }

  @override
  bool operator ==(Object other) => other is ThemeRepoRef && other.url == url;

  @override
  int get hashCode => url.hashCode;
}

/// The catalog itself: which repositories this app offers.
final class ThemeRepoCatalog {
  const ThemeRepoCatalog({this.name, this.repos = const []});

  /// What the catalog calls itself, for the store's title.
  final String? name;

  final List<ThemeRepoRef> repos;

  /// The schema this build reads. A catalog announcing a higher one is refused
  /// rather than half-read: the fields this build does not know about might be
  /// the ones that decide something.
  static const schema = 1;

  static const maxRepos = 100;

  /// The copy compiled in, used when the catalog's own address does not answer.
  ///
  /// A floor rather than a cache: it is the list this build shipped with, so a
  /// first run with no network offers the official repositories instead of an
  /// empty store.
  static const bundledAsset = 'assets/catalog/repos.toml';

  static Future<ThemeRepoCatalog> bundled({AssetBundle? bundle}) async {
    final data = await (bundle ?? rootBundle).load(bundledAsset);
    return parse(
      data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
    );
  }

  /// Reads a catalog, or throws [ThemeRepoError].
  ///
  /// [base] resolves a relative `url`, which is what a catalog listing a
  /// repository beside itself would write.
  static ThemeRepoCatalog parse(List<int> bytes, {Uri? base}) {
    if (bytes.length > ThemeRepos.maxCatalogBytes) {
      throw const ThemeRepoError('the catalog is larger than this app reads');
    }
    final Map<String, dynamic> raw;
    try {
      raw = TomlDocument.parse(utf8.decode(bytes)).toMap();
    } catch (e) {
      throw ThemeRepoError('the catalog is not readable TOML: $e');
    }

    final announced = raw['schema'];
    if (announced is! int) {
      throw const ThemeRepoError('the catalog names no schema version');
    }
    if (announced > schema) {
      throw ThemeRepoError(
        'this catalog is schema v$announced and this app reads v$schema',
      );
    }

    final rows = raw['repo'];
    if (rows is! List || rows.length > maxRepos) {
      throw const ThemeRepoError('the catalog lists no readable repository');
    }

    final repos = <ThemeRepoRef>[];
    for (final row in rows) {
      if (row is! Map) throw const ThemeRepoError('Invalid catalog entry');
      final url = row['url'];
      if (url is! String || url.trim().isEmpty) {
        throw const ThemeRepoError('a catalog entry names no url');
      }
      final Uri resolved;
      try {
        resolved = ThemePackages.httpsUri(
          (base ?? Uri()).resolve(url.trim()).toString(),
        );
      } on FormatException catch (e) {
        throw ThemeRepoError('${e.message}: $url');
      }
      final ref = ThemeRepoRef(resolved);
      // Listed twice is harmless and reading it twice is not free.
      if (!repos.contains(ref)) repos.add(ref);
    }

    return ThemeRepoCatalog(
      name: raw['name'] is String ? raw['name'] as String : null,
      repos: repos,
    );
  }
}

/// One version of one theme, as a repository lists it.
final class ThemeRelease {
  const ThemeRelease({
    required this.version,
    required this.schemaMin,
    required this.schemaMax,
    this.url,
    this.path,
    this.sha256,
    this.size,
    this.notes,
  });

  final String version;

  /// The manifest schema this build of the theme carries, compared against the
  /// app's own — the same negotiation a package makes at install time, done
  /// here so a version the app cannot read is not the one it downloads.
  final int schemaMin;
  final int schemaMax;

  /// Where the `.fsbt` is, for a package served as a release. Exactly one of
  /// this and [path].
  final String? url;

  /// Where the `.fsbt` is *inside* the repository, which costs no second
  /// request because the tree fetch already brought it.
  final String? path;

  /// SHA-256 of the package, lowercase hex. Null is a repository that did not
  /// say, and an install without one is refused — see [ThemeRepos.install].
  final String? sha256;

  /// For showing what an install will cost before it starts.
  final int? size;

  /// What changed, if the repository says.
  final String? notes;

  bool get verifiable => (sha256 ?? '').length == 64;

  /// Whether this app can read the manifest inside it.
  bool runsOn(int min, int max) => schemaMax >= min && schemaMin <= max;

  /// Reads one `[[version]]` table, or null when it is not usable.
  ///
  /// Null rather than throwing: one unreadable version costs that version,
  /// where a throw would cost the whole theme.
  static ThemeRelease? fromToml(Object? raw) {
    if (raw is! Map) return null;
    final version = raw['version'];
    if (version is! String || version.trim().isEmpty) return null;
    final min = raw['schema_min'];
    final max = raw['schema_max'];
    if (min is! int || max is! int || min > max) return null;

    final url = raw['url'];
    final path = raw['path'];
    final hasUrl = url is String && url.isNotEmpty;
    final hasPath = path is String && path.isNotEmpty;
    // Exactly one. Both would leave the reader choosing, and the two can
    // disagree about which bytes this version is.
    if (hasUrl == hasPath) return null;
    // A path that climbs out of the repository, which is the archive attack in
    // its other clothes: the entry it would name is not one the tree put there.
    if (hasPath && (path.startsWith('/') || path.split('/').contains('..'))) {
      return null;
    }

    final digest = raw['sha256'];
    return ThemeRelease(
      version: version.trim(),
      schemaMin: min,
      schemaMax: max,
      url: hasUrl ? url : null,
      path: hasPath ? path : null,
      sha256: digest is String && digest.isNotEmpty
          ? digest.toLowerCase()
          : null,
      size: raw['size'] is int ? raw['size'] as int : null,
      notes: raw['notes'] is String ? raw['notes'] as String : null,
    );
  }
}

/// One theme in a repository, with every version it offers.
final class ThemeListing {
  const ThemeListing({
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

  /// The order the file gave is not trusted — see [ThemeVersion.compare].
  final List<ThemeRelease> releases;

  /// The newest version this app can run.
  ///
  /// **Selected by schema, not by taking the top of the list.** A repository
  /// serves apps of different ages at once, and the newest build of a theme is
  /// routinely one an older app would refuse.
  ThemeRelease? bestFor(int min, int max) {
    ThemeRelease? best;
    for (final release in releases) {
      if (!release.runsOn(min, max)) continue;
      if (best == null || ThemeVersion.compare(release.version, best.version) > 0) {
        best = release;
      }
    }
    return best;
  }

  /// Everything this app is too old for, newest first — so the store can say
  /// "there is a newer one and this build cannot read it" rather than falling
  /// silent about a theme it was told about.
  List<ThemeRelease> tooNewFor(int max) =>
      [for (final r in releases) if (r.schemaMin > max) r]
        ..sort((a, b) => ThemeVersion.compare(b.version, a.version));

  /// Parses one theme's file, or throws [ThemeRepoError].
  ///
  /// [path] is where it was found, and it is checked: a file declaring an id
  /// its path does not agree with is refused.
  static ThemeListing parse(String text, String path) {
    final Map<String, dynamic> raw;
    try {
      raw = TomlDocument.parse(text).toMap();
    } catch (e) {
      throw ThemeRepoError('$path is not readable TOML: $e');
    }

    final id = raw['id'];
    if (id is! String || id.isEmpty) throw ThemeRepoError('$path names no id');
    final expected = ThemeRepoLayout.idOf(path);
    if (expected != null && expected != id) {
      throw ThemeRepoError('$path says it is $id, and its path says $expected');
    }

    final releases = <ThemeRelease>[
      for (final v in (raw['version'] as List? ?? const []))
        ?ThemeRelease.fromToml(v),
    ];
    // A listing with nothing installable is not a listing.
    if (releases.isEmpty) {
      throw ThemeRepoError('$path offers no readable version');
    }

    return ThemeListing(
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

/// One repository's tree, read.
final class ThemeRepoIndex {
  const ThemeRepoIndex({
    required this.themes,
    this.name,
    this.packages = const {},
  });

  final List<ThemeListing> themes;

  /// What the repository calls itself, for the list of repositories.
  final String? name;

  /// The `.fsbt` files the tree carried, by repository path. Kept in memory on
  /// purpose: the fetch already brought them, and the alternative is asking for
  /// the same bytes a second time.
  final Map<String, Uint8List> packages;

  static const repoFile = 'repo.toml';

  /// Reads a repository's files, or throws [ThemeRepoError].
  ///
  /// One bad theme file costs that theme; a bad [repoFile] costs the
  /// repository, because a file this build cannot read is a theme it cannot
  /// offer while a repository it cannot identify is one it cannot describe.
  ///
  /// A section that is not `themes/` is skipped, not refused: the same tree may
  /// carry a `plugins/` section this build has no business reading.
  static ThemeRepoIndex fromFiles(Map<String, Uint8List> files) {
    final repo = files[repoFile];
    if (repo == null) {
      throw const ThemeRepoError('no repo.toml, so this is not a repository');
    }

    final Map<String, dynamic> raw;
    try {
      raw = TomlDocument.parse(utf8.decode(repo)).toMap();
    } catch (e) {
      throw ThemeRepoError('repo.toml is not readable TOML: $e');
    }
    final announced = raw['schema'];
    if (announced is! int) {
      throw const ThemeRepoError('repo.toml names no schema version');
    }
    if (announced > ThemeRepoCatalog.schema) {
      throw ThemeRepoError(
        'this repository is schema v$announced and this app reads '
        'v${ThemeRepoCatalog.schema}',
      );
    }

    final themes = <ThemeListing>[];
    for (final path in files.keys.toList()..sort()) {
      if (ThemeRepoLayout.idOf(path) == null) continue;
      try {
        themes.add(ThemeListing.parse(utf8.decode(files[path]!), path));
      } catch (e) {
        Loggers.app.warning('Reading the theme file $path', e);
      }
    }

    return ThemeRepoIndex(
      themes: themes,
      name: raw['name'] is String ? raw['name'] as String : null,
      packages: {
        for (final e in files.entries)
          if (e.key.startsWith(ThemeRepoLayout.packagesDir)) e.key: e.value,
      },
    );
  }
}

/// One theme the store can offer, and where it comes from.
final class ThemeStoreItem {
  const ThemeStoreItem({
    required this.repo,
    required this.index,
    required this.listing,
    this.release,
  });

  /// What the repository is called, which the store shows beside the theme: an
  /// official list and a third party's repository are not the same offer.
  final String repo;

  final ThemeRepoIndex index;
  final ThemeListing listing;

  /// The version to install. Null means this app cannot read any of the ones on
  /// offer — see [ThemeListing.tooNewFor].
  final ThemeRelease? release;

  bool get installable => release != null;

  String get label => listing.name;

  /// The newest version the repository offers, installable or not: what a row
  /// says when it cannot be installed.
  String? get newestVersion => listing.releases.isEmpty
      ? null
      : listing.releases
            .map((r) => r.version)
            .reduce((a, b) => ThemeVersion.compare(a, b) >= 0 ? a : b);
}

/// What the catalog and its repositories answered.
final class ThemeStore {
  const ThemeStore({this.items = const [], this.repos = const []});

  final List<ThemeStoreItem> items;

  /// Every repository that answered, by label, whether or not it offered a
  /// theme this app can read.
  final List<String> repos;
}

/// Fetching the catalog and its repositories, and installing from one.
abstract final class ThemeRepos {
  /// How much of a catalog or a repository this app will read.
  ///
  /// A repository is not trusted to be small — it is a tarball somebody else
  /// wrote. The compressed cap bounds what reaches memory and the uncompressed
  /// one bounds what a small archive can claim to be.
  static const maxCatalogBytes = 1024 * 1024;
  static const maxArchiveBytes = 16 * 1024 * 1024;
  static const maxUnpackedBytes = 64 * 1024 * 1024;
  static const maxEntryBytes = 8 * 1024 * 1024;

  /// The tarball an address is fetched from.
  ///
  /// `<repo>/archive/HEAD.tar.gz` resolves the default branch server-side, and
  /// `HEAD` rather than a branch name because which branch a repository calls
  /// default is not this app's to guess. An address that already names an
  /// archive is taken as it is, so a repository served from anywhere can be
  /// used by pointing straight at it.
  static String archiveUrlOf(String address) {
    final trimmed = address.trim();
    if (RegExp(r'\.(tar\.gz|tgz)$', caseSensitive: false).hasMatch(trimmed)) {
      return trimmed;
    }
    final base = trimmed
        .replaceAll(RegExp(r'/+$'), '')
        .replaceAll(RegExp(r'\.git$', caseSensitive: false), '');
    return '$base/archive/HEAD.tar.gz';
  }

  /// Unpacks a repository's tree into its files, by path.
  ///
  /// Reads what the hosts a repository address resolves to actually emit —
  /// GitHub's archive endpoint, `git archive`, GitLab — which is ustar with the
  /// `prefix` field, GNU long names, and pax headers. A tarball macOS `tar`
  /// writes is not among them: it puts a binary `SCHILY.xattr` value in a pax
  /// record, and the decoder this runs on reads those as UTF-8, so one such
  /// record costs the whole tree. The plugin repository's reader drew the same
  /// line for the same reason, and the difference is that it was written to
  /// refuse what it does not know rather than guess.
  ///
  /// Separate and static so a test can hand it bytes: everything interesting
  /// about this is what it refuses.
  @visibleForTesting
  static Map<String, Uint8List> readArchive(List<int> bytes) {
    final Archive archive;
    try {
      archive = TarDecoder().decodeBytes(GZipDecoder().decodeBytes(bytes));
    } catch (e) {
      throw ThemeRepoError('the repository is not a readable .tar.gz: $e');
    }

    final files = <String, Uint8List>{};
    var total = 0;
    for (final file in archive) {
      if (!file.isFile) continue;
      final name = _safeName(file.name);
      // A name that escapes the tree, the classic archive attack. It matters
      // even though nothing here unpacks to disk: a path with `..` in it could
      // name a theme file position it has no right to.
      if (name == null) {
        throw ThemeRepoError('unsafe path in the repository: ${file.name}');
      }
      if (file.size > maxEntryBytes) {
        throw ThemeRepoError('$name is larger than $maxEntryBytes bytes');
      }
      total += file.size;
      if (total > maxUnpackedBytes) {
        throw const ThemeRepoError('the repository unpacks to too much');
      }
      files[name] = file.content;
    }

    return _stripTopDirectory(files);
  }

  /// Reads the repository at [address].
  ///
  /// Plain HTTP is refused: a repository decides which bytes get installed, so
  /// a plaintext one is a package chosen by whoever is on the path.
  static Future<ThemeRepoIndex> index(String address) async {
    final bytes = await ThemePackages.download(
      archiveUrlOf(address),
      maxBytes: maxArchiveBytes,
    );
    return ThemeRepoIndex.fromFiles(readArchive(bytes));
  }

  /// Reads the catalog and every repository it lists.
  ///
  /// A repository that does not answer costs its own themes and nothing else,
  /// which is why each one is caught here rather than failing the store: a
  /// catalog is a list of other people's addresses, and the shakiest of them
  /// should not be what decides whether the rest are reachable.
  static Future<ThemeStore> store(String catalogUrl, {AssetBundle? bundle}) async {
    ThemeRepoCatalog catalog;
    try {
      catalog = ThemeRepoCatalog.parse(
        await ThemePackages.download(
          catalogUrl,
          maxBytes: maxCatalogBytes,
        ),
        base: ThemePackages.httpsUri(catalogUrl),
      );
    } catch (e) {
      Loggers.app.warning('Reading the theme catalog', e);
      catalog = await ThemeRepoCatalog.bundled(bundle: bundle);
    }

    final answered = await Future.wait(
      catalog.repos.map((repo) async {
        try {
          return (repo, await index(repo.url.toString()));
        } catch (e) {
          Loggers.app.warning('Reading the theme repository ${repo.label}', e);
          return null;
        }
      }),
    );

    final items = <ThemeStoreItem>[];
    final repos = <String>[];
    for (final entry in answered) {
      if (entry == null) continue;
      final (ref, index) = entry;
      final label = index.name?.trim().isNotEmpty == true
          ? index.name!.trim()
          : ref.label;
      repos.add(label);
      for (final listing in index.themes) {
        items.add(
          ThemeStoreItem(
            repo: label,
            index: index,
            listing: listing,
            release: listing.bestFor(
              ThemePackages.supportedSchemaMin,
              ThemePackages.supportedSchemaMax,
            ),
          ),
        );
      }
    }
    return ThemeStore(items: items, repos: repos);
  }

  /// Installs one store item's version.
  ///
  /// **A version with no digest is refused**, which is the one rule a store
  /// install has that a direct link does not: the catalog is what told the user
  /// this theme exists, and an unverifiable package from it is not a theme the
  /// app can say anything about. There is no "install anyway" here because
  /// there is nothing else to weigh — a user who has the bytes has
  /// [ThemePackages.install] and the file picker.
  ///
  /// [rootDirectory] is where it lands, spelled the way every other install
  /// spells it, so a test can install a published theme without touching the
  /// installation a user would be looking at.
  static Future<ThemePackage> install(
    ThemeStoreItem item, {
    String? rootDirectory,
  }) async {
    final release = item.release;
    if (release == null) {
      throw const ThemeRepoError('that version needs a newer app');
    }
    final digest = release.sha256;
    if (!release.verifiable) {
      throw ThemeRepoError('${item.listing.id} ${release.version} has no sha256');
    }

    final Uint8List bytes;
    if (release.url case final url?) {
      bytes = await ThemePackages.download(url);
    } else {
      final carried = item.index.packages[release.path];
      if (carried == null) {
        throw ThemeRepoError('the repository does not carry ${release.path}');
      }
      bytes = carried;
    }

    if (sha256.convert(bytes).toString() != digest) {
      // Never a question for the user: it means the file and the package were
      // changed one after the other, and there is no version of that worth
      // proceeding through.
      throw const ThemeRepoError('Theme checksum mismatch');
    }
    return ThemePackages.install(bytes, rootDirectory: rootDirectory);
  }

  /// The path a name is read as, or null when it escapes the tree or is not a
  /// path at all.
  static String? _safeName(String name) {
    final parts = [for (final p in name.split('/')) if (p.isNotEmpty) p];
    if (parts.isEmpty) return null;
    if (parts.any((p) => p == '.' || p == '..')) return null;
    return parts.join('/');
  }

  /// Drops the one directory a source tarball wraps everything in
  /// (`owner-repo-sha/`), which is the only thing a hosting service adds to a
  /// tree. A single-file repository has no wrapper to drop.
  static Map<String, Uint8List> _stripTopDirectory(Map<String, Uint8List> files) {
    if (files.isEmpty) return files;
    final first = files.keys.first.split('/').first;
    if (!files.keys.every((k) => k.startsWith('$first/'))) return files;
    return {
      for (final e in files.entries)
        if (e.key.length > first.length + 1)
          e.key.substring(first.length + 1): e.value,
    };
  }
}

/// Comparing `1.10.0` against `1.9.0`.
///
/// Field by field and numerically, because a string comparison puts `1.10`
/// before `1.9` — which would pin every install to whichever version happens to
/// sort last.
abstract final class ThemeVersion {
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

class ThemeRepoError implements Exception {
  const ThemeRepoError(this.message);
  final String message;

  @override
  String toString() => message;
}
