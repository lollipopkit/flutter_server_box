/// The settings fixups, now that they are a schema step rather than two
/// methods each gating themselves on a flag key of their own.
///
/// Both bodies are idempotent against data they have already converted, but
/// that is not the whole of it: somebody who took Agent back out of their home
/// tabs holds exactly the legacy four again, and the flag is the only thing
/// that tells "never offered" from "offered and declined".
library;

import 'package:fl_lib/fl_lib.dart';
import 'package:fl_lib/fl_lib.dart' as lib show isMacOS;
import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/data/store/migrations/m008_settings_fixups.dart';
import 'package:server_box/data/store/setting.dart';

void main() {
  late SettingStore store;
  late SettingsFixupsMigration migration;

  setUp(() {
    SqliteDb.openInMemory();
    store = SettingStore.forTest();
    migration = SettingsFixupsMigration(store: store);
  });

  tearDown(SqliteDb.close);

  test('it is the step that follows the one before it', () {
    // A gap between `from` and `SchemaVersion.current` is a launch that throws
    // `Missing schema migration`, and an overlap is a step that never runs.
    expect(migration.from, 8);
  });

  group('home tabs', () {
    test('adds Agent to the legacy default set', () async {
      store.set('homeTabs', ['server', 'ssh', 'file', 'snippet']);

      await migration.apply();

      expect(store.get<List>('homeTabs'), [
        'server',
        'ssh',
        'file',
        'snippet',
        'agent',
      ]);
    });

    test('leaves a custom configuration alone', () async {
      store.set('homeTabs', ['server', 'ssh']);

      await migration.apply();

      expect(store.get<List>('homeTabs'), ['server', 'ssh']);
    });

    test('leaves a set that already contains Agent alone', () async {
      store.set('homeTabs', ['server', 'ssh', 'file', 'snippet', 'agent']);

      await migration.apply();

      expect(store.get<List>('homeTabs'), [
        'server',
        'ssh',
        'file',
        'snippet',
        'agent',
      ]);
    });

    test('does not put Agent back after somebody removed it', () async {
      // The case the flag exists for. The tab set is the legacy four again, so
      // the body alone cannot tell this apart from an install that was never
      // offered Agent — and re-adding it would overrule a deliberate choice.
      store.set('homeTabsAgentMigrated', true);
      store.set('homeTabs', ['server', 'ssh', 'file', 'snippet']);

      await migration.apply();

      expect(store.get<List>('homeTabs'), [
        'server',
        'ssh',
        'file',
        'snippet',
      ]);
    });

    test('and running the step twice is the same as running it once', () async {
      store.set('homeTabs', ['server', 'ssh', 'file', 'snippet']);
      await migration.apply();
      // The flag is gone by now, so the second pass is carried entirely by the
      // body's own idempotence.
      expect(store.get<bool>('homeTabsAgentMigrated'), isNull);

      await migration.apply();

      expect(store.get<List>('homeTabs'), [
        'server',
        'ssh',
        'file',
        'snippet',
        'agent',
      ]);
    });
  });

  group('sshConnectionMode', () {
    test('0 was the built-in client', () async {
      store.set('sshConnectionMode', 0);

      await migration.apply();

      expect(store.get<bool>('sshConnectionMode'), isFalse);
    });

    test('1 was the system one', () async {
      store.set('sshConnectionMode', 1);

      await migration.apply();

      expect(store.get<bool>('sshConnectionMode'), isTrue);
    });

    test('-1 was auto, which is per platform', () async {
      store.set('sshConnectionMode', -1);

      await migration.apply();

      expect(store.get<bool>('sshConnectionMode'), !lib.isMacOS);
    });

    test('a value already converted is left as it is', () async {
      store.set('sshConnectionMode', true);

      await migration.apply();

      expect(store.get<bool>('sshConnectionMode'), isTrue);
    });

    test('an install that already ran the flag version is not touched', () async {
      store.set('sshConnectionModeMigrated', true);
      store.set('sshConnectionMode', 0);

      await migration.apply();

      // Still the int it was: the flag says this device has had its pass.
      expect(store.get<Object>('sshConnectionMode'), 0);
    });

    test('nothing stored is nothing to do', () async {
      await migration.apply();

      expect(store.get<Object>('sshConnectionMode'), isNull);
    });
  });

  test('the flags are removed once they have been read', () async {
    store.set('homeTabsAgentMigrated', true);
    store.set('sshConnectionModeMigrated', true);

    await migration.apply();

    // One key per fixup, each exported by a backup and read by nothing else.
    expect(store.get<bool>('homeTabsAgentMigrated'), isNull);
    expect(store.get<bool>('sshConnectionModeMigrated'), isNull);
  });

  test('none of it counts as a user edit', () async {
    store.set('homeTabs', [
      'server',
      'ssh',
      'file',
      'snippet',
    ], updateLastUpdateTsOnSet: false);
    store.set('sshConnectionMode', 0, updateLastUpdateTsOnSet: false);

    await migration.apply();

    // Sync compares this number, so a device that had only ever run a
    // migration would otherwise claim the newer copy of everything.
    expect(store.lastUpdateTs, anyOf(isNull, isEmpty));
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
}
