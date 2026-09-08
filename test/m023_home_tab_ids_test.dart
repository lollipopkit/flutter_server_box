/// The home bar's row, converted to ids.
///
/// `homeTabs` accepted an `AppTab`, its name, or its `@HiveField` index, and
/// every reader ran the row back through the enum. A plugin's tab is not a
/// case of it, so the row had to stop being typed by it before one could be
/// arranged at all.
///
/// The conversion gets one pass over a user's arrangement, so what it drops it
/// drops for good — and this row is how every page in the app is reached.
///
/// The int-to-name path is also covered against bytes a released build really
/// wrote: `test/hive_release_migration_test.dart` asserts `['server', 'ssh',
/// 'snippet']` out of the v1.0.1466 fixture. What is here is the branches a
/// fixture does not reach.
library;

import 'package:fl_lib/fl_lib.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/data/model/app/tab.dart';
import 'package:server_box/data/store/migrations/all.dart';
import 'package:server_box/data/store/migrations/m023_home_tab_ids.dart';
import 'package:server_box/data/store/setting.dart';
import 'package:server_box/hive/legacy_adapters.dart';

void main() {
  late SettingStore store;
  late HomeTabIdsMigration migration;

  setUp(() {
    SqliteDb.openInMemory();
    store = SettingStore('setting_test');
    migration = HomeTabIdsMigration(store: store);
  });

  tearDown(SqliteDb.close);

  List<String>? stored() => store.get<List>(HomeTabIdsMigration.key)?.cast();

  test('it is the step that follows the one before it', () {
    expect(migration.from, 23);
    expect(
      kSchemaMigrations.where((m) => m.from == migration.from - 1),
      hasLength(1),
    );
  });

  /// The table it converts with, against the enum as it stood when the
  /// conversion was written. This is the *only* moment the two are allowed to
  /// agree: after it the declaration order is free and the table is frozen,
  /// which is the point of the step.
  test('the frozen table describes the order the released builds wrote', () {
    expect(kLegacyAppTabIds, [
      'server',
      'ssh',
      'file',
      'snippet',
      'agent',
      'benchmark',
    ]);
    // `pkg` is deliberately absent: no build that stored an integer had it.
    expect(kLegacyAppTabIds, isNot(contains(AppTab.pkg.name)));
  });

  test('an index becomes the name that index meant', () {
    store.set(HomeTabIdsMigration.key, [0, 4, 2]);

    migration.applySync();

    expect(stored(), ['server', 'agent', 'file']);
  });

  /// A row half-written by a crash, and a row a newer build already converted.
  test('a name is left as it is, and the two may be mixed', () {
    store.set(HomeTabIdsMigration.key, ['server', 1, 'agent']);

    migration.applySync();

    expect(stored(), ['server', 'ssh', 'agent']);
  });

  /// A second pass is what a process stopped between this returning and the
  /// version being recorded comes back to.
  test('running it twice changes nothing', () {
    store.set(HomeTabIdsMigration.key, [0, 1]);

    migration.applySync();
    final once = stored();
    migration.applySync();

    expect(stored(), once);
  });

  /// The row is an arrangement, and one entry twice has no meaning — an index
  /// and its own name in the same row is how that happens.
  test('a repeat is dropped', () {
    store.set(HomeTabIdsMigration.key, [0, 'server', 1]);

    migration.applySync();

    expect(stored(), ['server', 'ssh']);
  });

  /// An entry this build has no tab for is a row every later writer copies
  /// forward for nothing.
  test('an unknown entry is dropped rather than carried', () {
    store.set(HomeTabIdsMigration.key, [0, 99, 'nosuchtab', null]);

    migration.applySync();

    expect(stored(), ['server']);
  });

  /// The failure that would matter most: the bar is how every page is reached,
  /// so a row that converted to nothing has to come back as the default rather
  /// than as an install with no way anywhere.
  test('a row that converts to nothing falls back to the default bar', () {
    store.set(HomeTabIdsMigration.key, [98, 99]);

    migration.applySync();

    expect(stored(), AppTab.defaultOrder.map((e) => e.name).toList());
    expect(stored(), isNotEmpty);
  });

  test('a key that was never written is left alone', () {
    migration.applySync();

    expect(stored(), isNull);
  });

  /// A conversion the app performs on its own is not an edit the user made.
  /// Counting it as one has every install claim a newer copy than whatever it
  /// last synced with.
  test('it does not stamp the row as a user edit', () {
    store.set(HomeTabIdsMigration.key, [0, 1]);
    final before = store.lastUpdateTs;

    migration.applySync();

    expect(store.lastUpdateTs, before);
  });
}
