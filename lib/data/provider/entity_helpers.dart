import 'package:server_box/core/sync.dart';
import 'package:server_box/data/store/entity_store.dart';

/// Shared helpers for the three named-entity providers (BMC, private keys,
/// snippets, port forwards). Riverpod code-gen makes a true generic
/// `EntityNotifier<T>` awkward (each state has its own freezed shape), so the
/// shared bits live here as small extensions and functions instead of a base
/// class. See `RETIREMENT.md`.

extension EntityListOps<T extends Object> on List<T> {
  /// Returns a copy with [fresh] replacing [old] (matched by [idOf]), or
  /// appended if no match. Guards against id changes.
  List<T> withUpdated(
    T old,
    T fresh,
    String Function(T) idOf,
  ) {
    if (idOf(old) != idOf(fresh)) {
      throw ArgumentError('cannot change the id of a $T');
    }
    final idx = indexWhere((e) => idOf(e) == idOf(old));
    if (idx == -1) return [...this, fresh];
    final copy = [...this];
    copy[idx] = fresh;
    return copy;
  }

  List<T> withoutId(String id, String Function(T) idOf) =>
      where((e) => idOf(e) != id).toList();
}

/// Writes [item] to [store] and returns the new list, then schedules backup
/// sync. Centralizes the `put` + `copyWith` + `bakSync` triplet that was
/// copied across four notifiers.
List<T> entityAdd<T extends Object>(
  EntityStore<T> store,
  List<T> current,
  T item,
) {
  store.put(item);
  final next = [...current, item];
  bakSync.sync(milliDelay: 1000);
  return next;
}

List<T> entityUpdate<T extends Object>(
  EntityStore<T> store,
  List<T> current,
  T oldItem,
  T fresh,
  String Function(T) idOf,
) {
  final next = current.withUpdated(oldItem, fresh, idOf);
  store.put(fresh);
  bakSync.sync(milliDelay: 1000);
  return next;
}

List<T> entityDelete<T extends Object>(
  EntityStore<T> store,
  List<T> current,
  T item,
  String Function(T) idOf,
) {
  store.delete(item);
  final next = current.withoutId(idOf(item), idOf);
  bakSync.sync(milliDelay: 1000);
  return next;
}
