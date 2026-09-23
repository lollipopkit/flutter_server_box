import 'dart:async';
import 'dart:io';

import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/material.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/core/utils/plugin/package.dart';
import 'package:server_box/core/utils/plugin/report.dart';
import 'package:server_box/data/model/plugin/install.dart';
import 'package:server_box/data/model/plugin/installed.dart';
import 'package:server_box/data/model/plugin/l10n.dart';
import 'package:server_box/data/provider/plugin/installer.dart';
import 'package:server_box/data/res/build_data.dart';
import 'package:server_box/data/res/store.dart';
import 'package:server_box/src/rust/api/plugin.dart' as ffi;
import 'package:server_box/view/widget/plugin/consent.dart';

/// What is installed, and how to install more. PLUGINS.md sections 6 and 7.
///
/// The install dialog is the whole of what a user is asked. Everything after
/// it is enforced somewhere they cannot see — the runtime turns an ungranted
/// function into a throwing stub — so this page's job is to make the question
/// answerable: what it is, where it came from, and what it wants to be able to
/// do.
class PluginsPage extends StatefulWidget {
  const PluginsPage({super.key, this.embedded = false});

  /// Whether it is being shown inside the settings pane rather than pushed.
  ///
  /// The pane already names what it is showing, in the one bar the page has;
  /// a second one under it would say it twice.
  final bool embedded;

  static const route = AppRouteNoArg(
    page: PluginsPage.new,
    path: '/setting/plugins',
  );

  @override
  State<PluginsPage> createState() => _PluginsPageState();
}

class _PluginsPageState extends State<PluginsPage> {
  late final _installer = PluginInstaller(root: PluginInstaller.appRoot);

  List<InstalledPlugin>? _plugins;
  bool _busy = false;

  /// What each plugin could be put back to, by id.
  ///
  /// Read here rather than per row: it touches the filesystem — the kept
  /// directory has to be there and its manifest has to read — and a row
  /// builder is called on every scroll.
  Map<String, PluginRollback> _rollbacks = const {};

  @override
  void initState() {
    super.initState();
    unawaited(_reload());
  }

  Future<void> _reload() async {
    final plugins = await _installer.refresh();
    final rollbacks = <String, PluginRollback>{};
    for (final plugin in plugins) {
      final back = await _installer.rollbackOf(plugin.id);
      if (back != null) rollbacks[plugin.id] = back;
    }
    if (!mounted) return;
    setState(() {
      _plugins = plugins;
      _rollbacks = rollbacks;
    });
  }

  @override
  Widget build(BuildContext context) {
    final body = _buildBody();
    final add = FloatingActionButton(
      onPressed: _busy ? null : _onAdd,
      child: const Icon(Icons.add),
    );
    // In the bar rather than beside each plugin: one report covers all of
    // them, and which plugin is broken is often exactly what the person
    // reporting cannot tell.
    final report = Btn.icon(
      icon: const Icon(Icons.assignment_outlined, size: 18),
      onTap: _plugins == null ? null : () => unawaited(_onReport()),
    );
    if (widget.embedded) {
      return Scaffold(
        // The pane names what it is showing in the one bar the page has, so
        // this is the only place an action can go without saying it twice.
        appBar: PreferredSize(
          preferredSize: const Size.fromHeight(38),
          child: Align(alignment: Alignment.centerRight, child: report),
        ),
        body: body,
        floatingActionButton: add,
      );
    }
    return Scaffold(
      appBar: CustomAppBar(title: Text(l10n.plugins), actions: [report]),
      body: body,
      floatingActionButton: add,
    );
  }

