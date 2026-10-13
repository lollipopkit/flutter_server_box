import 'dart:async';

import 'package:fl_lib/fl_lib.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/data/model/server/monitor_stack.dart';
import 'package:server_box/data/model/server/server_private_info.dart';
import 'package:server_box/data/provider/server/all.dart';
import 'package:server_box/data/provider/server/web_apps.dart';
import 'package:server_box/view/page/web_apps/detail.dart';
import 'package:server_box/view/page/web_apps/status.dart';
import 'package:server_box/view/widget/pane_settings.dart';

/// The web apps every server's `monitor` agent deployed, by server.
///
/// One column is a browsing list: a tap opens the app in the device's
/// browser, which is what the tab is for, and the info button its page. Two
/// columns are the rail beside that page, as the snippets are: a tap selects,
/// and the page has the way in.
///
/// Deploying, updating and removing stay in the panel: this is where the apps
/// are used, not run.
class WebAppsTabPage extends ConsumerStatefulWidget {
  const WebAppsTabPage({super.key});

  @override
  ConsumerState<WebAppsTabPage> createState() => _WebAppsTabPageState();
}

typedef _ServerApps = ({Spi spi, WebAppsState state});

class _WebAppsTabPageState extends ConsumerState<WebAppsTabPage> {
  final _search = InlineSearchController();

  /// The server the list is narrowed to; null for all of them.
  String? _serverId;

  /// The app open beside the list.
  WebAppPageArgs? _open;

