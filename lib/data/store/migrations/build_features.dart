import 'package:fl_lib/fl_lib.dart';
import 'package:server_box/data/model/app/feature.dart';
import 'package:server_box/data/model/app/server_detail_card.dart';
import 'package:server_box/data/res/store.dart';

/// Applies feature-list migrations once when the installed build advances.
///
/// One pass over every slot, not one call per surface: what "an entry that
/// arrived in this release" means is the same for a button, a card and a tab,
/// and it was written out three times before [Features.autoAdd] existed.
void migrateBuildFeatures(int newVer) {
  final lastVer = Stores.setting.lastVer.fetch();
  if (lastVer >= newVer) return;
  if (lastVer == 0) return;

  SqliteStore.transact(() {
    Features.autoAdd(lastVer, newVer);
    // The one thing that is about a single slot: names of cards that were
    // folded into others and no longer exist.
    ServerDetailCards.dropFoldedTrendCards(newVer);
    Stores.setting.lastVer.putSync(newVer);
  });
}
