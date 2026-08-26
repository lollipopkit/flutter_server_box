import 'package:fl_lib/fl_lib.dart';
import 'package:server_box/data/model/app/menu/server_func.dart';
import 'package:server_box/data/model/app/server_detail_card.dart';
import 'package:server_box/data/res/store.dart';

/// Applies feature-list migrations once when the installed build advances.
void migrateBuildFeatures(int newVer) {
  final lastVer = Stores.setting.lastVer.fetch();
  if (lastVer >= newVer) return;
  if (lastVer == 0) return;

  SqliteStore.transact(() {
    ServerDetailCards.autoAddNewCards(lastVer, newVer);
    ServerFuncBtn.autoAddNewFuncs(lastVer, newVer);
    Stores.setting.lastVer.putSync(newVer);
  });
}
