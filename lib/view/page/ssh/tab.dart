import 'dart:math';

import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:icons_plus/icons_plus.dart';
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

typedef _TabMap = Map<String, ({Widget page, FocusNode? focus})>;

class _SSHTabPageState extends ConsumerState<SSHTabPage>
    with TickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  late final _TabMap _tabMap = {libL10n.add: (page: _AddPage(sortVersionVN: _sortVersionVN, onTapInitCard: _onTapInitCard, onLongPressInitCard: _onLongPressInitCard), focus: null)};
  final _pageCtrl = PageController();
  final _fabVN = 0.vn;
  final _tabRN = RNode();
  final _sortVersionVN = 0.vn;

  @override
  void dispose() {
    super.dispose();
    _pageCtrl.dispose();
    _tabRN.dispose();
    _fabVN.dispose();
    _sortVersionVN.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      appBar: PreferredSizeListenBuilder(
        listenable: _tabRN,
        builder: () {
          return _TabBar(
            idxVN: _fabVN,
            map: _tabMap,
            onTap: _onTapTab,
            onClose: _onTapClose,
            sortBtn: buildSortBtn(context),
            searchBtn: buildSearchBtn(context),
            historyBtn: buildHistoryBtn(context),
          );
        },
      ),
      body: _buildBody(),
      floatingActionButton: ValBuilder(
        listenable: _fabVN,
        builder: (idx) {
          if (idx != 0) return const SizedBox();
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

  Widget _buildBody() {
    return ListenBuilder(
      listenable: _tabRN,
      builder: () {
        return PageView.builder(
          physics: const NeverScrollableScrollPhysics(),
          controller: _pageCtrl,
          itemCount: _tabMap.length,
          itemBuilder: (_, idx) {
            final name = _tabMap.keys.elementAt(idx);
            return _tabMap[name]?.page ?? UIs.placeholder;
          },
          onPageChanged: (value) => _fabVN.value = value,
        );
      },
    );
  }

  @override
  bool get wantKeepAlive => true;
}

extension on _SSHTabPageState {
  void _onTapInitCard(Spi spi) async {
    final name = () {
      final reg = RegExp('${spi.name}\\((\\d+)\\)');
      final idxs = _tabMap.keys.map((e) => reg.firstMatch(e)).map((e) => e?.group(1)).whereType<String>();
      if (idxs.isEmpty) {
        return _tabMap.keys.contains(spi.name) ? '${spi.name}(1)' : spi.name;
      }
      final biggest = idxs.reduce((a, b) => a.length > b.length ? a : b);
      final biggestInt = int.tryParse(biggest);
      if (biggestInt != null && biggestInt > 0) {
        return '${spi.name}(${biggestInt + 1})';
      }
      return spi.name;
    }();
    final key = Key(name);
    final args = SshPageArgs(
      spi: spi,
      notFromTab: false,
      onSessionEnd: () {
        _tabMap.remove(name);
      },
    );
    _tabMap[name] = (
      page: SSHPage(
        key: key, // Keep it, or the Flutter will works unexpectedly
        args: args,
      ),
      focus: FocusNode(),
    );
    _tabRN.notify();
    Stores.history.sshServerHistory.add(spi.id);
    // Wait for the page to be built
    await Future.delayed(Durations.short3);
    final idx = _tabMap.keys.toList().indexOf(name);
    await _toPage(idx);
  }

  void _onLongPressInitCard(Spi spi) {
    ServerEditPage.route.go(context, args: SpiRequiredArgs(spi));
  }

  Future<void> _toPage(int idx) async {
    await _pageCtrl.animateToPage(idx, duration: Durations.short3, curve: Curves.fastEaseInToSlowEaseOut);
    final focus = _tabMap.values.elementAt(idx).focus;
    if (focus != null) {
      FocusScope.of(context).requestFocus(focus);
    }
  }

  void _onTapTab(int idx) async {
    await _toPage(idx);
  }

  void _onTapClose(String name) async {
    final confirm = await contextSafe?.showRoundDialog(
      title: libL10n.attention,
      child: Text('${libL10n.close} SSH ${libL10n.conn}($name) ?'),
      actions: Btnx.okReds,
    );
    Future.delayed(Durations.short1, FocusScope.of(context).unfocus);
    if (confirm != true) return;

    _tabMap.remove(name);
    _tabRN.notify();
    _pageCtrl.previousPage(duration: Durations.medium1, curve: Curves.fastEaseInToSlowEaseOut);
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
              Stores.setting.sshPageSortBy.put(0);
              Stores.setting.sshPageSortAsc.put(true);
              _tabRN.notify();
              _sortVersionVN.notify();
              context.pop();
            },
          ),
          _SortOption(
            icon: Icons.sort,
            label: '${l10n.sortByName} (Z-A)',
            selected: sortBy == 0 && !sortAsc,
            onTap: () {
              Stores.setting.sshPageSortBy.put(0);
              Stores.setting.sshPageSortAsc.put(false);
              _tabRN.notify();
              _sortVersionVN.notify();
              context.pop();
            },
          ),
          _SortOption(
            icon: Icons.arrow_upward,
            label: '${l10n.sortByJoinTime} (${l10n.ascending})',
            selected: sortBy == 1 && sortAsc,
            onTap: () {
              Stores.setting.sshPageSortBy.put(1);
              Stores.setting.sshPageSortAsc.put(true);
              _tabRN.notify();
              _sortVersionVN.notify();
              context.pop();
            },
          ),
          _SortOption(
            icon: Icons.arrow_downward,
            label: '${l10n.sortByJoinTime} (${l10n.descending})',
            selected: sortBy == 1 && !sortAsc,
            onTap: () {
              Stores.setting.sshPageSortBy.put(1);
              Stores.setting.sshPageSortAsc.put(false);
              _tabRN.notify();
              _sortVersionVN.notify();
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
          return allServers.where((spi) =>
            spi.name.toLowerCase().contains(q.toLowerCase()) ||
            spi.user.toLowerCase().contains(q.toLowerCase()) ||
            spi.ip.contains(q)
          ).toList();
        },
        builder: (ctx, spi) => ListTile(
          title: Text(spi.name),
          subtitle: Text('${spi.user}@${spi.ip}:${spi.port}'),
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
        height: 300,
        child: ListView.builder(
          itemCount: history.length,
          itemBuilder: (_, idx) {
            final id = history[idx];
            final spi = serverState.servers[id];
            return ListTile(
              title: Text(spi?.name ?? id),
              subtitle: spi != null ? Text('${spi.user}@${spi.ip}:${spi.port}') : null,
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
    required this.idxVN,
    required this.map,
    required this.onTap,
    required this.onClose,
    required this.sortBtn,
    required this.searchBtn,
    required this.historyBtn,
  });

  final ValueListenable<int> idxVN;
  final _TabMap map;
  final void Function(int idx) onTap;
  final void Function(String name) onClose;
  final Widget sortBtn;
  final Widget searchBtn;
  final Widget historyBtn;

  List<String> get names => map.keys.toList();

  @override
  Size get preferredSize => const Size.fromHeight(48);

  @override
  Widget build(BuildContext context) {
    return ListenBuilder(
      listenable: idxVN,
      builder: () {
        return Row(
          children: [
            Expanded(
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
                itemCount: names.length,
                itemBuilder: (_, idx) => _buildItem(idx),
                separatorBuilder: (_, _) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 17),
                  child: Container(color: Theme.of(context).dividerColor.withAlpha(61), width: 3),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 17),
              child: Container(color: Theme.of(context).dividerColor.withAlpha(61), width: 3),
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
        );
      },
    );
  }

  static const kWideWidth = 90.0;
  static const kNarrowWidth = 60.0;

  Widget _buildItem(int idx) {
    final name = names[idx];
    final selected = idxVN.value == idx;
    final color = selected ? null : Colors.grey;

    final Widget child;
    if (idx == 0) {
      child = Padding(
        padding: const EdgeInsets.symmetric(horizontal: 13),
        child: Icon(MingCute.add_circle_fill, size: 17, color: color),
      );
    } else {
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
            SizedBox(width: kNarrowWidth - 15, child: text),
          ],
        );
      } else {
        btn = Center(child: text);
      }
      child = AnimatedContainer(
        width: selected ? kWideWidth : kNarrowWidth,
        duration: Durations.medium3,
        curve: Curves.fastEaseInToSlowEaseOut,
        child: OverflowBox(maxWidth: selected ? kWideWidth : null, child: btn),
      );
    }

    return InkWell(
      borderRadius: BorderRadius.circular(13),
      onTap: () => onTap(idx),
      child: child,
    ).paddingSymmetric(horizontal: 7);
  }
}

class _AddPage extends ConsumerStatefulWidget {
  const _AddPage({required this.sortVersionVN, required this.onTapInitCard, required this.onLongPressInitCard});

  final ValueListenable<int> sortVersionVN;
  final void Function(Spi spi) onTapInitCard;
  final void Function(Spi spi) onLongPressInitCard;

  @override
  ConsumerState<_AddPage> createState() => _AddPageState();
}

class _AddPageState extends ConsumerState<_AddPage> {
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
    if (mounted) setState(() {});
  }

  Widget get _placeholder => const Expanded(child: UIs.placeholder);

  @override
  Widget build(BuildContext context) {
    const viewPadding = 7.0;
    final viewWidth = context.windowSize.width - 2 * viewPadding;

    final serverState = ref.watch(serversProvider);
    final sortBy = Stores.setting.sshPageSortBy.fetch();
    final sortAsc = Stores.setting.sshPageSortAsc.fetch();

    final order = serverState.serverOrder.toList();
    if (sortBy == 0) {
      order.sort((a, b) {
        final nameA = serverState.servers[a]?.name ?? '';
        final nameB = serverState.servers[b]?.name ?? '';
        return sortAsc ? nameA.compareTo(nameB) : nameB.compareTo(nameA);
      });
    } else if (sortBy == 1) {
      final indexMap = <String, int>{};
      for (var i = 0; i < serverState.serverOrder.length; i++) {
        indexMap[serverState.serverOrder[i]] = i;
      }
      order.sort((a, b) {
        final idxA = indexMap[a] ?? -1;
        final idxB = indexMap[b] ?? -1;
        return sortAsc ? idxA.compareTo(idxB) : idxB.compareTo(idxA);
      });
    }

    final itemCount = order.length;
    const itemPadding = 1.0;
    const itemWidth = 150.0;
    const itemHeight = 50.0;

    final visualCrossCount = viewWidth / itemWidth;
    final crossCount = max(viewWidth ~/ (visualCrossCount * itemPadding + itemWidth), 1);
    final mainCount = itemCount ~/ crossCount + 1;

    if (order.isEmpty) {
      return Center(child: Text(libL10n.empty, textAlign: TextAlign.center));
    }

    return ListView(
      padding: const EdgeInsets.all(viewPadding),
      children: List.generate(
        mainCount,
        (rowIndex) => Row(
          children: List.generate(crossCount, (columnIndex) {
            final idx = rowIndex * crossCount + columnIndex;
            final id = order.elementAtOrNull(idx);
            final spi = serverState.servers[id];
            if (spi == null) return _placeholder;

            return Expanded(
              child: Padding(
                padding: const EdgeInsets.all(itemPadding),
                child: InkWell(
                  onTap: () => widget.onTapInitCard(spi),
                  onLongPress: () => widget.onLongPressInitCard(spi),
                  child: Container(
                    height: itemHeight,
                    alignment: Alignment.centerLeft,
                    padding: const EdgeInsets.only(left: 17, right: 7),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            spi.name,
                            style: UIs.text18,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const Icon(Icons.chevron_right),
                      ],
                    ),
                  ),
                ).cardx,
              ),
            );
          }),
        ),
      ),
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
      title: Text(label, style: TextStyle(color: selected ? primaryColor : null)),
      onTap: onTap,
    );
  }
}
