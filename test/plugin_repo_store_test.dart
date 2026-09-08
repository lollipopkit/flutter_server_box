/// The repositories a device reads, as they are stored.
///
/// Two things here decide behaviour rather than presentation: the URL is the
/// key, and the order rows come back in is what settles a conflict between two
/// repositories offering the same plugin.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/data/model/plugin/repo_record.dart';
import 'package:server_box/data/store/migrations/all.dart';
import 'package:server_box/data/store/plugin.dart';
import 'package:server_box/data/store/schema.dart';

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
    test('a repository that never answered shows its host', () {
      expect(repo('https://plugins.example.com/index.json').label,
          'plugins.example.com');
      expect(repo('https://a.example/i.json', name: 'Official').label,
          'Official');
      // A name that is blank is not a name.
      expect(repo('https://a.example/i.json', name: '  ').label, 'a.example');
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

  /// Until a repository is actually published, the honest state is that this
  /// app knows none — a row pointing at an address that answers nothing looks
  /// broken, where an empty list is true.
  test('no repository is seeded', () {
    expect(PluginRepoStore.officialUrls, isEmpty);
    expect(store.readAll(), isEmpty);
  });
}
