import 'dart:convert';
import 'dart:math';

import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:icons_plus/icons_plus.dart';
import 'package:responsive_framework/responsive_framework.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/core/route.dart';
import 'package:server_box/data/model/server/server_private_info.dart';
import 'package:server_box/data/provider/server/all.dart';
import 'package:server_box/data/res/store.dart';
import 'package:server_box/view/page/server/edit/edit.dart';
import 'package:server_box/view/page/ssh/page/page.dart';

class SSHTabPage extends ConsumerStatefulWidget {
  const SSHTabPage({super.key});

  @override
  ConsumerState<SSHTabPage> createState() => _SSHTabPageState();

  static const route = AppRouteNoArg(page: SSHTabPage.new, path: '/ssh');
}

/// What a terminal tab is, beyond the name, focus and visibility that
/// [SessionTabs] already keeps for it.
///
/// The page is built once and held, not rebuilt from the record: a terminal's
/// state lives in its element, and handing `PageView` a fresh widget on every
/// frame would be relying on `GlobalKey` to put it back.
class _SshSession {
  const _SshSession({required this.page, required this.pageKey});

  final Widget page;
  final GlobalKey<SSHPageState> pageKey;
}

class _SSHTabPageState extends ConsumerState<SSHTabPage>
    with TickerProviderStateMixin, AutomaticKeepAliveClientMixin, RestorationMixin {
  // Restorable state for tab restoration
  final RestorableString _restorableTabsState = RestorableString('');

  @override
  String get restorationId => 'ssh_tab_page';

  @override
  void restoreState(RestorationBucket? oldBucket, bool initialRestore) {
    registerForRestoration(_restorableTabsState, 'tabs_state');

    // Restore tabs after the first frame
    if (initialRestore && _restorableTabsState.value.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _restoreTabs();
      });
    }
  }

  void _saveTabsState() {
    final tabsData = <Map<String, dynamic>>[];
    for (final tab in _sessions.tabs) {
      final sshPageState = tab.data.pageKey.currentState;
      final sshPage = tab.data.page as SSHPage;
      final serverId = sshPageState?.widget.args.spi.id ?? sshPage.args.spi.id;
      final tmuxSession =
          sshPageState?.tmuxCurrentSession ?? sshPage.args.tmuxSession;
      final tmuxWindow =
          sshPageState?.tmuxCurrentWindow ?? sshPage.args.tmuxWindow;

      tabsData.add({
        'serverId': serverId,
        'tmuxSession': tmuxSession,
        'tmuxWindow': tmuxWindow,
      });
    }
    _restorableTabsState.value = jsonEncode(tabsData);
  }

  void _restoreTabs() {
    try {
      final tabsData = jsonDecode(_restorableTabsState.value) as List;
      for (final tabData in tabsData) {
        final serverId = tabData['serverId'] as String;
        final tmuxSession = tabData['tmuxSession'] as String?;
        final tmuxWindow = tabData['tmuxWindow'] as int?;

        // Find the server
        final servers = Stores.server.fetch();
        final spi = servers.where((s) => s.id == serverId).firstOrNull;
        if (spi == null) {
          continue;
        }

        // Add the tab with tmux state
        _addTab(spi, tmuxSession: tmuxSession, tmuxWindow: tmuxWindow);
      }
    } catch (e, st) {
      Loggers.app.warning('Failed to restore SSH tabs', e, st);
    }
  }

  late final _sessions = SessionTabsController<_SshSession>(
    leadingName: libL10n.add,
  );
  late final _addPage = _AddPage(
    sortVersionVN: _sortVersionVN,
    onTapInitCard: _onTapInitCard,
    onLongPressInitCard: _onLongPressInitCard,
  );
  final _sortVersionVN = 0.vn;

  @override
  void dispose() {
    _restorableTabsState.dispose();
    _sessions.dispose();
    _sortVersionVN.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      appBar: PreferredSizeListenBuilder(
        listenable: _sessions,
        builder: () {
          return _TabBar(
            names: _sessions.names,
            index: _sessions.index,
            onTap: _sessions.select,
            onClose: _onTapClose,
            snippetBtn: buildSnippetBtn(context),
            sortBtn: buildSortBtn(context),
            searchBtn: buildSearchBtn(context),
            historyBtn: buildHistoryBtn(context),
          );
        },
      ),
      body: SessionTabsView<_SshSession>(
        controller: _sessions,
        leading: _addPage,
        builder: (_, tab) => tab.data.page,
      ),
      floatingActionButton: ListenBuilder(
        listenable: _sessions,
        builder: () {
          if (_sessions.index != 0) return const SizedBox();
          return FloatingActionButton(
            heroTag: 'sshAddServer',
            onPressed: () => ServerEditPage.route.go(context),
            tooltip: libL10n.add,
            child: const Icon(Icons.add),
          );
        },
      ),
    );
  }

  @override
  bool get wantKeepAlive => true;
}

