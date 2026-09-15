import 'package:fl_lib/fl_lib.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/data/model/app/menu/server_func.dart';
import 'package:server_box/data/model/app/server_sort.dart';
import 'package:server_box/data/store/migrations/all.dart';
import 'package:server_box/data/store/migrations/m023_enum_names.dart';
import 'package:server_box/data/store/schema.dart';
import 'package:server_box/data/store/setting.dart';

/// Two settings held an enum as `Enum.index`. An index means whatever the
/// build reading it says it means, and cases have been removed from
/// `ServerFuncBtn` — each removal shifting every value after it, silently,
/// because every index still resolves to some valid case.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('the step', () {
    late SettingStore store;

    setUp(() {
      SqliteDb.openInMemory();
      store = SettingStore('setting_test');
    });

    tearDown(SqliteDb.close);

    test('is registered as the step after the current schema', () {
      final migration = EnumNamesMigration(store: store);
      expect(migration.from, 23);
      expect(SchemaVersion.current, greaterThan(migration.from));
      // Missing from the list throws `Missing schema migration from v23` at
      // launch on a device that has one, and nothing here would say so.
      expect(kSchemaMigrations.any((m) => m is EnumNamesMigration), isTrue);
      expect(
        kSchemaMigrations.last.from,
        SchemaVersion.current - 1,
        reason: 'the chain has to reach the current version',
      );
    });

    test('converts a stored button row to names', () {
      store.set(EnumNamesMigration.btnsKey, [
        ServerFuncBtn.terminal.index,
        ServerFuncBtn.container.index,
        ServerFuncBtn.power.index,
      ], updateLastUpdateTsOnSet: false);

      EnumNamesMigration(store: store).applySync();

      expect(store.get<Object>(EnumNamesMigration.btnsKey), {
        'layout': 'current',
        'values': ['terminal', 'container', 'power'],
      });
    });

    test('preserves post-feature users and scheduled tasks indexes', () {
      store.set(
        EnumNamesMigration.btnsKey,
        [9, 10],
        updateLastUpdateTsOnSet: false,
      );

      EnumNamesMigration(store: store).applySync();

      expect(store.get<Object>(EnumNamesMigration.btnsKey), {
        'layout': 'current',
        'values': [
          ServerFuncBtn.users.name,
          ServerFuncBtn.scheduledTasks.name,
        ],
      });
    });

    test('converts the sort field', () {
      store.set(
        EnumNamesMigration.sortKey,
        ServerSortField.status.index,
        updateLastUpdateTsOnSet: false,
      );

      EnumNamesMigration(store: store).applySync();

      expect(store.get<Object>(EnumNamesMigration.sortKey), 'status');
    });

    test('an index no case answers to is dropped, not shifted', () {
      // What a row written by a build with more cases looks like here. Read as
      // an index it would name whatever sits at that position; there is no
      // such entry, so it goes.
      store.set(EnumNamesMigration.btnsKey, [
        ServerFuncBtn.terminal.index,
        ServerFuncBtn.values.length + 5,
        ServerFuncBtn.files.index,
      ], updateLastUpdateTsOnSet: false);

      EnumNamesMigration(store: store).applySync();

      expect(store.get<Object>(EnumNamesMigration.btnsKey), {
        'layout': 'current',
        'values': ['terminal', 'files'],
      });
    });

    test(
      'settings decoding preserves post-feature users and scheduled tasks',
      () {
        store.set(
          EnumNamesMigration.btnsKey,
          [9, 10],
          updateLastUpdateTsOnSet: false,
        );

        expect(store.serverFuncBtns.fetch(), [
          ServerFuncBtn.users.name,
          ServerFuncBtn.scheduledTasks.name,
        ]);
      },
    );

    test('writes a current layout marker for synchronized rows', () {
      store.serverFuncBtns.put([
        ServerFuncBtn.users.name,
        ServerFuncBtn.scheduledTasks.name,
      ]);

      expect(store.get<Object>(EnumNamesMigration.btnsKey), {
        'layout': 'current',
        'values': [
          ServerFuncBtn.users.name,
          ServerFuncBtn.scheduledTasks.name,
        ],
      });
    });

    test('runs twice without changing what it wrote', () {
      store.set(EnumNamesMigration.btnsKey, [
        ServerFuncBtn.terminal.index,
      ], updateLastUpdateTsOnSet: false);

      EnumNamesMigration(store: store).applySync();
      final once = store.get<Object>(EnumNamesMigration.btnsKey);
      EnumNamesMigration(store: store).applySync();

      expect(store.get<Object>(EnumNamesMigration.btnsKey), once);
    });

    test('leaves a store that holds nothing alone', () {
      EnumNamesMigration(store: store).applySync();

      expect(store.get<Object>(EnumNamesMigration.btnsKey), isNull);
      expect(store.get<Object>(EnumNamesMigration.sortKey), isNull);
    });
  });

  group('reading either shape', () {
    test('a name and an index both resolve', () {
      expect(ServerFuncBtn.byStored('terminal'), ServerFuncBtn.terminal);
      expect(
        ServerFuncBtn.byStored(ServerFuncBtn.power.index),
        ServerFuncBtn.power,
      );
      expect(
        ServerFuncBtn.byStored(
          ServerFuncBtn.users.index,
          legacyIntegerNames: ServerFuncBtn.legacyIndexNamesBeforeM021,
        ),
        isNull,
      );
      expect(
        ServerFuncBtn.namesFromStored({
          'layout': 'preM021',
          'values': [5, 6, 7, 8],
        }),
        ['iperf', 'systemd', 'portForward', 'power'],
      );
      expect(
        ServerFuncBtn.namesFromStored({
          'layout': 'current',
          'values': [5, 6, 7, 8],
        }),
        ['iperf', 'systemd', 'portForward', 'power'],
      );
      expect(ServerFuncBtn.byStored('nothing-of-the-sort'), isNull);
      expect(ServerFuncBtn.byStored(ServerFuncBtn.values.length), isNull);
      expect(ServerFuncBtn.byStored(-1), isNull);
    });

    test('the sort field falls back rather than throwing', () {
      expect(ServerSortField.fromStored('status'), ServerSortField.status);
      expect(
        ServerSortField.fromStored(ServerSortField.name.index),
        ServerSortField.name,
      );
      expect(ServerSortField.fromStored('gone'), ServerSortField.manual);
      expect(ServerSortField.fromStored(null), ServerSortField.manual);
      expect(ServerSortField.fromStored(99), ServerSortField.manual);
    });
  });
}
