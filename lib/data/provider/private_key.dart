import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:server_box/core/sync.dart';
import 'package:server_box/data/model/server/private_key_info.dart';
import 'package:server_box/data/model/server/server_private_info.dart';
import 'package:server_box/data/provider/server/all.dart';
import 'package:server_box/data/res/store.dart';

part 'private_key.freezed.dart';
part 'private_key.g.dart';

enum PrivateKeyDeleteMode {
  clearServerKey,
  deleteServers,
}

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
    Stores.key.invalidateCache();
    final newState = _load();
    if (newState == state) return;
    state = newState;
  }

  PrivateKeyState _load() {
    final keys = Stores.key.fetch();
    return stateOrNull?.copyWith(keys: keys) ?? PrivateKeyState(keys: keys);
  }

  void add(PrivateKeyInfo info) {
    final newKeys = [...state.keys, info];
    state = state.copyWith(keys: newKeys);
    Stores.key.put(info);
    bakSync.sync(milliDelay: 1000);
  }

  void delete(PrivateKeyInfo info) {
    final newKeys = state.keys.where((e) => e.id != info.id).toList();
    state = state.copyWith(keys: newKeys);
    Stores.key.delete(info);
    bakSync.sync(milliDelay: 1000);
  }

  List<Spi> findReferencedServers(String keyId) {
    return ref
        .read(serversProvider)
        .servers
        .values
        .where((e) => e.keyId == keyId)
        .toList();
  }

  Future<void> deleteWithServerRefs(
    PrivateKeyInfo info,
    PrivateKeyDeleteMode mode,
  ) async {
    final servers = findReferencedServers(info.id);
    final serverNotifier = ref.read(serversProvider.notifier);

    switch (mode) {
      case PrivateKeyDeleteMode.clearServerKey:
        for (final spi in servers) {
          await serverNotifier.updateServer(spi, spi.copyWith(keyId: null));
        }
        delete(info);
      case PrivateKeyDeleteMode.deleteServers:
        for (final spi in servers) {
          await serverNotifier.delServer(spi.id);
        }
        delete(info);
    }
  }

  void update(PrivateKeyInfo old, PrivateKeyInfo newInfo) {
    final keys = [...state.keys];
    final idx = keys.indexWhere((e) => e.id == old.id);
    if (idx == -1) {
      keys.add(newInfo);
      Stores.key.put(newInfo);
      Stores.key.delete(old);
    } else {
      keys[idx] = newInfo;
      Stores.key.put(newInfo);
    }
    state = state.copyWith(keys: keys);
    bakSync.sync(milliDelay: 1000);
  }
}
