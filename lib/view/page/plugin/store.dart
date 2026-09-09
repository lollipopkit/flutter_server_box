import 'dart:async';

import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/material.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/core/utils/plugin/package.dart';
import 'package:server_box/data/model/plugin/repo.dart';
import 'package:server_box/data/model/plugin/repo_record.dart';
import 'package:server_box/data/model/plugin/store.dart';
import 'package:server_box/data/provider/plugin/installer.dart';
import 'package:server_box/data/provider/plugin/repo_source.dart';
import 'package:server_box/data/store/plugin.dart';
import 'package:server_box/src/rust/api/plugin.dart' as ffi;
import 'package:server_box/view/widget/plugin/consent.dart';

/// Installing from a repository. PLUGINS.md section 7.
///
/// Three things on this page are decisions rather than layout, and each is
/// there because the alternative reads as something else:
///
/// - a plugin this build is too old for is **listed and not installable**,
///   with the version that needs a newer app named. Hiding it reads as the
///   plugin not existing; offering it would be a button that fails.
/// - a plugin two repositories both offer says which one it came from. The
///   first-added wins, and a conflict nobody is told about is one nobody can
///   act on.
/// - a package the repository named no checksum for is **not installed by
///   default**. The dialog says what that means, and going ahead is the user's
///   answer to having been told — not a preference they set once.
class PluginStorePage extends StatefulWidget {
  const PluginStorePage({
    super.key,
    this.embedded = false,
    @visibleForTesting this.source,
    @visibleForTesting this.installer,
  });

  /// Shown inside the settings pane, which already names it in its bar.
  final bool embedded;

  /// Where an index and a package come from. Given in a test so the install
  /// path can be walked without a repository — which is the only way to check
  /// the refusals, since a real one would have to be made to serve bad bytes.
  final PluginRepoSource? source;

  /// Given in a test so nothing is written under the app's own data directory.
  final PluginInstaller? installer;

  @override
  State<PluginStorePage> createState() => _PluginStorePageState();
}

class _PluginStorePageState extends State<PluginStorePage> {
  late final _installer =
      widget.installer ?? PluginInstaller(root: PluginInstaller.appRoot);
  late final _source = widget.source ?? PluginRepoSource();
  final _repos = PluginRepoStore.instance;

  var _busy = false;

  /// Repository URL to what it last answered. Absent is "not read".
  final _indexes = <String, PluginIndex>{};

  /// Repository URL to why it could not be read, so the list can say which one
  /// is broken rather than showing a short list and no reason.
  final _failures = <String, String>{};

  List<StoreEntry> _entries = const [];

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  /// Reads what is cached and fetches what is stale.
  ///
  /// Paced rather than fetched on every visit: an index changes when somebody
  /// publishes, which is not often, and a page that hits the network every
  /// time it opens is a page nobody opens on a train.
  Future<void> _load({bool force = false}) async {
    setState(() => _busy = true);
    final now = DateTime.now();
    try {
      for (final repo in _repos.readAll()) {
        if (!repo.enabled) continue;
        if (!force && !repo.staleAt(now) && _indexes.containsKey(repo.url)) {
          continue;
        }
        try {
          final index = await _source.index(repo.url);
          _indexes[repo.url] = index;
          _failures.remove(repo.url);
          // Including what it calls itself, which is the only place that name
          // is ever learned — read on every fetch and, before this, thrown
          // away, so every GitHub-hosted repository was listed as its address.
          _repos.put(repo.copyWith(lastFetchedAt: now, name: index.name));
        } catch (e) {
          _failures[repo.url] = '$e';
          Loggers.app.warning('Reading the plugin index ${repo.url}', e);
        }
      }
      _rebuild();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _rebuild() {
    final installed = {
      for (final i in PluginInstallStore.instance.readAll()) i.id: i,
    };
    _entries = PluginStore.merge(
      repos: _repos.readAll(),
      indexes: _indexes,
      installed: installed,
      abi: ffi.pluginAbiVersion(),
    );
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final outdated = PluginStore.outdated(_entries);
    return Scaffold(
      appBar: CustomAppBar(
        title: widget.embedded ? null : Text(l10n.pluginStore),
        actions: [
          Btn.icon(
            icon: const Icon(Icons.dns_outlined, size: 18),
            onTap: _showRepos,
          ),
          Btn.icon(
            icon: const Icon(Icons.refresh, size: 18),
            onTap: _busy ? null : () => unawaited(_load(force: true)),
          ),
        ],
      ),
      body: _body(outdated),
    );
  }

  Widget _body(List<StoreEntry> outdated) {
    if (_repos.readAll().isEmpty) {
      return _Empty(
        icon: Icons.dns_outlined,
        title: l10n.pluginNoRepos,
        detail: l10n.pluginNoReposTip,
        action: (label: l10n.pluginAddRepo, onTap: _addRepo),
      );
    }
    if (_busy && _entries.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_entries.isEmpty) {
      return _Empty(
        icon: Icons.extension_outlined,
        title: l10n.pluginStoreEmpty,
        detail: _failures.isEmpty
            ? l10n.pluginStoreEmptyTip
            : _failures.values.first,
        action: (label: libL10n.refresh, onTap: () => _load(force: true)),
      );
    }

    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 7),
      children: [
        // Above the list, because it is the reason to have opened the page.
        if (outdated.isNotEmpty)
          CardX(
            child: ListTile(
              leading: const Icon(Icons.upgrade, size: 19),
              title: Text(l10n.pluginUpdatesAvailable(outdated.length)),
              subtitle: Text(
                outdated.map((e) => e.listing.name).join(', '),
                style: UIs.text12Grey,
              ),
              trailing: Btn.text(
                text: l10n.pluginUpdateAll,
                onTap: _busy ? null : () => unawaited(_updateAll(outdated)),
              ),
            ),
          ),
        for (final entry in _entries)
          _EntryTile(entry: entry, busy: _busy, onTap: _install),
      ],
    );
  }

