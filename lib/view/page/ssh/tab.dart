import 'package:flutter/material.dart';
import 'package:toolbox/core/extension/context/dialog.dart';
import 'package:toolbox/data/model/server/server.dart';
import 'package:toolbox/data/res/provider.dart';
import 'package:toolbox/view/page/ssh/page.dart';

class SSHTabPage extends StatefulWidget {
  const SSHTabPage({super.key});

  @override
  _SSHTabPageState createState() => _SSHTabPageState();
}

class _SSHTabPageState extends State<SSHTabPage>
    with TickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  final _tabIds = <String, SSHPage>{};
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
      floatingActionButton: _buildFAB(),
    );
  }

  Widget _buildTabItem(String e) {
    return Tab(
      child: Row(
        children: [
          Text(e),
          IconButton(
            icon: const Icon(Icons.close),
            padding: EdgeInsets.zero,
            onPressed: () {
              _tabKeys[e]?.currentState?.dispose();
              _tabIds.remove(e);
              _refreshTabs();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildFAB() {
    return FloatingActionButton(
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
        );
        _tabKeys[name] = key;
        _refreshTabs();
        _tabController.animateTo(_tabIds.length - 1);
      },
      child: const Icon(Icons.add),
    );
  }

  Widget _buildBody() {
    if (_tabIds.isEmpty) {
      return const Center(
        child: Text('Click the fab to open a session'),
      );
    }
    return TabBarView(
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