  // Not kept alive: the home page disposes a tab off screen, and with it the
  // lists it watched, each a request a minute.

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Watched here, on this page's element: the list builder below runs on
    // the pane's.
    final all = ref.watch(serversProvider);
    final servers = <_ServerApps>[
      for (final id in all.serverOrder)
        if (all.servers[id] case final spi? when spi.monitorOn != null)
          if (ref.watch(webAppsProvider(id)) case final state when state.offered) (spi: spi, state: state),
    ];
    // A server filtered to that no longer offers apps: all of them.
    if (_serverId != null && !servers.any((s) => s.spi.id == _serverId)) _serverId = null;
    final open = _open;
    return PaneSettings.listenAll((paneWidth, paneCollapsed) {
      return AdaptivePanes.detail(
        listWidth: paneWidth,
        onListWidthChanged: PaneSettings.saveWidth,
        collapsed: paneCollapsed,
        onCollapsedChanged: PaneSettings.saveCollapsed,
        collapseTooltip: libL10n.fold,
        expandTooltip: libL10n.open,
        detailId: open == null ? null : '${open.serverId}/${open.appId}',
        onCloseDetail: () => setState(() => _open = null),
        // Never null, so two columns are what this tab looks like from the
        // moment it opens, as the snippets' does.
        detailBuilder: (_) => open == null ? const EmptyPane(icon: Icons.apps) : WebAppPage(args: open),
        listBuilder: (_, split) => ListenBuilder(
          listenable: _search,
          builder: () => Scaffold(
            appBar: _buildBar(servers, split),
            body: _buildList(servers, split),
          ),
        ),
      );
    });
  }

  Future<void> _refresh(List<_ServerApps> servers) => Future.wait([
    for (final (:spi, state: _) in servers) ref.read(webAppsProvider(spi.id).notifier).refresh(),
  ]);

  String? get _serverName => switch (_serverId) {
    final id? => ref.read(serversProvider).servers[id]?.name,
    null => null,
  };

  PreferredSizeWidget _buildBar(List<_ServerApps> servers, bool split) {
    final search = BarAction(icon: Icons.search, label: libL10n.search, onTap: _search.start);
    final refresh = BarAction(
      icon: Icons.refresh,
      label: libL10n.refresh,
      onTap: () => unawaited(_refresh(servers)),
    );
    if (!split) {
      // Every tab's bar on one column: which servers on the left, opening the
      // rest, as the snippets' tag is.
      return SwitcherBar(
        search: _search,
        searchHint: l10n.webApps,
        switcher: SessionSwitcherLabel(
          name: _serverName ?? libL10n.all,
          icon: Icons.dns_outlined,
          onTap: servers.length < 2 ? null : () => _pickServer(servers),
        ),
        actions: [search, refresh],
      );
    }
    // Beside the page: the head of the column, as every other tab's list has.
    return PreferredSize(
      preferredSize: const Size.fromHeight(SideBarActions.height),
      child: WindowControlsInset(
        safeArea: true,
        child: SideBarActions(
          search: _search,
          searchHint: l10n.webApps,
          actions: [
            if (servers.length > 1)
              BarAction.menu(
                icon: Icons.dns_outlined,
                label: _serverName ?? libL10n.server,
                color: _serverId == null ? null : Theme.of(context).colorScheme.primary,
                menu: () => [
                  ContextMenuAction(
                    text: libL10n.all,
                    checked: _serverId == null,
                    onTap: () => setState(() => _serverId = null),
                  ),
                  for (final (:spi, state: _) in servers)
                    ContextMenuAction(
                      text: spi.name,
                      checked: _serverId == spi.id,
                      onTap: () => setState(() => _serverId = spi.id),
                    ),
                ],
              ),
            search,
            refresh,
          ],
        ),
      ),
    );
  }

  Future<void> _pickServer(List<_ServerApps> servers) => showRowsSheet<void>(
    context,
    rows: (ctx) {
      void pick(String? id) {
        Navigator.of(ctx).pop();
        setState(() => _serverId = id);
      }

      return [
        SheetChoiceTile(
          icon: Icons.dns_outlined,
          title: libL10n.all,
          selected: _serverId == null,
          onTap: () => pick(null),
        ),
        const Divider(height: 1),
        for (final (:spi, state: _) in servers)
          SheetChoiceTile(
            icon: Icons.dns_outlined,
            title: spi.name,
            selected: _serverId == spi.id,
            onTap: () => pick(spi.id),
          ),
      ];
    },
  );

  Widget _buildList(List<_ServerApps> servers, bool split) {
    final needle = _search.needle;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final groups = <({Spi spi, String? error, List<MonitorWebApp> apps})>[];
    var waiting = false;
    for (final (:spi, :state) in servers) {
      if (_serverId != null && spi.id != _serverId) continue;
      final apps = state.apps;
      if (apps == null) {
        if (state.error == null) {
          waiting = true;
        } else {
          groups.add((spi: spi, error: state.error, apps: const []));
        }
        continue;
      }
      final matched = [
        for (final app in apps)
          if (needle.isEmpty ||
              app.titleIn(locale).toLowerCase().contains(needle) ||
              spi.name.toLowerCase().contains(needle))
            app,
      ];
      if (matched.isNotEmpty) groups.add((spi: spi, error: null, apps: matched));
    }
    if (groups.isEmpty) {
      if (waiting) return UIs.centerLoading;
      return EmptyPane(
        icon: needle.isEmpty ? Icons.apps : Icons.search_off,
        label: needle.isEmpty ? l10n.webAppsEmpty : _search.needle,
      );
    }
    final scheme = Theme.of(context).colorScheme;
    Widget dot(MonitorWebApp app) => Icon(Icons.circle, size: 11, color: webAppStatus(app).$2.color(scheme));

    final Widget list;
    if (split) {
      // The rail every two-column tab has: a narrow index beside the page.
      list = ListView(
        padding: const EdgeInsets.only(top: 4, bottom: 13),
        children: [
          for (final group in groups) ...[
            SideBarSection(group.spi.name),
            if (group.error case final error?)
              SideBarTile(title: '${libL10n.fail}: $error', icon: Icons.error_outline)
            else
              for (final app in group.apps)
                SideBarTile(
                  key: ValueKey('${group.spi.id}/${app.id}'),
                  title: app.titleIn(locale),
                  leading: dot(app),
                  selected: _open?.serverId == group.spi.id && _open?.appId == app.id,
                  onTap: () => setState(
                    () => _open = WebAppPageArgs(serverId: group.spi.id, appId: app.id),
                  ),
                ),
          ],
        ],
      );
    } else {
      list = ListView(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
        children: [
          for (final group in groups) ...[
            CenterGreyTitle(group.spi.name),
            if (group.error case final error?)
              CardTile(title: libL10n.fail, subtitle: error, trailing: null)
            else
              for (final app in group.apps) _buildCard(group.spi, app, locale, dot),
          ],
        ],
      );
    }
    return RefreshIndicator(onRefresh: () => _refresh(servers), child: list);
  }

  Widget _buildCard(Spi spi, MonitorWebApp app, String locale, Widget Function(MonitorWebApp) dot) {
    final (status, _) = webAppStatus(app);
    final args = WebAppPageArgs(serverId: spi.id, appId: app.id);
    return CardTile(
      key: ValueKey('${spi.id}/${app.id}'),
      leading: dot(app),
      title: app.titleIn(locale),
      subtitle: app.failing.isEmpty ? status : '$status · ${app.failing.join(', ')}',
      trailing: IconButton(
        icon: const Icon(Icons.info_outline),
        tooltip: libL10n.about,
        onPressed: () => WebAppPage.route.go(context, args: args),
      ),
      // An app the proxy is not in front of (being deployed, failed) cannot
      // be opened: its page says why.
      onTap: app.proxy ? () => openWebApp(ref, spi.id, app.id) : () => WebAppPage.route.go(context, args: args),
    );
  }
}
