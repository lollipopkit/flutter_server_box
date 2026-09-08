import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:server_box/core/utils/refresh_interval.dart';
import 'package:server_box/data/model/plugin/contributions.dart';
import 'package:server_box/data/model/plugin/installed.dart';
import 'package:server_box/data/model/server/server_private_info.dart';
import 'package:server_box/data/provider/plugin/runtime.dart';
import 'package:server_box/data/store/plugin.dart';
import 'package:server_box/view/widget/plugin/surface_view.dart';

/// A whole page drawn by a plugin, opened from the server function bar.
/// PLUGINS.md section 5.3.
///
/// The same surface as a card, given the window rather than a slot in a
/// column — which is the only difference between the two contributions, and
/// why this is a scaffold around [PluginSurfaceView] and nothing else.
class PluginPage extends ConsumerWidget {
  const PluginPage({super.key, this.args});

  final PluginPageArgs? args;

  static const route = AppRoute<void, PluginPageArgs>(
    page: PluginPage.new,
    path: '/plugin/page',
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Rebuilt whenever the installed set is replaced, so an edit to a
    // development directory reaches a page that is already open: `refresh()`
    // re-reads the directory, `publish` bumps the revision, and the newer
    // `source` below reaches `PluginSurfaceView`, which reloads the instance
    // when it changes. The captured `args` is what the route carries and does
    // not change on its own.
    return ValueListenableBuilder(
      valueListenable: PluginContributions.revision,
      builder: (context, _, _) => _build(context, ref),
    );
  }

  Widget _build(BuildContext context, WidgetRef ref) {
    // Re-resolved rather than taken from the route: the copy the route carries
    // is the one that existed when the page was opened. Falls back to it for
    // a plugin the registry no longer has — the branch below says so, and
    // saying it with the name the user tapped is better than a blank bar.
    final captured = this.args;
    final args = captured == null
        ? null
        : PluginPageArgs(
            plugin: PluginContributions.byId(captured.plugin.id) ?? captured.plugin,
            spi: captured.spi,
          );
    final page = args?.plugin.manifest.page;
    // Uninstalled, disabled, or updated to a version that no longer
    // contributes one — all reachable, because a page can outlive the entry
    // that opened it.
    if (args == null || page == null) {
      return Scaffold(
        appBar: CustomAppBar(title: Text(args?.plugin.manifest.name ?? '')),
        body: Center(child: Text(libL10n.empty, style: UIs.textGrey)),
      );
    }

    return Scaffold(
      appBar: CustomAppBar(title: Text(page.label)),
      body: PluginSurfaceView(
        spec: PluginSurfaceSpec(
          pluginId: args.plugin.id,
          manifestJson: args.plugin.manifestJson,
          source: args.plugin.source,
          kind: 'page',
          contributionId: page.id,
          granted: args.plugin.granted,
          config: args.spi == null
              ? const {}
              : PluginCfgStore.instance.fetch(args.spi!.id, args.plugin.id),
          serverId: args.spi?.id,
          l10n: args.plugin.l10nFor(
            Localizations.maybeLocaleOf(context)?.toLanguageTag() ?? 'en',
          ),
        ),
        service: ref.read(pluginRuntimeProvider),
        // A page is what the user is looking at, so it follows the status
        // poll rather than the slower interval a card in a column does.
        refreshInterval: serverStatusRefreshInterval(),
      ),
    );
  }
}

class PluginPageArgs {
  const PluginPageArgs({required this.plugin, this.spi});

  final InstalledPlugin plugin;

  /// The server it was opened from, or null where it was reached from
  /// somewhere with no server in hand.
  final Spi? spi;
}
