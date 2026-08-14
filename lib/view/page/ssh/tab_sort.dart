part of 'tab.dart';

/// How the server picker orders its list.
///
/// An enum rather than the two loose values it is stored as. The stored form
/// is an int and a bool — kept, so nobody's setting resets — but everything
/// above the store deals in one value, which is what stops "0 means name" from
/// having to be remembered in three places at once.
enum _SortField {
  name,
  added;

  static _SortField fromStored(int index) {
    return index >= 0 && index < values.length ? values[index] : name;
  }
}

/// A field and a direction, with the label and icon that go with them.
class _SortOrder {
  const _SortOrder(this.field, {required this.ascending});

  final _SortField field;
  final bool ascending;

  static _SortOrder get stored => _SortOrder(
    _SortField.fromStored(Stores.setting.sshPageSortBy.fetch()),
    ascending: Stores.setting.sshPageSortAsc.fetch(),
  );

  void save() {
    Stores.setting.sshPageSortBy.put(field.index);
    Stores.setting.sshPageSortAsc.put(ascending);
  }

  /// Every option the menu offers, in the order it offers them.
  static List<_SortOrder> get all => [
    for (final field in _SortField.values)
      for (final ascending in [true, false]) _SortOrder(field, ascending: ascending),
  ];

  IconData get icon => switch ((field, ascending)) {
    (_SortField.name, true) => Icons.sort_by_alpha,
    (_SortField.name, false) => Icons.sort,
    (_SortField.added, true) => Icons.arrow_upward,
    (_SortField.added, false) => Icons.arrow_downward,
  };

  String get label {
    final direction = switch (field) {
      // Alphabetical order reads as A-Z, not as "ascending"
      _SortField.name => ascending ? '(A-Z)' : '(Z-A)',
      _SortField.added => '(${ascending ? libL10n.ascending : libL10n.descending})',
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

  /// [order] is the servers in the order they were added, which is the whole
  /// of what [_SortField.added] sorts by — so that case is a copy or a
  /// reverse, not a comparison.
  List<String> apply(List<String> order, Map<String, Spi> servers) {
    switch (field) {
      case _SortField.added:
        return ascending ? order : order.reversed.toList();
      case _SortField.name:
        final sorted = order.toList();
        sorted.sort((a, b) {
          final nameA = servers[a]?.name ?? '';
          final nameB = servers[b]?.name ?? '';
          return ascending
              ? nameA.compareTo(nameB)
              : nameB.compareTo(nameA);
        });
        return sorted;
    }
  }
}

/// One row of the sort menu.
class _SortOptionTile extends StatelessWidget {
  const _SortOptionTile({required this.order, required this.onTap});

  final _SortOrder order;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final selected = order.isCurrent;
    final color = selected ? Theme.of(context).colorScheme.primary : null;
    return ListTile(
      leading: Icon(order.icon, color: color),
      title: Text(order.label, style: TextStyle(color: color)),
      onTap: onTap,
    );
  }
}
