import 'dart:async';

import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/material.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/core/utils/plugin/package.dart';
import 'package:server_box/data/model/plugin/install.dart';
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

  /// What an "update all" is doing, or null when nothing is.
  ///
  /// **Counted in plugins, not in bytes.** A package is tens of kilobytes and
  /// the download is the quick part; unpacking, writing and republishing what
  /// the plugin contributes is the rest. A byte bar would run to the end and
  /// then sit there, which is two meanings in one bar.
  _UpdateRun? _run;

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
    final run = _run;
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

    // The head is what a run and an update are about; the plugins follow it.
    // Built lazily below rather than as one list of children: how long that
    // list is belongs to somebody else's repository, and building two hundred
    // rows to show eight is a cost this page does not get to decide.
    final head = [
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
              trailing: run == null
                  ? Btn.text(
                      text: l10n.pluginUpdateAll,
                      onTap: _busy ? null : () => unawaited(_updateAll(outdated)),
                    )
                  : Btn.text(
                      text: l10n.pluginStopAfterThis,
                      onTap: run.stopping ? null : () => setState(run.stop),
                    ),
            ),
          ),
        if (run != null) _RunProgress(run: run),
    ];

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 7),
      itemCount: head.length + _entries.length,
      itemBuilder: (_, i) {
        if (i < head.length) return head[i];
        final entry = _entries[i - head.length];
        return _EntryTile(
          entry: entry,
          busy: _busy,
          updating: run?.name == entry.listing.name,
          onTap: _install,
        );
      },
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
    final run = _UpdateRun(total: outdated.length);
    setState(() => _run = run);
    var failed = 0;
    try {
      for (final entry in outdated) {
        if (!mounted) return;
        // Checked before the next one rather than during: a plugin is written
        // to disk in one go, and stopping half way through would leave one
        // whose files and record disagree. The button says so.
        if (run.stopping) break;
        setState(() => run.begin(entry.listing.name));
        if (await _install(entry, announce: false)) {
          run.done++;
        } else {
          failed++;
        }
      }
    } finally {
      if (mounted) setState(() => _run = null);
    }
    // One message for the run rather than one per plugin, and both numbers:
    // a count of what worked, on its own, says nothing about what did not.
    if (!mounted || run.done + failed == 0) return;
    Toast.show(
      failed == 0
          ? l10n.pluginUpdatedCount(run.done)
          : l10n.pluginUpdatedSome(run.done, failed),
    );
  }

  /// Runs [ask] with the progress row saying it is waiting for an answer.
  Future<T> _whileAsking<T>(Future<T> Function() ask) async {
    final run = _run;
    if (run == null) return ask();
    setState(() => run.asking = true);
    try {
      return await ask();
    } finally {
      if (mounted) setState(() => run.asking = false);
    }
  }

  /// Installs [entry]'s best release, answering whether it landed.
  Future<bool> _install(StoreEntry entry, {bool announce = true}) async {
    final release = entry.best;
    if (release == null || _busy) return false;
    setState(() => _busy = true);
    try {
      // A copy this repository did not install is replaced only on purpose.
      // The id is the same and the bytes are somebody else's: a working tree,
      // a file that came from who knows where, another repository offering the
      // same name. Asked before the download, like the checksum question.
      if (entry.installed case final have? when entry.elsewhere) {
        final ok = await _whileAsking(
          () => context.showRoundDialog<bool>(
            title: l10n.pluginReplace,
            child: Text(
              l10n.pluginReplaceTip(have.sourceLabel, entry.repo.label),
            ),
            actions: Btnx.cancelRedOk,
          ),
        );
        if (ok != true || !mounted) return false;
      }

      var accept = false;
      if (!release.verifiable) {
        // Asked before anything is downloaded. Afterwards the bytes are
        // already here, and "do you want this anyway" is a worse question than
        // "shall I fetch something nobody can check".
        final ok = await _whileAsking(
          () => context.showRoundDialog<bool>(
            title: l10n.pluginNoChecksum,
            child: Text(l10n.pluginNoChecksumTip(entry.repo.label)),
            actions: Btnx.cancelRedOk,
          ),
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
      final installedNow = installed;
      // Said while a dialog is up: a bar that stops moving looks stuck, and
      // this one has stopped because it is waiting for the person looking at
      // it.
      // The package's own strings, so a manifest that names its plugin with an
      // `l10n.` key is read in the dialog rather than shown as the key. It is
      // the only copy of them there is at this point — nothing is installed
      // yet.
      final strings = package.l10nFor(
        Localizations.maybeLocaleOf(context)?.toLanguageTag() ?? 'en',
      );
      final consented = await _whileAsking(
        () => installedNow == null
            ? askPluginConsent(context, manifest, strings: strings)
            : askPluginUpgradeConsent(
                context,
                manifest,
                granted: installedNow.granted,
                strings: strings,
              ),
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

/// What an "update all" is doing.
///
/// A plain object rather than a set of fields on the state, because every one
/// of them is about the same run and they are only ever read together.
class _UpdateRun {
  _UpdateRun({required this.total});

  final int total;

  /// How many landed. Not "how many were tried": a plugin whose update failed
  /// is not progress, and the summary at the end counts both.
  int done = 0;

  /// The one being updated, for the label. Null before the first.
  String? name;

  /// Whether a dialog is up. The bar has stopped because it is waiting for
  /// the person looking at it, which is worth saying.
  bool asking = false;

  /// Whether the user asked to stop after the current one.
  bool stopping = false;

  void begin(String next) {
    name = next;
    asking = false;
  }

  void stop() => stopping = true;
}

/// The bar, and one line saying which plugin and what is happening to it.
class _RunProgress extends StatelessWidget {
  const _RunProgress({required this.run});

  final _UpdateRun run;

  @override
  Widget build(BuildContext context) {
    final name = run.name;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 3, 20, 11),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 6,
        children: [
          // Determinate, because the number of plugins is known before the
          // first one starts. An indeterminate bar here would be the app
          // withholding something it has.
          LinearProgressIndicator(
            value: run.total == 0 ? null : run.done / run.total,
            minHeight: 3,
          ),
          Text(
            switch (run) {
              _ when run.stopping => l10n.pluginStopping,
              _ when run.asking && name != null => l10n.pluginWaitingForYou(name),
              _ when name != null =>
                l10n.pluginUpdateProgress(run.done + 1, run.total, name),
              _ => l10n.pluginUpdateAll,
            },
            style: UIs.text12Grey,
          ),
        ],
      ),
    );
  }
}

class _EntryTile extends StatelessWidget {
  const _EntryTile({
    required this.entry,
    required this.busy,
    required this.onTap,
    this.updating = false,
  });

  final StoreEntry entry;

  /// Something else on the page is downloading. The button says so rather than
  /// looking pressable and being declined.
  final bool busy;

  /// This is the one an "update all" is working on. Said on the row as well as
  /// in the bar: the bar says how far the run is, the row says which of these
  /// it is at.
  final bool updating;

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
          _ when updating => Text(l10n.pluginUpdating, style: UIs.text12Grey),
          _ when best == null => Text(l10n.pluginNeedsNewerApp, style: UIs.text12Grey),
          _ when entry.outdated => Btn.text(text: libL10n.update, onTap: act),
          // Installed, but not by this repository. Offered as a replacement
          // rather than as an update, and never taken by "update all": which
          // of two copies of an id is the real one is not a version question.
          _ when entry.elsewhere => Btn.text(text: l10n.pluginReplace, onTap: act),
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
      // Which copy is on the device, when it is not one of this repository's.
      // Without it the row offers to replace something it never named, and a
      // plugin installed from a working tree reads as simply "installed".
      if (entry.installed case final i? when entry.elsewhere)
        l10n.pluginInstalledFrom('v${i.version} · ${i.sourceLabel}'),
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
