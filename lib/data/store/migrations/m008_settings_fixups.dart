import 'package:fl_lib/fl_lib.dart';
import 'package:server_box/data/model/app/tab.dart';
import 'package:server_box/data/store/schema.dart';
import 'package:server_box/data/store/setting.dart';

/// The two settings fixups that used to gate themselves on a flag key.
///
/// Each was a `xxxMigrated` boolean written into the `setting` store beside
/// the user's own preferences: read it, and if it is true do nothing. That is
/// a schema version with a worse implementation — one flag per fixup, each
/// exported by a backup, each needing its own retirement, and none of them
/// ordered against the others or against the steps in this directory. There is
/// a version number for this, so these use it.
///
/// The flags are still read here, and correctness rests on it. Each body is
/// idempotent against data it has already converted — one acts only on an
/// `int`, the other only on the exact legacy tab set — but "already converted"
/// is not the same question as "already offered". Somebody who took Agent
/// *back out* of their home tabs is left holding exactly the legacy four, and
/// without the flag this step would put it back. The flag is what says this
/// device has been asked once already.
///
/// Removed at the end, rather than from `removeRetiredKeys`: that runs from
/// `Stores.init`, which is before `SchemaVersion.migrate`, so leaving it there
/// would delete the flags in the same launch that needed to read them.
///
/// TODO: drop the flag reads and the removal below once no install can still
/// be carrying them. A backup restored from before this release can, so not
/// until backups of that vintage are out of circulation too.
class SettingsFixupsMigration implements SchemaMigration {
  const SettingsFixupsMigration({SettingStore? store}) : _store = store;

  /// Which store to convert. Null is the app's own; a test hands in a
  /// `forTest` one, since the singleton is bound to the real store name and
  /// an in-memory database has no rows under it.
  final SettingStore? _store;

  @override
  int get from => 8;

  /// Written throughout with `updateLastUpdateTsOnSet: false`: a conversion
  /// this build performs on its own is not an edit the user made, and counting
  /// it as one would have every install claim a newer copy than whatever it
  /// last synced with.
  @override
  Future<void> apply() async {
    final store = _store ?? SettingStore.instance;
    _migrateSshConnectionMode(store);
    _migrateHomeTabsAgent(store);
    // Last, so a process that stops partway leaves the version unchanged and
    // the flags still readable by the rerun.
    store.remove(_sshFlagKey, updateLastUpdateTsOnRemove: false);
    store.remove(_homeTabsFlagKey, updateLastUpdateTsOnRemove: false);
  }

  /// `sshConnectionMode` was an int (-1 auto, 0 built-in, 1 system SSH) and is
  /// a bool.
  ///
  /// Idempotent on its own: a value already converted is a bool and falls
  /// through untouched.
  static void _migrateSshConnectionMode(SettingStore store) {
    if (store.get<bool>(_sshFlagKey) == true) return;
    const key = 'sshConnectionMode';
    final raw = store.get<Object>(key);
    if (raw is! int) return;
    // macOS defaults to the built-in client, everything else to the system one.
    final value = raw == -1 ? !isMacOS : raw != 0;
    store.set(key, value, updateLastUpdateTsOnSet: false);
  }

  /// Adds Agent to the home tabs of an install still on the legacy default.
  ///
  /// Idempotent on its own: it acts only when the tab set is exactly the four
  /// legacy defaults, which it no longer is once Agent has been added.
  static void _migrateHomeTabsAgent(SettingStore store) {
    if (store.get<bool>(_homeTabsFlagKey) == true) return;
    const key = 'homeTabs';
    const legacyDefaults = {
      AppTab.server,
      AppTab.ssh,
      AppTab.file,
      AppTab.snippet,
    };
    final tabs = AppTab.parseAppTabsFromObj(store.get<Object>(key));
    if (tabs.length != legacyDefaults.length) return;
    if (!tabs.toSet().containsAll(legacyDefaults)) return;
    store.set(
      key,
      [...tabs, AppTab.agent].map((tab) => tab.name).toList(),
      updateLastUpdateTsOnSet: false,
    );
  }

  /// TODO: delete with the flag reads above.
  static const _sshFlagKey = 'sshConnectionModeMigrated';

  /// TODO: delete with the flag reads above.
  static const _homeTabsFlagKey = 'homeTabsAgentMigrated';
}
