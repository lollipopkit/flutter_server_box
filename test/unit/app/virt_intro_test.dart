/// The intro's Virtualization page: shown to every install that has not seen
/// feature revision 2, and saying more to one that had PVE configured.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/app.dart';
import 'package:server_box/data/model/app/tab.dart';
import 'package:server_box/data/model/server/pve_config.dart';
import 'package:server_box/data/res/store.dart';
import 'package:server_box/data/store/pve.dart';
import 'package:server_box/data/store/server.dart';
import 'package:server_box/data/store/setting.dart';

import '../../helpers/spi_fixture.dart';
import '../../helpers/test_db.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    await openTestDb();
    getIt.registerSingleton<SettingStore>(SettingStore('setting_test'));
    getIt.registerSingleton<ServerStore>(ServerStore());
    getIt.registerSingleton<PveStore>(PveStore());
  });

  tearDown(() async {
    await getIt.reset();
    await closeTestDb();
  });

  test('is shown until feature revision 2 has been seen', () async {
    for (final (seen, shown) in [(0, true), (1, true), (2, false), (3, false)]) {
      Stores.setting.featureIntroVer.put(seen);
      expect(await introShowsVirt(), shown, reason: 'featureIntroVer $seen');
    }
  });

  test('says PVE moved only when a server has PVE, read at display time', () {
    expect(introVirtFacts().pveMoved, isFalse);

    Stores.server.put(spiFixture(id: 'pve', name: 'pve', ip: 'h'));
    Stores.pve.put('pve', const PveConfig(addr: 'https://localhost:8006'));
    expect(introVirtFacts().pveMoved, isTrue);

    Stores.pve.put('pve', null);
    expect(introVirtFacts().pveMoved, isFalse);
  });

  test('says where the tab is: the bar, or under more', () {
    Stores.setting.homeTabs.put([AppTab.server, AppTab.virt]);
    expect(introVirtFacts().inBar, isTrue);

    Stores.setting.homeTabs.put([AppTab.server, AppTab.ssh]);
    expect(introVirtFacts().inBar, isFalse);
  });
}
