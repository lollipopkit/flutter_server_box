import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/material.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/core/service/theme_package.dart';
import 'package:server_box/core/service/theme_repo.dart';
import 'package:server_box/data/model/app/theme_sort.dart';
import 'package:server_box/data/res/store.dart';
import 'package:server_box/data/res/url.dart';
import 'package:server_box/view/page/theme_store/rows.dart';

/// What the theme catalog offers, and what this device has.
///
/// One list, not two. A theme installed from the catalog is the theme the
/// catalog lists, so drawing them apart drew `Aurora` twice and left the reader
/// to work out that the two were one; a row that names the theme and says what
/// is true of it — in use, on this device, or only in the store — is the same
/// information with the cross-reference done. See [ThemeRow].
///
/// The catalog is kept between runs, so opening the page shows themes rather
/// than a spinner, and refreshing is something the user asks for instead of
/// something the page needs before it is usable. What is on screen when nothing
/// has been read yet is what this device has.
final class ThemeStorePage extends StatefulWidget {
  const ThemeStorePage({super.key});

  static const route = AppRouteNoArg(
    page: ThemeStorePage.new,
    path: '/theme_store',
  );

  @override
  State<ThemeStorePage> createState() => _ThemeStorePageState();
}

final class _ThemeStorePageState extends State<ThemeStorePage> {
  late final _setting = Stores.setting;

  ThemeStore _store = const ThemeStore();
  List<ThemePackage> _installed = const [];
  bool _busy = false;

  /// Set when the last refresh produced nothing, and cleared by one that did.
  /// A failure is drawn on the caption rather than over the list, since a
  /// catalog that could not be read still leaves the themes already here.
  String? _failure;

  /// What a row is waiting on, by the identity of what it applies to. Either
  /// action blocks the page, so only one row is ever in this state.
  String? _working;

  /// The query, and whether the bar is a field.
  final _search = InlineSearchController();

  /// How the list is ordered, held here as well as in the setting so a choice
  /// in the sheet redraws without a second read.
  late ThemeSort _sort = ThemeSort.fromStored(_setting.themeStoreSort.fetch());

  /// The builders and actions below are extensions, which are not the class and
  /// cannot reach its `setState`.
  void _rebuild(VoidCallback update) {
    if (mounted) setState(update);
  }