  // ------------------------------------------------------------ installing

  /// Updates everything with a newer runnable release, one at a time.
  ///
  /// Through [_install], because an update is an install: same download, same
  /// digest rule, and the same dialog whenever the permissions moved. One
  /// failure does not stop the rest — they are separate plugins from separate
  /// repositories, and stopping would make the first slow server decide what
  /// the others get.
  Future<void> _updateAll(List<StoreEntry> outdated) async {
    var done = 0;
    for (final entry in outdated) {
      if (!mounted) return;
      if (await _install(entry, announce: false)) done++;
    }
    // One message for the run rather than one per plugin, and the count
    // because it is how a cancelled or failed one is visible at all.
    if (mounted && done > 0) Toast.show('${libL10n.saved} ($done)');
  }

  /// Installs [entry]'s best release, answering whether it landed.
  Future<bool> _install(StoreEntry entry, {bool announce = true}) async {
    final release = entry.best;
    if (release == null || _busy) return false;
    setState(() => _busy = true);
    try {
      var accept = false;
      if (!release.verifiable) {
        // Asked before anything is downloaded. Afterwards the bytes are
        // already here, and "do you want this anyway" is a worse question than
        // "shall I fetch something nobody can check".
        final ok = await context.showRoundDialog<bool>(
          title: l10n.pluginNoChecksum,
          child: Text(l10n.pluginNoChecksumTip(entry.repo.label)),
          actions: Btnx.cancelRedOk,
        );
        if (ok != true || !mounted) return false;
        accept = true;
      }

      final download = await _source.download(
        release,
        // The repository this came from: a release naming a path inside it is
        // already in hand from the fetch, and asking for those bytes again over
        // the same connection would be the only request this makes.
        from: _indexes[entry.repo.url],
        acceptWithoutDigest: accept,
      );
      final package = PluginPackage.read(download.bytes);
      final manifest = ffi.pluginReadManifest(
        manifestJson: package.manifestJson,
      );
      if (!mounted) return false;

      // The same dialog an `.sbp` install shows. An update asks too, but only
      // when the new version wants something the user has not already agreed
      // to — see `askPluginUpgradeConsent`.
      final installed = entry.installed;
      final consented = installed == null
          ? await askPluginConsent(context, manifest)
          : await askPluginUpgradeConsent(
              context,
              manifest,
              granted: installed.granted,
            );
      if (consented == null || !mounted) return false;

      await _installer.install(
        download.bytes,
        consented: consented,
        // Where it came from, so an update knows where to look.
        repo: entry.repo.url,
      );
      _rebuild();
      if (announce) Toast.show(libL10n.saved);
      return true;
    } on PluginTrustRefused catch (e) {
      // A mismatch is not a question — see `PluginTrustRefused.skippable`.
      if (mounted) Toast.error(l10n.pluginChecksumFailed, body: '$e');
      return false;
    } catch (e, s) {
      Loggers.app.warning('Installing ${entry.listing.id}', e, s);
      if (mounted) Toast.error(libL10n.fail, body: '$e');
      return false;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // --------------------------------------------------------- repositories

  Future<void> _showRepos() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _ReposSheet(
        repos: _repos.readAll(),
        failures: _failures,
        onAdd: _addRepo,
        onRemove: (url) {
          _repos.remove(url);
          _indexes.remove(url);
          _failures.remove(url);
          _rebuild();
        },
        onToggle: (url, on) {
          _repos.setEnabled(url, on);
          _rebuild();
        },
      ),
    );
    if (mounted) await _load();
  }

