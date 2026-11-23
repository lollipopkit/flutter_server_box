import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:server_box/data/model/server/bmc_target.dart';
import 'package:server_box/data/model/server/server_private_info.dart';
import 'package:server_box/data/provider/bmc/selection.dart';
import 'package:server_box/data/provider/server/selection.dart';

/// One entry rendered on the Status tab grid, search, grouping, sorting, and
/// bulk selection.
///
/// Each concrete subtype wraps an independent domain entity so adding future
/// card types (e.g. uptime probes) does not bloat `Spi` or host-only features.
sealed class StatusCardItem {
  const StatusCardItem();

  /// Stable, type-namespaced key used for widget keys, selection, and
  /// per-card UI preferences (`srv:<id>`, `bmc:<id>`, ...).
  String get cardKey;

  /// Underlying entity id within its own store.
  String get id;

  /// Display title used for alphabetical sorting and text search.
  String get name;

  /// Address or host string included in text search.
  String get displayAddr;

  /// Tags associated with this item for filtering and tag grouping.
  List<String> get tags;
}

final class ServerCardItem extends StatusCardItem {
  const ServerCardItem(this.spi);

  final Spi spi;

  static String keyOf(String id) => 'srv:$id';

  @override
  String get cardKey => keyOf(spi.id);

  @override
  String get id => spi.id;

  @override
  String get name => spi.name;

  @override
  String get displayAddr => spi.displayAddr;

  @override
  List<String> get tags => spi.tags ?? const [];

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is ServerCardItem && other.spi == spi);

  @override
  int get hashCode => spi.hashCode;
}

final class BmcCardItem extends StatusCardItem {
  const BmcCardItem(this.target);

  final BmcTarget target;

  static String keyOf(String id) => 'bmc:$id';

  @override
  String get cardKey => keyOf(target.id);

  @override
  String get id => target.id;

  @override
  String get name => target.name;

  @override
  String get displayAddr => target.displayAddr;

  @override
  List<String> get tags => target.tags ?? const [];

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is BmcCardItem && other.target == target);

  @override
  int get hashCode => target.hashCode;
}

/// Which Status tab item is open in the wide two-pane detail host.
///
/// Backed by `serverSelectionProvider` (kept untouched for existing deep links,
/// tray, Agent screen awareness, and tests) plus `bmcSelectionProvider`,
/// mutually exclusive.
abstract final class StatusSelection {
  static String? watchCardKey(WidgetRef ref) {
    final serverId = ref.watch(serverSelectionProvider);
    final bmcId = ref.watch(bmcSelectionProvider);
    if (serverId != null) return ServerCardItem.keyOf(serverId);
    if (bmcId != null) return BmcCardItem.keyOf(bmcId);
    return null;
  }

  static void selectItem(WidgetRef ref, StatusCardItem? item) {
    switch (item) {
      case null:
        ref.read(serverSelectionProvider.notifier).select(null);
        ref.read(bmcSelectionProvider.notifier).select(null);
      case ServerCardItem(:final spi):
        ref.read(bmcSelectionProvider.notifier).select(null);
        ref.read(serverSelectionProvider.notifier).select(spi.id);
      case BmcCardItem(:final target):
        ref.read(serverSelectionProvider.notifier).select(null);
        ref.read(bmcSelectionProvider.notifier).select(target.id);
    }
  }
}
