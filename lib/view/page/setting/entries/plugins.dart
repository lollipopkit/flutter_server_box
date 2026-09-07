import 'dart:async';
import 'dart:io';

import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/material.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/core/utils/plugin/package.dart';
import 'package:server_box/data/model/plugin/installed.dart';
import 'package:server_box/data/provider/plugin/installer.dart';
import 'package:server_box/src/rust/api/plugin.dart' as ffi;

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

  @override
  void initState() {
    super.initState();
    unawaited(_reload());
  }

  Future<void> _reload() async {
    final plugins = await _installer.refresh();
    if (!mounted) return;
    setState(() => _plugins = plugins);
  }

  @override
  Widget build(BuildContext context) {
    final body = _buildBody();
    final add = FloatingActionButton(
      onPressed: _busy ? null : _onAdd,
      child: const Icon(Icons.add),
    );
    if (widget.embedded) {
      return Scaffold(body: body, floatingActionButton: add);
    }
    return Scaffold(
      appBar: CustomAppBar(title: Text(l10n.plugins)),
      body: body,
      floatingActionButton: add,
    );
  }

  Widget _buildBody() {
    final plugins = _plugins;
    if (plugins == null) return UIs.centerLoading;
    if (plugins.isEmpty) {
      return Center(child: Text(libL10n.empty, style: UIs.textGrey));
    }
    return ListView(
      padding: const EdgeInsets.only(left: 7, right: 7, top: 7, bottom: 77),
      children: [for (final plugin in plugins) _buildTile(plugin)],
    );
  }

  Widget _buildTile(InstalledPlugin plugin) {
    final record = plugin.record;
    final source = record.bundled
        ? l10n.pluginBundled
        : (record.isDev ? l10n.pluginDev : record.repo!);
    return CardX(
      key: ValueKey(plugin.id),
      child: ListTile(
        title: Text(plugin.manifest.name),
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

      final consented = await _askConsent(plugin.manifest);
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

      final consented = await _askConsent(manifest);
      if (consented == null || !mounted) return;

      await _installer.install(bytes, consented: consented);
      await _reload();
      Toast.show(libL10n.saved);
    } catch (e, s) {
      Loggers.app.warning('Installing a plugin', e, s);
      if (mounted) Toast.error(libL10n.fail, body: '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// The permissions dialog, and the only place consent is given.
  ///
  /// Answers the set the user agreed to, or null if they did not. All or
  /// nothing on purpose: a plugin that asks for two things and is granted one
  /// is a plugin whose author never tested that combination, and the failure
  /// lands on the user as a feature that half works.
  Future<Set<String>?> _askConsent(ffi.PluginManifestInfo manifest) async {
    final permissions = manifest.permissions;
    final ok = await context.showRoundDialog<bool>(
      title: '${manifest.name} ${manifest.version}',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 7,
        children: [
          if (manifest.description.isNotEmpty)
            Text(manifest.description, style: UIs.textGrey),
          Text(
            permissions.isEmpty
                ? l10n.pluginNoPermissions
                : l10n.pluginPermissionsAsk,
          ),
          for (final name in permissions)
            Row(
              spacing: 5,
              children: [
                const Icon(Icons.chevron_right, size: 15),
                Flexible(child: Text(_describe(name), style: UIs.text13)),
              ],
            ),
          // A status plugin runs a command it chose on every server it is
          // shown for. `server.exec` is what says so in the list above, but
          // the list is names and this is what they mean.
          if (permissions.contains('server.exec'))
            Text(
              l10n.pluginRunsOnServer,
              style: TextStyle(
                fontSize: 11,
                color: context.theme.colorScheme.error,
              ),
            ),
        ],
      ),
      actions: Btnx.cancelOk,
    );
    if (ok != true) return null;
    return permissions.toSet();
  }

  /// What a permission means, in the app's own words where it has them.
  ///
  /// Falls back to the name rather than to nothing: a build that meets a
  /// permission it has no sentence for should still say which one, since the
  /// alternative is asking the user to agree to a blank line.
  String _describe(String name) => switch (name) {
    'server.exec' => libL10n.cmd,
    'net.http' => libL10n.network,
    'ui.dialog' => libL10n.attention,
    'clipboard' => libL10n.copy,
    _ => name,
  };

  Future<void> _onUninstall(InstalledPlugin plugin) async {
    var keepData = false;
    final ok = await context.showRoundDialog<bool>(
      title: libL10n.attention,
      child: StatefulBuilder(
        builder: (_, setInner) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(libL10n.delFmt(l10n.plugins, plugin.manifest.name)),
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
