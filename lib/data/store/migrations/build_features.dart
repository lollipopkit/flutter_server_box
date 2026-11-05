import 'package:fl_lib/fl_lib.dart';
import 'package:server_box/data/model/app/menu/server_func.dart';
import 'package:server_box/data/store/stores.dart';

/// Applies feature-list migrations once when the installed build advances.
void migrateBuildFeatures(int newVer) {
  final lastVer = Stores.setting.lastVer.fetch();
  if (lastVer >= newVer) return;
  if (lastVer == 0) return;

  SqliteStore.transact(() {
    // The detail cards no longer have an order to insert a new one into: a
    // card is drawn unless it is switched off, so one that did not exist
    // before is on by arriving.
    addNewServerFuncs(lastVer, newVer);
    Stores.setting.lastVer.putSync(newVer);
  });
}

/// Writes [ServerFuncBtn.withNewFuncs] of the stored row, when it adds any.
void addNewServerFuncs(int from, int to) {
  final prop = Stores.setting.serverFuncBtns;
  final list = prop.fetch();
  final next = ServerFuncBtn.withNewFuncs(list, from, to);
  if (next.length != list.length) prop.putSync(next);
}
