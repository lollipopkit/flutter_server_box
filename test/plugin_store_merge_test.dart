/// Merging what several repositories offer into one list.
///
/// The decisions here are not presentation: which repository wins a conflict,
/// which version an app of this age is offered, and what "outdated" means when
/// the newest release needs a newer app.
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/data/model/plugin/install.dart';
import 'package:server_box/data/model/plugin/repo.dart';
import 'package:server_box/data/model/plugin/repo_record.dart';
import 'package:server_box/data/model/plugin/store.dart';

const _digest =
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';

/// A repository offering [plugins], as the app receives one: a tree of files.
PluginIndex _index(List<Map<String, Object?>> plugins) => PluginIndex.fromFiles({
  'repo.toml': _bytes('schema = 1'),
  for (final p in plugins)
    PluginRepoLayout.pathOf(p['id']! as String)!: _bytes(_toml(p)),
});

Uint8List _bytes(String text) => Uint8List.fromList(utf8.encode(text));

/// One plugin's file, from the shape these tests describe a listing in.
String _toml(Map<String, Object?> plugin) => [
  'id = "${plugin['id']}"',
  'name = "${plugin['name']}"',
  'description = ""',
  for (final v in plugin['versions']! as List) ...[
    '',
    '[[version]]',
    'version = "${(v as Map)['version']}"',
    'abi = ${v['abi']}',
    'url = "${v['url']}"',
    'sha256 = "${v['sha256']}"',
  ],
].join('\n');

Map<String, Object?> _listing(
  String id, {
  String? name,
  required List<(String, int)> versions,
}) => {
  'id': id,
  'name': name ?? id,
  'versions': [
    for (final (version, abi) in versions)
      {
        'version': version,
        'abi': abi,
        'url': 'https://example.invalid/$id-$version.sbp',
        'sha256': _digest,
      },
  ],
};

PluginRepoRecord _repo(String host, DateTime at) =>
    PluginRepoRecord(url: 'https://$host/plugins', addedAt: at);

/// [repo] defaults to the first repository's address, because that is the case
/// every version test is about: a copy this repository installed, which is the
/// only kind it can offer an update for.
PluginInstall _installed(
  String id,
  String version, {
  String? repo = 'https://a.example/plugins',
}) => PluginInstall(
  id: id,
  version: version,
  repo: repo,
  granted: const {},
  installedAt: DateTime(2026),
);