extension on _SSHTabPageState {
  void _applySort({required int sortBy, required bool sortAsc}) {
    Stores.setting.sshPageSortBy.put(sortBy);
    Stores.setting.sshPageSortAsc.put(sortAsc);
    _sortVersionVN.notify();
  }

  Future<void> _handleTabRemoved(String name) async {
    _sessions.remove(name);
    if (!mounted) return;
    _saveTabsState();
  }

  Future<void> _addTab(Spi spi, {String? tmuxSession, int? tmuxWindow}) async {
    final tab = _sessions.add(
      preferred: spi.name,
      build: (name, focus, visible) {
        final key = GlobalKey<SSHPageState>(debugLabel: name);
        return _SshSession(
          pageKey: key,
          page: SSHPage(
            key: key,
            args: SshPageArgs(
              spi: spi,
              notFromTab: false,
              onSessionEnd: () {
                _handleTabRemoved(name).ignore();
              },
              focusNode: focus,
              visibleListenable: visible,
              tmuxSession: tmuxSession,
              tmuxWindow: tmuxWindow,
              onTmuxStateChanged: _saveTabsState,
            ),
          ),
        );
      },
    );
    Stores.history.sshServerHistory.add(spi.id);
    _saveTabsState();
    _sessions.select(_sessions.names.indexOf(tab.name));
  }

  void _onTapInitCard(Spi spi) async {
    await _addTab(spi);
  }

  void _onLongPressInitCard(Spi spi) {
    ServerEditPage.route.go(context, args: SpiRequiredArgs(spi));
  }

  void _onTapClose(String name) async {
    final confirm = await contextSafe?.showRoundDialog(
      title: libL10n.attention,
      child: Text('${libL10n.close} SSH ${libL10n.conn}($name) ?'),
      actions: Btnx.okReds,
    );
    Future.delayed(Durations.short1, FocusScope.of(context).unfocus);
    if (confirm != true) return;
    await _handleTabRemoved(name);
  }

  Widget buildSortBtn(BuildContext context) {
    final sortBy = Stores.setting.sshPageSortBy.fetch();
    final sortAsc = Stores.setting.sshPageSortAsc.fetch();
    final sortIcon = sortBy == 0
        ? (sortAsc ? Icons.sort_by_alpha : Icons.sort)
        : (sortAsc ? Icons.arrow_upward : Icons.arrow_downward);

    return Btn.icon(
      icon: Icon(sortIcon, size: 18),
      onTap: () => showSortMenu(context),
    );
  }

