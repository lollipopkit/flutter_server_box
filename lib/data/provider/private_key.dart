import 'dart:async';

import 'package:fl_lib/fl_lib.dart';
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
  void _persist(Future<void> future, String ctx) {
    unawaited(
      future.catchError((Object e, StackTrace s) {
        Loggers.app.warning('$ctx failed', e, s);
      }),
    );
  }

  void _syncBackup() {
    try {
      final maybe = bakSync.sync(milliDelay: 1000);
      if (maybe is Future<void>) {
        _persist(maybe, 'bakSync.sync');
      }
    } catch (e, s) {
      Loggers.app.warning('bakSync.sync failed', e, s);
    }
  }

  @override
  PrivateKeyState build() {
    unawaited(reload());
    return const PrivateKeyState();
  }

  Future<void> reload() async {
    final newState = await _load();
    if (newState == state) return;
    state = newState;
  }

  Future<PrivateKeyState> _load() async {
    final keys = await Stores.key.fetch();
    return stateOrNull?.copyWith(keys: keys) ?? PrivateKeyState(keys: keys);
  }

  void add(PrivateKeyInfo info) {
    final newKeys = [...state.keys, info];
    state = state.copyWith(keys: newKeys);
    _persist(Stores.key.put(info), 'Stores.key.put(add)');
    _syncBackup();
  }

  void delete(PrivateKeyInfo info) {
    final newKeys = state.keys.where((e) => e.id != info.id).toList();
    state = state.copyWith(keys: newKeys);
    _persist(Stores.key.delete(info), 'Stores.key.delete(delete)');
    _syncBackup();
  }

  void update(PrivateKeyInfo old, PrivateKeyInfo newInfo) {
    final keys = [...state.keys];
    final idx = keys.indexWhere((e) => e.id == old.id);
    if (idx == -1) {
      keys.add(newInfo);
      _persist(Stores.key.put(newInfo), 'Stores.key.put(update_add)');
      if (old.id != newInfo.id) {
        _persist(Stores.key.delete(old), 'Stores.key.delete(update_add_old)');
      }
    } else {
      final oldInState = keys[idx];
      keys[idx] = newInfo;
      if (oldInState.id != newInfo.id) {
        _persist(
          Stores.key.delete(oldInState),
          'Stores.key.delete(update_replace_old)',
        );
      }
      _persist(Stores.key.put(newInfo), 'Stores.key.put(update_replace)');
    }
    state = state.copyWith(keys: keys);
    _syncBackup();
  }
}
