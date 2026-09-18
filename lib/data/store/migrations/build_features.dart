import 'package:fl_lib/fl_lib.dart';
import 'package:server_box/data/model/app/menu/server_func.dart';
import 'package:server_box/data/res/store.dart';

/// Applies feature-list migrations once when the installed build advances.
void migrateBuildFeatures(int newVer) {
  final lastVer = Stores.setting.lastVer.fetch();
  if (lastVer >= newVer) return;
  if (lastVer == 0) return;

  SqliteStore.transact(() {
    // The detail cards no longer have an order to insert a new one into: a
    // card is drawn unless it is switched off, so one that did not exist
    // before is on by arriving.
    ServerFuncBtn.autoAddNewFuncs(lastVer, newVer);
    Stores.setting.lastVer.putSync(newVer);
  });
}
