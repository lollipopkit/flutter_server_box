import 'package:fl_lib/fl_lib.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/data/model/app/tab.dart';
import 'package:server_box/data/store/migrations/all.dart';
import 'package:server_box/data/store/migrations/m021_home_tabs_bar.dart';
import 'package:server_box/data/store/schema.dart';
import 'package:server_box/data/store/setting.dart';

void main() {
  late SettingStore store;
  late HomeTabsBarMigration migration;

  setUp(() {
    SqliteDb.openInMemory();
    store = SettingStore('setting_test');
    migration = HomeTabsBarMigration(store: store);
  });

  tearDown(SqliteDb.close);

  test('is registered as the step after the current schema', () {
    expect(migration.from, 21);
    // Relative, not absolute: pinning this as the newest step fails the day
    // another is added. See `m013_virt_key_names_test.dart`.
    expect(SchemaVersion.current, greaterThan(migration.from));
    expect(
      kSchemaMigrations.where((m) => m.from == migration.from),
      hasLength(1),
    );
  });

  test('moves the last item from the old five-tab arrangement', () async {
    store.set('homeTabs', [
      AppTab.server.name,
      AppTab.ssh.name,
      AppTab.file.name,
      AppTab.agent.name,
      AppTab.snippet.name,
    ]);

    await migration.apply();

    expect(store.get<List>('homeTabs'), [
      AppTab.server.name,
      AppTab.ssh.name,
      AppTab.file.name,
      AppTab.agent.name,
    ]);
  });

  test('preserves the stored order while moving its last item', () async {
    store.set('homeTabs', [
      AppTab.snippet.name,
      AppTab.file.name,
      AppTab.agent.name,
      AppTab.server.name,
      AppTab.ssh.name,
    ]);

    await migration.apply();

    expect(store.get<List>('homeTabs'), [
      AppTab.snippet.name,
      AppTab.file.name,
      AppTab.agent.name,
      AppTab.server.name,
    ]);
  });

  test('does not change a custom arrangement or a newer tab set', () async {
    final custom = [AppTab.server.name, AppTab.ssh.name];
    store.set('homeTabs', custom);
    await migration.apply();
    expect(store.get<List>('homeTabs'), custom);

    final newer = [
      AppTab.server.name,
      AppTab.ssh.name,
      AppTab.file.name,
      AppTab.agent.name,
      AppTab.benchmark.name,
    ];
    store.set('homeTabs', newer);
    await migration.apply();
    expect(store.get<List>('homeTabs'), newer);
  });

  test('is idempotent', () async {
    store.set('homeTabs', [
      AppTab.server.name,
      AppTab.ssh.name,
      AppTab.file.name,
      AppTab.agent.name,
      AppTab.snippet.name,
    ]);

    await migration.apply();
    await migration.apply();

    expect(store.get<List>('homeTabs'), [
      AppTab.server.name,
      AppTab.ssh.name,
      AppTab.file.name,
      AppTab.agent.name,
    ]);
  });
}
