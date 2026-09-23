part of 'tab.dart';

enum _SortField {
  name,
  added;

  static _SortField fromStored(int index) =>
      index >= 0 && index < values.length ? values[index] : name;
}

class _SortOrder {
  const _SortOrder(this.field, {required this.ascending});

  final _SortField field;
  final bool ascending;

  static _SortOrder get stored => _SortOrder(
    _SortField.fromStored(Stores.setting.remoteDesktopSortBy.fetch()),
    ascending: Stores.setting.remoteDesktopSortAsc.fetch(),
  );

  void save() {
    Stores.setting.remoteDesktopSortBy.put(field.index);
    Stores.setting.remoteDesktopSortAsc.put(ascending);
  }

  static List<_SortOrder> get all => [
    for (final field in _SortField.values)
      for (final ascending in [true, false])
        _SortOrder(field, ascending: ascending),
  ];

  IconData get icon => switch ((field, ascending)) {
    (_SortField.name, true) => Icons.sort_by_alpha,
    (_SortField.name, false) => Icons.sort,
    (_SortField.added, true) => Icons.arrow_upward,
    (_SortField.added, false) => Icons.arrow_downward,
  };

  String get label {
    final direction = switch (field) {
      _SortField.name => ascending ? '(A-Z)' : '(Z-A)',
      _SortField.added =>
        '(${ascending ? libL10n.ascending : libL10n.descending})',
    };
    final subject = switch (field) {
      _SortField.name => libL10n.sortByName,
      _SortField.added => l10n.sortByJoinTime,
    };
    return '$subject $direction';
  }

  bool get isCurrent {
    final current = stored;
    return current.field == field && current.ascending == ascending;
  }

  List<String> apply(List<String> order, Map<String, Spi> servers) {
    switch (field) {
      case _SortField.added:
        return ascending ? order : order.reversed.toList();
      case _SortField.name:
        final sorted = order.toList();
        sorted.sort((a, b) {
          final nameA = (servers[a]?.name ?? '').toLowerCase();
          final nameB = (servers[b]?.name ?? '').toLowerCase();
          return ascending ? nameA.compareTo(nameB) : nameB.compareTo(nameA);
        });
        return sorted;
    }
  }
}
