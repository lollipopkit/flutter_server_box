import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:icons_plus/icons_plus.dart';
import 'package:provider/provider.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/core/route.dart';
import 'package:server_box/data/model/server/server_private_info.dart';
import 'package:server_box/data/provider/server.dart';
import 'package:server_box/data/res/provider.dart';
import 'package:server_box/view/page/ssh/page.dart';

class SSHTabPage extends StatefulWidget {
  const SSHTabPage({super.key});

  @override
  State<SSHTabPage> createState() => _SSHTabPageState();
}

typedef _TabMap = Map<String, ({Widget page, GlobalKey<SSHPageState>? key})>;

class _SSHTabPageState extends State<SSHTabPage>
    with TickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  late final _TabMap _tabMap = {
    l10n.add: (page: _buildAddPage(), key: null),
  };
  final _pageCtrl = PageController();
  final _fabVN = 0.vn;
  final _tabRN = RNode();

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
            onPressed: () => AppRoutes.serverEdit().go(context),
            tooltip: l10n.addAServer,
            child: const Icon(Icons.add),
          );
        },
      ),
    );
  }

  void _onTapTab(int idx) async {
    await _toPage(idx);
    SSHPage.focusNode.unfocus();
  }

  void _onTapClose(String name) async {
    SSHPage.focusNode.unfocus();

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(l10n.attention),
          content: Text('${l10n.close} SSH ${l10n.conn}($name) ?'),
          actions: [
            TextButton(
              onPressed: () => context.pop(true),
              child: Text(l10n.ok, style: UIs.textRed),
            ),
            TextButton(
              onPressed: () => context.pop(false),
              child: Text(l10n.cancel),
            ),
          ],
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

  Widget _buildAddPage() {
    return Center(
      key: const Key('sshTabAddServer'),
      child: Consumer<ServerProvider>(builder: (_, pro, __) {
        if (pro.serverOrder.isEmpty) {
          return Center(
            child: Text(
              l10n.serverTabEmpty,
              textAlign: TextAlign.center,
            ),
          );
        }
        return GridView.builder(
          padding: const EdgeInsets.all(7),
          itemBuilder: (context, idx) {
            final spi = Pros.server.pick(id: pro.serverOrder[idx])?.spi;
            if (spi == null) return UIs.placeholder;
            return CardX(
              child: InkWell(
                onTap: () => _onTapInitCard(spi),
                child: Container(
                  alignment: Alignment.centerLeft,
                  padding: const EdgeInsets.only(left: 17, right: 7),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        spi.name,
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                      const Icon(Icons.chevron_right)
                    ],
                  ),
                ),
              ),
            );
          },
          itemCount: pro.servers.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 3,
            crossAxisSpacing: 3,
            mainAxisSpacing: 3,
          ),
        );
      }),
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

  void _onTapInitCard(ServerPrivateInfo spi) async {
    final name = () {
      final reg = RegExp('${spi.name}\\((\\d+)\\)');
      final idxs = _tabMap.keys
          .map((e) => reg.firstMatch(e))
          .map((e) => e?.group(1))
          .where((e) => e != null);
      if (idxs.isEmpty) {
        return _tabMap.keys.contains(spi.name) ? '${spi.name}(1)' : spi.name;
      }
      final biggest = idxs.reduce((a, b) => a!.length > b!.length ? a : b);
      final biggestInt = int.tryParse(biggest ?? '0');
      if (biggestInt != null && biggestInt > 0) {
        return '${spi.name}(${biggestInt + 1})';
      }
      return spi.name;
    }();
    final key = GlobalKey<SSHPageState>();
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
      key: key,
    );
    _tabRN.notify();
    // Wait for the page to be built
    await Future.delayed(Durations.short3);
    final idx = _tabMap.keys.toList().indexOf(name);
    await _toPage(idx);
  }

  Future<void> _toPage(int idx) => _pageCtrl.animateToPage(idx,
      duration: Durations.short3, curve: Curves.fastEaseInToSlowEaseOut);

  @override
  bool get wantKeepAlive => true;
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
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
          itemCount: names.length,
          itemBuilder: (_, idx) => _buillItem(idx),
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

  Widget _buillItem(int idx) {
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
        textAlign: TextAlign.center,
        textWidthBasis: TextWidthBasis.parent,
      );
      child = AnimatedContainer(
        width: selected ? 90 : 50,
        duration: Durations.medium3,
        curve: Curves.fastEaseInToSlowEaseOut,
        child: switch (selected) {
          true => Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                SizedBox(width: 55, child: text),
                if (selected)
                  FadeIn(
                    child: IconBtn(
                      icon: MingCute.close_circle_fill,
                      color: color,
                      onTap: () => onClose(name),
                    ),
                  ),
              ],
            ),
          false => Center(child: text),
        },
      ).paddingOnly(left: 3, right: 3);
    }

    return InkWell(
      borderRadius: BorderRadius.circular(13),
      onTap: () => onTap(idx),
      child: child,
    ).paddingSymmetric(horizontal: 13);
  }
}
