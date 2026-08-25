import 'package:server_box/data/model/ssh/virtual_key.dart';
import 'package:server_box/data/store/schema.dart';
import 'package:server_box/data/store/setting.dart';

/// The virtual keys, stored by name instead of by enum index.
///
/// `sshVirtKeys` is the order they are drawn in and `sshVirtKeysDisabled` is
/// which of them are hidden; both were lists of `VirtKey.index`. An index is
/// the one shape that stops meaning what it said when the enum changes —
/// inserting a case anywhere but the end silently renames every entry in every
/// stored arrangement — and these values outlive the build that wrote them,
/// through a backup and through a sync. Every other enum in this store is
/// already kept by name.
///
/// An index this build has no case for is dropped rather than guessed at, and
/// so is a repeat, which is what [VirtKeyX.loadFromStore] does with the same
/// input. Converting them here rather than leaving them to that reader is what
/// makes the old shape unreachable: `loadFromStore` is not the only reader, and
/// a shape two readers disagree about is the thing this removes.
///
/// Also run after a restore, from `Backup.merge` and `BackupV2.merge`: a file
/// written before this carries the indices, and the version has long since
/// moved past the point where the migrator would look.
class VirtKeyNamesMigration implements SchemaMigration {
  const VirtKeyNamesMigration({SettingStore? store}) : _store = store;

  /// Which store to convert. Null is the app's own; a test hands in a
  /// `forTest` one, since the singleton is bound to the real store name and an
  /// in-memory database has no rows under it.
  final SettingStore? _store;

  static const appliedAt = 13;

  @override
  int get from => appliedAt;

  static const orderKey = 'sshVirtKeys';
  static const disabledKey = 'sshVirtKeysDisabled';

  @override
  Future<void> apply() async {
    final store = _store ?? SettingStore.instance;
    _convert(store, orderKey);
    _convert(store, disabledKey);
  }

  /// A no-op on anything that is not a list of ints — a value already
  /// converted, a key never written, a row a newer build left behind. That is
  /// what makes a second pass safe, which is what a process stopped between
  /// this returning and the version being recorded comes back to.
  static void _convert(SettingStore store, String key) {
    final raw = store.get<Object>(key);
    if (raw is! List) return;
    if (!raw.any((e) => e is int)) return;

    final seen = <String>{};
    final names = <String>[];
    for (final entry in raw) {
      final name = switch (entry) {
        final int index
            when index >= 0 && index < VirtKey.values.length =>
          VirtKey.values[index].name,
        // Half-converted, which a crash between the two writes below leaves.
        final String s
            when VirtKey.values.any((k) => k.name == s) =>
          s,
        _ => null,
      };
      if (name == null || !seen.add(name)) continue;
      names.add(name);
    }

    // `updateLastUpdateTsOnSet: false`: a conversion this build performs on its
    // own is not an edit the user made, and counting it as one would have every
    // install claim a newer copy than whatever it last synced with.
    //
    // `set` answers false rather than throwing, and this step has no return
    // value — a quiet failure would let `SchemaVersion.migrate` record the
    // version and never come back, leaving a list of indices that every reader
    // now sees as empty.
    if (!store.set(key, names, updateLastUpdateTsOnSet: false)) {
      throw StateError('m013: writing "$key" failed');
    }
  }
}
