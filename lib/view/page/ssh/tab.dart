import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:toolbox/core/extension/context/locale.dart';
import 'package:toolbox/core/route.dart';
import 'package:toolbox/data/model/server/server_private_info.dart';
import 'package:toolbox/data/provider/server.dart';
import 'package:toolbox/data/res/provider.dart';
import 'package:toolbox/view/page/ssh/page.dart';

class SSHTabPage extends StatefulWidget {
  const SSHTabPage({super.key});

  @override
  State<SSHTabPage> createState() => _SSHTabPageState();
}

class _SSHTabPageState extends State<SSHTabPage>
    with TickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  late final _tabMap = <String, ({Widget page, FocusNode? focus})>{
    l10n.add: (page: _buildAddPage(), focus: null),
  };
  late var _tabController = TabController(
    length: _tabMap.length,
    vsync: this,
  );
  final _fabRN = ValueNotifier(0);

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      appBar: TabBar(
        controller: _tabController,
        tabs: _tabMap.keys.map(_buildTabItem).toList(),
        isScrollable: true,
        tabAlignment: TabAlignment.start,
        dividerColor: Colors.transparent,
        onTap: (value) {
          _fabRN.value = value;
          final mapKey = _tabMap.keys.elementAt(value);
          _tabMap[mapKey]?.focus?.requestFocus();
        },
      ),
      body: _buildBody(),
      floatingActionButton: ListenableBuilder(
        listenable: _fabRN,
        builder: (_, __) {
          if (_fabRN.value != 0) return const SizedBox();
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

  Widget _buildTabItem(String e) {
    if (e == l10n.add) {
      return Tab(child: Text(e));
    }
    return Tab(
      child: Row(
        children: [
          Text(e),
          UIs.width7,
          IconBtn(
            icon: Icons.close,
            onTap: () async {
              final confirm = await context.showRoundDialog<bool>(
                title: l10n.attention,
                child: Text('${l10n.close} SSH ${l10n.conn}($e) ?'),
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
              if (confirm != true) {
                return;
              }
              _tabMap.remove(e);
              _refreshTabs();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildAddPage() {
    return Center(
      child: Consumer<ServerProvider>(builder: (_, pro, __) {
        if (pro.serverOrder.isEmpty) {
          return Center(
            child: Text(
              l10n.serverTabEmpty,
              textAlign: TextAlign.center,
            ),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(7),
          itemBuilder: (_, idx) {
            final spi = Pros.server.pick(id: pro.serverOrder[idx])?.spi;
            if (spi == null) return UIs.placeholder;
            return CardX(
              child: ListTile(
                title: Text(spi.name),
                subtitle: Text(spi.id, style: UIs.textGrey),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _onTapInitCard(spi),
              ),
            );
          },
          itemCount: pro.servers.length,
        );
      }),
    );
  }

  Widget _buildBody() {
    return TabBarView(
      physics: const NeverScrollableScrollPhysics(),
      controller: _tabController,
      children: _tabMap.values.map((e) => e.page).toList(),
    );
  }

  void _onTapInitCard(ServerPrivateInfo spi) {
    final name = () {
      if (_tabMap.containsKey(spi.name)) {
        return '${spi.name}(${_tabMap.length + 1})';
      }
      return spi.name;
    }();
    final focus = FocusNode();
    _tabMap[name] = (
      page: SSHPage(
        spi: spi,
        focus: focus,
        notFromTab: false,
        onSessionEnd: () {
          _tabMap.remove(name);
          _refreshTabs();
        },
      ),
      focus: focus,
    );
    _refreshTabs();
    final idx = _tabMap.length - 1;
    _tabController.animateTo(idx);
    _fabRN.value = idx;
  }

  void _refreshTabs() {
    _tabController = TabController(
      length: _tabMap.length,
      vsync: this,
    );
    setState(() {});
  }

  @override
  bool get wantKeepAlive => true;
}
