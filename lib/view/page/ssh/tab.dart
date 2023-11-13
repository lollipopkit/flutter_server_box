import 'package:flutter/material.dart';
import 'package:toolbox/core/extension/context/common.dart';
import 'package:toolbox/core/extension/context/dialog.dart';
import 'package:toolbox/core/extension/context/locale.dart';
import 'package:toolbox/data/model/server/server.dart';
import 'package:toolbox/data/res/provider.dart';
import 'package:toolbox/data/res/ui.dart';
import 'package:toolbox/view/page/ssh/page.dart';

class SSHTabPage extends StatefulWidget {
  const SSHTabPage({super.key});

  @override
  _SSHTabPageState createState() => _SSHTabPageState();
}

class _SSHTabPageState extends State<SSHTabPage>
    with TickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  late final _tabIds = <String, Widget>{
    l10n.add: _addPage,
  };
  final _tabKeys = <String, GlobalKey>{};
  late var _tabController = TabController(
    length: _tabIds.length,
    vsync: this,
  );

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      appBar: TabBar(
        controller: _tabController,
        tabs: _tabIds.keys.map(_buildTabItem).toList(),
        isScrollable: true,
      ),
      body: _buildBody(),
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
          InkWell(
            borderRadius: BorderRadius.circular(17),
            child: const Padding(
              padding: EdgeInsets.all(7),
              child: Icon(Icons.close, size: 17),
            ),
            onTap: () async {
              final confirm = await context.showRoundDialog<bool>(
                title: Text(l10n.attention),
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
              //_tabKeys[e]?.currentState?.dispose();
            },
          ),
        ],
      ),
    );
  }

  late final Widget _addPage = Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(77),
            color: Colors.white10,
          ),
          child: IconButton(
            padding: const EdgeInsets.all(17),
            onPressed: () async {
              final spi = (await context.showPickDialog<Server>(
                items: Pros.server.servers.toList(),
                name: (e) => e.spi.name,
                multi: false,
              ))
                  ?.first
                  .spi;
              if (spi == null) {
                return;
              }
              final name = () {
                if (_tabIds.containsKey(spi.name)) {
                  return '${spi.name}(${_tabIds.length + 1})';
                }
                return spi.name;
              }();
              final key = GlobalKey(debugLabel: 'sshTabPage_$name');
              _tabIds[name] = SSHPage(
                key: key,
                spi: spi,
                pop: false,
              );
              _tabKeys[name] = key;
              _refreshTabs();
              _tabController.animateTo(_tabIds.length - 1);
            },
            icon: const Icon(Icons.add),
          ),
        ),
        UIs.height13,
        Text(l10n.add),
      ],
    ),
  );

  Widget _buildBody() {
    return TabBarView(
      physics: const NeverScrollableScrollPhysics(),
      controller: _tabController,
      children: _tabIds.values.toList(),
    );
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
