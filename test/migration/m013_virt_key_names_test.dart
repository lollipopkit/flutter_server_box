/// The virtual keys' order and hidden set, converted from enum indices to
/// names.
///
/// An index means a different key the moment a case is inserted into
/// [VirtKey], and these values travel through backups and sync. The conversion
/// gets one pass over a user's arrangement, so what it drops it drops for good.
library;

import 'package:fl_lib/fl_lib.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/data/model/ssh/virtual_key.dart';
import 'package:server_box/data/store/migrations/all.dart';
import 'package:server_box/data/store/migrations/m013_virt_key_names.dart';
import 'package:server_box/data/store/setting.dart';

import '../helpers/test_db.dart';

// Indices as the releases wrote them, which `VirtKey.index` stopped being when
// `clipboard` (12) left the enum.
const _esc = 0;
const _tab = 7;
const _ctrl = 8;
const _ime = 13;
const _sudo = 45;
const _tmux = 46;

void main() {
  late SettingStore store;
  late VirtKeyNamesMigration migration;

  setUp(() {
    SqliteDb.openInMemory();
    store = SettingStore.instance;
    migration = VirtKeyNamesMigration();
  });

  tearDown(closeTestDb);

  test('it is the step that follows the one before it', () {
    expect(migration.from, 13);
    // Not `SchemaVersion.current`, which this used to assert: that pins this
    // step as the newest one and fails the day another is added, which is
    // information about `all.dart` rather than about this migration.
    // `schema_migration_list_test.dart` is where the chain as a whole is
    // checked.
    expect(
      kSchemaMigrations.where((m) => m.from == migration.from + 1),
      hasLength(1),
    );
  });

  test('the order comes across as the same keys, in the same places', () async {
    const order = [VirtKey.tab, VirtKey.ctrl, VirtKey.esc];
    store.set(
      VirtKeyNamesMigration.orderKey,
      [_tab, _ctrl, _esc],
    );

    await migration.apply();

    expect(store.sshVirtKeys.fetch(), order.map((e) => e.name).toList());
  });

  test('an index past the removed clipboard key is still its own key', () async {
    store.set(VirtKeyNamesMigration.orderKey, [_ime, 12, _tmux]);

    await migration.apply();

    // `clipboard` comes across by name, and is dropped where every name this
    // build has no case for is: by [VirtKeyX.loadFromStore].
    expect(store.sshVirtKeys.fetch(), ['ime', 'clipboard', 'tmux']);
  });

  test('a name among the indices is kept, even one this build lacks', () async {
    store.set(VirtKeyNamesMigration.orderKey, ['aNewerKey', _tab, 'esc']);

    await migration.apply();

    expect(store.sshVirtKeys.fetch(), ['aNewerKey', 'tab', 'esc']);
  });

  test('and so does the hidden set', () async {
    store.set(VirtKeyNamesMigration.disabledKey, [_sudo]);

    await migration.apply();

    expect(store.sshVirtKeysDisabled.fetch(), [VirtKey.sudo.name]);
  });

  test('an index no case answers to is dropped, not guessed at', () async {
    store.set(VirtKeyNamesMigration.orderKey, [
      _tab,
      VirtKey.values.length + 3,
      -1,
      _ctrl,
    ]);

    await migration.apply();

    expect(store.sshVirtKeys.fetch(), [VirtKey.tab.name, VirtKey.ctrl.name]);
  });

  test('and a repeat is dropped, keeping the first', () async {
    store.set(VirtKeyNamesMigration.orderKey, [
      _tab,
      _ctrl,
      _tab,
    ]);

    await migration.apply();

    expect(store.sshVirtKeys.fetch(), [VirtKey.tab.name, VirtKey.ctrl.name]);
  });

  test('an install that never arranged them is left alone', () async {
    await migration.apply();

    expect(store.get<Object>(VirtKeyNamesMigration.orderKey), isNull);
    // Which reads as the default, not as an empty strip.
    expect(store.sshVirtKeys.fetch(), VirtKeyX.defaultOrder.map((e) => e.name));
  });

  /// A second pass is what a process stopped between `apply` and the version
  /// being recorded comes back to.
  test('running it again changes nothing', () async {
    store.set(VirtKeyNamesMigration.orderKey, [_tab]);
    await migration.apply();

    await migration.apply();

    expect(store.sshVirtKeys.fetch(), [VirtKey.tab.name]);
  });

  test('a list half converted by an interrupted write is finished', () async {
    // Two writes, so a crash between them leaves one key converted.
    store.set(VirtKeyNamesMigration.orderKey, [
      VirtKey.tab.name,
      _ctrl,
    ]);

    await migration.apply();

    expect(store.sshVirtKeys.fetch(), [VirtKey.tab.name, VirtKey.ctrl.name]);
  });

  test('none of it counts as a user edit', () async {
    // Sync compares this number, so a device that had only ever run a
    // migration would otherwise claim the newer copy of everything.
    store.set(VirtKeyNamesMigration.orderKey, [
      _tab,
    ], updateLastUpdateTsOnSet: false);
    final before = store.lastUpdateTs;

    await migration.apply();

    expect(store.lastUpdateTs, before);
  });
}
