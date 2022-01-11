import 'package:after_layout/after_layout.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:toolbox/core/analysis.dart';
import 'package:toolbox/core/build_mode.dart';
import 'package:toolbox/core/route.dart';
import 'package:toolbox/core/update.dart';
import 'package:toolbox/core/utils.dart';
import 'package:toolbox/data/provider/server.dart';
import 'package:toolbox/data/res/build_data.dart';
import 'package:toolbox/data/res/icon/common.dart';
import 'package:toolbox/data/res/url.dart';
import 'package:toolbox/locator.dart';
import 'package:toolbox/view/page/convert.dart';
import 'package:toolbox/view/page/debug.dart';
import 'package:toolbox/view/page/private_key/list.dart';
import 'package:toolbox/view/page/server/tab.dart';
import 'package:toolbox/view/page/setting.dart';
import 'package:toolbox/view/page/snippet/list.dart';
import 'package:toolbox/view/widget/url_text.dart';

class MyHomePage extends StatefulWidget {
  const MyHomePage({Key? key, required this.primaryColor}) : super(key: key);
  final Color primaryColor;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage>
    with
        AutomaticKeepAliveClientMixin,
        SingleTickerProviderStateMixin,
        AfterLayoutMixin,
        WidgetsBindingObserver {
  final List<String> _tabs = ['Servers', 'En/Decode'];
  late final TabController _tabController;
  late final ServerProvider _serverProvider;

  @override
  void initState() {
    super.initState();
    _serverProvider = locator<ServerProvider>();
    WidgetsBinding.instance?.addObserver(this);
    _tabController = TabController(length: _tabs.length, vsync: this);
  }

  @override
  void dispose() {
    super.dispose();
    WidgetsBinding.instance?.removeObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.paused) {
      _serverProvider.stopAutoRefresh();
    }
    if (state == AppLifecycleState.resumed) {
      _serverProvider.startAutoRefresh();
    }
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
          child: const Text(BuildData.name),
        ),
        bottom: TabBar(
          indicatorColor: widget.primaryColor,
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
            accountName: const Text(BuildData.name),
            accountEmail: Text(_buildVersionStr()),
            currentAccountPicture: _buildIcon(),
          ),
          ListTile(
            leading: const Icon(Icons.settings),
            title: const Text('Setting'),
            onTap: () => AppRoute(const SettingPage(), 'Setting').go(context),
          ),
          ListTile(
            leading: const Icon(Icons.vpn_key),
            title: const Text('Private Key'),
            onTap: () =>
                AppRoute(const StoredPrivateKeysPage(), 'private key list')
                    .go(context),
          ),
          ListTile(
            leading: const Icon(Icons.snippet_folder),
            title: const Text('Snippet'),
            onTap: () =>
                AppRoute(const SnippetListPage(), 'snippet list').go(context),
          ),
          AboutListTile(
            icon: const Icon(Icons.text_snippet),
            child: const Text('Licences'),
            applicationName: BuildData.name,
            applicationVersion: _buildVersionStr(),
            applicationIcon: _buildIcon(),
            aboutBoxChildren: const [
              UrlText(
                  text: '\nMade with ❤️ by $myGithub', replace: 'LollipopKit'),
              UrlText(
                text:
                    '\nThanks $rainSunMeGithub for participating in the test.\n\nAll rights reserved.',
                replace: 'RainSunMe',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildIcon() {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 60, maxWidth: 60),
      child: appIcon,
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
    if (BuildMode.isRelease) {
      await Analysis.init(false);
    }
  }
}
