import 'dart:math';

import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:icons_plus/icons_plus.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/data/model/server/server_private_info.dart';
import 'package:server_box/data/provider/server.dart';
import 'package:server_box/view/page/server/edit.dart';
import 'package:server_box/view/page/ssh/page.dart';

class SSHTabPage extends StatefulWidget {
  const SSHTabPage({super.key});

  @override
  State<SSHTabPage> createState() => _SSHTabPageState();
}

typedef _TabMap = Map<String, ({Widget page, FocusNode? focus})>;

class _SSHTabPageState extends State<SSHTabPage>
    with TickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  late final _TabMap _tabMap = {
    libL10n.add: (page: _AddPage(onTapInitCard: _onTapInitCard), focus: null),
  };
  final _pageCtrl = PageController();
  final _fabVN = 0.vn;
  final _tabRN = RNode();

  @override
  void dispose() {
    super.dispose();
    _pageCtrl.dispose();
    _tabRN.dispose();
    _fabVN.dispose();
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
      final idxs = _tabMap.keys
          .map((e) => reg.firstMatch(e))
          .map((e) => e?.group(1))
          .whereType<String>();
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
    _tabMap[name] = (
      page: SSHPage(
        // Keep it, or the Flutter will works unexpectedly
        key: key,
        spi: spi,
        notFromTab: false,
        onSessionEnd: () {
          _tabMap.remove(name);
        },
      ),
      focus: FocusNode(),
    );
    _tabRN.notify();
    // Wait for the page to be built
    await Future.delayed(Durations.short3);
    final idx = _tabMap.keys.toList().indexOf(name);
    await _toPage(idx);
  }

  Future<void> _toPage(int idx) async {
    await _pageCtrl.animateToPage(idx,
        duration: Durations.short3, curve: Curves.fastEaseInToSlowEaseOut);
    final focus = _tabMap.values.elementAt(idx).focus;
    if (focus != null) {
      FocusScope.of(context).requestFocus(focus);
    }
  }

  void _onTapTab(int idx) async {
    await _toPage(idx);
  }

  void _onTapClose(String name) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(libL10n.attention),
          content: Text('${libL10n.close} SSH ${l10n.conn}($name) ?'),
          actions: Btnx.okReds,
        );
      },
    );
    Future.delayed(Durations.short1, FocusScope.of(context).unfocus);
    if (confirm != true) return;

    _tabMap.remove(name);
    _tabRN.notify();
    _pageCtrl.previousPage(
        duration: Durations.medium1, curve: Curves.fastEaseInToSlowEaseOut);
  }
}

final class _TabBar extends StatelessWidget implements PreferredSizeWidget {
  const _TabBar({
    required this.idxVN,
    required this.map,
    required this.onTap,
    required this.onClose,
  });

  final ValueListenable<int> idxVN;
  final _TabMap map;
  final void Function(int idx) onTap;
  final void Function(String name) onClose;

  List<String> get names => map.keys.toList();

  @override
  Size get preferredSize => const Size.fromHeight(48);

  @override
  Widget build(BuildContext context) {
    return ListenBuilder(
      listenable: idxVN,
      builder: () {
        return ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
          itemCount: names.length,
          itemBuilder: (_, idx) => _buildItem(idx),
          separatorBuilder: (_, __) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 17),
            child: Container(
              color: const Color.fromARGB(61, 158, 158, 158),
              width: 3,
            ),
          ),
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
        child: OverflowBox(
          maxWidth: selected ? kWideWidth : null,
          child: btn,
        ),
      );
    }

    return InkWell(
      borderRadius: BorderRadius.circular(13),
      onTap: () => onTap(idx),
      child: child,
    ).paddingSymmetric(horizontal: 7);
  }
}

class _AddPage extends StatelessWidget {
  const _AddPage({required this.onTapInitCard});

  final void Function(Spi spi) onTapInitCard;

  Widget get _placeholder => const Expanded(child: UIs.placeholder);

  @override
  Widget build(BuildContext context) {
    const viewPadding = 7.0;
    final viewWidth = context.mediaQuery.size.width - 2 * viewPadding;

    final itemCount = ServerProvider.servers.length;
    const itemPadding = 1.0;
    const itemWidth = 150.0;
    const itemHeight = 50.0;

    final visualCrossCount = viewWidth / itemWidth;
    final crossCount =
        max(viewWidth ~/ (visualCrossCount * itemPadding + itemWidth), 1);
    final mainCount = itemCount ~/ crossCount + 1;

    return ServerProvider.serverOrder.listenVal((order) {
      if (order.isEmpty) {
        return Center(
          child: Text(libL10n.empty, textAlign: TextAlign.center),
        );
      }

      // Custom grid
      return ListView(
        padding: const EdgeInsets.all(viewPadding),
        children: List.generate(
          mainCount,
          (rowIndex) => Row(
            children: List.generate(crossCount, (columnIndex) {
              final idx = rowIndex * crossCount + columnIndex;
              final id = order.elementAtOrNull(idx);
              final spi = ServerProvider.pick(id: id)?.value.spi;
              if (spi == null) return _placeholder;

              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(itemPadding),
                  child: InkWell(
                    onTap: () => onTapInitCard(spi),
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
                          const Icon(Icons.chevron_right)
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
    });
  }
}