  /// Puts the report on screen, and on the clipboard.
  ///
  /// Shown before it is copied: it is about to be pasted into an issue, and
  /// somebody who cannot read what they are sending will either send it
  /// anyway or not send it at all.
  Future<void> _onReport() async {
    final text = PluginReport(
      plugins: _plugins ?? const [],
      health: Stores.pluginHealth.readAll(),
      appVersion: '1.0.${BuildData.build}',
      abi: ffi.pluginAbiVersion(),
      at: DateTime.now(),
    ).write();
    if (!mounted) return;

    await context.showRoundDialog<void>(
      title: l10n.pluginReport,
      child: SizedBox(
        width: 500,
        child: SingleChildScrollView(
          // Monospace and selectable, for the reason the failed-surface view
          // is: this is meant to be read in columns and then taken away.
          child: SelectableText(
            text,
            style: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
          ),
        ),
      ),
      actions: [
        Btn.text(
          text: libL10n.copy,
          onTap: () {
            Pfs.copy(text);
            context.popDialog();
            Toast.show(libL10n.success);
          },
        ),
      ],
    );
  }

  Widget _buildBody() {
    final plugins = _plugins;
    if (plugins == null) return UIs.centerLoading;
    if (plugins.isEmpty) {
      return Center(child: Text(libL10n.empty, style: UIs.textGrey));
    }
    // Short by nature — it is what this user installed — but built lazily
    // anyway, so that stays true of the code rather than of the data.
    return ListView.builder(
      padding: const EdgeInsets.only(left: 7, right: 7, top: 7, bottom: 77),
      itemCount: plugins.length,
      itemBuilder: (_, i) => _buildTile(plugins[i]),
    );
  }