  void showSortMenu(BuildContext context) {
    final sortBy = Stores.setting.sshPageSortBy.fetch();
    final sortAsc = Stores.setting.sshPageSortAsc.fetch();

    context.showRoundDialog(
      title: l10n.sort,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _SortOption(
            icon: Icons.sort_by_alpha,
            label: '${l10n.sortByName} (A-Z)',
            selected: sortBy == 0 && sortAsc,
            onTap: () {
              _applySort(sortBy: 0, sortAsc: true);
              context.pop();
            },
          ),
          _SortOption(
            icon: Icons.sort,
            label: '${l10n.sortByName} (Z-A)',
            selected: sortBy == 0 && !sortAsc,
            onTap: () {
              _applySort(sortBy: 0, sortAsc: false);
              context.pop();
            },
          ),
          _SortOption(
            icon: Icons.arrow_upward,
            label: '${l10n.sortByJoinTime} (${l10n.ascending})',
            selected: sortBy == 1 && sortAsc,
            onTap: () {
              _applySort(sortBy: 1, sortAsc: true);
              context.pop();
            },
          ),
          _SortOption(
            icon: Icons.arrow_downward,
            label: '${l10n.sortByJoinTime} (${l10n.descending})',
            selected: sortBy == 1 && !sortAsc,
            onTap: () {
              _applySort(sortBy: 1, sortAsc: false);
              context.pop();
            },
          ),
        ],
      ),
    );
  }

  Widget buildSearchBtn(BuildContext context) {
    return Btn.icon(
      icon: const Icon(Icons.search, size: 18),
      onTap: () => showSearchDialog(context),
    );
  }

  void showSearchDialog(BuildContext context) {
    final serverState = ref.read(serversProvider);
    final allServers = serverState.serverOrder
        .map((id) => serverState.servers[id])
        .whereType<Spi>()
        .toList();

    showSearch(
      context: context,
      delegate: SearchPage<Spi>(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        future: (q) async {
          if (q.isEmpty) return [];
          return allServers
              .where(
                (spi) =>
                    spi.name.toLowerCase().contains(q.toLowerCase()) ||
                    spi.displayAddr.toLowerCase().contains(q.toLowerCase()),
              )
              .toList();
        },
        builder: (ctx, spi) => ListTile(
          title: Text(spi.name),
          subtitle: Text(spi.displayAddr),
          trailing: const Icon(Icons.chevron_right),
          onTap: () {
            ctx.pop();
            _onTapInitCard(spi);
          },
        ),
      ),
    );
  }

  Widget buildHistoryBtn(BuildContext context) {
    return Btn.icon(
      icon: const Icon(Icons.history, size: 18),
      onTap: () => showHistoryDialog(context),
    );
  }

  Widget buildSnippetBtn(BuildContext context) {
    return Btn.icon(
      icon: const Icon(Icons.code, size: 18),
      onTap: () {
        _sessions.current?.data.pageKey.currentState
            ?.pickSnippetFromToolbar();
      },
    );
  }

  void showHistoryDialog(BuildContext context) {
    final history = Stores.history.sshServerHistory.all.cast<String>();
    if (history.isEmpty) {
      context.showRoundDialog(
        title: l10n.serverHistory,
        child: Text(libL10n.empty),
        actions: [Btn.ok(onTap: context.pop)],
      );
      return;
    }

    final serverState = ref.read(serversProvider);
    context.showRoundDialog(
      title: l10n.serverHistory,
      child: SizedBox(
        width: 420,
        height: 300,
        child: ListView.builder(
          itemCount: history.length,
          itemBuilder: (_, idx) {
            final id = history[idx];
            final spi = serverState.servers[id];
            return ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(spi?.name ?? id),
              subtitle: spi != null
                  ? Text(spi.displayAddr)
                  : null,
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                context.pop();
                if (spi != null) {
                  _onTapInitCard(spi);
                } else {
                  context.showSnackBar(libL10n.error);
                }
              },
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            Stores.history.sshServerHistory.clear();
            context.pop();
          },
          child: Text(l10n.clearHistory),
        ),
        Btn.ok(onTap: context.pop),
      ],
    );
  }
}

final class _TabBar extends StatelessWidget implements PreferredSizeWidget {
  const _TabBar({
    required this.names,
    required this.index,
    required this.onTap,
    required this.onClose,
    required this.snippetBtn,
    required this.sortBtn,
    required this.searchBtn,
    required this.historyBtn,
  });

  final List<String> names;
  final int index;
  final void Function(int idx) onTap;
  final void Function(String name) onClose;
  final Widget snippetBtn;
  final Widget sortBtn;
  final Widget searchBtn;
  final Widget historyBtn;

  List<String> get connectionNames => names.skip(1).toList();

  @override
  Size get preferredSize => const Size.fromHeight(48);