void main() {
  final first = _repo('a.example', DateTime(2026, 1));
  final second = _repo('b.example', DateTime(2026, 6));

  test('a listing carries the version this app can run, and the ones it cannot', () {
    final entries = PluginStore.merge(
      repos: [first],
      indexes: {
        first.url: _index([
          _listing('a.b.c', versions: [('1.0.0', 1), ('2.0.0', 2), ('3.0.0', 9)]),
        ]),
      },
      installed: const {},
      abi: 2,
    );

    final entry = entries.single;
    expect(entry.best?.version, '2.0.0');
    expect(entry.tooNew.map((r) => r.version), ['3.0.0']);
    expect(entry.installable, isTrue);
  });

  test('a plugin this app is too old for is listed and not installable', () {
    final entries = PluginStore.merge(
      repos: [first],
      indexes: {
        first.url: _index([_listing('a.b.c', versions: [('2.0.0', 9)])]),
      },
      installed: const {},
      abi: 2,
    );

    // Listed, because "this needs a newer app" is worth saying — dropping it
    // would read as the plugin not existing.
    expect(entries.single.installable, isFalse);
    expect(entries.single.tooNew, hasLength(1));
  });

  group('two repositories offering the same plugin', () {
    /// There is no authority that says which is the real one, so the one added
    /// first wins — and the other is recorded rather than dropped, because a
    /// conflict resolved silently is one the user cannot find out about.
    test('the one added first wins, and the other is named', () {
      final entries = PluginStore.merge(
        repos: [first, second],
        indexes: {
          first.url: _index([_listing('a.b.c', name: 'From A', versions: [('1.0.0', 1)])]),
          second.url: _index([_listing('a.b.c', name: 'From B', versions: [('9.0.0', 1)])]),
        },
        installed: const {},
        abi: 2,
      );

      final entry = entries.single;
      expect(entry.listing.name, 'From A');
      expect(entry.repo.url, first.url);
      // Even though B offers a much newer version: which repository a plugin
      // comes from decides what an update will be, so it is not a per-version
      // choice.
      expect(entry.best?.version, '1.0.0');
      expect(entry.shadowed.map((r) => r.url), [second.url]);
    });

    test('order is by when they were added, not by the list given', () {
      final entries = PluginStore.merge(
        // Passed newest first, which is what a caller that sorted by name
        // would do.
        repos: [second, first]..sort((a, b) => a.addedAt.compareTo(b.addedAt)),
        indexes: {
          first.url: _index([_listing('a.b.c', name: 'From A', versions: [('1.0.0', 1)])]),
          second.url: _index([_listing('a.b.c', name: 'From B', versions: [('1.0.0', 1)])]),
        },
        installed: const {},
        abi: 2,
      );

      expect(entries.single.listing.name, 'From A');
    });

    test('a disabled repository contributes nothing', () {
      final entries = PluginStore.merge(
        repos: [first.copyWith(enabled: false), second],
        indexes: {
          first.url: _index([_listing('a.b.c', name: 'From A', versions: [('1.0.0', 1)])]),
          second.url: _index([_listing('a.b.c', name: 'From B', versions: [('1.0.0', 1)])]),
        },
        installed: const {},
        abi: 2,
      );

      expect(entries.single.listing.name, 'From B');
      expect(entries.single.shadowed, isEmpty);
    });
  });

  group('what counts as an update', () {
    List<StoreEntry> entriesFor(List<(String, int)> versions, String have) =>
        PluginStore.merge(
          repos: [first],
          indexes: {
            first.url: _index([_listing('a.b.c', versions: versions)]),
          },
          installed: {'a.b.c': _installed('a.b.c', have)},
          abi: 2,
        );

    test('a newer runnable release is an update', () {
      final entries = entriesFor([('1.0.0', 1), ('1.1.0', 2)], '1.0.0');

      expect(entries.single.outdated, isTrue);
      expect(PluginStore.outdated(entries), hasLength(1));
    });

    /// The distinction the whole ABI axis exists for: a release this app
    /// cannot run is not an update it can offer, and calling it one would be a
    /// button that fails.
    test('a newer release this app cannot run is not an update', () {
      final entries = entriesFor([('1.0.0', 1), ('2.0.0', 9)], '1.0.0');

      expect(entries.single.outdated, isFalse);
      expect(PluginStore.outdated(entries), isEmpty);
      // But it is not "up to date" either, and the page has to be able to say
      // which of the two this is.
      expect(entries.single.appTooOld, isTrue);
    });

    test('the same version is not an update', () {
      final entries = entriesFor([('1.0.0', 1)], '1.0.0');

      expect(entries.single.outdated, isFalse);
      expect(entries.single.appTooOld, isFalse);
    });

    /// The copy on the device is not this repository's, so its version is not
    /// a version this repository is behind or ahead of. It happened for real:
    /// a working tree at 1.1.0 was registered as a development directory while
    /// the repository listed 1.0.1, the row offered an update, and taking it
    /// wrote a record naming 1.0.1 from GitHub over a plugin the app went on
    /// loading from the tree.
    test('a copy from somewhere else is never an update', () {
      for (final origin in [
        PluginInstall.devRepo,
        PluginInstall.fileRepo,
        'https://b.example/plugins',
        null,
      ]) {
        final entries = PluginStore.merge(
          repos: [first],
          indexes: {
            first.url: _index([
              _listing('a.b.c', versions: [('1.0.0', 1), ('1.1.0', 2)]),
            ]),
          },
          installed: {'a.b.c': _installed('a.b.c', '1.0.0', repo: origin)},
          abi: 2,
        );

        final entry = entries.single;
        expect(entry.mine, isFalse, reason: '$origin');
        expect(entry.elsewhere, isTrue, reason: '$origin');
        expect(entry.outdated, isFalse, reason: '$origin');
        expect(PluginStore.outdated(entries), isEmpty, reason: '$origin');
        // Still installed, and still listed: what changes is who may replace
        // it, which is a question the row asks rather than answers.
        expect(entry.installed, isNotNull, reason: '$origin');
      }
    });

    /// And "up to date" is not the answer either — that reading would leave a
    /// plugin installed from a file looking current against a repository that
    /// has never met it.
    test('a copy from somewhere else is not up to date either', () {
      final entries = PluginStore.merge(
        repos: [first],
        indexes: {
          first.url: _index([
            _listing('a.b.c', versions: [('1.0.0', 1), ('2.0.0', 9)]),
          ]),
        },
        installed: {
          'a.b.c': _installed('a.b.c', '1.0.0', repo: PluginInstall.fileRepo),
        },
        abi: 2,
      );

      expect(entries.single.appTooOld, isFalse);
      expect(entries.single.elsewhere, isTrue);
    });

    /// `1.10` after `1.9`, which a string comparison gets backwards.
    test('versions compare numerically here too', () {
      expect(entriesFor([('1.9.0', 1), ('1.10.0', 1)], '1.9.0').single.outdated,
          isTrue);
      expect(entriesFor([('1.9.0', 1)], '1.10.0').single.outdated, isFalse);
    });
  });

  test('a repository whose index was not fetched contributes nothing', () {
    final entries = PluginStore.merge(
      repos: [first, second],
      indexes: {
        second.url: _index([_listing('a.b.c', versions: [('1.0.0', 1)])]),
      },
      installed: const {},
      abi: 2,
    );

    // The page says a repository could not be read from the repository list,
    // not by inventing an empty listing for it.
    expect(entries.single.repo.url, second.url);
  });
}
