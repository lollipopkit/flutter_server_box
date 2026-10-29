import 'dart:async';

import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:server_box/core/utils/ssh_key_passphrase.dart';
import 'package:server_box/data/model/server/private_key_info.dart';
import 'package:server_box/data/provider/entity_helpers.dart';
import 'package:server_box/data/provider/server/all.dart';
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
    state = state.copyWith(keys: entityAdd(Stores.key, state.keys, info));
  }

  Future<void> delete(PrivateKeyInfo info) async {
    // The bytes stored under the id, which may have changed since [info] was read.
    final stored = _storedKey(info.id) ?? info.key;
    state = state.copyWith(
      keys: entityDelete(Stores.key, state.keys, info, (e) => e.id),
    );
    _forgetPassphrases([stored]);
    // DB cleared ssh_key_id via ON DELETE SET NULL, but in-memory Spis still
    // hold the old keyId until reloaded; without this the editor sees
    // _keyIdx == -1 and rejects a valid save.
    try {
      final serversNotifier = ref.read(serversProvider.notifier);
      await serversNotifier.reload(refreshConnections: false);
    } catch (_) {}
  }

  /// The id never changes, so this is one write either way. The branch that
  /// deleted the old record existed because the id *was* the name — and with
  /// ids equal it deleted the record it had just written.
  Future<void> update(PrivateKeyInfo old, PrivateKeyInfo newInfo) async {
    final stored = _storedKey(old.id) ?? old.key;
    state = state.copyWith(
      keys: entityUpdate(
        Stores.key,
        state.keys,
        old,
        newInfo,
        (e) => e.id,
      ),
    );
    if (stored != newInfo.key) _forgetPassphrases([stored]);
  }

  String? _storedKey(String id) =>
      state.keys.where((e) => e.id == id).firstOrNull?.key;

  /// A passphrase kept for bytes no key holds any more.
  void _forgetPassphrases(List<String> gone) => unawaited(
    KeyPassphrases.forgetGone(gone, state.keys.map((e) => e.key)),
  );
}