  @override
  Widget build(BuildContext context) {
    final showHomeActions = index == 0;
    final showSnippetAction = index != 0;
    return Builder(
      builder: (context) {
        return Row(
          children: [
            _buildAddItem(context),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 17),
              child: Container(
                color: Theme.of(context).dividerColor.withAlpha(61),
                width: 3,
              ),
            ),
            Expanded(
              child: ClipRect(
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 5,
                  ),
                  itemCount: connectionNames.length,
                  itemBuilder: (_, idx) => _buildItem(context, idx + 1),
                  separatorBuilder: (_, _) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 17),
                    child: Container(
                      color: Theme.of(context).dividerColor.withAlpha(61),
                      width: 3,
                    ),
                  ),
                ),
              ),
            ),
            if (showSnippetAction) ...[
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 17),
                child: Container(
                  color: Theme.of(context).dividerColor.withAlpha(61),
                  width: 3,
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 7),
                child: snippetBtn,
              ),
            ],
            if (showHomeActions) ...[
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 17),
                child: Container(
                  color: Theme.of(context).dividerColor.withAlpha(61),
                  width: 3,
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 7),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    sortBtn,
                    const SizedBox(width: 7),
                    searchBtn,
                    const SizedBox(width: 7),
                    historyBtn,
                  ],
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _buildAddItem(BuildContext context) {
    final color = index == 0 ? null : Colors.grey;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(13),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        borderRadius: BorderRadius.circular(13),
        onTap: () => onTap(0),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Icon(MingCute.add_circle_fill, size: 17, color: color),
        ),
      ),
    );
  }

  Widget _buildItem(BuildContext context, int idx) {
    final isMobile = ResponsiveBreakpoints.of(context).isMobile;
    final wideWidth = isMobile ? 90.0 : 130.0;
    final narrowWidth = isMobile ? 60.0 : 90.0;
    final name = names[idx];
    final selected = index == idx;
    final color = selected ? null : Colors.grey;

    final text = Text(
      name,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(color: color),
      softWrap: false,
      textAlign: TextAlign.right,
      textWidthBasis: TextWidthBasis.parent,
    );
    final Widget btn;
    if (selected) {
      btn = Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          Btn.icon(
            icon: Icon(MingCute.close_circle_fill, color: color, size: 17),
            onTap: () => onClose(name),
            padding: null,
          ),
          Expanded(child: text),
        ],
      );
    } else {
      btn = Center(child: text);
    }
    final child = AnimatedContainer(
      width: selected ? wideWidth : narrowWidth,
      duration: Durations.medium3,
      curve: Curves.fastEaseInToSlowEaseOut,
      child: btn,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 7),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(13),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          borderRadius: BorderRadius.circular(13),
          onTap: () => onTap(idx),
          child: child,
        ),
      ),
    );
  }
}

class _AddPage extends ConsumerStatefulWidget {
  const _AddPage({
    required this.sortVersionVN,
    required this.onTapInitCard,
    required this.onLongPressInitCard,
  });

  final ValueListenable<int> sortVersionVN;
  final void Function(Spi spi) onTapInitCard;
  final void Function(Spi spi) onLongPressInitCard;

  @override
  ConsumerState<_AddPage> createState() => _AddPageState();
}

class _AddPageState extends ConsumerState<_AddPage> {
  // Cache for sorted server order
  List<String>? _cachedOrder;
  int _cachedSortBy = -1;
  bool _cachedSortAsc = true;
  List<String>? _cachedServerOrder;
  Map<String, String>? _cachedServerNames;

  @override
  void initState() {
    super.initState();
    widget.sortVersionVN.addListener(_onSortVersionChanged);
  }

  @override
  void dispose() {
    widget.sortVersionVN.removeListener(_onSortVersionChanged);
    super.dispose();
  }

  void _onSortVersionChanged() {
    // Invalidate cache when sort version changes
    _cachedOrder = null;
    if (mounted) setState(() {});
  }

  List<String> _getSortedOrder(ServersState serverState, int sortBy, bool sortAsc) {
    // Check if cache is valid
    final serverOrder = serverState.serverOrder;
    final serverNames = <String, String>{};
    for (final id in serverOrder) {
      final name = serverState.servers[id]?.name;
      if (name != null) serverNames[id] = name;
    }

    if (_cachedOrder != null &&
        _cachedSortBy == sortBy &&
        _cachedSortAsc == sortAsc &&
        listEquals(_cachedServerOrder, serverOrder) &&
        mapEquals(_cachedServerNames, serverNames)) {
      return _cachedOrder!;
    }

    // Rebuild cache
    final order = serverOrder.toList();
    if (sortBy == 0) {
      order.sort((a, b) {
        final nameA = serverNames[a] ?? '';
        final nameB = serverNames[b] ?? '';
        return sortAsc ? nameA.compareTo(nameB) : nameB.compareTo(nameA);
      });
    } else if (sortBy == 1) {
      final indexMap = <String, int>{};
      for (var i = 0; i < serverOrder.length; i++) {
        indexMap[serverOrder[i]] = i;
      }
      order.sort((a, b) {
        final idxA = indexMap[a] ?? -1;
        final idxB = indexMap[b] ?? -1;
        return sortAsc ? idxA.compareTo(idxB) : idxB.compareTo(idxA);
      });
    }

    _cachedOrder = order;
    _cachedSortBy = sortBy;
    _cachedSortAsc = sortAsc;
    _cachedServerOrder = serverOrder;
    _cachedServerNames = serverNames;

    return order;
  }

