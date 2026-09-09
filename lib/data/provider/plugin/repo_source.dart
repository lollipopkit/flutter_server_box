/// Fetching a repository and installing from it.
///
/// **The address is the repository, and what is fetched is its latest tree.** One
/// request, no git client: for GitHub and everything GitHub-shaped that is
/// `<repo>/archive/HEAD.tar.gz`, which resolves the default branch server-side.
/// `HEAD` rather than a branch name, because which branch a repository calls
/// default is not this app's to guess.
///
/// The rule this file exists to hold: **a package is verified against the digest
/// its plugin file named, and an unverifiable one is never installed by
/// default.** Skipping is a decision the user makes with the reason in front of
/// them, which is why [PluginRepoSource.download] takes it as an argument rather
/// than reading a setting — a setting would be answered once, months earlier,
/// for a different repository.
library;

import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:dio/dio.dart';
import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:server_box/data/model/plugin/repo.dart';

/// Why a download will not proceed on its own.
enum PluginTrustIssue {
  /// The repository named no digest, so nothing about the bytes is checked.
  noDigest,

  /// It named one and the bytes are not it. **Never skippable**: this is not an
  /// absence of assurance, it is assurance that something is wrong.
  digestMismatch,
}

class PluginDownload {
  const PluginDownload({required this.bytes, required this.release});

  final List<int> bytes;
  final PluginRelease release;
}

class PluginRepoSource {
  PluginRepoSource({Dio? dio}) : _dio = dio ?? Dio();

  final Dio _dio;

  /// How much of a repository this app will read.
  ///
  /// A repository is not trusted to be small — it is a tarball somebody else
  /// wrote. The compressed cap bounds what reaches memory, the uncompressed one
  /// bounds what a small archive can claim to be, and a package is capped again
  /// by `PluginPackage.maxTotalBytes` when it is opened.
  static const maxArchiveBytes = 16 * 1024 * 1024;
  static const maxUnpackedBytes = 64 * 1024 * 1024;
  static const maxEntryBytes = 8 * 1024 * 1024;
  static const maxPackageBytes = 16 * 1024 * 1024;

  /// The tarball an address is fetched from.
  ///
  /// A URL that already names an archive is taken as it is, so a repository
  /// served from anywhere at all can be used by pointing straight at the
  /// tarball.
  ///
  /// **This rule is implemented twice** — here and in
  /// `packages/plugin-tools/src/fetch.ts` — because the tools and the app both
  /// have to turn the same address into the same URL. The table in
  /// `test/plugin_repo_test.dart` and the one in that package's
  /// `test/fetch.test.ts` are the same table for that reason.
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

  /// Reads the repository at [address].
  ///
  /// Plain HTTP is refused. A repository decides which bytes get installed and
  /// where they come from, so a plaintext one is a package chosen by whoever is
  /// on the path.
  Future<PluginIndex> index(String address) async {
    final uri = Uri.tryParse(archiveUrlOf(address));
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
      throw const PluginRepoError('that is not an address');
    }
    if (uri.scheme != 'https' && !_isLoopback(uri)) {
      throw const PluginRepoError(
        'a repository has to be reached over https; it decides what runs on '
        'your servers',
      );
    }

    final Response<List<int>> res;
    try {
      res = await _dio.getUri<List<int>>(
        uri,
        options: Options(
          responseType: ResponseType.bytes,
          receiveTimeout: const Duration(seconds: 60),
        ),
      );
    } on DioException catch (e) {
      throw PluginRepoError('the repository could not be reached: ${e.message}');
    }

