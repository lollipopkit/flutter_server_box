/// The theme catalog and the repositories it lists.
///
/// Two levels, and every failure below is silent in the app: a repository that
/// will not parse costs its themes, a theme whose file is refused costs that
/// theme, and what is left is a store that offers less than it was told about
/// with nothing on screen saying so.
library;

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/core/service/theme_package.dart';
import 'package:server_box/core/service/theme_repo.dart';
import 'package:toml/toml.dart';

/// A catalog as this repository ships one.
String catalogToml({String schema = '1', String repos = ''}) =>
    'schema = $schema\nname = "ServerBox themes"\n$repos';

String repoEntry(String url) => '[[repo]]\nurl = "$url"\n';

/// One theme's file, `versions` verbatim so a test can write the one it means.
String themeToml({String id = 'aurora', String versions = ''}) =>
    'id = "$id"\nname = "Aurora"\ndescription = "Green"\n$versions';

String version({
  String version = '1.0.0',
  int schemaMin = 1,
  int schemaMax = 1,
  String? url = 'https://example.org/aurora-1.0.0.fsbt',
  String? path,
  String? sha256,
}) {
  final buffer = StringBuffer(
    '[[version]]\nversion = "$version"\n'
    'schema_min = $schemaMin\nschema_max = $schemaMax\n',
  );
  if (url != null) buffer.writeln('url = "$url"');
  if (path != null) buffer.writeln('path = "$path"');
  buffer.writeln('sha256 = "${sha256 ?? List.filled(64, 'a').join()}"');
  return buffer.toString();
}

/// A `repo.toml` plus the files beside it, as a tree fetch hands them over.
Map<String, Uint8List> files({
  String? repo = 'schema = 1\nname = "A test repository"\n',
  Map<String, String> themes = const {'themes/aurora.toml': ''},
  Map<String, String> extra = const {},
}) => {
  if (repo != null) 'repo.toml': Uint8List.fromList(utf8.encode(repo)),
  for (final e in themes.entries)
    e.key: Uint8List.fromList(
      utf8.encode(e.value.isEmpty ? themeToml(versions: version()) : e.value),
    ),
  for (final e in extra.entries)
    e.key: Uint8List.fromList(utf8.encode(e.value)),
};

/// A `.tar.gz` of a repository's tree, wrapped the way a hosting service does.
List<int> tarGz(Map<String, String> entries, {String? top = 'owner-repo-sha'}) {
  final archive = Archive();
  for (final e in entries.entries) {
    final bytes = utf8.encode(e.value);
    archive.addFile(
      ArchiveFile(
        top == null ? e.key : '$top/${e.key}',
        bytes.length,
        bytes,
      ),
    );
  }
  return GZipEncoder().encode(TarEncoder().encode(archive));
}

