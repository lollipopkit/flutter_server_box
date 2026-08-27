/// `horizonVirtKey`, a switch, becoming `virtKeyRows`, a count.
///
/// Two things have to hold. Somebody who had the switch on keeps a one-row
/// strip, and somebody who did not keeps all their rows — which means the step
/// writing nothing at all for them, since a key absent from the store is what
/// reads as 0.
library;

import 'package:fl_lib/fl_lib.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/data/store/migrations/m011_virt_key_rows.dart';
import 'package:server_box/data/store/setting.dart';

void main() {
  late SettingStore store;
  late VirtKeyRowsMigration migration;

  setUp(() {
    SqliteDb.openInMemory();
    store = SettingStore('setting_test');
    migration = VirtKeyRowsMigration(store: store);
  });

  tearDown(SqliteDb.close);

  test('it is the step that follows the one before it', () {
    expect(migration.from, 11);
  });

  test('the switch on becomes one row', () async {
    store.set(VirtKeyRowsMigration.legacyKey, true);

    await migration.apply();

    expect(store.get<int>('virtKeyRows'), 1);
  });

  test('the switch off writes nothing, which reads as all of them', () async {
    store.set(VirtKeyRowsMigration.legacyKey, false);

    await migration.apply();

    expect(store.get<int>('virtKeyRows'), isNull);
    expect(store.virtKeyRows.fetch(), 0);
  });

  test('an install that never held the key is left alone', () async {
    await migration.apply();

    expect(store.get<int>('virtKeyRows'), isNull);
  });

  /// A second pass is what a process stopped between `apply` and the version
  /// being recorded comes back to.
  test('running it again changes nothing', () async {
    store.set(VirtKeyRowsMigration.legacyKey, true);
    await migration.apply();
    store.set('virtKeyRows', 3);

    await migration.apply();

    expect(store.get<int>('virtKeyRows'), 3);
  });
}
