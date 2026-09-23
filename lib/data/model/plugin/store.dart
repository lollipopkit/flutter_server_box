/// What the store page shows: every repository's listings, merged.
///
/// The merge is the part with a decision in it. Two repositories are free to
/// offer the same plugin id, and there is no authority that says which is the
/// real one — so **the repository added first wins**, and the other is
/// recorded rather than dropped. Homebrew settles a tap conflict the same way
/// and for the same reason: silently picking one is the worst answer, because
/// the user cannot tell it happened.
library;

import 'package:server_box/data/model/plugin/install.dart';
import 'package:server_box/data/model/plugin/repo.dart';
import 'package:server_box/data/model/plugin/repo_record.dart';

/// One plugin as the store offers it, with where it came from.
class StoreEntry {
  const StoreEntry({
    required this.listing,
    required this.repo,
    required this.best,
    required this.tooNew,
    this.installed,
    this.shadowed = const [],
  });

  final PluginListing listing;

  /// The repository this listing was taken from.
  final PluginRepoRecord repo;

  /// The newest release this app can run, or null if every one needs a newer
  /// ABI than this build has.
  final PluginRelease? best;

  /// Releases skipped because this app is too old for them, newest first.
  ///
  /// Shown rather than ignored: "there is a newer one and this app is too old"
  /// is a different answer from "you are up to date", and an entry that showed
  /// neither would make a stale install look current.
  final List<PluginRelease> tooNew;

  /// The install this device already has, if any.
  final PluginInstall? installed;

  /// Other repositories offering this same id, in the order they were added.
  ///
  /// Kept so the page can say so. A conflict that is resolved silently is one
  /// the user cannot find out about, and which repository a plugin came from
  /// decides what an update will be.
  final List<PluginRepoRecord> shadowed;

  bool get installable => best != null;

  /// Whether the copy on this device is one *this* repository put there.
  ///
  /// The question an update is really asking. A plugin id is not owned by
  /// anybody, so the same id installed from a file, from a working tree, or
  /// from another repository is a different set of bytes that happens to answer
  /// to the same name — and replacing it is a choice, not an update.
  bool get mine => installed?.repoUrl == repo.url;

  /// Installed, and from somewhere this repository cannot update.
  ///
  /// What the row says out loud, because the alternative is a plugin that is
  /// listed as installed and never offered anything, with no way to find out
  /// why.
  bool get elsewhere => installed != null && !mine;

  /// Whether a newer runnable release exists than the one installed.
  ///
  /// Compares against [best] rather than the newest release: a version this
  /// app cannot run is not an update it can offer. And only for a copy this
  /// repository installed — a working tree's 1.1.0 is not behind a
  /// repository's 1.0.1, and offering that update wrote a record naming a
  /// version the app then did not run.
  bool get outdated {
    final have = installed;
    final want = best;
    if (have == null || want == null || !mine) return false;
    return PluginVersion.compare(want.version, have.version) > 0;
  }

  /// Installed, and the only newer releases need a newer app.
  bool get appTooOld =>
      mine && installed != null && !outdated && tooNew.isNotEmpty;
}

abstract final class PluginStore {
  /// Merges what every enabled repository offers.
  ///
  /// [indexes] is keyed by repository URL. A repository that has not been
  /// fetched, or whose fetch failed, is simply absent — the page says so from
  /// the repository list rather than by inventing an empty listing.
  static List<StoreEntry> merge({
    required List<PluginRepoRecord> repos,
    required Map<String, PluginIndex> indexes,
    required Map<String, PluginInstall> installed,
    required int abi,
  }) {
    final byId = <String, StoreEntry>{};
    final shadowed = <String, List<PluginRepoRecord>>{};

    // `repos` is oldest first, which is what makes "the first one wins" mean
    // "the one added first".
    for (final repo in repos) {
      if (!repo.enabled) continue;
      final index = indexes[repo.url];
      if (index == null) continue;

      for (final listing in index.plugins) {
        if (byId.containsKey(listing.id)) {
          (shadowed[listing.id] ??= []).add(repo);
          continue;
        }
        byId[listing.id] = StoreEntry(
          listing: listing,
          repo: repo,
          best: listing.bestFor(abi),
          tooNew: listing.tooNewFor(abi),
          installed: installed[listing.id],
        );
      }
    }

    final out = [
      for (final e in byId.values)
        StoreEntry(
          listing: e.listing,
          repo: e.repo,
          best: e.best,
          tooNew: e.tooNew,
          installed: e.installed,
          shadowed: shadowed[e.listing.id] ?? const [],
        ),
    ];
    // By name, because that is what the reader is scanning. Not by repository:
    // which repository a plugin came from matters when deciding to install it,
    // not when looking for it.
    out.sort(
      (a, b) => a.listing.name.toLowerCase().compareTo(
        b.listing.name.toLowerCase(),
      ),
    );
    return out;
  }

  /// Everything installed that has a newer runnable release.
  static List<StoreEntry> outdated(List<StoreEntry> entries) =>
      [for (final e in entries) if (e.outdated) e];
}
