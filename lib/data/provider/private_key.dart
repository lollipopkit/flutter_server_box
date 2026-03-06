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
  Future<bool> _persist(Future<void> future, String ctx) async {
    try {
      await future;
      return true;
    } catch (e, s) {
      Loggers.app.warning('$ctx failed', e, s);
      return false;
    }
  }

  void _persistUnawaited(Future<void> future, String ctx) {
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
        _persistUnawaited(maybe, 'bakSync.sync');
      }
    } catch (e, s) {
      Loggers.app.warning('bakSync.sync failed', e, s);
    }
  }

  @override
  /// keepAlive provider starts with an empty [PrivateKeyState] and asynchronously
  /// hydrates via [reload()]. Consumers should listen for state updates after
  /// initialization.
  PrivateKeyState build() {
    unawaited(reload());
    return const PrivateKeyState();
  }

  Future<void> reload() async {
    PrivateKeyState newState;
    try {
      newState = await _load();
    } catch (e, s) {
      Loggers.app.warning('Reload private keys failed', e, s);
      return;
    }
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
    unawaited(_persistAdd(info));
  }

  Future<void> _persistAdd(PrivateKeyInfo info) async {
    final ok = await _persist(Stores.key.put(info), 'Stores.key.put(add)');
    if (ok) _syncBackup();
  }

  void delete(PrivateKeyInfo info) {
    final newKeys = state.keys.where((e) => e.id != info.id).toList();
    state = state.copyWith(keys: newKeys);
    unawaited(_persistDelete(info));
  }

  Future<void> _persistDelete(PrivateKeyInfo info) async {
    final ok = await _persist(
      Stores.key.delete(info),
      'Stores.key.delete(delete)',
    );
    if (ok) _syncBackup();
  }

  void update(PrivateKeyInfo old, PrivateKeyInfo newInfo) {
    final keys = [...state.keys];
    final idx = keys.indexWhere((e) => e.id == old.id);
    PrivateKeyInfo? oldInState;
    if (idx == -1) {
      keys.add(newInfo);
    } else {
      oldInState = keys[idx];
      keys[idx] = newInfo;
    }
    state = state.copyWith(keys: keys);
    unawaited(
      _persistUpdate(old: old, newInfo: newInfo, oldInState: oldInState),
    );
  }

  Future<void> _persistUpdate({
    required PrivateKeyInfo old,
    required PrivateKeyInfo newInfo,
    required PrivateKeyInfo? oldInState,
  }) async {
    var allOk = true;
    if (oldInState == null) {
      allOk = await _persist(
        Stores.key.put(newInfo),
        'Stores.key.put(update_add)',
      );
      if (allOk && old.id != newInfo.id) {
        allOk = await _persist(
          Stores.key.delete(old),
          'Stores.key.delete(update_add_old)',
        );
      }
    } else {
      allOk = await _persist(
        Stores.key.put(newInfo),
        'Stores.key.put(update_replace)',
      );
      if (allOk && oldInState.id != newInfo.id) {
        allOk = await _persist(
          Stores.key.delete(oldInState),
          'Stores.key.delete(update_replace_old)',
        );
      }
    }
    if (allOk) _syncBackup();
  }
}
