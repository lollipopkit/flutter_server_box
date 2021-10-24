import 'package:after_layout/after_layout.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:toolbox/core/route.dart';
import 'package:toolbox/core/update.dart';
import 'package:toolbox/core/utils.dart';
import 'package:toolbox/data/provider/server.dart';
import 'package:toolbox/data/res/build_data.dart';
import 'package:toolbox/locator.dart';
import 'package:toolbox/view/page/convert.dart';
import 'package:toolbox/view/page/debug.dart';
import 'package:toolbox/view/page/server.dart';

class MyHomePage extends StatefulWidget {
  const MyHomePage({Key? key, required this.title}) : super(key: key);
  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage>
    with
        AutomaticKeepAliveClientMixin,
        SingleTickerProviderStateMixin,
        AfterLayoutMixin {
  final List<String> _tabs = ['Servers', 'En/Decode'];
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
  }

  @override
  Widget build(BuildContext context) {
    setTransparentNavigationBar(context);
    super.build(context);
    return Scaffold(
      appBar: AppBar(
        title: GestureDetector(
          onLongPress: () =>
              AppRoute(const DebugPage(), 'Debug Page').go(context),
          child: Text(widget.title),
        ),
        bottom: TabBar(
          tabs: _tabs.map((e) => Tab(text: e)).toList(),
          controller: _tabController,
        ),
      ),
      drawer: _buildDrawer(),
      body: TabBarView(controller: _tabController, children: const [
        ServerPage(),
        ConvertPage(),
      ]),
    );
  }

  Widget _buildDrawer() {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          UserAccountsDrawerHeader(
            accountName: const Text('ToolBox'),
            accountEmail: Text(_buildVersionStr()),
            currentAccountPicture: _buildIcon(),
          ),
          // const ListTile(
          //   leading: Icon(Icons.settings),
          //   title: Text('设置'),
          // ),
          AboutListTile(
            icon: const Icon(Icons.text_snippet),
            child: const Text('Open source licenses'),
            applicationName: BuildData.name,
            applicationVersion: _buildVersionStr(),
            applicationIcon: _buildIcon(),
            aboutBoxChildren: const [
              Text('''\nMade with Love.
            \nAll rights reserved.'''),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildIcon() {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 60, maxWidth: 60),
      child: Stack(
        children: [
          Center(
            child: Container(
              color: Colors.white,
              height: 37,
              width: 37,
            ),
          ),
          Image.asset('assets/app_icon.jpg'),
        ],
      ),
    );
  }

  String _buildVersionStr() {
    return 'Ver: 1.0.${BuildData.build}';
  }

  @override
  bool get wantKeepAlive => true;

  @override
  Future<void> afterFirstLayout(BuildContext context) async {
    await GetIt.I.allReady();
    await locator<ServerProvider>().loadLocalData();
    await doUpdate(context);
  }
}
