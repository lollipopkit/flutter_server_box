/// The tool's output, read by the app that has to install from it.
///
/// The two sides are in different languages and neither build reads the other,
/// so nothing else makes them meet. A key spelled differently is not a compile
/// error on either side: it is a plugin file the app skips, and the symptom is a
/// repository that looks empty to everybody. **A file written to a path the app
/// does not look in has the same symptom**, which is why the layout is asserted
/// here as well as in each language's own tests.
///
/// The fixture is what the tool emitted; recipe in
/// `test/fixtures/plugin_repo/README.md`.
library;

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/data/model/plugin/repo.dart';

const _fixture = 'test/fixtures/plugin_repo';

const _plugins = [
  'packages/plugins/disk-usage',
  'packages/plugins/listening-ports',
  'packages/plugins/scheduled',
];

/// The fixture as the app receives a repository: a flat map of path to bytes.
Map<String, Uint8List> _files() {
  final files = <String, Uint8List>{};
  for (final entity in Directory(_fixture).listSync(recursive: true)) {
    if (entity is! File) continue;
    final path = entity.path.substring('$_fixture/'.length);
    if (path == 'README.md') continue;
    files[path] = entity.readAsBytesSync();
  }
  return files;
}

void main() {
  final index = PluginIndex.fromFiles(_files());

  test('it reads, and every plugin has a release', () {
    expect(index.name, isNotNull);
    expect(index.plugins, hasLength(_plugins.length));
    for (final listing in index.plugins) {
      // `PluginListing.parse` refuses a file with no readable version, so one
      // would not be here at all — the count is what says so.
      expect(listing.releases, isNotEmpty, reason: listing.id);
      expect(listing.name, isNotEmpty);
    }
  });

  test('every release carries what an install needs', () {
    for (final listing in index.plugins) {
      for (final release in listing.releases) {
        expect(release.version, isNotEmpty);
        // A digest is what the app checks the bytes against, and a release
        // without one is refused by default — so a generator that stopped
        // emitting it would turn every install into a warning dialog.
        expect(release.verifiable, isTrue, reason: listing.id);
        expect(release.sha256, matches(RegExp(r'^[0-9a-f]{64}$')));
        expect(release.size, isNotNull);
        expect(release.size, greaterThan(0));
        // An address, which is what the tool writes: **nothing binary goes
        // into the repository**, so a package lives wherever its publisher put
        // it and the digest above is what binds that address to these bytes.
        expect(release.url, isNotNull, reason: listing.id);
        expect(release.path, isNull);
        expect(Uri.parse(release.url!).scheme, 'https');
        expect(release.url, endsWith('.sbp'));
      }
    }
  });

  /// Where the app looks. A file one directory too deep or too shallow is not an
  /// error anywhere — it is simply never read.
  test('every plugin file is where its id puts it', () {
    for (final path in _files().keys) {
      if (path == PluginIndex.repoFile) continue;
      final id = PluginRepoLayout.idOf(path);
      expect(id, isNotNull, reason: '$path is in the tree and nothing reads it');
      expect(PluginRepoLayout.pathOf(id!), path);
    }
  });

  test('the id, version and abi are the ones in each manifest', () {
    final listings = {for (final l in index.plugins) l.id: l};
    for (final dir in _plugins) {
      final manifest =
          jsonDecode(File('$dir/manifest.json').readAsStringSync()) as Map;
      final listing = listings[manifest['id']];
      expect(
        listing,
        isNotNull,
        reason: '$dir is not in the fixture — regenerate it',
      );
      final release = listing!.releases.firstWhere(
        (r) => r.version == manifest['version'],
        orElse: () => throw TestFailure(
          '${manifest['id']} ${manifest['version']} is not in the fixture — '
          'regenerate it',
        ),
      );
      expect(release.abi, manifest['abi']);
      // The name the packer gives a package, which is what the file has to
      // point at. A mismatch here is an install that cannot find its bytes.
      expect(
        release.url,
        endsWith('/${manifest['id']}-${manifest['version']}.sbp'),
      );
    }
  });

  /// The reason a file lists versions at all, and the one thing that cannot be
  /// checked by reading it: a build of this app picks by ABI.
  test('this build can install every release in it', () {
    for (final listing in index.plugins) {
      final abi = listing.releases
          .map((r) => r.abi)
          .reduce((a, b) => a > b ? a : b);
      expect(listing.bestFor(abi), isNotNull);
      // And an app one ABI older finds nothing rather than the wrong thing.
      expect(listing.tooNewFor(abi - 1), isNotEmpty);
    }
  });
}
