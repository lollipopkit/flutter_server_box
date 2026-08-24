/// The stored order of the terminal's virtual keys, read back.
///
/// It is a list of enum *indices*, which is the one shape that stops meaning
/// what it said when the enum changes. A backup restored from a newer build
/// carries indices this build has no case for, and there are two places that
/// turn them back into keys: the terminal, and the settings page that arranges
/// them. Both used to be wrong, in opposite directions — one threw the whole
/// order away, the other threw.
library;

import 'package:fl_lib/fl_lib.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/data/model/ssh/virtual_key.dart';
import 'package:server_box/data/res/store.dart';
import 'package:server_box/data/store/setting.dart';

import 'helpers/test_db.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    await openTestDb();
    // `loadFromStore` reads the singleton rather than a store handed to it,
    // so the singleton is what has to point at the in-memory database.
    getIt.registerSingleton<SettingStore>(SettingStore.forTest());
  });

  tearDown(() async {
    await getIt.reset();
    await SqliteDb.close();
  });

  test('an order this build knows every key of is returned as it was', () {
    const order = [VirtKey.tab, VirtKey.ctrl, VirtKey.esc];
    Stores.setting.sshVirtKeys.put(order.map((e) => e.index).toList());

    expect(VirtKeyX.loadFromStore(), order);
  });

  test('an index past the end of the enum is dropped, and the rest kept', () {
    // Written by a build with more keys than this one. Resetting to the
    // default instead — which is what it did — discards an arrangement that
    // was otherwise entirely readable.
    Stores.setting.sshVirtKeys.put([
      VirtKey.tab.index,
      VirtKey.values.length + 3,
      VirtKey.ctrl.index,
    ]);

    expect(VirtKeyX.loadFromStore(), [VirtKey.tab, VirtKey.ctrl]);
  });

  test('and what it dropped is written back, so it is not read again', () {
    Stores.setting.sshVirtKeys.put([VirtKey.esc.index, 9999]);

    VirtKeyX.loadFromStore();

    expect(Stores.setting.sshVirtKeys.fetch(), [VirtKey.esc.index]);
  });

  test('a negative index is dropped the same way', () {
    Stores.setting.sshVirtKeys.put([-1, VirtKey.esc.index]);

    expect(VirtKeyX.loadFromStore(), [VirtKey.esc]);
  });

  test('nothing readable at all falls back to the default, unsaved', () {
    // Unsaved matters: the stored value is the only record of what the user
    // arranged, and a build that cannot read it is not entitled to replace it.
    Stores.setting.sshVirtKeys.put([9998, 9999]);

    expect(VirtKeyX.loadFromStore(), VirtKeyX.defaultOrder);
    expect(Stores.setting.sshVirtKeys.fetch(), [9998, 9999]);
  });

  test('an order it can read entirely is not rewritten', () {
    // The write is the part with a cost — it stamps the store, and a settings
    // sync then carries an edit nobody made.
    final order = VirtKeyX.defaultOrder.map((e) => e.index).toList();
    Stores.setting.sshVirtKeys.put(order);
    final before = Stores.setting.lastUpdateTs;

    VirtKeyX.loadFromStore();

    expect(Stores.setting.lastUpdateTs, before);
  });
}
