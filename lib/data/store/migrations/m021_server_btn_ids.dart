import 'package:server_box/data/model/app/menu/server_func.dart';
import 'package:server_box/data/store/schema.dart';
import 'package:server_box/data/store/setting.dart';
import 'package:server_box/hive/legacy_adapters.dart';

/// The server function-bar row, stored by id instead of by enum index.
///
/// `serverBtns` was a list of `ServerFuncBtn.index`. An index is the one shape
/// that stops meaning what it said when the enum changes — inserting a case
/// anywhere but the end silently renames every entry in every stored row — and
/// this row outlives the build that wrote it, through a backup and through a
/// sync. Everything else arranged by the user is already kept by name: the
/// detail cards, the home tabs, the virtual keys (m013).
///
/// It also had to change before the feature registry could exist. A registry
/// whose entries are positions in one enum cannot hold an entry that is not in
/// that enum, which is what a plugin's contribution is.
///
/// Converted with [kLegacyServerFuncBtnIds] rather than with
/// `ServerFuncBtn.values`, and this is the difference that matters: resolving
/// against today's enum would be correct only for as long as nobody reorders
/// it, which is precisely the freedom this migration exists to give.
///
/// An index this table has no entry for is dropped rather than guessed at, and
/// so is a repeat — the row is a list of positions in a bar, and one entry
/// twice has no meaning.
///
/// Also run after a restore, from `Backup.merge` and `BackupV2.merge`: a file
/// written before this carries the indices, and by then the stored version has
/// long since moved past the point where the migrator would look.
class ServerBtnIdsMigration implements SchemaMigration {
  const ServerBtnIdsMigration({SettingStore? store}) : _store = store;

  /// Which store to convert. Null is the app's own; a test hands in a
  /// caller-provided one, since the singleton is bound to the real store name
  /// and an in-memory database has no rows under it.
  final SettingStore? _store;

  static const appliedAt = 21;

  @override
  int get from => appliedAt;

  static const key = 'serverBtns';

  @override
  Future<void> apply() async => applySync();

  /// Runs the conversion inside a caller-owned SQLite transaction.
  void applySync() {
    final store = _store ?? SettingStore.instance;
    final raw = store.get<Object>(key);
    // A no-op on anything that is not a list of ints — a value already
    // converted, a key never written, a row a newer build left behind. That is
    // what makes a second pass safe, which is what a process stopped between
    // this returning and the version being recorded comes back to.
    if (raw is! List) return;
    if (!raw.any((e) => e is int)) return;

    final known = {for (final b in ServerFuncBtn.values) b.id};
    final seen = <String>{};
    final ids = <String>[];
    for (final entry in raw) {
      final id = switch (entry) {
        final int i when i >= 0 && i < kLegacyServerFuncBtnIds.length =>
          kLegacyServerFuncBtnIds[i],
        // Half-converted, which a crash between the read and the write leaves.
        final String s => s,
        _ => null,
      };
      // An id this build has no entry for is dropped here as well as by the
      // reader: a row that carries one is a row every later writer copies
      // forward for nothing.
      if (id == null || !known.contains(id) || !seen.add(id)) continue;
      ids.add(id);
    }

    // `updateLastUpdateTsOnSet: false`: a conversion this build performs on its
    // own is not an edit the user made, and counting it as one would have every
    // install claim a newer copy than whatever it last synced with.
    //
    // `set` answers false rather than throwing, and this step has no return
    // value — a quiet failure would let `SchemaVersion.migrate` record the
    // version and never come back, leaving a list of indices that every reader
    // now sees as empty.
    if (!store.set(key, ids, updateLastUpdateTsOnSet: false)) {
      throw StateError('m021: writing "$key" failed');
    }
  }
}