  @override
  void initState() {
    super.initState();
    _installed = ThemePackages.listInstalled();
    _store = _readCache();
    // The cache is on screen from the first frame; this only brings it up to
    // date, so a launch with no network still shows the themes there were.
    Future.microtask(_refresh);
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  /// The catalog as the last run left it, or an empty one.
  ///
  /// A cache that cannot be read is dropped rather than reported: it is a copy
  /// of something the network still has, and the refresh already on its way is
  /// the answer to it having gone stale.
  ThemeStore _readCache() {
    try {
      return ThemeStore.fromJson(_setting.themeStoreCache.fetch()) ??
          const ThemeStore();
    } catch (e, stack) {
      Loggers.app.warning('Reading the theme store cache', e, stack);
      return const ThemeStore();
    }
  }

  Future<void> _saveCache(ThemeStore store) async {
    try {
      await _setting.themeStoreCache.set(store.toJson());
    } catch (e, stack) {
      // Not a failed refresh: the catalog was read and is on screen. It only
      // means the next launch reads it from the network again.
      Loggers.app.warning('Writing the theme store cache', e, stack);
    }
  }

  Future<void> _refresh() async {
    setState(() => _busy = true);
    try {
      final store = await ThemeRepos.store(Urls.themeCatalog);
      if (!mounted) return;
      // A read that comes back with no repository is not an answer: every way
      // the catalog can fail reports itself by leaving the list empty, and
      // showing that would replace the themes on screen with none of them and
      // call it an empty catalog.
      if (store.repos.isEmpty) return _fail(l10n.themeStoreRefreshFailed);
      await _saveCache(store);
      if (!mounted) return;
      setState(() {
        _store = store;
        _failure = null;
      });
    } catch (e, stack) {
      Loggers.app.warning('Reading the theme store', e, stack);
      if (mounted) _fail(l10n.themeStoreRefreshFailed);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Reports a refresh that produced nothing.
  ///
  /// With themes already on screen the caption under the bar is what says so,
  /// and a dialog over them would only interrupt; with none, the message is the
  /// whole page.
  void _fail(String message) {
    setState(() => _failure = message);
    Toast.error(message);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // The bar is the field while a search is on, as on every other list in
      // the app that searches.
      appBar: CustomAppBar(
        title: InlineSearchBar(
          controller: _search,
          hint: libL10n.theme,
          child: Text(l10n.appearanceThemeStore),
        ),
        actions: [
          Btn.icon(
            text: libL10n.search,
            icon: const Icon(Icons.search, size: 18),
            onTap: _search.start,
          ),
          Btn.icon(
            text: libL10n.sort,
            icon: Icon(_sortIcon(_sort), size: 18),
            onTap: _showSortSheet,
          ),
          if (_busy)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 11),
              child: SizedBox.square(
                dimension: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            Btn.icon(
              text: libL10n.refresh,
              icon: const Icon(Icons.refresh, size: 18),
              onTap: _refresh,
            ),
        ],
      ),
      body: _buildBody(),
    );
  }
}

// --- Widget builders ---

extension on _ThemeStorePageState {
  Widget _buildBody() {
    return ListenableBuilder(
      listenable: _search,
      builder: (context, _) {
        final rows = buildThemeRows(
          installed: _installed,
          items: _store.items,
          activeInstallationId: _setting.appThemePackage.fetch(),
          query: _search.needle,
          sort: _sort,
        );
        // Nothing read and nothing on this device: the first read is still out,
        // or it came back empty and said why. Either way there is no list to
        // draw, so the page is the answer rather than a caption on one.
        if (rows.isEmpty && _store.fetchedAt == null) {
          if (_failure case final failure?) return _issueBody(failure);
          return const Center(child: UIs.centerLoading);
        }
        return RefreshIndicator(onRefresh: _refresh, child: _buildList(rows));
      },
    );
  }

  /// The list, in one column the width of a settings form.
  ///
  /// A row here is a name, a description and a row of facts, and on a wide
  /// window a full-bleed list puts its title against one edge and its buttons
  /// against the other. The page is opened from settings, where the content is
  /// capped the same way, so going full-bleed after it reads as a different
  /// app.
  Widget _buildList(List<ThemeRow> rows) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: PageColumns.columnWidth),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(left: 7, right: 7, top: 7, bottom: 27),
          children: [
            _buildCaption(),
            if (rows.isEmpty) _buildEmpty() else for (final row in rows) _row(row),
          ],
        ),
      ),
    );
  }

  /// What the catalog behind the list is, and how long ago it was read.
  ///
  /// The page is usable without a refresh, so this is the only thing that says
  /// how old what is on screen is: a theme's version and repository are on its
  /// own row, and a catalog nobody has re-read otherwise looks like a fresh one.
  Widget _buildCaption() {
    final fetchedAt = _store.fetchedAt;
    final text =
        _failure ??
        (fetchedAt == null ? null : _updatedAgo(fetchedAt));
    if (text == null) return UIs.placeholder;
    return Padding(
      padding: const EdgeInsets.fromLTRB(3, 3, 3, 9),
      child: Text(
        text,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.right,
        style: UIs.text12Grey,
      ),
    );
  }

  /// How long ago the catalog was read.
  ///
  /// The minute is spelled out rather than taken from `toAgoStr`, whose
  /// "just now" is a sentence of its own and reads as "updated Just now" under
  /// a verb.
  String _updatedAgo(DateTime fetchedAt) {
    final elapsed = DateTime.now().difference(fetchedAt);
    if (elapsed < const Duration(minutes: 1)) {
      return l10n.themeStoreUpdatedJustNow;
    }
    return l10n.themeStoreUpdatedFmt(fetchedAt.toAgoStr());
  }

  Widget _buildEmpty() {
    // Two different empties, and the way out of each is different: a query that
    // matched nothing is cleared in the bar, and a store with nothing in it is
    // refreshed from the bar.
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 27),
      child: _search.active
          ? EmptyMark(icon: Icons.search_off, label: _search.text.text)
          : EmptyMark(icon: Icons.storefront_outlined, label: libL10n.empty),
    );
  }

  Widget _issueBody(String failure) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(
          height: MediaQuery.sizeOf(context).height * 0.65,
          child: PageIssueView(
            title: libL10n.fail,
            explain: failure,
            icon: Icons.storefront_outlined,
            onRetry: _refresh,
          ),
        ),
      ],
    );
  }

  /// One theme.
  ///
  /// What the row can do is what is true of it: tapping installs a theme the
  /// catalog has and this device does not, switches to one it does, and does
  /// nothing to the one already on. The catalog's description and version stay
  /// on the row after an install — they are as true of the installed copy, and
  /// a second row saying them again is what the page used to do.
  Widget _row(ThemeRow row) {
    final release = row.item?.release;
    final facts = [
      if (row.item case final item?) item.repo,
      if (release != null) 'v${release.version}',
      if (release?.size case final size?) size.bytes2Str,
    ].join(' · ');
    final description = row.item?.listing.description.trim() ?? '';
    final subtitle = [
      if (description.isNotEmpty) description,
      if (facts.isNotEmpty) facts,
      // A theme imported from a file has neither: the manifest id is the only
      // thing that says which theme the row is.
      if (description.isEmpty && facts.isEmpty) row.id,
    ].join('\n');

    final busy = _working == row.key;
    final scheme = Theme.of(context).colorScheme;
    return ListTile(
      title: Text(row.name),
      subtitle: Text(subtitle, maxLines: 3, overflow: TextOverflow.ellipsis),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (row.inUse) Icon(Icons.check, size: 18, color: scheme.primary),
          if (busy)
            const SizedBox.square(
              dimension: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else if (row.installed case final theme?)
            Btn.icon(
              text: libL10n.delete,
              icon: const Icon(Icons.delete_outline, size: 18),
              onTap: () => _delete(theme),
            )
          else if (row.item case final item?)
            Btn.icon(
              text: l10n.appearanceThemeInstall,
              icon: const Icon(Icons.file_download_outlined, size: 18),
              onTap: () => _install(item),
            ),
        ],
      ),
      onTap: busy
          ? null
          : switch ((row.installed, row.item)) {
              (final theme?, _) => () => _apply(theme),
              (_, final item?) => () => _install(item),
              _ => null,
            },
    ).cardx;
  }
}

