/// A repository this device reads, as it is stored.
///
/// Separate from [PluginIndex], which is what a repository *said*: this is
/// what the user added. The two meet only when a fetch succeeds, and a
/// repository that has never answered still has a row — otherwise removing a
/// broken address would mean first getting it to work.
library;

class PluginRepoRecord {
  const PluginRepoRecord({
    required this.url,
    required this.addedAt,
    this.name,
    this.enabled = true,
    this.lastFetchedAt,
  });

  /// The `index.json` address, which is the identity.
  final String url;

  /// What the index called itself when it was last read, for display only.
  final String? name;

  final bool enabled;
  final DateTime addedAt;

  /// When its index was last read. Null means never.
  final DateTime? lastFetchedAt;

  /// What to show when the index has not been read yet.
  ///
  /// The host, because a full URL in a list is mostly `https://` and a path
  /// nobody reads — and because a repository that has never answered has no
  /// name to show.
  String get label {
    final named = name;
    if (named != null && named.trim().isNotEmpty) return named;
    return Uri.tryParse(url)?.host ?? url;
  }

  /// Whether it is worth fetching again.
  ///
  /// Paced rather than fetched on every visit to the list. A day, which is the
  /// order of magnitude Homebrew uses for the same decision — an index changes
  /// when somebody publishes, which is not often, and the cost of being a day
  /// stale is seeing a release a day late.
  static const staleAfter = Duration(hours: 24);

  bool staleAt(DateTime now) {
    final last = lastFetchedAt;
    return last == null || now.difference(last) >= staleAfter;
  }

  PluginRepoRecord copyWith({
    String? name,
    bool? enabled,
    DateTime? lastFetchedAt,
  }) => PluginRepoRecord(
    url: url,
    name: name ?? this.name,
    enabled: enabled ?? this.enabled,
    addedAt: addedAt,
    lastFetchedAt: lastFetchedAt ?? this.lastFetchedAt,
  );
}
