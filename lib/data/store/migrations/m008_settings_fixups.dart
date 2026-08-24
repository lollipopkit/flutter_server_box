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
/// One flag is still read here, and correctness rests on it. Each body is
/// idempotent against data it has already converted — one acts only on an
/// `int`, the other only on the exact legacy tab set — but for the tab set
/// "already converted" is not the same question as "already offered". Somebody
/// who took Agent *back out* of their home tabs is left holding exactly the
/// legacy four, and without the flag this step would put it back. The flag is
/// what says this device has been asked once already. The `int` has no such
/// second question and is converted whenever one is found.
///
/// Both halves run again after a restore, from [Backup.restore] and
/// [BackupV2.merge], for the reason recorded there: a file older than this step
/// carries the shape it converts, and the version has long since moved past the
/// point where the migrator would look.
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
  /// Ungated, unlike the tab set below. The flag answers "has this device been
  /// offered it already", which only matters where the user can undo what the
  /// step did; there is nothing to undo here — an int is a value written before
  /// the conversion, whatever any flag says, and a bool falls through
  /// untouched. Reading the flag made the answer wrong on the one path that
  /// needs this most: a restore brings the flag back alongside the int, so the
  /// step declared itself done over a value it had never seen.
  static void _migrateSshConnectionMode(SettingStore store) {
    const key = 'sshConnectionMode';
    final raw = store.get<Object>(key);
    if (raw is! int) return;
    // macOS defaults to the built-in client, everything else to the system one.
    final value = raw == -1 ? !isMacOS : raw != 0;
    _write(store, key, value);
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
    _write(store, key, [...tabs, AppTab.agent].map((tab) => tab.name).toList());
  }

  /// `set` answers `false` rather than throwing — a write that could not be
  /// encoded or could not reach the database returns quietly.
  ///
  /// This step has no return value, so a quiet failure would let
  /// `SchemaVersion.migrate` record the version and never look again: the
  /// conversion is one pass over a record only an upgrading install holds.
  /// Throwing leaves the version where it was, so the next launch retries.
  static void _write(SettingStore store, String key, Object value) {
    final ok = store.set(key, value, updateLastUpdateTsOnSet: false);
    if (!ok) throw StateError('m008: writing "$key" failed');
  }
}
