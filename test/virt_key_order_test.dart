/// The stored order of the terminal's virtual keys, read back.
///
/// It is a list of [VirtKey.name]s. It was a list of enum *indices*, which is
/// the one shape that stops meaning what it said when the enum changes — see
/// `VirtKeyNamesMigration`. A backup restored from a newer build still carries
/// names this build has no case for, and there are two places that turn them
/// back into keys: the terminal, and the settings page that arranges them. Both
/// used to be wrong, in opposite directions — one threw the whole order away,
/// the other threw.
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
    getIt.registerSingleton<SettingStore>(SettingStore('setting_test'));
  });

  tearDown(() async {
    await getIt.reset();
    await SqliteDb.close();
  });

  test('an order this build knows every key of is returned as it was', () {
    const order = [VirtKey.tab, VirtKey.ctrl, VirtKey.esc];
    Stores.setting.sshVirtKeys.put(order.map((e) => e.name).toList());

    expect(VirtKeyX.loadFromStore(), order);
  });

  test('a name this build has no case for is dropped, and the rest kept', () {
    // Written by a build with more keys than this one. Resetting to the
    // default instead — which is what it did — discards an arrangement that
    // was otherwise entirely readable.
    Stores.setting.sshVirtKeys.put([
      VirtKey.tab.name,
      'somethingNewerBuildsHave',
      VirtKey.ctrl.name,
    ]);

    expect(VirtKeyX.loadFromStore(), [VirtKey.tab, VirtKey.ctrl]);
  });

  test('and what it dropped is written back, so it is not read again', () {
    Stores.setting.sshVirtKeys.put([VirtKey.esc.name, 'unknownKey']);

    VirtKeyX.loadFromStore();

    expect(Stores.setting.sshVirtKeys.fetch(), [VirtKey.esc.name]);
  });

  test('nothing readable at all falls back to the default, unsaved', () {
    // Unsaved matters: the stored value is the only record of what the user
    // arranged, and a build that cannot read it is not entitled to replace it.
    Stores.setting.sshVirtKeys.put(['unknownA', 'unknownB']);

    expect(VirtKeyX.loadFromStore(), VirtKeyX.defaultOrder);
    expect(Stores.setting.sshVirtKeys.fetch(), ['unknownA', 'unknownB']);
  });

  test('a key named twice is drawn once', () {
    // Two rows for one key in the settings page, and two buttons in the
    // terminal sharing one `ValueKey` and one modifier state. First
    // occurrence wins, so the arrangement is otherwise untouched — the same
    // rule `AppTab.parseAppTabsFromObj` follows for the home tabs.
    Stores.setting.sshVirtKeys.put([
      VirtKey.tab.name,
      VirtKey.ctrl.name,
      VirtKey.tab.name,
    ]);

    expect(VirtKeyX.loadFromStore(), [VirtKey.tab, VirtKey.ctrl]);
    expect(Stores.setting.sshVirtKeys.fetch(), [
      VirtKey.tab.name,
      VirtKey.ctrl.name,
    ]);
  });

  test('an order it can read entirely is not rewritten', () {
    // The write is the part with a cost — it stamps the store, and a settings
    // sync then carries an edit nobody made.
    final order = VirtKeyX.defaultOrder.map((e) => e.name).toList();
    Stores.setting.sshVirtKeys.put(order);
    final before = Stores.setting.lastUpdateTs;

    VirtKeyX.loadFromStore();

    expect(Stores.setting.lastUpdateTs, before);
  });

  test('a row still holding indices reads as nothing rather than throwing', () {
    // `VirtKeyNamesMigration` is what stops this being reached. If one ever
    // is — a row a downgrade left behind — the page has to come up.
    Stores.setting.set('sshVirtKeys', [0, 1, 2]);

    expect(VirtKeyX.loadFromStore(), VirtKeyX.defaultOrder);
  });
}
