/// Reading a plugin repository, and deciding what may be installed from it.
///
/// A repository is a git repository of TOML files — one per plugin — fetched as
/// a tarball of its latest tree. So there are four things here that decide what
/// runs on somebody's servers: which address is fetched, which files in the tree
/// are plugins, which version an app of this age picks, and whether the bytes
/// are the ones the file named.
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/data/model/plugin/repo.dart';
import 'package:server_box/data/provider/plugin/repo_source.dart';

/// A digest-shaped string. The value does not matter where the test is about
/// selection rather than about verification.
const _someDigest =
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';

Uint8List _bytes(String text) => Uint8List.fromList(utf8.encode(text));

/// A repository's files, with `repo.toml` unless one is given.
Map<String, Uint8List> _repo(
  Map<String, String> files, {
  String? repoFile = 'schema = 1\nname = "Test"\n',
}) => {
  if (repoFile != null) 'repo.toml': _bytes(repoFile),
  for (final e in files.entries) e.key: _bytes(e.value),
};

String _plugin(
  String id, {
  String name = 'A',
  List<String> versions = const [],
}) => [
  'id = "$id"',
  'name = "$name"',
  'description = "One line."',
  ...versions,
].join('\n');

String _version(
  String version,
  int abi, {
  String? sha256 = _someDigest,
  String? path,
  String? url,
}) => [
  '',
  '[[version]]',
  'version = "$version"',
  'abi = $abi',
  if (path != null) 'path = "$path"',
  if (url != null) 'url = "$url"',
  if (path == null && url == null) 'path = "packages/$version.sbp"',
  if (sha256 != null) 'sha256 = "$sha256"',
  'size = 10',
].join('\n');

