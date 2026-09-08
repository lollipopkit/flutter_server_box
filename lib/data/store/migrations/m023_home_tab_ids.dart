import 'package:server_box/data/model/app/tab.dart';
import 'package:server_box/data/store/schema.dart';
import 'package:server_box/data/store/setting.dart';
import 'package:server_box/hive/legacy_adapters.dart';

/// The home bar, stored as ids instead of as anything that resolves to an
/// [AppTab].
///
/// `homeTabs` accepted three shapes at once — an `AppTab`, its `name`, or its
/// `@HiveField` index — and every reader ran them back through
/// `AppTab.parseAppTabsFromObj`. That worked while every tab was a case of one
/// enum. A plugin's tab is not: it has no case, no index, and no name the enum
/// can resolve, so a row typed by that enum has nowhere to put it.
///
/// This is the same change `m021` made to the function-bar row and for the
/// same reason, one release later. After it, [FeatureSlot.homeTab] is an id
/// list like the other two slots and stops being the exception its own
/// documentation called out.
///
/// Converted with [kLegacyAppTabIds] rather than with `AppTab.values`: an
/// index means what the *writing* build's declaration order said, and
/// resolving against today's would be correct only until somebody reorders the
/// enum — which is the freedom this migration exists to give.
///
/// Also run after a restore, from `Backup.merge` and `BackupV2.merge`: a file
/// written before this carries the old shapes, and by then the stored version
/// has long since moved past the point where the migrator would look.
class HomeTabIdsMigration implements SchemaMigration {
  const HomeTabIdsMigration({SettingStore? store}) : _store = store;

  /// Which store to convert. Null is the app's own; a test hands in a
  /// caller-provided one, since the singleton is bound to the real store name
  /// and an in-memory database has no rows under it.
  final SettingStore? _store;

  static const appliedAt = 23;

  @override
  int get from => appliedAt;

  static const key = 'homeTabs';

  @override
  Future<void> apply() async => applySync();

  /// Runs the conversion inside a caller-owned SQLite transaction.
  void applySync() {
    final store = _store ?? SettingStore.instance;
    final raw = store.get<Object>(key);
    // A no-op on a key never written, and on a list that is already nothing
    // but known names — which is what makes a second pass safe, and a second
    // pass is what a process stopped between this returning and the version
    // being recorded comes back to.
    if (raw is! List) return;

    final known = {for (final tab in AppTab.values) tab.name};
    final seen = <String>{};
    final ids = <String>[];
    for (final entry in raw) {
      final id = switch (entry) {
        final int i when i >= 0 && i < kLegacyAppTabIds.length =>
          kLegacyAppTabIds[i],
        // Already a name, which a half-converted row and a newer build both
        // leave. An unknown one is dropped below rather than carried.
        final String s => s,
        _ => null,
      };
      // A name this build has no tab for is dropped here as well as by the
      // reader: a row carrying one is a row every later writer copies forward
      // for nothing.
      //
      // A plugin's id is not in `known` and would be dropped by that rule —
      // which is correct *here*, because no build before this one could have
      // written one. The reader keeps them; see `FeatureSlot.putEnabledIds`.
      if (id == null || !known.contains(id) || !seen.add(id)) continue;
      ids.add(id);
    }

    // Never empty. The bar is how every page is reached, and a row that
    // converted to nothing — every entry an index this table has no name for —
    // would leave an install with no way anywhere.
    final result = ids.isEmpty ? AppTab.defaultOrder.map((e) => e.name).toList() : ids;

    // `updateLastUpdateTsOnSet: false`: a conversion this build performs on its
    // own is not an edit the user made, and counting it as one would have every
    // install claim a newer copy than whatever it last synced with.
    //
    // `set` answers false rather than throwing, and this step has no return
    // value — a quiet failure would let `SchemaVersion.migrate` record the
    // version and never come back.
    if (!store.set(key, result, updateLastUpdateTsOnSet: false)) {
      throw StateError('m023: writing "$key" failed');
    }
  }
}