  Widget get _placeholder => const Expanded(child: UIs.placeholder);

  @override
  Widget build(BuildContext context) {
    const viewPadding = 7.0;
    final isMobile = ResponsiveBreakpoints.of(context).isMobile;

    final serverState = ref.watch(serversProvider);
    final sortBy = Stores.setting.sshPageSortBy.fetch();
    final sortAsc = Stores.setting.sshPageSortAsc.fetch();

    final order = _getSortedOrder(serverState, sortBy, sortAsc);

    final itemCount = order.length;
    const itemPadding = 1.0;
    final isDesktopWide = !isMobile;
    const desktopMinItemWidth = 280.0;
    const desktopMaxItemWidth = 320.0;

    if (order.isEmpty) {
      return Center(child: Text(libL10n.empty, textAlign: TextAlign.center));
    }

    return LayoutBuilder(
      builder: (_, cons) {
        final availableWidth = max(cons.maxWidth - 2 * viewPadding, 0.0);
        final canUseTwoColumns =
            availableWidth >= 2 * (desktopMinItemWidth + itemPadding);
        final crossCount = isDesktopWide
            ? max(
                availableWidth ~/ (desktopMinItemWidth + itemPadding),
                canUseTwoColumns ? 2 : 1,
              )
            : 1;
        final mainCount = (itemCount + crossCount - 1) ~/ crossCount;
        final desktopItemWidth = isDesktopWide
            ? max(
                0.0,
                min(
                  desktopMaxItemWidth,
                  (availableWidth - crossCount * itemPadding * 2) / crossCount,
                ),
              )
            : null;

        return ListView(
          padding: const EdgeInsets.all(viewPadding),
          children: List.generate(
            mainCount,
            (rowIndex) => Row(
              mainAxisAlignment: isDesktopWide
                  ? MainAxisAlignment.center
                  : MainAxisAlignment.start,
              children: List.generate(crossCount, (columnIndex) {
                final idx = rowIndex * crossCount + columnIndex;
                final id = order.elementAtOrNull(idx);
                final spi = serverState.servers[id];
                if (spi == null) {
                  return isDesktopWide
                      ? SizedBox(width: desktopItemWidth)
                      : _placeholder;
                }

                final child = Padding(
                  padding: const EdgeInsets.all(itemPadding),
                  child: InkWell(
                    onTap: () => widget.onTapInitCard(spi),
                    onLongPress: () => widget.onLongPressInitCard(spi),
                    child: Container(
                      alignment: Alignment.centerLeft,
                      constraints: BoxConstraints(
                        minHeight: isDesktopWide ? 58.0 : 50.0,
                      ),
                      padding: const EdgeInsets.only(left: 17, right: 7),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: Text(
                              spi.name,
                              style: UIs.text18,
                              maxLines: isDesktopWide ? null : 2,
                              overflow: isDesktopWide
                                  ? null
                                  : TextOverflow.ellipsis,
                            ),
                          ),
                          const Icon(Icons.chevron_right),
                        ],
                      ),
                    ),
                  ).cardx,
                );

                if (isDesktopWide) {
                  return SizedBox(width: desktopItemWidth, child: child);
                }

                return Expanded(child: child);
              }),
            ),
          ),
        );
      },
    );
  }
}

class _SortOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _SortOption({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;
    return ListTile(
      leading: Icon(icon, color: selected ? primaryColor : null),
      title: Text(
        label,
        style: TextStyle(color: selected ? primaryColor : null),
      ),
      onTap: onTap,
    );
  }
}