  Future<void> _addRepo() async {
    final url = await context.showRoundDialog<String>(
      title: l10n.pluginAddRepo,
      child: Input(
        autoFocus: true,
        hint: 'https://github.com/you/serverbox-plugins',
        onSubmitted: (v) => context.popDialog(v.trim()),
      ),
    );
    if (url == null || url.isEmpty || !mounted) return;

    setState(() => _busy = true);
    try {
      // Fetched before it is stored, so a typo is a message rather than a row
      // that fails quietly every time the page opens.
      final index = await _source.index(url);
      _repos.put(
        PluginRepoRecord(
          url: url,
          name: index.name,
          addedAt: DateTime.now(),
          lastFetchedAt: DateTime.now(),
        ),
      );
      _indexes[url] = index;
      _rebuild();
    } catch (e) {
      if (mounted) Toast.error(libL10n.fail, body: '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}

class _EntryTile extends StatelessWidget {
  const _EntryTile({
    required this.entry,
    required this.busy,
    required this.onTap,
  });

  final StoreEntry entry;

  /// Something else on the page is downloading. The button says so rather than
  /// looking pressable and being declined.
  final bool busy;

  final Future<bool> Function(StoreEntry) onTap;

  @override
  Widget build(BuildContext context) {
    final best = entry.best;
    final installed = entry.installed;
    final act = busy ? null : () => unawaited(onTap(entry));
    return CardX(
      child: ListTile(
        leading: const Icon(Icons.extension_outlined, size: 19),
        title: Text(entry.listing.name, style: UIs.text15),
        subtitle: Text(_subtitle(), style: UIs.text12Grey),
        trailing: switch (entry) {
          _ when best == null => Text(l10n.pluginNeedsNewerApp, style: UIs.text12Grey),
          _ when entry.outdated => Btn.text(text: libL10n.update, onTap: act),
          _ when installed != null => Text(l10n.pluginInstalled, style: UIs.text12Grey),
          _ => Btn.text(text: l10n.pluginInstall, onTap: act),
        },
      ),
    );
  }

  String _subtitle() {
    final parts = <String>[
      if (entry.best case final r?) 'v${r.version}',
      if (entry.installed case final i? when entry.outdated) '← v${i.version}',
      entry.repo.label,
      // Said out loud: a conflict resolved silently is one nobody can act on,
      // and which repository this came from decides what its updates will be.
      if (entry.shadowed.isNotEmpty)
        l10n.pluginAlsoIn(entry.shadowed.length),
      // Not the same as "up to date", and the two must not both read as
      // nothing.
      if (entry.appTooOld && entry.tooNew.isNotEmpty)
        l10n.pluginNewerNeedsApp(entry.tooNew.first.version),
    ];
    final description = entry.listing.description;
    // What the repository says changed, and only for an update: it is the
    // question somebody about to press Update is asking, and on a plugin that
    // is not installed it is a note about a version nobody has.
    final notes = entry.outdated ? entry.best?.notes : null;
    return [
      parts.join('  ·  '),
      if (notes != null && notes.isNotEmpty) notes,
      if (description.isNotEmpty) description,
    ].join('\n');
  }
}

class _ReposSheet extends StatelessWidget {
  const _ReposSheet({
    required this.repos,
    required this.failures,
    required this.onAdd,
    required this.onRemove,
    required this.onToggle,
  });

  final List<PluginRepoRecord> repos;
  final Map<String, String> failures;
  final Future<void> Function() onAdd;
  final void Function(String url) onRemove;
  final void Function(String url, bool enabled) onToggle;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            title: Text(l10n.pluginRepos),
            trailing: Btn.icon(
              icon: const Icon(Icons.add, size: 19),
              onTap: () {
                context.pop();
                unawaited(onAdd());
              },
            ),
          ),
          const Divider(height: 1),
          if (repos.isEmpty)
            Padding(
              padding: const EdgeInsets.all(17),
              child: Text(l10n.pluginNoRepos, style: UIs.textGrey),
            ),
          for (final repo in repos)
            ListTile(
              dense: true,
              title: Text(repo.label, style: UIs.text13),
              subtitle: Text(
                failures[repo.url] ?? repo.url,
                style: failures.containsKey(repo.url)
                    ? UIs.text12Grey.copyWith(color: Colors.orange)
                    : UIs.text12Grey,
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Switch(
                    value: repo.enabled,
                    onChanged: (on) => onToggle(repo.url, on),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete, size: 19),
                    onPressed: () => onRemove(repo.url),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({
    required this.icon,
    required this.title,
    required this.detail,
    this.action,
  });

  final IconData icon;
  final String title;
  final String detail;
  final ({String label, Future<void> Function() onTap})? action;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(27),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          spacing: 11,
          children: [
            Icon(icon, size: 37, color: context.theme.hintColor),
            Text(title, style: UIs.text15),
            Text(detail, style: UIs.text12Grey, textAlign: TextAlign.center),
            if (action case final a?)
              Btn.text(text: a.label, onTap: () => unawaited(a.onTap())),
          ],
        ),
      ),
    );
  }
}