void main() {
  group('catalog', () {
    test('reads the repositories it lists', () {
      final catalog = ThemeRepoCatalog.parse(
        utf8.encode(
          catalogToml(
            repos:
                repoEntry('https://github.com/lollipopkit/serverbox-themes') +
                repoEntry('https://github.com/someone/themes'),
          ),
        ),
      );
      expect(catalog.name, 'ServerBox themes');
      expect(catalog.repos, hasLength(2));
      expect(catalog.repos.first.label, 'lollipopkit/serverbox-themes');
      expect(catalog.repos.last.label, 'someone/themes');
    });

    test('resolves a repository beside the catalog', () {
      final catalog = ThemeRepoCatalog.parse(
        utf8.encode(catalogToml(repos: repoEntry('./themes'))),
        base: Uri.parse('https://example.org/store/repos.toml'),
      );
      expect(
        catalog.repos.single.url.toString(),
        'https://example.org/store/themes',
      );
    });

    test('lists a repository once, however often it is named', () {
      final catalog = ThemeRepoCatalog.parse(
        utf8.encode(
          catalogToml(
            repos: repoEntry('https://github.com/a/b') + repoEntry(
              'https://github.com/a/b',
            ),
          ),
        ),
      );
      expect(catalog.repos, hasLength(1));
    });

    test('refuses a plaintext repository and a schema it cannot read', () {
      expect(
        () => ThemeRepoCatalog.parse(
          utf8.encode(catalogToml(repos: repoEntry('http://github.com/a/b'))),
        ),
        throwsA(isA<ThemeRepoError>()),
      );
      expect(
        () => ThemeRepoCatalog.parse(
          utf8.encode(catalogToml(schema: '2', repos: repoEntry('https://a/b'))),
        ),
        throwsA(isA<ThemeRepoError>()),
      );
      expect(
        () => ThemeRepoCatalog.parse(utf8.encode('name = "no schema"\n')),
        throwsA(isA<ThemeRepoError>()),
      );
    });

    test('the catalog this repository ships is one this build reads', () {
      final file = File(ThemeRepoCatalog.bundledAsset);
      final catalog = ThemeRepoCatalog.parse(file.readAsBytesSync());
      expect(
        catalog.repos,
        isNotEmpty,
        reason: 'the bundled catalog offers no repository',
      );
      expect(
        catalog.repos.single.url.host,
        'github.com',
        reason: 'the official repository moved off github',
      );
    });
  });

  group('repository', () {
    test('reads a theme file and keeps what the tree carries', () {
      final index = ThemeRepoIndex.fromFiles(
        files(
          themes: {
            // In-tree, so no second request: the fetch already brought it.
            'themes/aurora.toml': themeToml(
              versions: version(
                version: '1.1.0',
                url: null,
                path: 'packages/a-1.1.0.fsbt',
              ),
            ),
          },
          extra: {'packages/a-1.1.0.fsbt': 'bytes'},
        ),
      );
      expect(index.name, 'A test repository');
      expect(index.themes.single.id, 'aurora');
      expect(index.packages.keys, ['packages/a-1.1.0.fsbt']);
    });

    test('a plugins section beside themes costs nothing', () {
      // One repository can serve both kinds, and a build that reads themes has
      // no business refusing a tree because of what else is in it.
      final index = ThemeRepoIndex.fromFiles(
        files(
          extra: {
            'plugins/app/serverbox/diskusage.toml':
                'id = "app.serverbox.diskusage"\n',
            'packages/app.serverbox.diskusage-1.0.0.sbp': 'bytes',
            'README.md': '# A repository',
          },
        ),
      );
      expect(index.themes.single.id, 'aurora');
    });

    test('one unreadable theme file costs that theme only', () {
      final index = ThemeRepoIndex.fromFiles(
        files(
          themes: {
            'themes/aurora.toml': '',
            'themes/broken.toml': 'id = "something-else"\n',
            'themes/dracula.toml': themeToml(
              id: 'dracula',
              versions: version(),
            ),
          },
        ),
      );
      expect(index.themes.map((t) => t.id), ['aurora', 'dracula']);
    });

    test('a tree that is not a repository is refused', () {
      expect(
        () => ThemeRepoIndex.fromFiles(files(repo: null)),
        throwsA(isA<ThemeRepoError>()),
      );
      expect(
        () => ThemeRepoIndex.fromFiles(
          files(repo: 'schema = 2\nname = "From the future"\n'),
        ),
        throwsA(isA<ThemeRepoError>()),
      );
    });

    test('a file whose path and id disagree is refused', () {
      expect(
        () => ThemeListing.parse(themeToml(id: 'dracula'), 'themes/aurora.toml'),
        throwsA(isA<ThemeRepoError>()),
      );
    });

    test('a file is named after the id its package carries, dots and all', () {
      final index = ThemeRepoIndex.fromFiles(
        files(
          themes: {
            'themes/serverbox.aurora.toml': themeToml(
              id: 'serverbox.aurora',
              versions: version(),
            ),
          },
        ),
      );
      expect(index.themes.single.id, 'serverbox.aurora');
    });

    test('the reference theme can be listed under the id it declares', () {
      // The two ids are one spelling, so a theme the app ships as an example is
      // one a repository can offer. A layout narrower than the manifest's own
      // would leave the reference theme unpublishable.
      final manifest = TomlDocument.parse(
        File('docs/examples/aurora/manifest.toml').readAsStringSync(),
      ).toMap();
      final id = manifest['id'] as String;
      expect(ThemePackages.idPattern.hasMatch(id), isTrue);
      expect(ThemeRepoLayout.pathOf(id), 'themes/$id.toml');
      expect(ThemeRepoLayout.idOf('themes/$id.toml'), id);
    });
  });

  group('versions', () {
    ThemeListing listing(String versions) =>
        ThemeListing.parse(themeToml(versions: versions), 'themes/aurora.toml');

    test('the newest readable one wins, whatever order the file is in', () {
      final theme = listing(
        '${version(version: '1.9.0')}\n${version(version: '1.10.0')}\n',
      );
      expect(theme.bestFor(1, 1)?.version, '1.10.0');
    });

    test('a version this app is too old for is not the one installed', () {
      final theme = listing(
        '${version(version: '2.0.0', schemaMin: 2, schemaMax: 2)}\n'
        '${version(version: '1.0.0')}\n',
      );
      expect(theme.bestFor(1, 1)?.version, '1.0.0');
      expect(theme.tooNewFor(1).single.version, '2.0.0');
      // Nothing readable at all is not an error: the store lists it to say so.
      expect(listing(version(version: '2.0.0', schemaMin: 2, schemaMax: 2)).bestFor(1, 1), isNull);
    });

    test('a version naming both a url and a path is dropped', () {
      final theme = listing(
        '${version(url: 'https://a/b.fsbt', path: 'packages/b.fsbt')}\n'
        '${version(version: '1.0.1')}\n',
      );
      expect(theme.releases.single.version, '1.0.1');
    });

    test('a version whose path climbs out of the tree is dropped', () {
      final theme = listing(
        '${version(url: null, path: '../packages/b.fsbt')}\n'
        '${version(version: '1.0.1')}\n',
      );
      expect(
        theme.releases.single.version,
        '1.0.1',
        reason: 'a path with .. in it names an entry the tree did not put there',
      );
    });

    test('a listing offering nothing at all is refused', () {
      expect(
        () => ThemeListing.parse('id = "aurora"\nname = "Aurora"\n', 'themes/aurora.toml'),
        throwsA(isA<ThemeRepoError>()),
      );
    });

    test('1.10 is newer than 1.9, and a pre-release is older than both', () {
      expect(ThemeVersion.compare('1.10.0', '1.9.0'), 1);
      expect(ThemeVersion.compare('1.0.0', '1.0.0'), 0);
      expect(ThemeVersion.compare('1.0.0', '1.0.0-beta'), 1);
      expect(ThemeVersion.compare('2.0.0', '1.99.99'), 1);
    });

    test('a version without a digest is one the store will not install', () {
      final theme = listing(
        version(sha256: '').replaceFirst('sha256 = ""', 'notes = "no digest"'),
      );
      expect(theme.releases.single.verifiable, isFalse);
      expect(
        () => ThemeRepos.install(
          ThemeStoreItem(
            repo: 'a/b',
            index: const ThemeRepoIndex(themes: []),
            listing: theme,
            release: theme.releases.single,
          ),
        ),
        throwsA(isA<ThemeRepoError>()),
      );
    });

    test('a version this app cannot read is not installed by accident', () {
      final theme = listing(version(version: '2.0.0', schemaMin: 2, schemaMax: 2));
      expect(
        () => ThemeRepos.install(
          ThemeStoreItem(
            repo: 'a/b',
            index: const ThemeRepoIndex(themes: []),
            listing: theme,
            release: null,
          ),
        ),
        throwsA(isA<ThemeRepoError>()),
      );
    });
  });

  group('archive', () {
    test('a fetched tree is read without its wrapping directory', () {
      final read = ThemeRepos.readArchive(
        tarGz({
          'repo.toml': 'schema = 1\nname = "A test repository"\n',
          'themes/aurora.toml': themeToml(versions: version()),
        }),
      );
      expect(read.keys, containsAll(['repo.toml', 'themes/aurora.toml']));
      expect(ThemeRepoIndex.fromFiles(read).themes.single.id, 'aurora');
    });

    test('an address becomes the tarball it is fetched from', () {
      expect(
        ThemeRepos.archiveUrlOf('https://github.com/a/b'),
        'https://github.com/a/b/archive/HEAD.tar.gz',
      );
      expect(
        ThemeRepos.archiveUrlOf('https://github.com/a/b.git/'),
        'https://github.com/a/b/archive/HEAD.tar.gz',
      );
      expect(
        ThemeRepos.archiveUrlOf('https://example.org/a/b.tar.gz'),
        'https://example.org/a/b.tar.gz',
        reason: 'an address that already names an archive is taken as it is',
      );
    });

    test('a name that escapes the tree is refused', () {
      expect(
        () => ThemeRepos.readArchive(tarGz({'../evil.toml': 'x'}, top: null)),
        throwsA(isA<ThemeRepoError>()),
      );
    });

    test('an archive that is not one, and one that is too big', () {
      expect(
        () => ThemeRepos.readArchive(utf8.encode('not a tarball')),
        throwsA(isA<ThemeRepoError>()),
      );
      expect(
        () => ThemeRepos.readArchive(
          tarGz({'themes/big.toml': 'x' * (ThemeRepos.maxEntryBytes + 1)}),
        ),
        throwsA(isA<ThemeRepoError>()),
      );
    });
  });
}
