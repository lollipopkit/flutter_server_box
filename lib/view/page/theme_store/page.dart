import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/material.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/core/service/theme_package.dart';
import 'package:server_box/core/service/theme_repo.dart';
import 'package:server_box/data/res/store.dart';

const _kPad = 13.0;

/// What the theme catalog offers, and what this device already has.
///
/// The two are on one page because they are the same decision seen twice:
/// installing puts a theme in the list below, and taking one off this device is
/// the only way off that list. The catalog is kept between runs, so opening the
/// page shows themes rather than a spinner, and refreshing is something the
/// user asks for instead of something the page needs before it is usable.
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
  /// What the page does about it depends on whether themes are on screen.
  String? _failure;

  /// What a row is waiting on, by the identity of what it applies to. Either
  /// action blocks the page, so only one row is ever in this state.
  String? _working;

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
    final url = _setting.themeStoreUrl.fetch().trim();
    if (url.isEmpty) {
      Toast.show(l10n.appearanceThemeStoreUrl);
      return;
    }
    setState(() => _busy = true);
    try {
      final store = await ThemeRepos.store(url);
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
  /// With themes already on screen the line under the bar is what says so, and
  /// a dialog over them would only interrupt; with none, the message is the
  /// whole page.
  void _fail(String message) {
    setState(() => _failure = message);
    Toast.error(message);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(
        title: Text(l10n.appearanceThemeStore),
        actions: [
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
    final fetchedAt = _store.fetchedAt;
    if (fetchedAt == null) {
      if (_failure case final failure?) return _issueBody(failure);
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [SizedBox(height: 280, child: UIs.centerLoading)],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildStaleness(fetchedAt),
        Expanded(
          child: RefreshIndicator(onRefresh: _refresh, child: _buildList()),
        ),
      ],
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

  /// Which repositories the catalog on screen came from, and how long ago it
  /// was read.
  ///
  /// The page is usable without a refresh, so this line is the only thing that
  /// says what is on it: an ago string that has been saying "5 days" is what a
  /// catalog nobody re-read looks like.
  Widget _buildStaleness(DateTime fetchedAt) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(_kPad, 8, _kPad, 8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  _store.repos.join(' · '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: UIs.text12Grey,
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  _failure ?? l10n.readAgoFmt(fetchedAt.toAgoStr()),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.right,
                  style: UIs.text12Grey,
                ),
              ),
            ],
          ),
        ),
        if (_busy)
          const LinearProgressIndicator(minHeight: 2)
        else
          Divider(height: 2, color: Hairline.color(context)),
      ],
    );
  }

  Widget _buildList() {
    final active = _setting.appThemePackage.fetch();
    final installedIds = {for (final theme in _installed) theme.id};
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        _sectionHeader(l10n.appearancePreset),
        if (_installed.isEmpty)
          _note(libL10n.empty)
        else
          for (final theme in _installed)
            _installedRow(theme, active: active),
        _sectionHeader(l10n.appearanceThemeStore),
        if (_store.items.isEmpty)
          _note(libL10n.empty)
        else
          for (final item in _store.items)
            _storeRow(item, installed: installedIds.contains(item.listing.id)),
      ],
    );
  }

  Widget _sectionHeader(String text) => Padding(
    padding: const EdgeInsets.fromLTRB(_kPad, 18, _kPad, 6),
    child: Text(text, style: UIs.text13Bold),
  );

  Widget _note(String text) => Padding(
    padding: const EdgeInsets.fromLTRB(_kPad, 6, _kPad, 18),
    child: Text(text, style: UIs.text12Grey),
  );

  /// One theme installed on this device.
  ///
  /// Two actions on one row: tapping puts the theme on, and the button takes it
  /// off. Which one is on is marked rather than spelled out, since a row saying
  /// "in use" is the row that does not with a word added.
  Widget _installedRow(ThemePackage theme, {required String active}) {
    final inUse = active.isNotEmpty && theme.installationId == active;
    final busy = _working == theme.installationId;
    final colorScheme = Theme.of(context).colorScheme;
    return ListTile(
      title: Text(theme.name),
      subtitle: Text(theme.id, maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (inUse) Icon(Icons.check, size: 18, color: colorScheme.primary),
          if (busy)
            const SizedBox.square(
              dimension: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else
            Btn.icon(
              text: libL10n.delete,
              icon: const Icon(Icons.delete_outline, size: 18),
              onTap: () => _delete(theme),
            ),
        ],
      ),
      onTap: busy ? null : () => _apply(theme),
    );
  }

  /// One theme a repository offers.
  ///
  /// A version this build cannot read is drawn as a row that says so rather
  /// than hidden: the answer to "is there one" is yes, and what to do about it
  /// is a sentence of its own.
  Widget _storeRow(ThemeStoreItem item, {required bool installed}) {
    final release = item.release;
    final facts = [
      item.repo,
      if (release != null) 'v${release.version}',
      if (release?.size case final size?) size.bytes2Str,
    ].join(' · ');
    final description = item.listing.description.trim();
    final subtitle = release == null
        ? '${l10n.appearanceThemeNeedsNewerApp(item.newestVersion ?? '')}\n'
              '$facts'
        : description.isEmpty
        ? facts
        : '$description\n$facts';
    return ListTile(
      title: Text(item.label),
      subtitle: Text(subtitle, maxLines: 3, overflow: TextOverflow.ellipsis),
      trailing: installed
          ? Icon(
              Icons.check,
              size: 18,
              color: Theme.of(context).colorScheme.primary,
            )
          : null,
      onTap: () => _install(item),
    );
  }
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
