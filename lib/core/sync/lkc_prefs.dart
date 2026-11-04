import 'package:fl_lib/fl_lib.dart';
import 'package:server_box/core/lkc.dart';

/// Whether the backup syncs to LK Cloud, and the storage it goes through.
///
/// Apart from [BakSyncer], which picks it as one remote among the others, so
/// the LK Cloud halves (`lkc.dart`, `lkc_log.dart`) can read it without
/// importing the engine that imports them.
abstract final class LkcSyncPrefs {
  /// As the signed-in account. Key is permanent.
  static const enabled = PrefPropDefault(
    'lkc_sync',
    false,
    updateLastUpdateTsOnSetProp: false,
  );

  static final storage = LkcRemoteStorage(Lkc.client, Lkc.app);
}
