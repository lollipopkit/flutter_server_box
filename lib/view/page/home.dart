import 'package:after_layout/after_layout.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/l10n.dart';
import 'package:get_it/get_it.dart';
import 'package:toolbox/data/model/app/tab.dart';
import 'package:toolbox/data/provider/app.dart';
import 'package:toolbox/data/res/misc.dart';
import 'package:toolbox/view/widget/round_rect_card.dart';
import 'package:toolbox/view/widget/value_notifier.dart';

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
import 'private_key/list.dart';
import 'setting.dart';
import 'sftp/local.dart';

class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage>
    with
        AutomaticKeepAliveClientMixin,
        AfterLayoutMixin,
        WidgetsBindingObserver {
  final _serverProvider = locator<ServerProvider>();
  final _setting = locator<SettingStore>();

  late final PageController _pageController;

  final _selectIndex = ValueNotifier(0);
  late S _s;

  @override
  void initState() {
    super.initState();
    switchStatusBar(hide: false);
    WidgetsBinding.instance.addObserver(this);
    _selectIndex.value = _setting.launchPage.fetch()!;
    // avoid index out of range
    if (_selectIndex.value >= AppTab.values.length || _selectIndex.value < 0) {
      _selectIndex.value = 0;
    }
    _pageController = PageController(initialPage: _selectIndex.value);
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
        title: const Text(BuildData.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.developer_mode, size: 23),
            tooltip: _s.debug,
            onPressed: () => AppRoute(
              const DebugPage(),
              'Debug Page',
            ).go(context),
          ),
        ],
      ),
      body: PageView.builder(
        physics: const NeverScrollableScrollPhysics(),
        controller: _pageController,
        itemBuilder: (_, index) => AppTab.values[index].page,
      ),
      bottomNavigationBar:
          ValueBuilder(listenable: _selectIndex, build: _buildBottomBar),
    );
  }

  Widget _buildBottomBar() {
    return NavigationBar(
      selectedIndex: _selectIndex.value,
      animationDuration: const Duration(milliseconds: 250),
      onDestinationSelected: (int index) {
        _selectIndex.value = index;
        _pageController.animateToPage(
          index,
          duration: const Duration(milliseconds: 677),
          curve: Curves.fastLinearToSlowEaseIn,
        );
      },
      labelBehavior: NavigationDestinationLabelBehavior.onlyShowSelected,
      destinations: [
        NavigationDestination(
          icon: const Icon(Icons.cloud_outlined),
          label: _s.server,
          selectedIcon: const Icon(Icons.cloud),
        ),
        NavigationDestination(
          icon: const Icon(Icons.snippet_folder_outlined),
          label: _s.snippet,
          selectedIcon: const Icon(Icons.snippet_folder),
        ),
        const NavigationDestination(
          icon: Icon(Icons.network_check_outlined),
          label: 'Ping',
          selectedIcon: Icon(Icons.network_check),
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
          const SizedBox(height: 37),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 17),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.settings),
                  title: Text(_s.setting),
                  onTap: () => AppRoute(
                    const SettingPage(),
                    'Setting',
                  ).go(context),
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
                  onTap: () => AppRoute(
                    const SFTPDownloadedPage(),
                    'sftp local page',
                  ).go(context),
                ),
                ListTile(
                  leading: const Icon(Icons.import_export),
                  title: Text(_s.backup),
                  onTap: () => AppRoute(
                    BackupPage(),
                    'backup page',
                  ).go(context),
                ),
                ListTile(
                  leading: const Icon(Icons.code),
                  title: Text(_s.convert),
                  onTap: () => AppRoute(
                    const ConvertPage(),
                    'convert page',
                  ).go(context),
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
                          onPressed: () => openUrl(appHelpUrl),
                          child: Text(_s.feedback),
                        ),
                        TextButton(
                          onPressed: () => showLicensePage(context: context),
                          child: Text(_s.license),
                        ),
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
    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 57, maxWidth: 57),
      child: appIcon,
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
