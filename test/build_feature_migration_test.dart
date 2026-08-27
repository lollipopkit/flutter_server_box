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
    setting = SettingStore('setting_test');
    getIt.registerSingleton<SettingStore>(setting);
  });

  tearDown(() async {
    await getIt.reset();
    await closeTestDb();
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
      setting = SettingStore('setting_test');
      getIt.registerSingleton<SettingStore>(setting);

      migrateBuildFeatures(1536);

      expect(setting.lastVer.get(), 1536);
      expect(setting.detailCardOrder.get(), [ServerDetailCards.about.name]);
      expect(setting.serverFuncBtns.get(), [ServerFuncBtn.terminal.index]);
    },
  );

  test('leaves a fresh install identifiable until intro completes', () {
    migrateBuildFeatures(1536);

    expect(setting.lastVer.get(), 0);
    expect(setting.get<List>('detailCardOrder'), isNull);
    expect(setting.get<List>('serverBtns'), isNull);
  });

  test('rolls back every feature write when one persistence step fails', () {
    setting.lastVer.put(1491);
    setting.detailCardOrder.put([ServerDetailCards.about.name]);
    setting.serverFuncBtns.put([ServerFuncBtn.terminal.index]);
    SqliteDb.instance.execute('''
      CREATE TRIGGER fail_server_btn_migration
      BEFORE UPDATE OF value ON kv
      WHEN OLD.store = 'setting_test' AND OLD.key = 'serverBtns'
      BEGIN
        SELECT RAISE(ABORT, 'forced migration failure');
      END;
    ''');

    expect(() => migrateBuildFeatures(1536), throwsStateError);

    expect(setting.lastVer.get(), 1491);
    expect(setting.detailCardOrder.get(), [ServerDetailCards.about.name]);
    expect(setting.serverFuncBtns.get(), [ServerFuncBtn.terminal.index]);
  });
}
