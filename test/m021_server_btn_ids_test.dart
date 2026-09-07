/// The server function bar's row, converted from enum indices to ids.
///
/// An index means a different entry the moment a case moves in
/// [ServerFuncBtn], and this row travels through backups and sync. The
/// conversion gets one pass over a user's arrangement, so what it drops it
/// drops for good.
library;

import 'package:fl_lib/fl_lib.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/data/model/app/menu/server_func.dart';
import 'package:server_box/data/store/migrations/all.dart';
import 'package:server_box/data/store/migrations/m021_server_btn_ids.dart';
import 'package:server_box/data/store/setting.dart';
import 'package:server_box/hive/legacy_adapters.dart';

void main() {
  late SettingStore store;
  late ServerBtnIdsMigration migration;

  setUp(() {
    SqliteDb.openInMemory();
    store = SettingStore('setting_test');
    migration = ServerBtnIdsMigration(store: store);
  });

  tearDown(SqliteDb.close);

  test('it is the step that follows the one before it', () {
    expect(migration.from, 21);
    expect(
      kSchemaMigrations.where((m) => m.from == migration.from - 1),
      hasLength(1),
    );
  });

  /// The table it converts with, against the enum as it stood when the
  /// conversion was written. This is the *only* moment the two are allowed to
  /// agree: after it, the declaration order is free and the table is frozen,
  /// which is the whole point of the step.
  test('the frozen table describes the order the released builds wrote', () {
    expect(kLegacyServerFuncBtnIds, [
      'terminal',
      'files',
      'container',
      'process',
      'snippet',
      'iperf',
      'systemd',
      'portForward',
      'power',
    ]);
    // And every one of them is still an entry, or a stored row would lose it.
    final known = ServerFuncBtn.values.map((e) => e.id).toSet();
    expect(known, containsAll(kLegacyServerFuncBtnIds));
  });

  test('the row comes across as the same entries, in the same places', () {
    store.set(ServerBtnIdsMigration.key, [1, 0, 8]);

    migration.applySync();

    expect(store.serverFuncBtns.fetch(), [
      ServerFuncBtn.files.id,
      ServerFuncBtn.terminal.id,
      ServerFuncBtn.power.id,
    ]);
  });

  test('an index no entry answers to is dropped, not guessed at', () {
    store.set(ServerBtnIdsMigration.key, [
      0,
      kLegacyServerFuncBtnIds.length + 3,
      -1,
      2,
    ]);

    migration.applySync();

    expect(store.serverFuncBtns.fetch(), [
      ServerFuncBtn.terminal.id,
      ServerFuncBtn.container.id,
    ]);
  });

  test('and a repeat is dropped, keeping the first', () {
    store.set(ServerBtnIdsMigration.key, [0, 2, 0]);

    migration.applySync();

    expect(store.serverFuncBtns.fetch(), [
      ServerFuncBtn.terminal.id,
      ServerFuncBtn.container.id,
    ]);
  });

  test('an install that never arranged the row is left alone', () {
    migration.applySync();

    expect(store.get<Object>(ServerBtnIdsMigration.key), isNull);
    // Which reads as the default row, not as an empty bar.
    expect(store.serverFuncBtns.fetch(), ServerFuncBtn.defaultIds);
  });

  /// A second pass is what a process stopped between `apply` and the version
  /// being recorded comes back to.
  test('running it again changes nothing', () {
    store.set(ServerBtnIdsMigration.key, [0, 6]);
    migration.applySync();

    migration.applySync();

    expect(store.serverFuncBtns.fetch(), [
      ServerFuncBtn.terminal.id,
      ServerFuncBtn.systemd.id,
    ]);
  });

  test('a row half converted by an interrupted write is finished', () {
    store.set(ServerBtnIdsMigration.key, [ServerFuncBtn.terminal.id, 2]);

    migration.applySync();

    expect(store.serverFuncBtns.fetch(), [
      ServerFuncBtn.terminal.id,
      ServerFuncBtn.container.id,
    ]);
  });

  test('none of it counts as a user edit', () {
    // Sync compares this number, so a device that had only ever run a
    // migration would otherwise claim the newer copy of everything.
    store.set(
      ServerBtnIdsMigration.key,
      [0],
      updateLastUpdateTsOnSet: false,
    );
    final before = store.lastUpdateTs;

    migration.applySync();

    expect(store.lastUpdateTs, before);
  });
}