    final bytes = res.data ?? const <int>[];
    if (bytes.length > maxArchiveBytes) {
      throw const PluginRepoError(
        'the repository is larger than this app will read',
      );
    }
    return PluginIndex.fromFiles(readRepoArchive(bytes));
  }

  /// Unpacks a `.tar.gz` of a repository into its files, by path.
  ///
  /// Separate and static so a test can hand it bytes: everything interesting
  /// about this is what it refuses.
  @visibleForTesting
  static Map<String, Uint8List> readRepoArchive(List<int> bytes) {
    final Archive archive;
    try {
      archive = TarDecoder().decodeBytes(GZipDecoder().decodeBytes(bytes));
    } catch (e) {
      throw PluginRepoError('the repository is not a readable .tar.gz: $e');
    }

    final files = <String, Uint8List>{};
    var total = 0;
    for (final file in archive) {
      if (!file.isFile) continue;
      final name = _safeName(file.name);
      // A name that escapes the tree, which is the classic archive attack. It
      // matters even though nothing here unpacks to disk: a path with `..` in it
      // could name a plugin file position it has no right to.
      if (name == null) {
        throw PluginRepoError('unsafe path in the repository: ${file.name}');
      }
      if (file.size > maxEntryBytes) {
        throw PluginRepoError('$name is larger than $maxEntryBytes bytes');
      }
      total += file.size;
      if (total > maxUnpackedBytes) {
        throw const PluginRepoError('the repository unpacks to too much');
      }
      files[name] = file.content;
    }

    return _stripTopDirectory(files);
  }

  /// Downloads or extracts [release] and checks it against its digest.
  ///
  /// [from] is the repository it came out of. A release naming a `path` is
  /// already in there — the fetch brought it — so this makes no request at all;
  /// one naming a `url` is fetched.
  ///
  /// [acceptWithoutDigest] is the user's answer to having been told, and it only
  /// ever covers [PluginTrustIssue.noDigest]. A **mismatch** is refused whatever
  /// it says: a repository that named a digest and a file that is not it means
  /// one of the two was changed, and there is no version of that worth
  /// proceeding through.
  Future<PluginDownload> download(
    PluginRelease release, {
    PluginIndex? from,
    bool acceptWithoutDigest = false,
  }) async {
    if (!release.verifiable && !acceptWithoutDigest) {
      throw const PluginTrustRefused(PluginTrustIssue.noDigest);
    }

    final bytes = await _bytesOf(release, from);
    if (bytes.length > maxPackageBytes) {
      throw const PluginRepoError(
        'the package is larger than this app will read',
      );
    }

    final expected = release.sha256;
    if (expected != null && release.verifiable) {
      if (!PluginDigest.matches(expected, bytes)) {
        // Logged with both digests because the useful question afterwards is
        // whether the repository republished or somebody is on the path, and
        // nobody can tell those apart without the numbers.
        Loggers.app.warning(
          'Plugin ${release.version}: expected $expected, '
          'got ${PluginDigest.of(bytes)}',
        );
        throw const PluginTrustRefused(PluginTrustIssue.digestMismatch);
      }
    }

    return PluginDownload(bytes: bytes, release: release);
  }

  Future<List<int>> _bytesOf(PluginRelease release, PluginIndex? from) async {
    final path = release.path;
    if (path != null) {
      final bytes = from?.packages[path];
      if (bytes == null) {
        throw PluginRepoError(
          'the repository lists $path and does not carry it',
        );
      }
      return bytes;
    }

    final uri = Uri.tryParse(release.url ?? '');
    if (uri == null || (uri.scheme != 'https' && !_isLoopback(uri))) {
      throw const PluginRepoError('the package address is not https');
    }
    try {
      final res = await _dio.getUri<List<int>>(
        uri,
        options: Options(
          responseType: ResponseType.bytes,
          receiveTimeout: const Duration(minutes: 2),
        ),
      );
      return res.data ?? const <int>[];
    } on DioException catch (e) {
      throw PluginRepoError(
        'the package could not be downloaded: ${e.message}',
      );
    }
  }

  /// Drops the single top directory a source tarball is wrapped in.
  ///
  /// **Its name cannot be predicted**: GitHub names it `<repo>-<ref>`, and for a
  /// `HEAD` archive that ref is the resolved commit sha. So the prefix is taken
  /// from the entries rather than constructed, and an archive whose entries do
  /// not share one is left alone — a tarball made from inside the directory is
  /// already flat.
  static Map<String, Uint8List> _stripTopDirectory(
    Map<String, Uint8List> files,
  ) {
    final tops = <String>{};
    for (final name in files.keys) {
      final at = name.indexOf('/');
      if (at < 0) return files;
      tops.add(name.substring(0, at));
    }
    if (tops.length != 1) return files;

    final prefix = '${tops.first}/';
    return {
      for (final e in files.entries) e.key.substring(prefix.length): e.value,
    };
  }

  /// The entry name, or null when it is one nothing may be read under.
  static String? _safeName(String raw) {
    final name = raw.replaceAll('\\', '/');
    if (name.isEmpty || name.startsWith('/')) return null;
    if (RegExp('^[A-Za-z]:').hasMatch(name)) return null;
    for (final part in name.split('/')) {
      if (part == '..') return null;
    }
    return name;
  }

  /// Loopback counts as reachable without TLS, which is the same rule the
  /// monitor agent applies: a repository served by something on this machine is
  /// not crossing a network.
  static bool _isLoopback(Uri uri) {
    final host = uri.host;
    return host == 'localhost' || host == '127.0.0.1' || host == '::1';
  }
}

/// A download stopped because of what is or is not known about the bytes.
class PluginTrustRefused implements Exception {
  const PluginTrustRefused(this.issue);

  final PluginTrustIssue issue;

  /// Whether the user may be offered a way past this.
  ///
  /// Only [PluginTrustIssue.noDigest]. A mismatch is not a question.
  bool get skippable => issue == PluginTrustIssue.noDigest;

  @override
  String toString() => switch (issue) {
    PluginTrustIssue.noDigest =>
      'the repository named no checksum for this package',
    PluginTrustIssue.digestMismatch =>
      'the package is not the one the repository described',
  };
}

/// What a repository is expected to hold, for the docs and for tests.
///
/// Kept beside the reader so the two cannot drift: this is the shape
/// [PluginIndex.fromFiles] accepts, written out.
const kPluginRepoExample = {
  'repo.toml': '''
schema = 1
name = "ServerBox plugins"
''',
  'plugins/app/serverbox/diskusage.toml': '''
id = "app.serverbox.diskusage"
name = "Disk usage"
description = "Where the space went, one directory at a time."
license = "MIT"

[[version]]
version = "1.0.0"
abi = 2
path = "packages/app.serverbox.diskusage-1.0.0.sbp"
sha256 = "0000000000000000000000000000000000000000000000000000000000000000"
size = 16408
notes = "First release."
''',
};

/// So the example above is not prose that drifted from the parser.
PluginIndex parseExampleRepo() => PluginIndex.fromFiles({
  for (final e in kPluginRepoExample.entries)
    e.key: Uint8List.fromList(e.value.codeUnits),
});
