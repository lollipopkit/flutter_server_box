import 'package:after_layout/after_layout.dart';
import 'package:flutter/material.dart';
import 'package:flutter_advanced_drawer/flutter_advanced_drawer.dart';
import 'package:get_it/get_it.dart';
import 'package:toolbox/core/analysis.dart';
import 'package:toolbox/core/build_mode.dart';
import 'package:toolbox/core/route.dart';
import 'package:toolbox/core/update.dart';
import 'package:toolbox/core/utils.dart';
import 'package:toolbox/data/model/app/navigation_item.dart';
import 'package:toolbox/data/provider/server.dart';
import 'package:toolbox/data/res/build_data.dart';
import 'package:toolbox/data/res/color.dart';
import 'package:toolbox/data/res/icon/common.dart';
import 'package:toolbox/data/res/tab.dart';
import 'package:toolbox/data/res/url.dart';
import 'package:toolbox/data/store/setting.dart';
import 'package:toolbox/locator.dart';
import 'package:toolbox/view/page/convert.dart';
import 'package:toolbox/view/page/debug.dart';
import 'package:toolbox/view/page/ping.dart';
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
  late final ServerProvider _serverProvider;
  late final PageController _pageController;
  late final AdvancedDrawerController _advancedDrawerController;
  late int _selectIndex;
  late double _width;

  @override
  void initState() {
    super.initState();
    _serverProvider = locator<ServerProvider>();
    WidgetsBinding.instance?.addObserver(this);
    _selectIndex = locator<SettingStore>().launchPage.fetch()!;
    _pageController = PageController(initialPage: _selectIndex);
    _advancedDrawerController = AdvancedDrawerController();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _width = MediaQuery.of(context).size.width;
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
      _serverProvider.setDisconnected();
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
    return WillPopScope(
        child: _buildMain(context),
        onWillPop: () {
          if (_advancedDrawerController.value.visible) {
            _advancedDrawerController.hideDrawer();
            return Future.value(false);
          }
          return Future.value(true);
        });
  }

  Widget _buildMain(BuildContext context) {
    return AdvancedDrawer(
        controller: _advancedDrawerController,
        animationCurve: Curves.easeInOutCirc,
        animationDuration: const Duration(milliseconds: 300),
        animateChildDecoration: true,
        rtlOpening: false,
        disabledGestures: true,
        childDecoration: const BoxDecoration(
          // NOTICE: Uncomment if you want to add shadow behind the page.
          // Keep in mind that it may cause animation jerks.
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: Colors.black12,
              blurRadius: 0.0,
            ),
          ],
          borderRadius: BorderRadius.all(Radius.circular(16)),
        ),
        drawer: _buildDrawer(),
        child: Scaffold(
          appBar: AppBar(
            title: Text(tabItems[_selectIndex].title),
            actions: [
              IconButton(
                icon: const Icon(Icons.developer_mode, size: 23),
                tooltip: 'Debug',
                onPressed: () =>
                    AppRoute(const DebugPage(), 'Debug Page').go(context),
              ),
            ],
            leading: IconButton(
              onPressed: () => _advancedDrawerController.showDrawer(),
              icon: ValueListenableBuilder<AdvancedDrawerValue>(
                valueListenable: _advancedDrawerController,
                builder: (_, value, __) {
                  return AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),
                    child: Icon(
                      value.visible ? Icons.clear : Icons.menu,
                      key: ValueKey<bool>(value.visible),
                    ),
                  );
                },
              ),
            ),
          ),
          body: PageView(
            physics: const ClampingScrollPhysics(),
            controller: _pageController,
            onPageChanged: (i) {
              FocusScope.of(context).unfocus();
              _selectIndex = i;
              setState(() {});
            },
            children: const [ServerPage(), ConvertPage(), PingPage()],
          ),
          bottomNavigationBar: _buildBottom(context),
        ));
  }

  Widget _buildItem(int idx, NavigationItem item, bool isSelected) {
    bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final width = _width / tabItems.length;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 377),
      curve: Curves.fastOutSlowIn,
      height: 50,
      width: isSelected ? width : width - 17,
      decoration: BoxDecoration(
          color: isSelected
              ? isDarkMode
                  ? Colors.white12
                  : Colors.black.withOpacity(0.07)
              : Colors.transparent,
          borderRadius: const BorderRadius.all(Radius.circular(50))),
      child: IconButton(
        icon: Icon(item.icon),
        tooltip: item.title,
        splashRadius: width / 3.3,
        padding: const EdgeInsets.only(left: 17, right: 17),
        onPressed: () {
          setState(() {
            _pageController.animateToPage(idx,
                duration: const Duration(milliseconds: 677),
                curve: Curves.fastLinearToSlowEaseIn);
          });
        },
      ),
    );
  }

  Widget _buildBottom(BuildContext context) {
    return SafeArea(
        child: Container(
      height: 56,
      padding: const EdgeInsets.only(left: 8, top: 4, bottom: 4, right: 8),
      width: _width,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: tabItems.map((item) {
          int itemIndex = tabItems.indexOf(item);
          return _buildItem(itemIndex, item, _selectIndex == itemIndex);
        }).toList(),
      ),
    ));
  }

  Widget _buildDrawer() {
    return SafeArea(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildIcon(),
          const Text(BuildData.name),
          Text(_buildVersionStr()),
          SizedBox(
            height: MediaQuery.of(context).size.height * 0.07,
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
    return Stack(
      alignment: Alignment.center,
      children: [
        ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 53, maxWidth: 53),
            child: Container(
              color: primaryColor,
            )),
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 83, maxWidth: 83),
          child: appIcon,
        )
      ],
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
