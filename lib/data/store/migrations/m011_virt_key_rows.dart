import 'package:server_box/data/store/schema.dart';
import 'package:server_box/data/store/setting.dart';

/// `horizonVirtKey`, a switch, becomes `virtKeyRows`, a count.
///
/// The switch meant "show one row and scroll it sideways"; the count says how
/// many rows to show, with the rest on pages swiped sideways. On means one
/// row, so that is what it converts to. Off is the default and needs nothing
/// written — a key absent from the store reads as 0, which is "all of them".
///
/// TODO: delete this step, [SettingStore.removeRetiredKeys]'s entry for
/// [legacyKey], and the key itself, once no install and no backup can still be
/// carrying it.
class VirtKeyRowsMigration implements SchemaMigration {
  const VirtKeyRowsMigration({SettingStore? store}) : _store = store;

  /// Which store to convert. Null is the app's own; a test hands in a
  /// `forTest` one, since the singleton is bound to the real store name and an
  /// in-memory database has no rows under it.
  final SettingStore? _store;

  /// The version this step converts *from*. Named so `removeRetiredKeys` can
  /// ask whether the step has had its pass without repeating the number.
  static const appliedAt = 11;

  static const legacyKey = 'horizonVirtKey';

  @override
  int get from => appliedAt;

  static const key = 'virtKeyRows';

  @override
  Future<void> apply() async {
    final store = _store ?? SettingStore.instance;
    // Already converted, or set by hand since. A second pass is what a process
    // stopped between this returning and the version being recorded comes back
    // to, and without this it would put the count back to 1 over whatever the
    // user had chosen in between.
    if (store.get<int>(key) != null) return;
    if (store.get<bool>(legacyKey) != true) return;
    // `updateLastUpdateTsOnSet: false`: a conversion this build performs on
    // its own is not an edit the user made, and counting it as one would have
    // every install claim a newer copy than whatever it last synced with.
    // `set` answers false rather than throwing, and this step has no return
    // value — a quiet failure would let `SchemaVersion.migrate` record v12 and
    // never come back, leaving `horizonVirtKey` set and `virtKeyRows` absent.
    if (!store.set(key, 1, updateLastUpdateTsOnSet: false)) {
      throw StateError('m011: writing "$key" failed');
    }
  }
}
