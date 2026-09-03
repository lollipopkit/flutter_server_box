part of 'tab.dart';

/// How the server list is ordered.
///
/// [manual] is the arrangement the user made on the settings page, which is
/// what `serverOrder` already is — so it sorts nothing, and is the default for
/// that reason. Anything else here is a view over that list, remembered but
/// never written back to it.
///
/// An enum rather than the two loose values it is stored as. The stored form
/// is an int and a bool, which is what the terminal tab's own sort keeps, and
/// everything above the store deals in one value.
enum _SortField {
  manual,
  name,
  status;

  static _SortField fromStored(int index) {
    return index >= 0 && index < values.length ? values[index] : manual;
  }

  /// Whether reversing this field means anything.
  ///
  /// [manual] *is* the arrangement, so a reversed one is a second arrangement
  /// nobody made — and the list already has a page for saying what the order
  /// should be. The other two are comparisons and read both ways.
  bool get directional => this != manual;
}

/// A field and a direction, with the label and icon that go with them.
class _SortOrder {
  const _SortOrder(this.field, {required this.ascending});

  final _SortField field;
  final bool ascending;

  static _SortOrder get stored {
    final field = _SortField.fromStored(Stores.setting.serverPageSortBy.fetch());
    return _SortOrder(
      field,
      // Normalised, so a direction left behind by another field cannot make
      // the default look like something nothing in the sheet offers.
      ascending: field.directional
          ? Stores.setting.serverPageSortAsc.fetch()
          : true,
    );
  }

  void save() {
    Stores.setting.serverPageSortBy.put(field.index);
    Stores.setting.serverPageSortAsc.put(ascending);
  }

  /// Every option the menu offers, in the order it offers them.
  static List<_SortOrder> get all => [
    for (final field in _SortField.values)
      if (field.directional)
        for (final ascending in [true, false])
          _SortOrder(field, ascending: ascending)
      else
        _SortOrder(field, ascending: true),
  ];

  IconData get icon => switch ((field, ascending)) {
    (_SortField.manual, _) => Icons.format_list_numbered,
    (_SortField.name, true) => Icons.sort_by_alpha,
    (_SortField.name, false) => Icons.sort,
    (_SortField.status, true) => Icons.arrow_upward,
    (_SortField.status, false) => Icons.arrow_downward,
  };

  String get label {
    final subject = switch (field) {
      _SortField.manual => libL10n.sequence,
      _SortField.name => libL10n.sortByName,
      _SortField.status => l10n.status,
    };
    if (!field.directional) return subject;
    final direction = switch (field) {
      // Alphabetical order reads as A-Z, not as "ascending"
      _SortField.name => ascending ? '(A-Z)' : '(Z-A)',
      _ => '(${ascending ? libL10n.ascending : libL10n.descending})',
    };
    return '$subject $direction';
  }

  bool get isCurrent {
    final current = stored;
    if (current.field != field) return false;
    return !field.directional || current.ascending == ascending;
  }

  /// [order] is the arrangement from the settings, which is the whole of what
  /// [_SortField.manual] orders by — so that case is a copy or a reverse, not
  /// a comparison.
  ///
  /// [connOf] answers what a server's connection is doing. Read through a
  /// callback rather than from a provider here, because this runs inside a
  /// build and the caller is the one holding a `ref`.
  List<String> apply(
    List<String> order,
    Map<String, Spi> servers,
    ServerConn Function(String id) connOf,
  ) {
    switch (field) {
      case _SortField.manual:
        return order;
      case _SortField.name:
        final sorted = order.toList();
        sorted.sort((a, b) {
          // Case-folded, or the order is ASCII's rather than the alphabet's:
          // every capitalised name sorts above every lowercase one, so `Zeus`
          // comes before `alpha` under A-Z.
          final nameA = (servers[a]?.name ?? '').toLowerCase();
          final nameB = (servers[b]?.name ?? '').toLowerCase();
          return ascending ? nameA.compareTo(nameB) : nameB.compareTo(nameA);
        });
        return sorted;
      case _SortField.status:
        // Both read once per server rather than inside the comparator, which
        // runs O(n log n) times: `connOf` reaches a provider, and a position
        // looked up with `indexOf` is a scan of the list being sorted.
        final conn = {for (final id in order) id: connOf(id).index};
        final rank = {for (var i = 0; i < order.length; i++) order[i]: i};
        final sorted = order.toList();
        // By how far along the connection is, and by the settings order within
        // each state — `sort` is not stable, so the tie is broken explicitly
        // or servers in the same state shuffle between rebuilds.
        sorted.sort((a, b) {
          final byState = conn[a]!.compareTo(conn[b]!);
          if (byState != 0) return ascending ? byState : -byState;
          return rank[a]!.compareTo(rank[b]!);
        });
        return sorted;
    }
  }
}

