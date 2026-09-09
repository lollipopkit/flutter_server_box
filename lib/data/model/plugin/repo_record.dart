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

  /// What to call it: the name it announced, or its address read short.
  String get label {
    final named = name;
    if (named != null && named.trim().isNotEmpty) return named;
    return labelOfAddress(url);
  }

  /// What to show for a repository that has not answered yet.
  ///
  /// **`owner/repo`, not the host.** A repository is a git repository now, and
  /// nearly all of them are on github.com — so the host is the part of the
  /// address that tells two of them apart *least*, and a list of them all read
  /// "github.com". Homebrew names a tap the same way and for the same reason.
  ///
  /// A full URL is not the answer either: in a list it is mostly `https://` and
  /// a path nobody reads.
  static String labelOfAddress(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null || uri.host.isEmpty) return url;

    var segments = [for (final s in uri.pathSegments) if (s.isNotEmpty) s];
    // The archive form the app also accepts (`…/archive/HEAD.tar.gz`), so
    // pasting one does not produce a repository called `archive/HEAD.tar.gz`.
    if (segments.length >= 2 &&
        segments[segments.length - 2] == 'archive' &&
        segments.last.endsWith('.tar.gz')) {
      segments = segments.sublist(0, segments.length - 2);
    }
    if (segments.isEmpty) return uri.host;

    final last = segments.last.replaceFirst(RegExp(r'\.git$'), '');
    // With one segment the host is what identifies it, so it stays.
    if (segments.length == 1) return '${uri.host}/$last';
    return '${segments[segments.length - 2]}/$last';
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
