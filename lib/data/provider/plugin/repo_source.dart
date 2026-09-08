/// Fetching an index and installing from it.
///
/// The rule this file exists to hold: **a package is verified against the
/// digest the index named, and an unverifiable one is never installed by
/// default.** Skipping is a decision the user makes with the reason in front
/// of them, which is why [download] takes it as an argument rather than
/// reading a setting — a setting would be answered once, months earlier, for
/// a different repository.
library;

import 'package:dio/dio.dart';
import 'package:fl_lib/fl_lib.dart';
import 'package:server_box/data/model/plugin/repo.dart';

/// Why a download will not proceed on its own.
enum PluginTrustIssue {
  /// The index named no digest, so nothing about the bytes is checked.
  noDigest,

  /// The index named one and the bytes are not it. **Never skippable**: this
  /// is not an absence of assurance, it is assurance that something is wrong.
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

  /// How much of an index or a package will be read.
  ///
  /// A repository is not trusted to be small. An index is a few kilobytes of
  /// JSON and a package is capped again by `PluginPackage.maxTotalBytes`;
  /// this bounds what reaches memory before either of those gets a say.
  static const maxIndexBytes = 4 * 1024 * 1024;
  static const maxPackageBytes = 16 * 1024 * 1024;

  /// Reads `index.json` from [url].
  ///
  /// Plain HTTP is refused. The index decides which bytes get installed and
  /// where they come from, so a plaintext one is a package chosen by whoever
  /// is on the path.
  Future<PluginIndex> index(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null || !uri.hasScheme) {
      throw const PluginRepoError('that is not an address');
    }
    if (uri.scheme != 'https' && !_isLoopback(uri)) {
      throw const PluginRepoError(
        'a repository has to be reached over https; it decides what runs on '
        'your servers',
      );
    }

    final Response<String> res;
    try {
      res = await _dio.getUri<String>(
        uri,
        options: Options(
          responseType: ResponseType.plain,
          receiveTimeout: const Duration(seconds: 30),
        ),
      );
    } on DioException catch (e) {
      throw PluginRepoError('the repository could not be reached: ${e.message}');
    }

    final body = res.data ?? '';
    if (body.length > maxIndexBytes) {
      throw const PluginRepoError('the index is larger than this app will read');
    }
    return PluginIndex.parse(body);
  }

  /// Downloads [release] and checks it against the digest the index named.
  ///
  /// [acceptWithoutDigest] is the user's answer to having been told, and it
  /// only ever covers [PluginTrustIssue.noDigest]. A **mismatch** is refused
  /// whatever it says: an index that named a digest and a file that is not it
  /// means one of the two was changed, and there is no version of that worth
  /// proceeding through.
  Future<PluginDownload> download(
    PluginRelease release, {
    bool acceptWithoutDigest = false,
  }) async {
    if (!release.verifiable && !acceptWithoutDigest) {
      throw const PluginTrustRefused(PluginTrustIssue.noDigest);
    }

    final uri = Uri.tryParse(release.url);
    if (uri == null || (uri.scheme != 'https' && !_isLoopback(uri))) {
      throw const PluginRepoError(
        'the package address is not https',
      );
    }

    final Response<List<int>> res;
    try {
      res = await _dio.getUri<List<int>>(
        uri,
        options: Options(
          responseType: ResponseType.bytes,
          receiveTimeout: const Duration(minutes: 2),
        ),
      );
    } on DioException catch (e) {
      throw PluginRepoError('the package could not be downloaded: ${e.message}');
    }

    final bytes = res.data ?? const <int>[];
    if (bytes.length > maxPackageBytes) {
      throw const PluginRepoError('the package is larger than this app will read');
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

  /// Loopback counts as reachable without TLS, which is the same rule the
  /// monitor agent applies: a repository served by something on this machine
  /// is not crossing a network.
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

/// The index a repository is expected to serve, for the docs and for tests.
///
/// Kept beside the reader so the two cannot drift: this is the shape
/// [PluginIndex.parse] accepts, written out.
const kPluginIndexExample = '''
{
  "schema": 1,
  "plugins": [
    {
      "id": "app.serverbox.diskusage",
      "name": "Disk usage",
      "description": "Where the space went, one directory at a time.",
      "homepage": "https://github.com/lollipopkit/flutter_server_box",
      "versions": [
        {
          "version": "1.0.0",
          "abi": 2,
          "url": "https://example.com/app.serverbox.diskusage-1.0.0.sbp",
          "sha256": "0000000000000000000000000000000000000000000000000000000000000000",
          "size": 16408,
          "notes": "First release."
        }
      ]
    }
  ]
}
''';

/// So the example above is not prose that drifted from the parser.
PluginIndex parseExampleIndex() => PluginIndex.parse(kPluginIndexExample);
