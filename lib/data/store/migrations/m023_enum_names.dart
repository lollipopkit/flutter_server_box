import 'package:server_box/data/model/app/menu/server_func.dart';
import 'package:server_box/data/model/app/server_sort.dart';
import 'package:server_box/data/store/schema.dart';
import 'package:server_box/data/store/setting.dart';

/// Rewrites the two settings that stored an enum as `Enum.index` to store its
/// name.
///
/// An index means whatever the build that reads it says it means. Three
/// `ServerFuncBtn` cases have been removed over the releases, and each removal
/// shifted every value after it — so a row chosen before one of them names a
/// different entry now, silently, and the user's row of buttons quietly became
/// somebody else's. Nothing announces it, because every index still resolves
/// to a valid case.
///
/// This cannot repair a row that already shifted: what a stored `4` meant
/// depends on which build wrote it, and that is not recorded anywhere. It
/// converts under today's meaning, which is the one the app has been acting on
/// anyway, and stops the next removal from doing it again.
class EnumNamesMigration implements SchemaMigration {
  const EnumNamesMigration({SettingStore? store}) : _store = store;

  final SettingStore? _store;

  static const appliedAt = 23;
  static const btnsKey = 'serverBtns';
  static const sortKey = 'serverPageSortBy';

  @override
  int get from => appliedAt;

  @override
  Future<void> apply() async => applySync();

  void applySync() {
    final store = _store ?? SettingStore.instance;

    final btns = store.get<Object>(btnsKey);
    if (btns is List || btns is Map) {
      // The first nine entries happen to match the pre-feature order, while
      // indices 9 and 10 are users and scheduledTasks and must not be
      // discarded. The decoder uses an explicit marker when one is present,
      // and otherwise applies the safe legacy fallback for old integer rows.
      final names = ServerFuncBtn.namesFromStored(btns);
      // Only when it says something different, so a store already holding
      // names is untouched and the step stays safe to run twice.
      if (!_sameList(btns, names)) {
        _write(store, btnsKey, ServerFuncBtn.toStored(names)!);
      }
    }

    final sort = store.get<Object>(sortKey);
    if (sort is int) {
      _write(store, sortKey, ServerSortField.fromStored(sort).name);
    }
  }

  static bool _sameList(Object? stored, List<String> names) {
    if (stored is Map &&
        stored['layout'] == 'current' &&
        stored['values'] is List) {
      stored = stored['values'];
    }
    if (stored is! List) return false;
    if (stored.length != names.length) return false;
    for (var i = 0; i < names.length; i++) {
      if (stored[i] != names[i]) return false;
    }
    return true;
  }

  static void _write(SettingStore store, String key, Object value) {
    final ok = store.set(
      key,
      value,
      // Not a user edit: the row means what it already meant. Stamping it
      // would push a rewrite nobody made over every other device's copy.
      updateLastUpdateTsOnSet: false,
    );
    if (!ok) throw StateError('m023: writing "$key" failed');
  }
}