void main() {
  group('where a plugin file lives', () {
    /// **The same table as `packages/plugin-tools/test/repo.test.ts`.** The rule
    /// is implemented twice, in two languages, and a generator that puts a file
    /// somewhere the app does not look for it publishes a plugin nobody sees.
    test('two directory levels, taken from the id', () {
      expect(
        PluginRepoLayout.pathOf('app.serverbox.diskusage'),
        'plugins/app/serverbox/diskusage.toml',
      );
      // Everything after the publisher is the file name, dots and all, so a
      // four-part id is not a third directory.
      expect(
        PluginRepoLayout.pathOf('com.example.my.thing'),
        'plugins/com/example/my.thing.toml',
      );
    });

    test('the path reads back as the id', () {
      for (final id in ['app.serverbox.ports', 'com.example.my.thing']) {
        expect(PluginRepoLayout.idOf(PluginRepoLayout.pathOf(id)!), id);
      }
    });

    test('an id that cannot be laid out has no path', () {
      for (final id in ['single', 'two.parts', 'app..empty', 'a.b.c/d']) {
        expect(PluginRepoLayout.pathOf(id), isNull, reason: id);
      }
    });

    test('what is not a plugin file has no id', () {
      for (final path in [
        'repo.toml',
        'README.md',
        'packages/x.sbp',
        'plugins/a/b.toml',
        'plugins/a/b/c.txt',
      ]) {
        expect(PluginRepoLayout.idOf(path), isNull, reason: path);
      }
    });
  });

  group('the repository', () {
    test('the documented example is one this build reads', () {
      final index = parseExampleRepo();

      expect(index.name, 'ServerBox plugins');
      expect(index.plugins.single.id, 'app.serverbox.diskusage');
      expect(index.plugins.single.bestFor(2)?.version, '1.0.0');
      expect(index.plugins.single.license, 'MIT');
    });

    test('a tree with no repo.toml is not a repository', () {
      expect(
        () => PluginIndex.fromFiles(
          _repo({
            'plugins/a/b/c.toml': _plugin('a.b.c', versions: [_version('1.0.0', 1)]),
          }, repoFile: null),
        ),
        throwsA(isA<PluginRepoError>()),
      );
    });

    test('a schema this build does not read is refused whole', () {
      // Not half-read: the fields it does not know about might be the ones that
      // decide something.
      expect(
        () => PluginIndex.fromFiles(_repo({}, repoFile: 'schema = 99\n')),
        throwsA(isA<PluginRepoError>()),
      );
      expect(
        () => PluginIndex.fromFiles(_repo({}, repoFile: 'name = "x"\n')),
        throwsA(isA<PluginRepoError>()),
      );
      expect(
        () => PluginIndex.fromFiles(_repo({}, repoFile: 'schema = ')),
        throwsA(isA<PluginRepoError>()),
      );
    });

    test('files that are not plugins are ignored, not refused', () {
      final index = PluginIndex.fromFiles(
        _repo({
          'README.md': '# hello',
          'plugins/a/b/c.toml': _plugin('a.b.c', versions: [_version('1.0.0', 1)]),
          '.github/workflows/ci.yml': 'on: push',
        }),
      );

      expect(index.plugins.map((p) => p.id), ['a.b.c']);
    });

    /// One unreadable file costs that plugin. A repository holds files other
    /// people sent, and one of them being wrong must not take the rest with it.
    test('a plugin file that will not read costs that plugin', () {
      final index = PluginIndex.fromFiles(
        _repo({
          'plugins/a/b/good.toml': _plugin(
            'a.b.good',
            versions: [_version('1.0.0', 1)],
          ),
          'plugins/a/b/broken.toml': 'id = "a.b.broken"\nname = ',
          // Nothing installable is not a listing.
          'plugins/a/b/empty.toml': _plugin('a.b.empty'),
          // A file in the wrong folder: refused rather than read, because the
          // app would otherwise offer something the repository does not think
          // it is serving.
          'plugins/c/d/moved.toml': _plugin(
            'a.b.moved',
            versions: [_version('1.0.0', 1)],
          ),
        }),
      );

      expect(index.plugins.map((p) => p.id), ['a.b.good']);
    });

    test('the packages the tree carried come with it', () {
      final index = PluginIndex.fromFiles(
        _repo({
          'plugins/a/b/c.toml': _plugin('a.b.c', versions: [_version('1.0.0', 1)]),
          'packages/1.0.0.sbp': 'not really a package',
        }),
      );

      expect(index.packages.keys, ['packages/1.0.0.sbp']);
    });
  });

  group('a version', () {
    PluginListing listing(List<String> versions) => PluginIndex.fromFiles(
      _repo({
        'plugins/a/b/c.toml': _plugin('a.b.c', versions: versions),
      }),
    ).plugins.single;

    test('names exactly one of path and url', () {
      final both = listing([
        _version('1.0.0', 1, path: 'packages/x.sbp', url: 'https://x.invalid/x.sbp'),
        _version('2.0.0', 1),
      ]);
      expect(both.releases.map((r) => r.version), ['2.0.0']);

      final neither = PluginIndex.fromFiles(
        _repo({
          'plugins/a/b/c.toml': [
            _plugin('a.b.c'),
            '',
            '[[version]]',
            'version = "1.0.0"',
            'abi = 1',
            'sha256 = "$_someDigest"',
          ].join('\n'),
        }),
      );
      expect(neither.plugins, isEmpty);
    });

    /// The archive attack in its other clothes. Nothing here unpacks to disk,
    /// but a path that climbs out would name an entry the tarball did not put
    /// there.
    test('a path that escapes the repository is dropped', () {
      final l = listing([
        _version('1.0.0', 1, path: '../elsewhere/x.sbp'),
        _version('1.1.0', 1, path: '/etc/x.sbp'),
        _version('2.0.0', 1, path: 'packages/ok.sbp'),
      ]);

      expect(l.releases.map((r) => r.version), ['2.0.0']);
    });

    group('picking one', () {
      /// The whole point of a file carrying several: an older app has to find
      /// one it can run rather than download the newest and be told no by the
      /// manifest parser afterwards.
      test('the newest at or below this app ABI', () {
        final l = listing([
          _version('1.0.0', 1),
          _version('2.0.0', 2),
          _version('3.0.0', 3),
        ]);

        expect(l.bestFor(1)?.version, '1.0.0');
        expect(l.bestFor(2)?.version, '2.0.0');
        expect(l.bestFor(9)?.version, '3.0.0');
      });

      test('an app too old for everything gets nothing', () {
        expect(listing([_version('2.0.0', 5)]).bestFor(1), isNull);
      });

      /// So a listing can say "there is a newer one and this app is too old",
      /// which is a different thing from "you are up to date".
      test('it can name what it could not offer', () {
        final l = listing([_version('1.0.0', 1), _version('2.0.0', 5)]);

        expect(l.bestFor(1)?.version, '1.0.0');
        expect(l.tooNewFor(1).map((r) => r.version), ['2.0.0']);
        expect(l.tooNewFor(9), isEmpty);
      });

      /// The order in the file is not trusted, and a string comparison puts
      /// `1.10` before `1.9` — which would pin every install to whichever
      /// version happened to sort last.
      test('versions compare by number, not as strings', () {
        expect(PluginVersion.compare('1.10.0', '1.9.0'), greaterThan(0));
        expect(PluginVersion.compare('1.2.0', '1.10.0'), lessThan(0));
        expect(PluginVersion.compare('2.0.0', '10.0.0'), lessThan(0));
        expect(PluginVersion.compare('1.0.0', '1.0.0'), 0);

        expect(
          listing([_version('1.9.0', 1), _version('1.10.0', 1)])
              .bestFor(1)
              ?.version,
          '1.10.0',
        );
      });

      /// A pre-release is below the release of the same number, which is what
      /// calling it one means.
      test('a pre-release sorts below the release', () {
        expect(PluginVersion.compare('1.0.0-beta', '1.0.0'), lessThan(0));
        expect(PluginVersion.compare('1.0.0', '1.0.0-beta'), greaterThan(0));
        expect(PluginVersion.compare('1.0.0-alpha', '1.0.0-beta'), lessThan(0));
      });
    });
  });

  group('the address', () {
    /// **The same table as `packages/plugin-tools/test/fetch.test.ts`.** The
    /// tools and the app both turn an address into a URL, and a client deriving
    /// a different one reads a different repository.
    test('a repository address becomes its latest tree', () {
      const cases = {
        'https://github.com/lollipopkit/serverbox-plugins':
            'https://github.com/lollipopkit/serverbox-plugins/archive/HEAD.tar.gz',
        'https://github.com/lollipopkit/serverbox-plugins/':
            'https://github.com/lollipopkit/serverbox-plugins/archive/HEAD.tar.gz',
        'https://github.com/lollipopkit/serverbox-plugins.git':
            'https://github.com/lollipopkit/serverbox-plugins/archive/HEAD.tar.gz',
        // Gitea and Forgejo answer the same path, so nothing here is
        // GitHub-only.
        'https://codeberg.org/someone/plugins':
            'https://codeberg.org/someone/plugins/archive/HEAD.tar.gz',
        // Already an archive: taken as it is, so a repository served from
        // anywhere can be used by pointing straight at the tarball.
        'https://example.com/plugins.tar.gz': 'https://example.com/plugins.tar.gz',
        'https://example.com/plugins.tgz': 'https://example.com/plugins.tgz',
      };

      cases.forEach((address, expected) {
        expect(PluginRepoSource.archiveUrlOf(address), expected, reason: address);
      });
    });

    test('a repository has to be reached over https', () async {
      for (final url in ['http://example.invalid/repo', 'not a url']) {
        await expectLater(
          PluginRepoSource().index(url),
          throwsA(isA<PluginRepoError>()),
          reason: url,
        );
      }
    });

    /// Something served by this machine is not crossing a network, which is the
    /// same rule the monitor agent applies to its own plaintext listener.
    test('loopback is allowed without tls', () async {
      // It will fail to connect, and that is a different error from the one the
      // scheme check raises.
      await expectLater(
        PluginRepoSource().index('http://127.0.0.1:1/repo'),
        throwsA(
          isA<PluginRepoError>().having(
            (e) => e.message,
            'message',
            contains('could not be reached'),
          ),
        ),
      );
    });
  });

  group('unpacking a tree', () {
    List<int> tarGz(Map<String, List<int>> files) {
      final archive = Archive();
      for (final e in files.entries) {
        archive.add(ArchiveFile.bytes(e.key, e.value));
      }
      return GZipEncoder().encodeBytes(TarEncoder().encodeBytes(archive));
    }

    test('entries come back by name', () {
      final files = PluginRepoSource.readRepoArchive(
        tarGz({
          'repo.toml': utf8.encode('schema = 1'),
          'plugins/a/b/c.toml': utf8.encode('id = "a.b.c"'),
        }),
      );

      expect(files.keys.toList()..sort(), ['plugins/a/b/c.toml', 'repo.toml']);
    });

    /// The name of the directory a source tarball wraps everything in **cannot
    /// be predicted**: GitHub puts the resolved commit sha in it for a `HEAD`
    /// archive. So it is taken from the entries.
    test('the single top directory is dropped, whatever it is called', () {
      final files = PluginRepoSource.readRepoArchive(
        tarGz({
          'serverbox-plugins-fca4edc/repo.toml': utf8.encode('schema = 1'),
          'serverbox-plugins-fca4edc/plugins/a/b/c.toml': utf8.encode('id = 1'),
        }),
      );

      expect(files.keys.toList()..sort(), ['plugins/a/b/c.toml', 'repo.toml']);
    });

    test('an already flat archive is left alone', () {
      final files = PluginRepoSource.readRepoArchive(
        tarGz({'repo.toml': utf8.encode('schema = 1')}),
      );

      expect(files.keys, ['repo.toml']);
    });

    test('what is not a readable tarball', () {
      expect(
        () => PluginRepoSource.readRepoArchive(utf8.encode('hello')),
        throwsA(isA<PluginRepoError>()),
      );
    });

    /// A tarball is an untrusted archive: a small one can claim a great deal.
    test('an entry larger than the cap is refused', () {
      expect(
        () => PluginRepoSource.readRepoArchive(
          tarGz({
            'big': List.filled(PluginRepoSource.maxEntryBytes + 1, 0x61),
          }),
        ),
        throwsA(isA<PluginRepoError>()),
      );
    });

    test('a path that escapes is refused', () {
      expect(
        () => PluginRepoSource.readRepoArchive(
          tarGz({'../outside': utf8.encode('x')}),
        ),
        throwsA(isA<PluginRepoError>()),
      );
    });
  });

  group('installing from one', () {
    const inRepo = PluginRelease(
      version: '1.0.0',
      abi: 1,
      path: 'packages/x.sbp',
      sha256: _someDigest,
    );

    PluginIndex indexWith(Map<String, Uint8List> packages) =>
        PluginIndex(plugins: const [], packages: packages);

    test('a package the tree carried is taken from it, with no request', () async {
      final bytes = utf8.encode('a package');
      final release = PluginRelease(
        version: '1.0.0',
        abi: 1,
        path: 'packages/x.sbp',
        sha256: PluginDigest.of(bytes),
      );

      final download = await PluginRepoSource().download(
        release,
        from: indexWith({'packages/x.sbp': Uint8List.fromList(bytes)}),
      );

      expect(download.bytes, bytes);
    });

    /// A file naming a package the tree does not have. Said plainly, because the
    /// alternative is a network error for an address nobody wrote.
    test('a path the tree does not carry says so', () async {
      await expectLater(
        PluginRepoSource().download(inRepo, from: indexWith(const {})),
        throwsA(
          isA<PluginRepoError>().having(
            (e) => e.message,
            'message',
            contains('does not carry'),
          ),
        ),
      );
    });

    test('a package with no digest is not installed by default', () async {
      // Refused before anything is read: there is nothing to check it against,
      // and asking afterwards would mean the bytes are already here.
      await expectLater(
        PluginRepoSource().download(
          const PluginRelease(version: '1.0.0', abi: 1, path: 'packages/x.sbp'),
          from: indexWith(const {}),
        ),
        throwsA(
          isA<PluginTrustRefused>()
              .having((e) => e.issue, 'issue', PluginTrustIssue.noDigest)
              .having((e) => e.skippable, 'skippable', isTrue),
        ),
      );
    });

    test('bytes that are not the ones named are refused', () async {
      await expectLater(
        PluginRepoSource().download(
          inRepo,
          from: indexWith({
            'packages/x.sbp': Uint8List.fromList(utf8.encode('something else')),
          }),
        ),
        throwsA(
          isA<PluginTrustRefused>().having(
            (e) => e.issue,
            'issue',
            PluginTrustIssue.digestMismatch,
          ),
        ),
      );
    });

    /// A mismatch is not an absence of assurance, it is assurance that something
    /// is wrong — so there is no answer the user could give.
    test('a mismatch is not skippable', () {
      const refusal = PluginTrustRefused(PluginTrustIssue.digestMismatch);

      expect(refusal.skippable, isFalse);
    });

    test('a package served from elsewhere has to be https', () async {
      await expectLater(
        PluginRepoSource().download(
          const PluginRelease(
            version: '1',
            abi: 1,
            url: 'http://example.invalid/p.sbp',
            sha256: _someDigest,
          ),
        ),
        throwsA(isA<PluginRepoError>()),
      );
    });
  });

  group('the digest', () {
    test('it is the sha256 of the bytes, lowercase hex', () {
      // `echo -n abc | shasum -a 256`
      expect(
        PluginDigest.of(utf8.encode('abc')),
        'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad',
      );
    });

    test('it matches the bytes it names and nothing else', () {
      final bytes = utf8.encode('a plugin');
      final digest = PluginDigest.of(bytes);

      expect(PluginDigest.matches(digest, bytes), isTrue);
      expect(PluginDigest.matches(digest.toUpperCase(), bytes), isTrue);
      expect(PluginDigest.matches(digest, utf8.encode('a plugin ')), isFalse);
      expect(PluginDigest.matches('short', bytes), isFalse);
      expect(PluginDigest.matches('', bytes), isFalse);
    });

    /// A release with no digest is not an inconvenience to route around — it is
    /// the case where nothing about the bytes is checked at all, and the only
    /// honest thing is to say so before asking.
    test('a release says whether it can be verified', () {
      final index = PluginIndex.fromFiles(
        _repo({
          'plugins/a/b/c.toml': _plugin(
            'a.b.c',
            versions: [
              _version('1.0.0', 1),
              _version('1.1.0', 1, sha256: null),
              _version('1.2.0', 1, sha256: 'not-a-digest'),
            ],
          ),
        }),
      );
      final releases = {
        for (final r in index.plugins.single.releases) r.version: r,
      };

      expect(releases['1.0.0']!.verifiable, isTrue);
      expect(releases['1.1.0']!.verifiable, isFalse);
      // Present but the wrong length is not a digest either.
      expect(releases['1.2.0']!.verifiable, isFalse);
    });
  });
}
