/// How the theme store orders its rows.
///
/// In the model layer rather than beside the page that uses it, for the reason
/// the other sort vocabularies are: the chosen value is stored, and the store
/// that defaults it is not a view.
enum ThemeSort {
  /// What is in use, then what this device has, then what only the catalog
  /// offers — each part by name.
  ///
  /// The default, because the question the page is opened with is which theme
  /// is on, and that answer should not be a scroll away.
  inUse,

  /// One ordering of one name, in its two directions.
  nameAsc,
  nameDesc;

  /// Reads the name a build wrote, falling back to [inUse].
  ///
  /// A name rather than an index, and for the reason every stored enum is: an
  /// index changes meaning when a case is inserted, and this value outlives the
  /// build that wrote it.
  static ThemeSort fromStored(Object? stored) {
    for (final sort in values) {
      if (sort.name == stored) return sort;
    }
    return inUse;
  }
}
