/// The repositories a device reads, as they are stored.
///
/// Two things here decide behaviour rather than presentation: the URL is the
/// key, and the order rows come back in is what settles a conflict between two
/// repositories offering the same plugin.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/data/model/plugin/repo_record.dart';
import 'package:server_box/data/provider/plugin/repo_source.dart';
import 'package:server_box/data/res/store.dart';
import 'package:server_box/data/store/migrations/all.dart';
import 'package:server_box/data/store/plugin.dart';
import 'package:server_box/data/store/schema.dart';
import 'package:server_box/data/store/setting.dart';

import 'helpers/test_db.dart';

void main() {
  late PluginRepoStore store;

  setUp(() async {
    await openTestDb();
    store = PluginRepoStore();
  });

  tearDown(closeTestDb);

  PluginRepoRecord repo(String url, {DateTime? at, String? name}) =>
      PluginRepoRecord(
        url: url,
        name: name,
        addedAt: at ?? DateTime(2026, 1, 1),
      );

  test('the migration is registered and the version moved with it', () {
    // Both halves, because neither is visible in the step's own test: missing
    // the version leaves every install on the old one with a green suite, and
    // missing the list throws at launch on a user's device.
    expect(SchemaVersion.current, 25);
    // The step's `from` is the version it migrates *from*, so 24. Numbering it
    // 25 leaves a gap, and the only place that shows is a `StateError` at
    // launch on a device that already had the app.
    expect(kSchemaMigrations.map((m) => m.from), contains(24));
    // And no gap between the earliest step and `current`. The run is checked
    // from wherever it actually begins rather than from 1: v1 is what
    // `createTables` produces, so nothing migrates *to* it.
    final froms = kSchemaMigrations.map((m) => m.from).toSet();
    final first = froms.reduce((a, b) => a < b ? a : b);
    expect(
      froms,
      {for (var v = first; v < SchemaVersion.current; v++) v},
      reason: 'the steps and `current` disagree somewhere',
    );
  });

  test('a repository is kept by url, and re-adding updates it', () {
    store.put(repo('https://a.example/index.json'));
    store.put(
      repo('https://a.example/index.json', at: DateTime(2027), name: 'A'),
    );

    final all = store.readAll();
    expect(all, hasLength(1));
    expect(all.single.name, 'A');
    // `added_at` is not overwritten: it is what decides which repository wins
    // when two offer the same plugin, and re-adding is not being added again.
    expect(all.single.addedAt, DateTime(2026, 1, 1));
  });

  test('they come back oldest first, which is what settles a conflict', () {
    store.put(repo('https://b.example/index.json', at: DateTime(2026, 3)));
    store.put(repo('https://a.example/index.json', at: DateTime(2026, 1)));

    expect(
      store.readAll().map((r) => r.url),
      ['https://a.example/index.json', 'https://b.example/index.json'],
    );
  });

  /// Switched off rather than removed: turning it back on should not mean
  /// typing the URL again.
  test('disabling keeps the row', () {
    store.put(repo('https://a.example/index.json'));

    store.setEnabled('https://a.example/index.json', false);

    expect(store.readAll().single.enabled, isFalse);
    store.remove('https://a.example/index.json');
    expect(store.readAll(), isEmpty);
  });

  group('what to show and when to fetch', () {
    test('what it calls itself wins', () {
      expect(
        repo('https://github.com/a/b', name: 'ServerBox plugins').label,
        'ServerBox plugins',
      );
      // A name that is blank is not a name.
      expect(repo('https://github.com/a/b', name: '  ').label, 'a/b');
    });

    /// **Not the host.** A repository is a git repository, nearly all of them
    /// are on github.com, and a list of them all read "github.com" — which is
    /// the address's least distinguishing part. Homebrew names a tap the same
    /// way.
    test('one that has not answered is named the way a tap is', () {
      const cases = {
        'https://github.com/lollipopkit/serverbox-plugins':
            'lollipopkit/serverbox-plugins',
        'https://github.com/lollipopkit/serverbox-plugins/':
            'lollipopkit/serverbox-plugins',
        'https://github.com/lollipopkit/serverbox-plugins.git':
            'lollipopkit/serverbox-plugins',
        'https://codeberg.org/someone/plugins': 'someone/plugins',
        // The archive form the app also accepts, so pasting one does not
        // produce a repository called `archive/HEAD.tar.gz`.
        'https://github.com/a/b/archive/HEAD.tar.gz': 'a/b',
        // With one segment the host is what identifies it, so it stays.
        'https://example.com/plugins.tar.gz': 'example.com/plugins.tar.gz',
        'https://example.com': 'example.com',
      };

      cases.forEach((url, expected) {
        expect(repo(url).label, expected, reason: url);
      });
    });

    /// Paced rather than fetched on every visit: an index changes when
    /// somebody publishes, which is not often.
    test('never fetched is stale, and a day old is stale', () {
      final now = DateTime(2026, 6, 1, 12);
      final never = repo('https://a.example/i.json');

      expect(never.staleAt(now), isTrue);
      expect(
        never.copyWith(lastFetchedAt: now.subtract(const Duration(hours: 1)))
            .staleAt(now),
        isFalse,
      );
      expect(
        never.copyWith(lastFetchedAt: now.subtract(const Duration(hours: 25)))
            .staleAt(now),
        isTrue,
      );
    });
  });

  group('the repository this build ships with', () {
    late SettingStore setting;

    setUp(() {
      setting = SettingStore('setting_test');
      getIt.registerSingleton<SettingStore>(setting);
    });

    tearDown(getIt.reset);

    test('every official address is https, and resolves to a tree', () {
      expect(PluginRepoStore.officialUrls, isNotEmpty);
      for (final url in PluginRepoStore.officialUrls) {
        // The app refuses a repository over plain http, so a seeded one that
        // was not https would be a row that can never be read.
        expect(Uri.parse(url).scheme, 'https', reason: url);
        // And the address has to be one the fetcher can turn into an archive:
        // what is seeded is a repository, not a file in one.
        final archive = Uri.parse(PluginRepoSource.archiveUrlOf(url));
        expect(archive.scheme, 'https', reason: url);
        expect(archive.path, endsWith('.tar.gz'), reason: url);
      }
    });

    test('it is added once, and adding it again is not a second row', () {
      store.seedOfficial();
      final first = store.readAll();
      expect(first.map((r) => r.url), PluginRepoStore.officialUrls);

      store.seedOfficial();

      expect(store.readAll().map((r) => r.url), first.map((r) => r.url));
    });

    /// The reason this is recorded per URL rather than as one flag. Removing a
    /// repository has to stick, and an empty list is exactly what removing the
    /// only one looks like — so "seed when empty" would put it back on the next
    /// launch, every launch.
    test('one the user removed stays removed', () {
      store.seedOfficial();
      store.remove(PluginRepoStore.officialUrls.single);

      store.seedOfficial();

      expect(store.readAll(), isEmpty);
    });

    /// The other half of the same decision: a later build that adds a second
    /// official repository has to be able to add it, which a bool could not
    /// express.
    test('a url this build has not seeded yet is added', () {
      setting.pluginReposSeeded.put(['https://old.example/index.json']);

      store.seedOfficial();

      expect(
        store.readAll().map((r) => r.url),
        PluginRepoStore.officialUrls,
      );
      expect(
        setting.pluginReposSeeded.fetch(),
        ['https://old.example/index.json', ...PluginRepoStore.officialUrls],
      );
    });

    test('one the user typed in first keeps when they added it', () {
      final url = PluginRepoStore.officialUrls.single;
      store.put(repo(url, at: DateTime(2020), name: 'Mine'));

      store.seedOfficial();

      final row = store.readAll().single;
      expect(row.addedAt, DateTime(2020));
      expect(row.name, 'Mine');
    });
  });
}
