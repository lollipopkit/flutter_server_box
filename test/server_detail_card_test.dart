import 'package:fl_lib/fl_lib.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/data/model/app/server_detail_card.dart';
import 'package:server_box/data/res/store.dart';
import 'package:server_box/data/store/setting.dart';

import 'helpers/test_db.dart';

void main() {
  late SettingStore setting;

  setUp(() async {
    await openTestDb();
    setting = SettingStore.forTest();
    getIt.registerSingleton<SettingStore>(setting);
  });

  tearDown(() async {
    await getIt.reset();
    await SqliteDb.close();
  });

  List<String> order() => setting.detailCardOrder.get();

  test('uses release tags as the legacy card boundaries', () {
    setting.detailCardOrder.put([ServerDetailCards.about.name]);

    ServerDetailCards.autoAddNewCards(493, 918);
    expect(order(), [
      ServerDetailCards.about.name,
      ServerDetailCards.pve.name,
      ServerDetailCards.custom.name,
    ]);

    ServerDetailCards.autoAddNewCards(1130, 1184);
    expect(order(), [
      ServerDetailCards.about.name,
      ServerDetailCards.pve.name,
      ServerDetailCards.custom.name,
      ServerDetailCards.smart.name,
    ]);
  });

  test('does not add cards when the target is the release boundary', () {
    const boundaries = {
      493: [ServerDetailCards.pve, ServerDetailCards.custom],
      1130: [ServerDetailCards.smart],
      1491: [ServerDetailCards.bmc],
    };

    for (final MapEntry(key: boundary, value: cards) in boundaries.entries) {
      setting.detailCardOrder.put([ServerDetailCards.about.name]);

      ServerDetailCards.autoAddNewCards(boundary - 1, boundary);

      for (final card in cards) {
        expect(order(), isNot(contains(card.name)));
      }
    }
  });

  for (final retainedBuild in [1466, 1480, 1491]) {
    test('adds BMC when upgrading from v$retainedBuild', () {
      setting.detailCardOrder.put([
        ServerDetailCards.about.name,
        ServerDetailCards.cpu.name,
      ]);

      ServerDetailCards.autoAddNewCards(retainedBuild, 1536);

      expect(order(), [
        ServerDetailCards.about.name,
        ServerDetailCards.cpu.name,
        ServerDetailCards.bmc.name,
      ]);
    });
  }

  test('does not restore old cards the user removed', () {
    setting.detailCardOrder.put([
      ServerDetailCards.about.name,
      ServerDetailCards.cpu.name,
    ]);

    ServerDetailCards.autoAddNewCards(1491, 1536);

    expect(order(), isNot(contains(ServerDetailCards.pve.name)));
    expect(order(), isNot(contains(ServerDetailCards.custom.name)));
  });

  test('does not add BMC again on a later upgrade', () {
    setting.detailCardOrder.put([
      ServerDetailCards.about.name,
      ServerDetailCards.bmc.name,
    ]);

    ServerDetailCards.autoAddNewCards(1536, 1600);

    expect(
      order().where((name) => name == ServerDetailCards.bmc.name),
      hasLength(1),
    );
  });

  test('keeps a new card while removing obsolete trend cards', () {
    setting.detailCardOrder.put([ServerDetailCards.about.name, 'usage']);

    ServerDetailCards.autoAddNewCards(1491, 1536);

    expect(order(), [ServerDetailCards.about.name, ServerDetailCards.bmc.name]);
  });

  test('keeps a newly shipped card ordered but disabled', () {
    setting.detailCardOrder.put([ServerDetailCards.about.name]);
    setting.detailCardDisabled.put([ServerDetailCards.bmc.name]);

    ServerDetailCards.autoAddNewCards(1491, 1536);

    expect(order(), [ServerDetailCards.about.name, ServerDetailCards.bmc.name]);
    expect(setting.detailCardDisabled.get(), [ServerDetailCards.bmc.name]);
  });
}
