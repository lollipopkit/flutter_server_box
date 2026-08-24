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
/// Reading only — the removal is `SettingStore.removeRetiredKeys`, gated on
/// the version already being past this step. Deleting them here would have
/// been wrong twice over. `SchemaVersion.migrate` records the version *after*
/// `apply` returns, so a process that stopped in between would come back at v8
/// with the flags gone, and this step would then read somebody who removed
/// Agent as somebody who was never offered it. And a restore of an older
/// backup writes the flags back long after this step can run again, so the
/// removal has to live somewhere that runs on every launch.
///
/// TODO: drop the flag reads here and the two keys from `removeRetiredKeys`
/// once no install and no backup can still be carrying them.
class SettingsFixupsMigration implements SchemaMigration {
  const SettingsFixupsMigration({SettingStore? store}) : _store = store;

  /// Which store to convert. Null is the app's own; a test hands in a
  /// `forTest` one, since the singleton is bound to the real store name and
  /// an in-memory database has no rows under it.
  final SettingStore? _store;

  /// The version this step converts *from*. Named so `removeRetiredKeys` can
  /// ask whether the step has had its pass without repeating the number.
  static const appliedAt = 8;

  @override
  int get from => appliedAt;

  /// Written throughout with `updateLastUpdateTsOnSet: false`: a conversion
  /// this build performs on its own is not an edit the user made, and counting
  /// it as one would have every install claim a newer copy than whatever it
  /// last synced with.
  @override
  Future<void> apply() async {
    final store = _store ?? SettingStore.instance;
    _migrateSshConnectionMode(store);
    _migrateHomeTabsAgent(store);
  }

  /// TODO: delete with the flag reads below.
  static const sshFlagKey = 'sshConnectionModeMigrated';

  /// TODO: delete with the flag reads below.
  static const homeTabsFlagKey = 'homeTabsAgentMigrated';

  /// `sshConnectionMode` was an int (-1 auto, 0 built-in, 1 system SSH) and is
  /// a bool.
  ///
  /// Idempotent on its own: a value already converted is a bool and falls
  /// through untouched.
  static void _migrateSshConnectionMode(SettingStore store) {
    if (store.get<bool>(sshFlagKey) == true) return;
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
    if (store.get<bool>(homeTabsFlagKey) == true) return;
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
}
