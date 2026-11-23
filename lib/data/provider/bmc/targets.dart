import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:server_box/data/model/server/bmc_target.dart';
import 'package:server_box/data/provider/bmc/selection.dart';
import 'package:server_box/data/store/bmc_target.dart';
import 'package:server_box/data/store/stores.dart';

part 'targets.freezed.dart';
part 'targets.g.dart';

@freezed
abstract class BmcTargetsState with _$BmcTargetsState {
  const BmcTargetsState._();

  const factory BmcTargetsState({
    @Default(<String, BmcTarget>{}) Map<String, BmcTarget> targets,
    @Default(<String>[]) List<String> order,
    @Default(<String>{}) Set<String> tags,
  }) = _BmcTargetsState;

  /// The BMC target linked to [serverId], if any.
  BmcTarget? forServer(String serverId) {
    for (final id in order) {
      final target = targets[id];
      if (target != null && target.serverId == serverId) return target;
    }
    return null;
  }

  /// Targets that appear as standalone cards in the Status tab: unlinked, or
  /// whose referenced server no longer exists.
  List<BmcTarget> standalone(Set<String> serverIds) => [
    for (final id in order)
      if (targets[id] case final target?
          when !target.isLinked || !serverIds.contains(target.serverId))
        target,
  ];
}

/// Manages all [BmcTarget] records (both standalone and server-linked).
@Riverpod(keepAlive: true)
class BmcTargetsNotifier extends _$BmcTargetsNotifier {
  @override
  BmcTargetsState build() => _load();

  void reload() {
    if (getIt.isRegistered<BmcTargetStore>()) {
      Stores.bmcTarget.dropCache();
    }
    final fresh = _load();
    final selected = ref.read(bmcSelectionProvider);
    if (selected != null) {
      final chosen = fresh.targets[selected];
      if (chosen == null || chosen.isLinked) {
        ref.read(bmcSelectionProvider.notifier).select(null);
      }
    }
    if (fresh == state) return;
    state = fresh;
  }

  BmcTargetsState _load() {
    if (!getIt.isRegistered<BmcTargetStore>()) return const BmcTargetsState();
    final list = Stores.bmcTarget.fetch();
    final map = <String, BmcTarget>{};
    final order = <String>[];
    final tags = <String>{};
    for (final item in list) {
      map[item.id] = item;
      order.add(item.id);
      if (item.tags != null) tags.addAll(item.tags!);
    }
    return BmcTargetsState(targets: map, order: order, tags: tags);
  }

  void add(BmcTarget target) {
    Stores.bmcTarget.put(target);
    reload();
  }

  void update(BmcTarget old, BmcTarget fresh) {
    Stores.bmcTarget.update(old, fresh);
    reload();
  }

  void put(BmcTarget target) {
    final existing = state.targets[target.id];
    if (existing != null) {
      update(existing, target);
    } else {
      add(target);
    }
  }

  void delete(String id) {
    Stores.bmcTarget.deleteById(id);
    reload();
  }

  /// Persists a newly reviewed leaf certificate SHA-256 fingerprint on [id].
  void updateCertPin(String id, String sha256) {
    final existing = state.targets[id];
    if (existing == null) return;
    update(existing, existing.copyWith(certSha256: sha256));
  }

  /// Updates or clears tags on [id].
  void setTags(String id, List<String>? tags) {
    final existing = state.targets[id];
    if (existing == null) return;
    final clean = tags == null || tags.isEmpty ? null : tags;
    update(existing, existing.copyWith(tags: clean));
  }

  void renameTag(String from, String to) {
    Stores.bmcTarget.renameTag(from, to);
    reload();
  }
}
