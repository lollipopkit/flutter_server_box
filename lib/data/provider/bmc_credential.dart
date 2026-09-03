import 'dart:async';

import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:server_box/data/model/server/bmc_credential.dart';
import 'package:server_box/data/provider/entity_helpers.dart';
import 'package:server_box/data/provider/server/all.dart';
import 'package:server_box/data/res/store.dart';

part 'bmc_credential.freezed.dart';
part 'bmc_credential.g.dart';

@freezed
abstract class BmcCredentialState with _$BmcCredentialState {
  const factory BmcCredentialState({
    @Default(<BmcCredential>[]) List<BmcCredential> creds,
  }) = _BmcCredentialState;
}

/// The BMC accounts, as a provider so the picker and the list page see the
/// same set without either of them reloading the other.
///
/// The same shape as [PrivateKeyNotifier], which the accounts are the same kind
/// of record as: named, shared between servers, and edited from two places.
@Riverpod(keepAlive: true)
class BmcCredentialNotifier extends _$BmcCredentialNotifier {
  @override
  BmcCredentialState build() => _load();

  void reload() {
    Stores.bmcCredential.dropCache();
    final fresh = _load();
    if (fresh == state) return;
    state = fresh;
  }

  BmcCredentialState _load() {
    final creds = Stores.bmcCredential.fetch();
    return stateOrNull?.copyWith(creds: creds) ??
        BmcCredentialState(creds: creds);
  }

  Future<void> add(BmcCredential cred) async {
    state = state.copyWith(
      creds: entityAdd(Stores.bmcCredential, state.creds, cred),
    );
  }

  /// The id never changes — see [PrivateKeyNotifier.update] for why that
  /// matters. A rename is an `UPDATE` of one column, and every server pointing
  /// at this account keeps pointing at it.
  Future<void> update(BmcCredential old, BmcCredential fresh) async {
    state = state.copyWith(
      creds: entityUpdate(
        Stores.bmcCredential,
        state.creds,
        old,
        fresh,
        (e) => e.id,
      ),
    );
  }

  /// Deletes the account. The servers that used it keep their address and lose
  /// the account — `ON DELETE SET NULL`, not cascade.
  ///
  /// Those servers are cleared here rather than left to the foreign key, which
  /// on its own is not enough twice over. It writes the column directly, so
  /// `updated_at` and `rev` do not move and the clearing never travels: a
  /// peer's next sync reads the row as unchanged and puts the dangling id
  /// back. And it is invisible to this process, since [ServerStore] answers
  /// from a cache this delete does not touch — the next save of an affected
  /// server would send the id back to a row that is gone and take a foreign
  /// key error out of the editor.
  ///
  /// The key action stays as the backstop for a row written by anything that
  /// does not come through here.
  Future<void> delete(BmcCredential cred) async {
    final affected = Stores.server
        .fetch()
        .where((spi) => spi.bmc?.credId == cred.id)
        .toList();

    for (final spi in affected) {
      Stores.server.update(
        spi,
        spi.copyWith(bmc: spi.bmc!.copyWith(credId: null)),
      );
    }

    state = state.copyWith(
      creds: entityDelete(
        Stores.bmcCredential,
        state.creds,
        cred,
        (e) => e.id,
      ),
    );

    if (affected.isNotEmpty) {
      unawaited(ref.read(serversProvider.notifier).reload());
    }
  }

  /// How many servers point at [id], which the UI says before offering a
  /// delete or an edit: both change what all of them use.
  int serversUsing(String id) => Stores.bmcCredential.serversUsing(id);
}
