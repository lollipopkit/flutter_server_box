import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:server_box/core/sync.dart';
import 'package:server_box/data/model/server/private_key_info.dart';
import 'package:server_box/data/res/store.dart';

part 'private_key.freezed.dart';
part 'private_key.g.dart';

@freezed
abstract class PrivateKeyState with _$PrivateKeyState {
  const factory PrivateKeyState({
    @Default(<PrivateKeyInfo>[]) List<PrivateKeyInfo> keys,
  }) = _PrivateKeyState;
}

@Riverpod(keepAlive: true)
class PrivateKeyNotifier extends _$PrivateKeyNotifier {
  @override
  PrivateKeyState build() {
    return _load();
  }

  void reload() {
    Stores.key.dropCache();
    final newState = _load();
    if (newState == state) return;
    state = newState;
  }

  PrivateKeyState _load() {
    final keys = Stores.key.fetch();
    return stateOrNull?.copyWith(keys: keys) ?? PrivateKeyState(keys: keys);
  }

  Future<void> add(PrivateKeyInfo info) async {
    final newKeys = [...state.keys, info];
    Stores.key.put(info);
    state = state.copyWith(keys: newKeys);
    bakSync.sync(milliDelay: 1000);
  }

  Future<void> delete(PrivateKeyInfo info) async {
    final newKeys = state.keys.where((e) => e.id != info.id).toList();
    Stores.key.delete(info);
    state = state.copyWith(keys: newKeys);
    bakSync.sync(milliDelay: 1000);
  }

  /// The id never changes, so this is one write either way. The branch that
  /// deleted the old record existed because the id *was* the name — and with
  /// ids equal it deleted the record it had just written.
  Future<void> update(PrivateKeyInfo old, PrivateKeyInfo newInfo) async {
    if (old.id != newInfo.id) {
      // `EntityStore.update` refuses this; going straight to `put` would let a
      // caller insert a second record under the name of the first.
      throw ArgumentError('cannot change the id of a PrivateKeyInfo');
    }
    final keys = [...state.keys];
    final idx = keys.indexWhere((e) => e.id == old.id);
    if (idx == -1) {
      keys.add(newInfo);
    } else {
      keys[idx] = newInfo;
    }
    Stores.key.put(newInfo);
    state = state.copyWith(keys: keys);
    bakSync.sync(milliDelay: 1000);
  }
}
