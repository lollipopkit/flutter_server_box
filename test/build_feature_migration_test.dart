import 'package:fl_lib/fl_lib.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/data/model/app/menu/server_func.dart';
import 'package:server_box/data/model/app/server_detail_card.dart';
import 'package:server_box/data/res/store.dart';
import 'package:server_box/data/store/migrations/build_features.dart';
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

  test(
    'persists the build migration and does not repeat it on relaunch',
    () async {
      setting.lastVer.put(1491);
      setting.detailCardOrder.put([ServerDetailCards.about.name]);
      setting.serverFuncBtns.put([ServerFuncBtn.terminal.index]);

      migrateBuildFeatures(1536);

      expect(setting.lastVer.get(), 1536);
      expect(setting.detailCardOrder.get(), [
        ServerDetailCards.about.name,
        ServerDetailCards.bmc.name,
      ]);
      expect(setting.serverFuncBtns.get(), [
        ServerFuncBtn.terminal.index,
        ServerFuncBtn.power.index,
      ]);

      setting.detailCardOrder.put([ServerDetailCards.about.name]);
      setting.serverFuncBtns.put([ServerFuncBtn.terminal.index]);
      // Finish the store's queued timestamp writes before replacing it.
      await setting.updateLastUpdateTs(key: null);
      await getIt.unregister<SettingStore>();
      setting = SettingStore.forTest();
      getIt.registerSingleton<SettingStore>(setting);

      migrateBuildFeatures(1536);

      expect(setting.lastVer.get(), 1536);
      expect(setting.detailCardOrder.get(), [ServerDetailCards.about.name]);
      expect(setting.serverFuncBtns.get(), [ServerFuncBtn.terminal.index]);
    },
  );
}
