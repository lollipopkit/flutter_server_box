import 'package:after_layout/after_layout.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/l10n.dart';
import 'package:get_it/get_it.dart';
import 'package:toolbox/core/utils/navigator.dart';
import 'package:toolbox/data/provider/app.dart';
import 'package:toolbox/data/res/misc.dart';
import 'package:toolbox/view/widget/round_rect_card.dart';

import '../../core/analysis.dart';
import '../../core/route.dart';
import '../../core/update.dart';
import '../../core/utils/platform.dart';
import '../../core/utils/ui.dart';
import '../../data/provider/server.dart';
import '../../data/res/build_data.dart';
import '../../data/res/ui.dart';
import '../../data/res/url.dart';
import '../../data/store/setting.dart';
import '../../locator.dart';
import '../widget/url_text.dart';
import 'backup.dart';
import 'convert.dart';
import 'debug.dart';
import 'ping.dart';
import 'private_key/list.dart';
import 'server/tab.dart';
import 'setting.dart';
import 'sftp/downloaded.dart';
import 'snippet/list.dart';

class MyHomePage extends StatefulWidget {
  const MyHomePage({Key? key}) : super(key: key);

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage>
    with
        AutomaticKeepAliveClientMixin,
        AfterLayoutMixin,
        WidgetsBindingObserver {
  final _serverProvider = locator<ServerProvider>();
  final _setting = locator<SettingStore>();

  late final PageController _pageController;

  late int _selectIndex;
  late S _s;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _selectIndex = _setting.launchPage.fetch()!;
    _pageController = PageController(initialPage: _selectIndex);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _s = S.of(context)!;
  }

  @override
  void dispose() {
    super.dispose();
    WidgetsBinding.instance.removeObserver(this);
    _serverProvider.closeServer();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (isDesktop) return;

    switch (state) {
      case AppLifecycleState.resumed:
        if (!_serverProvider.isAutoRefreshOn) {
          _serverProvider.startAutoRefresh();
        }
        break;
      case AppLifecycleState.paused:
        // Keep running in background on Android device
        if (isAndroid && _setting.bgRun.fetch()!) {
          if (locator<AppProvider>().moveBg) {
            bgRunChannel.invokeMethod('sendToBackground');
          }
        } else {
          _serverProvider.setDisconnected();
          _serverProvider.stopAutoRefresh();
        }
        break;
      default:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      drawer: _buildDrawer(),
      appBar: AppBar(
        title: Text(tabTitleName(context, _selectIndex)),
        actions: [
          IconButton(
            icon: const Icon(Icons.developer_mode, size: 23),
            tooltip: _s.debug,
            onPressed: () =>
                AppRoute(const DebugPage(), 'Debug Page').go(context),
          ),
        ],
      ),
      body: PageView(
        physics: const ClampingScrollPhysics(),
        controller: _pageController,
        onPageChanged: (index) {
          setState(() {
            _selectIndex = index;
            FocusScope.of(context).requestFocus(FocusNode());
          });
        },
        children: const [ServerPage(), ConvertPage(), PingPage()],
      ),
      bottomNavigationBar: _buildBottomBar(context),
    );
  }

  Widget _buildBottomBar(BuildContext context) {
    return NavigationBar(
      selectedIndex: _selectIndex,
      animationDuration: const Duration(milliseconds: 250),
      onDestinationSelected: (int index) {
        setState(() {
          _selectIndex = index;
          _pageController.animateToPage(
            index,
            duration: const Duration(milliseconds: 677),
            curve: Curves.fastLinearToSlowEaseIn,
          );
        });
      },
      elevation: 0.47,
      labelBehavior: NavigationDestinationLabelBehavior.onlyShowSelected,
      destinations: [
        NavigationDestination(
          icon: const Icon(Icons.cloud_outlined),
          label: _s.server,
          selectedIcon: const Icon(Icons.cloud),
        ),
        NavigationDestination(
          icon: const Icon(Icons.code),
          label: _s.convert,
        ),
        NavigationDestination(
          icon: const Icon(Icons.leak_add),
          label: _s.ping,
        ),
      ],
    );
  }

  Widget _buildDrawer() {
    return Drawer(
      surfaceTintColor: Theme.of(context).scaffoldBackgroundColor,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildIcon(),
          TextButton(
            onPressed: () => showRoundDialog(
              context: context,
              title: Text(_versionStr),
              child: const Text(BuildData.buildAt),
            ),
            child: Text(
              '${BuildData.name}\n$_versionStr',
              textAlign: TextAlign.center,
              style: textSize13,
            ),
          ),
          SizedBox(
            height: MediaQuery.of(context).size.height * 0.07,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 17),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.settings),
                  title: Text(_s.setting),
                  onTap: () =>
                      AppRoute(const SettingPage(), 'Setting').go(context),
                ),
                ListTile(
                  leading: const Icon(Icons.vpn_key),
                  title: Text(_s.privateKey),
                  onTap: () => AppRoute(
                    const PrivateKeysListPage(),
                    'private key list',
                  ).go(context),
                ),
                ListTile(
                  leading: const Icon(Icons.download),
                  title: Text(_s.download),
                  onTap: () =>
                      AppRoute(const SFTPDownloadedPage(), 'snippet list')
                          .go(context),
                ),
                ListTile(
                  leading: const Icon(Icons.import_export),
                  title: Text(_s.backup),
                  onTap: () =>
                      AppRoute(BackupPage(), 'backup page').go(context),
                ),
                ListTile(
                  leading: const Icon(Icons.snippet_folder),
                  title: Text(_s.snippet),
                  onTap: () => AppRoute(const SnippetListPage(), 'snippet list')
                      .go(context),
                ),
                ListTile(
                  leading: const Icon(Icons.text_snippet),
                  title: Text('${_s.about} & ${_s.feedback}'),
                  onTap: () {
                    showRoundDialog(
                      context: context,
                      title: Text(_s.about),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          UrlText(
                              text: _s.madeWithLove(myGithub),
                              replace: 'lollipopkit'),
                          UrlText(
                            text: _s.aboutThanks,
                          ),
                          // Thanks
                          ...thanksMap.keys.map(
                            (key) => UrlText(
                              text: thanksMap[key] ?? '',
                              replace: key,
                            ),
                          )
                        ],
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => openUrl(issueUrl),
                          child: Text(_s.feedback),
                        ),
                        TextButton(
                          onPressed: () => showLicensePage(context: context),
                          child: Text(_s.license),
                        ),
                        TextButton(
                          onPressed: () => context.pop(),
                          child: Text(_s.close),
                        )
                      ],
                    );
                  },
                )
              ].map((e) => RoundRectCard(e)).toList(),
            ),
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
            color: Colors.white,
          ),
        ),
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 83, maxWidth: 83),
          child: appIcon,
        )
      ],
    );
  }

  String get _versionStr {
    var mod = '';
    if (BuildData.modifications != 0) {
      mod = '(+${BuildData.modifications})';
    }
    return 'Ver: 1.0.${BuildData.build}$mod';
  }

  @override
  bool get wantKeepAlive => true;

  @override
  Future<void> afterFirstLayout(BuildContext context) async {
    await GetIt.I.allReady();
    await _serverProvider.loadLocalData();
    await _serverProvider.refreshData();
    await doUpdate(context);
    if (!Analysis.enabled) {
      await Analysis.init();
    }
  }
}