// --- The bar's sort ---

extension on _ThemeStorePageState {
  Future<void> _showSortSheet() async {
    final sort = await showRowsSheet<ThemeSort>(
      context,
      rows: (ctx) => [
        for (final option in ThemeSort.values)
          SheetChoiceTile(
            title: _sortLabel(option),
            icon: _sortIcon(option),
            selected: option == _sort,
            onTap: () => Navigator.of(ctx).pop(option),
          ),
      ],
    );
    if (sort == null || sort == _sort || !mounted) return;
    _setting.themeStoreSort.put(sort.name);
    _rebuild(() => _sort = sort);
  }

  /// `(A-Z)` and its reverse are not translated, for the reason the server
  /// list's sort labels give: alphabetical order reads as A-Z in any language.
  String _sortLabel(ThemeSort sort) => switch (sort) {
    ThemeSort.inUse => l10n.themeStoreSortInUse,
    ThemeSort.nameAsc => '${libL10n.sortByName} (A-Z)',
    ThemeSort.nameDesc => '${libL10n.sortByName} (Z-A)',
  };

  IconData _sortIcon(ThemeSort sort) => switch (sort) {
    ThemeSort.inUse => Icons.vertical_align_top,
    ThemeSort.nameAsc => Icons.sort_by_alpha,
    ThemeSort.nameDesc => Icons.sort,
  };
}

// --- Actions ---

extension on _ThemeStorePageState {
  Future<void> _install(ThemeStoreItem item) async {
    if (!item.installable) {
      Toast.error(l10n.appearanceThemeNeedsNewerApp(item.newestVersion ?? ''));
      return;
    }
    final (theme, error) = await context.showLoadingDialog<ThemePackage>(
      // No timeout: this waits on a download, and a slow link is not a reason
      // to call it failed.
      timeout: null,
      fn: () => ThemeRepos.install(item),
    );
    if (!mounted) return;
    if (theme == null) {
      // The dialog reported it; there is nothing to add about a download that
      // did not arrive.
      Loggers.app.warning('Installing ${item.label} failed: $error');
      return;
    }
    _apply(theme);
    Toast.show(libL10n.success);
  }

  Future<void> _delete(ThemePackage theme) async {
    final confirmed = await context.showRoundDialog<bool>(
      title: libL10n.delete,
      child: Text(l10n.themeStoreDeleteTheme(theme.name)),
      actions: Btnx.cancelOk,
    );
    if (confirmed != true || !mounted) return;

    _rebuild(() => _working = theme.installationId);
    final removed = await ThemePackages.remove(theme.installationId);
    if (!mounted) return;
    _rebuild(() {
      _working = null;
      _installed = ThemePackages.listInstalled();
    });
    if (!removed) {
      Toast.error(libL10n.fail);
      return;
    }
    // Removing the theme in use put the app back on the default, so the frame
    // it is drawing is one whose files are gone.
    RNodes.app.notify();
    Toast.show(libL10n.success);
  }

  void _apply(ThemePackage theme) {
    ThemePackages.apply(theme);
    _rebuild(() => _installed = ThemePackages.listInstalled());
    RNodes.app.notify();
  }
}
