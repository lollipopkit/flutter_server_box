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
  late final _tabIds = <String, Widget>{
    l10n.add: _buildAddPage(),
  };
  late var _tabController = TabController(
    length: _tabIds.length,
    vsync: this,
  );
  final _fabRN = ValueNotifier(0);
  final _focusMap = <String, FocusNode>{};

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      appBar: TabBar(
        controller: _tabController,
        tabs: _tabIds.keys.map(_buildTabItem).toList(),
        isScrollable: true,
        tabAlignment: TabAlignment.start,
        dividerColor: Colors.transparent,
        onTap: (value) {
          _fabRN.value = value;
          _focusMap[_tabIds.keys.elementAt(value)]?.requestFocus();
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
          IconButton(
            icon: const Icon(Icons.close, size: 17),
            onPressed: () async {
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
              _tabIds.remove(e);
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
      children: _tabIds.values.toList(),
    );
  }

  void _onTapInitCard(ServerPrivateInfo spi) {
    final name = () {
      if (_tabIds.containsKey(spi.name)) {
        return '${spi.name}(${_tabIds.length + 1})';
      }
      return spi.name;
    }();
    final focus = _focusMap.putIfAbsent(name, () => FocusNode());
    _tabIds[name] = SSHPage(
      spi: spi,
      focus: focus,
      notFromTab: false,
      onSessionEnd: () {
        // debugPrint("Session done received on page whose tabId = $name");
        // debugPrint("key = $key");
        _tabIds.remove(name);
        _refreshTabs();
      },
    );
    _refreshTabs();
    final idx = _tabIds.length - 1;
    _tabController.animateTo(idx);
    _fabRN.value = idx;
  }

  void _refreshTabs() {
    _tabController = TabController(
      length: _tabIds.length,
      vsync: this,
    );
    setState(() {});
  }

  @override
  bool get wantKeepAlive => true;
}