  Widget _buildTile(InstalledPlugin plugin) {
    final record = plugin.record;
    // Which of the three, said the same way the store page says it — see
    // `PluginInstallX.sourceLabel`.
    final source = record.sourceLabel;
    return CardX(
      key: ValueKey(plugin.id),
      child: ListTile(
        title: Text(plugin.name),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${record.version} · $source', style: UIs.textGrey),
            // The one thing a list of installed plugins has to be able to say
            // on its own: this one is running with less than it asks for, and
            // nothing else will tell the user why it half works.
            if (plugin.needsConsent)
              Text(
                l10n.pluginNeedsConsent,
                style: TextStyle(
                  fontSize: 11,
                  color: context.theme.colorScheme.error,
                ),
              ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Only where there is a version kept, which is only after an
            // update. A button that is always there and usually does nothing
            // is one nobody reads.
            if (_rollbacks[plugin.id] case final back?)
              IconButton(
                icon: const Icon(Icons.history, size: 19),
                tooltip: l10n.pluginRollback(back.to),
                onPressed: _busy ? null : () => unawaited(_onRollback(back)),
              ),
            Switch(
              value: record.enabled,
              onChanged: _busy
                  ? null
                  : (on) => unawaited(_setEnabled(plugin.id, on)),
            ),
            IconButton(
              icon: const Icon(Icons.delete, size: 19),
              onPressed: _busy ? null : () => unawaited(_onUninstall(plugin)),
            ),
          ],
        ),
      ),
    );
  }

  /// Puts back the version an update replaced.
  ///
  /// Asked first, and the data warning is part of the question rather than
  /// something shown afterwards: a version that raised `data_version` started
  /// writing records the older code cannot read, and the older code will not
  /// say so — it will misread them.
  Future<void> _onRollback(PluginRollback back) async {
    final ok = await context.showRoundDialog<bool>(
      title: l10n.pluginRollback(back.to),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 9,
        children: [
          Text(l10n.pluginRollbackTip, style: UIs.text13),
          if (!back.dataCompatible)
            Text(
              l10n.pluginRollbackDataWarn(back.to),
              style: UIs.text13.copyWith(
                color: context.theme.colorScheme.error,
              ),
            ),
        ],
      ),
      actions: back.dataCompatible ? Btnx.cancelOk : Btnx.cancelRedOk,
    );
    if (ok != true || !mounted) return;

    setState(() => _busy = true);
    try {
      await _installer.rollback(back.id);
      await _reload();
      Toast.show(l10n.pluginRolledBack(back.to));
    } catch (e, s) {
      Loggers.app.warning('Rolling ${back.id} back to ${back.to}', e, s);
      if (mounted) Toast.error(libL10n.fail, body: '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _setEnabled(String id, bool enabled) async {
    setState(() => _busy = true);
    try {
      await _installer.setEnabled(id, enabled);
      await _reload();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// A package, or — on a desktop — a directory being worked on.
  ///
  /// Only asked where there is something to ask: a phone has no directory a
  /// developer edits in, so there it goes straight to the file picker.
  Future<void> _onAdd() async {
    if (!isDesktop) return _onInstall();
    final dev = await context.showRoundDialog<bool>(
      title: l10n.pluginInstall,
      actions: [
        Btn.text(text: l10n.pluginDev, onTap: () => context.popDialog(true)),
        Btn.text(text: '.sbp', onTap: () => context.popDialog(false)),
      ],
    );
    if (dev == null || !mounted) return;
    return dev ? _onAddDevDir() : _onInstall();
  }

  /// A directory laid out like an unpacked package.
  ///
  /// The same consent dialog as a package, and deliberately: a plugin loaded
  /// from a directory runs with the same permissions as one that was
  /// installed, and it is the running that the question is about.
  Future<void> _onAddDevDir() async {
    final path = await Pfs.pickDirectory();
    if (path == null || !mounted) return;
    setState(() => _busy = true);
    try {
      final plugin = await _installer.readDevDir(path);
      if (plugin == null) {
        throw const PluginPackageError('no manifest.json and plugin.js there');
      }
      if (!mounted) return;

      final consented = await _askConsent(plugin.manifest, plugin.strings);
      if (consented == null || !mounted) return;

      await _installer.addDevDir(path, consented: consented);
      await _reload();
      Toast.show(libL10n.saved);
    } catch (e, s) {
      Loggers.app.warning('Adding the plugin directory $path', e, s);
      if (mounted) Toast.error(libL10n.fail, body: '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _onInstall() async {
    final path = await Pfs.pickFilePath();
    if (path == null || !mounted) return;
    setState(() => _busy = true);
    try {
      final bytes = await File(path).readAsBytes();
      // Read and checked before anything is asked, so a package that will not
      // open costs a message rather than a dialog the user has to answer
      // first.
      final package = PluginPackage.read(bytes);
      final manifest = ffi.pluginReadManifest(
        manifestJson: package.manifestJson,
      );
      if (!mounted) return;

      final consented = await _askConsent(
        manifest,
        package.l10nFor(
          Localizations.maybeLocaleOf(context)?.toLanguageTag() ?? 'en',
        ),
      );
      if (consented == null || !mounted) return;

      await _installer.install(
        bytes,
        consented: consented,
        // A file the user picked, which is neither a repository nor a working
        // tree: nothing knows where its next version will come from, and the
        // store must not offer one from a repository that merely lists the same
        // id.
        repo: PluginInstall.fileRepo,
      );
      await _reload();
      Toast.show(libL10n.saved);
    } catch (e, s) {
      Loggers.app.warning('Installing a plugin', e, s);
      if (mounted) Toast.error(libL10n.fail, body: '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<Set<String>?> _askConsent(
    ffi.PluginManifestInfo manifest,
    PluginL10n strings,
  ) => askPluginConsent(context, manifest, strings: strings);

  Future<void> _onUninstall(InstalledPlugin plugin) async {
    var keepData = false;
    final ok = await context.showRoundDialog<bool>(
      title: libL10n.attention,
      child: StatefulBuilder(
        builder: (_, setInner) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(libL10n.delFmt(l10n.plugins, plugin.name)),
            // Removing one to reinstall it — an update that went wrong, a
            // repository being switched — should not take the configuration
            // typed into every server with it.
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: keepData,
              title: Text(l10n.pluginUninstallKeepData, style: UIs.text13),
              onChanged: (v) => setInner(() => keepData = v ?? false),
            ),
          ],
        ),
      ),
      actions: Btnx.cancelRedOk,
    );
    if (ok != true || !mounted) return;

    setState(() => _busy = true);
    try {
      await _installer.uninstall(plugin.id, keepData: keepData);
      await _reload();
    } catch (e, s) {
      Loggers.app.warning('Uninstalling ${plugin.id}', e, s);
      if (mounted) Toast.error(libL10n.fail, body: '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}
