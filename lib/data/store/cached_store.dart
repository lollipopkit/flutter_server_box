import 'package:fl_lib/fl_lib.dart';

/// A [SqliteStore] whose rows are one model type, kept in a list cache.
///
/// The cache is dropped by the write methods themselves rather than by watching
/// the store. Hive needed a watcher because a box could be written behind the
/// store's back — `Backup.restore` did exactly that — and a watcher then had to
/// be suppressed around the store's own writes so they did not each cost a
/// reload. Nothing can reach the database except through here now, so
/// invalidating in [set], [remove] and [clear] covers every path.
abstract class CachedSqliteStore<T extends Object> extends SqliteStore {
  CachedSqliteStore(super.name);

  List<T>? _cache;

  List<T>? get cachedItems => _cache;

  /// The row key for [item].
  String getKey(T item);

  /// Rebuilds one item from its stored JSON.
  T? fromJson(Map<String, dynamic> json);

  @override
  bool set<V extends Object>(
    String key,
    V val, {
    StoreToObj<V>? toObj,
    bool? updateLastUpdateTsOnSet,
  }) {
    final res = super.set(
      key,
      val,
      toObj: toObj,
      updateLastUpdateTsOnSet: updateLastUpdateTsOnSet,
    );
    if (res) _cache = null;
    return res;
  }

  @override
  bool remove(String key, {bool? updateLastUpdateTsOnRemove}) {
    final res = super.remove(
      key,
      updateLastUpdateTsOnRemove: updateLastUpdateTsOnRemove,
    );
    if (res) _cache = null;
    return res;
  }

  @override
  Future<bool> clear({bool? updateLastUpdateTsOnClear}) async {
    _cache = null;
    return await super.clear(
      updateLastUpdateTsOnClear: updateLastUpdateTsOnClear,
    );
  }

  void invalidateCache() => _cache = null;

  void put(T item) => set(getKey(item), item);

  /// A copy, so a caller sorting or filtering the result cannot reorder the
  /// cache everyone else reads.
  List<T> fetch() => List<T>.from(_cache ??= _loadAll());

  /// One query, not one per key.
  ///
  /// Under Hive `box.get` was a map lookup, so reading each key in turn was
  /// free; each is a prepared-statement round trip now, and this runs on every
  /// cache miss — which is every write, since the write methods drop the cache.
  List<T> _loadAll() {
    final result = <T>[];
    for (final entry in getAllMap().entries) {
      final raw = entry.value;
      if (raw is! Map) continue;
      try {
        final item = fromJson(Map<String, dynamic>.from(raw));
        if (item != null) result.add(item);
      } catch (e) {
        dprint('Parsing $T from JSON', e);
      }
    }
    return result;
  }

  /// Reads one row, bypassing the cache.
  T? fetchOneRaw(String key) {
    final raw = get<Object>(key);
    if (raw is! Map) return null;
    try {
      return fromJson(Map<String, dynamic>.from(raw));
    } catch (e) {
      dprint('Parsing $T from JSON', e);
      return null;
    }
  }

  void deleteById(String id) => remove(id);

  void delete(T item) => deleteById(getKey(item));

  void update(T old, T newItem) {
    final oldKey = getKey(old);
    if (!have(old)) {
      throw Exception('Old $T: $old not found');
    }
    final newKey = getKey(newItem);
    if (oldKey == newKey) {
      // In place, which is what every caller but the id migrations does. An
      // upsert is one statement and needs no transaction around it.
      set(newKey, newItem);
      return;
    }
    // The key moved, so this is a delete and an insert. As one unit: a crash
    // between them would leave the record under neither key. `transact` nests,
    // so this is also safe if a caller has already opened one.
    SqliteStore.transact(() {
      remove(oldKey);
      set(newKey, newItem);
    });
  }

  bool have(T item) => get<Object>(getKey(item)) != null;
}
