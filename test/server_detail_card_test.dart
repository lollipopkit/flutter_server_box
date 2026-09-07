import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/data/model/app/feature.dart';
import 'package:server_box/data/model/app/server_detail_card.dart';
import 'package:server_box/data/res/store.dart';
import 'package:server_box/data/store/setting.dart';

import 'helpers/test_db.dart';

void main() {
  late SettingStore setting;

  setUp(() async {
    await openTestDb();
    setting = SettingStore('setting_test');
    getIt.registerSingleton<SettingStore>(setting);
  });

  tearDown(() async {
    await getIt.reset();
    await closeTestDb();
  });

  List<String> order() => setting.detailCardOrder.get();

  test('uses release tags as the legacy card boundaries', () {
    setting.detailCardOrder.put([ServerDetailCards.about.name]);

    Features.autoAdd(493, 918);
    expect(order(), [
      ServerDetailCards.about.name,
      ServerDetailCards.pve.name,
      ServerDetailCards.custom.name,
    ]);

    Features.autoAdd(1130, 1184);
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

      Features.autoAdd(boundary - 1, boundary);

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

      Features.autoAdd(retainedBuild, 1536);

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

    Features.autoAdd(1491, 1536);

    expect(order(), isNot(contains(ServerDetailCards.pve.name)));
    expect(order(), isNot(contains(ServerDetailCards.custom.name)));
  });

  test('does not add BMC again on a later upgrade', () {
    setting.detailCardOrder.put([
      ServerDetailCards.about.name,
      ServerDetailCards.bmc.name,
    ]);

    Features.autoAdd(1536, 1600);

    expect(
      order().where((name) => name == ServerDetailCards.bmc.name),
      hasLength(1),
    );
  });

  // Two steps, and they are about different things: `autoAdd` puts in what
  // arrived, and only this slot has names that were folded into other cards.
  // An unclaimed id is otherwise kept — a plugin that is not installed right
  // now must not lose where the user put it.
  test('keeps a new card while removing obsolete trend cards', () {
    setting.detailCardOrder.put([ServerDetailCards.about.name, 'usage']);

    Features.autoAdd(1491, 1536);
    ServerDetailCards.dropFoldedTrendCards(1536);

    expect(order(), [ServerDetailCards.about.name, ServerDetailCards.bmc.name]);
  });

  test('keeps a newly shipped card ordered but disabled', () {
    setting.detailCardOrder.put([ServerDetailCards.about.name]);
    setting.detailCardDisabled.put([ServerDetailCards.bmc.name]);

    Features.autoAdd(1491, 1536);

    expect(order(), [ServerDetailCards.about.name, ServerDetailCards.bmc.name]);
    expect(setting.detailCardDisabled.get(), [ServerDetailCards.bmc.name]);
  });
}
