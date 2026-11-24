import 'package:fl_lib/fl_lib.dart';
import 'package:material_ui/material_ui.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/data/model/server/server_private_info.dart';

/// How a server picker orders its list.
///
/// Persisted as `(field.index, ascending)` across two store keys so existing
/// user preferences stay intact.
enum ServerPickerSortField {
  name,
  added;

  static ServerPickerSortField fromStored(int index) =>
      index >= 0 && index < values.length ? values[index] : name;
}

/// Pair of store properties holding a picker's [ServerPickerSortOrder].
final class ServerPickerSortPref {
  const ServerPickerSortPref({required this.sortBy, required this.sortAsc});

  final SqlitePropDefault<int> sortBy;
  final SqlitePropDefault<bool> sortAsc;

  ServerPickerSortOrder read() => ServerPickerSortOrder(
    ServerPickerSortField.fromStored(sortBy.fetch()),
    ascending: sortAsc.fetch(),
  );

  void write(ServerPickerSortOrder order) {
    sortBy.put(order.field.index);
    sortAsc.put(order.ascending);
  }
}

/// A sort field and direction for server pickers, with its menu label and icon.
@immutable
final class ServerPickerSortOrder {
  const ServerPickerSortOrder(this.field, {required this.ascending});

  final ServerPickerSortField field;
  final bool ascending;

  static const all = [
    ServerPickerSortOrder(ServerPickerSortField.name, ascending: true),
    ServerPickerSortOrder(ServerPickerSortField.name, ascending: false),
    ServerPickerSortOrder(ServerPickerSortField.added, ascending: true),
    ServerPickerSortOrder(ServerPickerSortField.added, ascending: false),
  ];

  IconData get icon => switch ((field, ascending)) {
    (ServerPickerSortField.name, true) => Icons.sort_by_alpha,
    (ServerPickerSortField.name, false) => Icons.sort,
    (ServerPickerSortField.added, true) => Icons.arrow_upward,
    (ServerPickerSortField.added, false) => Icons.arrow_downward,
  };

  String get label {
    final direction = switch (field) {
      ServerPickerSortField.name => ascending ? '(A-Z)' : '(Z-A)',
      ServerPickerSortField.added =>
        '(${ascending ? libL10n.ascending : libL10n.descending})',
    };
    final subject = switch (field) {
      ServerPickerSortField.name => libL10n.sortByName,
      ServerPickerSortField.added => l10n.sortByJoinTime,
    };
    return '$subject $direction';
  }

  /// Orders [order] (the servers in join order) according to [field] and
  /// [ascending], comparing names case-insensitively.
  List<String> apply(List<String> order, Map<String, Spi> servers) {
    switch (field) {
      case ServerPickerSortField.added:
        return ascending ? order : order.reversed.toList();
      case ServerPickerSortField.name:
        final sorted = order.toList();
        sorted.sort((a, b) {
          final nameA = (servers[a]?.name ?? '').toLowerCase();
          final nameB = (servers[b]?.name ?? '').toLowerCase();
          return ascending ? nameA.compareTo(nameB) : nameB.compareTo(nameA);
        });
        return sorted;
    }
  }

  @override
  bool operator ==(Object other) =>
      other is ServerPickerSortOrder &&
      other.field == field &&
      other.ascending == ascending;

  @override
  int get hashCode => Object.hash(field, ascending);
}
