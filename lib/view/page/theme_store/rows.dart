import 'package:server_box/core/service/theme_package.dart';
import 'package:server_box/core/service/theme_repo.dart';
import 'package:server_box/data/model/app/theme_sort.dart';

/// One theme, as the store page draws it.
///
/// The page used to draw two lists — what this device has and what the catalog
/// offers — and a theme installed from the catalog appeared in both, as
/// `Aurora` twice. They are one theme: the listing and the installed package
/// carry the same manifest id. A row saying which theme it is and what is true
/// of it is the same information with the cross-reference already done.
final class ThemeRow {
  const ThemeRow({
    required this.name,
    required this.inUse,
    this.installed,
    this.item,
  });

  /// What the theme is called.
  ///
  /// The catalog's name where the store carries one — it is the newer of the
  /// two records, so a theme renamed upstream is the name being looked for —
  /// and the manifest's own name for a theme only this device has.
  final String name;

  /// Whether this is the theme the app is drawing now.
  final bool inUse;

  /// What this device has, when it has something.
  final ThemePackage? installed;

  /// What the catalog offers, when it offers this theme.
  final ThemeStoreItem? item;

  bool get onDevice => installed != null;

  /// The manifest id: stable across versions, and what the two records of one
  /// theme are matched by.
  String get id => installed?.id ?? item!.listing.id;

  /// What the page tracks a row's work by: the installation id a removal takes,
  /// or — for a theme the store has and this device does not — the manifest id
  /// the install will land under.
  String get key => installed?.installationId ?? item!.listing.id;

  /// What a query is matched against: every name the row is known by, so a
  /// search for the manifest id or the repository finds it as well.
  String get searchText => [
    name,
    if (installed case final theme?) theme.id,
    if (item case final item?) ...[
      item.listing.id,
      item.listing.description,
      item.repo,
    ],
  ].join('\n').toLowerCase();
}

/// The rows the page draws: one per theme, filtered by [query] and ordered by
/// [sort].
///
/// Pure, and separate from the page for that reason — the merge is the part
/// with a decision in it, and it is the part a widget test cannot reach without
/// a filesystem full of themes to read.
List<ThemeRow> buildThemeRows({
  required List<ThemePackage> installed,
  required List<ThemeStoreItem> items,
  required String activeInstallationId,
  String query = '',
  ThemeSort sort = ThemeSort.inUse,
}) {
  final active = activeInstallationId.isNotEmpty;
  // One manifest id can be behind two installations — the store's copy and one
  // imported beside it, or two versions installed one after the other — and the
  // catalog's row is whichever of them the app is drawing.
  final byManifestId = <String, ThemePackage>{};
  for (final theme in installed) {
    if (theme.installationId == activeInstallationId ||
        !byManifestId.containsKey(theme.id)) {
      byManifestId[theme.id] = theme;
    }
  }
  final rows = <ThemeRow>[];
  // The installations the catalog's rows already carry. By installation and not
  // by manifest id: a second package of a theme the store lists is a row of its
  // own below, and matching on the manifest id would leave it on no row at all.
  final listed = <String>{};

  // The catalog first, so each of its themes is in the order the store offers
  // it; what only this device has follows.
  for (final item in items) {
    final match = byManifestId[item.listing.id];
    if (match != null) listed.add(match.installationId);
    rows.add(
      ThemeRow(
        name: item.listing.name,
        inUse: active && match?.installationId == activeInstallationId,
        installed: match,
        item: item,
      ),
    );
  }
  for (final theme in installed) {
    if (listed.contains(theme.installationId)) continue;
    rows.add(
      ThemeRow(
        name: theme.name,
        inUse: active && theme.installationId == activeInstallationId,
        installed: theme,
      ),
    );
  }

  final needle = query.trim().toLowerCase();
  final shown = needle.isEmpty
      ? rows
      : [
          for (final row in rows)
            if (row.searchText.contains(needle)) row,
        ];
  shown.sort((a, b) => _compare(a, b, sort));
  return shown;
}

int _compare(ThemeRow a, ThemeRow b, ThemeSort sort) {
  if (sort != ThemeSort.inUse) {
    final byName = _byName(a, b);
    return sort == ThemeSort.nameAsc ? byName : -byName;
  }
  final rank = _rank(a).compareTo(_rank(b));
  return rank != 0 ? rank : _byName(a, b);
}

int _rank(ThemeRow row) => row.inUse ? 0 : (row.onDevice ? 1 : 2);

/// Names compared folded, ties broken by [ThemeRow.key]: `sort` is not stable,
/// and two themes of one name would otherwise swap places between rebuilds.
int _byName(ThemeRow a, ThemeRow b) {
  final byName = a.name.toLowerCase().compareTo(b.name.toLowerCase());
  return byName != 0 ? byName : a.key.compareTo(b.key);
}
