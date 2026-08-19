import 'package:fl_lib/fl_lib.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/data/store/setting.dart';

void main() {
  late SettingStore store;

  setUp(() {
    SqliteDb.openInMemory();
    store = SettingStore.forTest();
  });

  tearDown(SqliteDb.close);

  test('adds Agent to the legacy default home tabs once', () async {
    store.set('homeTabs', ['server', 'ssh', 'file', 'snippet']);

    await store.migrateHomeTabsAgent();

    expect(store.get<List>('homeTabs'), [
      'server',
      'ssh',
      'file',
      'snippet',
      'agent',
    ]);
    expect(store.get<bool>('homeTabsAgentMigrated'), isTrue);
  });

  test('preserves a custom home tab configuration', () async {
    store.set('homeTabs', ['server', 'ssh']);

    await store.migrateHomeTabsAgent();

    expect(store.get<List>('homeTabs'), ['server', 'ssh']);
    expect(store.get<bool>('homeTabsAgentMigrated'), isTrue);
  });

  test('preserves home tabs that already contain Agent', () async {
    store.set('homeTabs', ['server', 'ssh', 'file', 'snippet', 'agent']);

    await store.migrateHomeTabsAgent();

    expect(store.get<List>('homeTabs'), [
      'server',
      'ssh',
      'file',
      'snippet',
      'agent',
    ]);
    expect(store.get<bool>('homeTabsAgentMigrated'), isTrue);
  });

  test('a second migration does not alter later custom tabs', () async {
    store.set('homeTabs', ['server', 'ssh', 'file', 'snippet']);
    await store.migrateHomeTabsAgent();
    store.set('homeTabs', ['server', 'agent']);

    await store.migrateHomeTabsAgent();

    expect(store.get<List>('homeTabs'), ['server', 'agent']);
    expect(store.get<bool>('homeTabsAgentMigrated'), isTrue);
  });

  test('removes retired setting keys without touching active settings', () async {
    store.setAll({
      'moveOutServerTabFuncBtns': true,
      'forceSinglePane': true,
      'recordHistory': false,
    });

    await store.removeRetiredKeys();

    expect(store.get<bool>('moveOutServerTabFuncBtns'), isNull);
    expect(store.get<bool>('forceSinglePane'), isNull);
    expect(store.get<bool>('recordHistory'), isFalse);
  });

  test('a migration flag does not count as a user edit', () async {
    await store.migrateHomeTabsAgent();

    // The Hive version wrote these straight to the box to keep them out of
    // `lastUpdateTs`. Sync compares that number, so a device that had only ever
    // run a migration would otherwise claim the newer copy.
    expect(store.lastUpdateTs, anyOf(isNull, isEmpty));
  });
}
