import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:server_box/data/model/plugin/contributions.dart';
import 'package:server_box/data/model/plugin/icons.dart';
import 'package:server_box/data/model/plugin/installed.dart';
import 'package:server_box/data/provider/plugin/runtime.dart';
import 'package:server_box/view/page/setting/entry.dart';
import 'package:server_box/view/widget/plugin/surface_view.dart';

/// A plugin's own page under Settings. PLUGINS.md section 5.3.
///
/// Not bound to a server and not in any arrangement. Both follow from what the
/// page is for: it is where the plugin itself is configured, so there is no
/// server to configure it *for*, and a switch the user would have to find
/// before they could reach it is the one thing a settings page cannot afford.
class PluginSettingsPage extends ConsumerWidget {
  const PluginSettingsPage({
    super.key,
    required this.plugin,
    this.embedded = false,
  });

  final InstalledPlugin plugin;

  /// Whether it is shown inside the settings pane rather than pushed — the
  /// pane already names what it is showing, in the one bar the page has.
  final bool embedded;

  /// One leaf per plugin that contributes one, in install order.
  ///
  /// Read at build time rather than kept: the menu is rebuilt whenever the
  /// settings page is, and installing or removing a plugin has to be able to
  /// add and remove a row without anything else being told.
  static List<SettingsNode> nodes() => [
    for (final plugin in PluginContributions.active)
      if (plugin.manifest.settings case final settings?)
        SettingsNode.leaf(
          id: 'plugin.${plugin.id}',
          title: settings.label,
          icon: PluginIcons.of(settings.icon),
          page: () => PluginSettingsPage(plugin: plugin, embedded: true),
        ),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Follows the registry for the same reason `PluginPage` does: this holds
    // the plugin it was built with, and an edit to a development directory
    // reaches it only if something says to look again.
    return ValueListenableBuilder(
      valueListenable: PluginContributions.revision,
      builder: (context, _, _) => _build(context, ref),
    );
  }

  Widget _build(BuildContext context, WidgetRef ref) {
    final plugin = PluginContributions.byId(this.plugin.id) ?? this.plugin;
    final settings = plugin.manifest.settings;
    if (settings == null) {
      return Scaffold(body: Center(child: Text(libL10n.empty, style: UIs.textGrey)));
    }

    final body = PluginSurfaceView(
      spec: PluginSurfaceSpec(
        pluginId: plugin.id,
        manifestJson: plugin.manifestJson,
        source: plugin.source,
        kind: 'settings',
        contributionId: settings.id,
        granted: plugin.granted,
        l10n: plugin.l10nFor(
          Localizations.maybeLocaleOf(context)?.toLanguageTag() ?? 'en',
        ),
      ),
      service: ref.read(pluginRuntimeProvider),
      // No ticking. A settings page shows what the user typed, and redrawing
      // it under them is how a half-entered field gets thrown away — the
      // plugin asks for a repaint with `sb.ui.patch` when it has something to
      // say.
    );
    if (embedded) return Scaffold(body: body);
    return Scaffold(
      appBar: CustomAppBar(title: Text(settings.label)),
      body: body,
    );
  }
}
