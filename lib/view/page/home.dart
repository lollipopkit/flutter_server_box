import 'package:after_layout/after_layout.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get_it/get_it.dart';
import 'package:toolbox/core/analysis.dart';
import 'package:toolbox/core/route.dart';
import 'package:toolbox/core/update.dart';
import 'package:toolbox/core/utils.dart';
import 'package:toolbox/data/model/app/navigation_item.dart';
import 'package:toolbox/data/provider/server.dart';
import 'package:toolbox/data/res/build_data.dart';
import 'package:toolbox/data/res/color.dart';
import 'package:toolbox/data/res/font_style.dart';
import 'package:toolbox/data/res/icon.dart';
import 'package:toolbox/data/res/tab.dart';
import 'package:toolbox/data/res/url.dart';
import 'package:toolbox/data/store/setting.dart';
import 'package:toolbox/generated/l10n.dart';
import 'package:toolbox/locator.dart';
import 'package:toolbox/view/page/backup.dart';
import 'package:toolbox/view/page/convert.dart';
import 'package:toolbox/view/page/debug.dart';
import 'package:toolbox/view/page/ping.dart';
import 'package:toolbox/view/page/private_key/list.dart';
import 'package:toolbox/view/page/server/tab.dart';
import 'package:toolbox/view/page/setting.dart';
import 'package:toolbox/view/page/sftp/downloaded.dart';
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
        AfterLayoutMixin,
        WidgetsBindingObserver {
  late final ServerProvider _serverProvider;
  late final PageController _pageController;
  late int _selectIndex;
  late double _width;
  late S _s;

  @override
  void initState() {
    super.initState();
    _serverProvider = locator<ServerProvider>();
    WidgetsBinding.instance.addObserver(this);
    _selectIndex = locator<SettingStore>().launchPage.fetch()!;
    _pageController = PageController(initialPage: _selectIndex);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _s = S.of(context);
    _width = MediaQuery.of(context).size.width;
  }

  @override
  void dispose() {
    super.dispose();
    WidgetsBinding.instance.removeObserver(this);
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
    super.build(context);
    return Scaffold(
      drawer: _buildDrawer(),
      appBar: AppBar(
        title: Text(tabTitleName(context, _selectIndex), style: textSize18),
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
        onPageChanged: (i) {
          FocusScope.of(context).requestFocus(FocusNode());
          _selectIndex = i;
          setState(() {});
        },
        children: const [ServerPage(), ConvertPage(), PingPage()],
      ),
      bottomNavigationBar: _buildBottom(context),
    );
  }

  Widget _buildItem(int idx, NavigationItem item, bool isSelected) {
    final width = _width / tabItems.length;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 377),
      curve: Curves.fastOutSlowIn,
      height: 50,
      width: isSelected ? width : width - 17,
      decoration: BoxDecoration(
        color: isSelected
            ? isDarkMode(context)
                ? Colors.white12
                : Colors.black.withOpacity(0.07)
            : Colors.transparent,
        borderRadius: const BorderRadius.all(
          Radius.circular(50),
        ),
      ),
      child: IconButton(
        icon: Icon(item.icon),
        tooltip: tabTitleName(context, idx),
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
          children: tabItems.map(
            (item) {
              int itemIndex = tabItems.indexOf(item);
              return _buildItem(itemIndex, item, _selectIndex == itemIndex);
            },
          ).toList(),
        ),
      ),
    );
  }

  Widget _buildDrawer() {
    return Drawer(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildIcon(),
          const Text(BuildData.name),
          Text(_versionStr),
          SizedBox(
            height: MediaQuery.of(context).size.height * 0.07,
          ),
          Padding(
            padding: const EdgeInsets.only(left: 29),
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
                          const StoredPrivateKeysPage(), 'private key list')
                      .go(context),
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
                  leading: const Icon(Icons.info),
                  title: Text(_s.feedback),
                  onTap: () => showRoundDialog(
                    context,
                    _s.feedback,
                    Text(_s.feedbackOnGithub),
                    [
                      TextButton(
                        onPressed: () => Clipboard.setData(
                            const ClipboardData(text: issueUrl)),
                        child: Text(_s.copy),
                      ),
                      TextButton(
                        onPressed: () => openUrl(issueUrl),
                        child: Text(_s.feedback),
                      ),
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: Text(_s.close),
                      )
                    ],
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.snippet_folder),
                  title: Text(_s.snippet),
                  onTap: () => AppRoute(const SnippetListPage(), 'snippet list')
                      .go(context),
                ),
                AboutListTile(
                  icon: const Icon(Icons.text_snippet),
                  applicationName: BuildData.name,
                  applicationVersion: _versionStr,
                  applicationIcon: _buildIcon(),
                  aboutBoxChildren: [
                    UrlText(
                        text: _s.madeWithLove(myGithub),
                        replace: 'lollipopkit'),
                    UrlText(
                      text: _s.aboutThanks,
                    ),
                    const UrlText(
                      text: rainSunMeGithub,
                      replace: 'RainSunMe',
                    ),
                    const UrlText(
                      text: fectureGithub,
                      replace: 'fecture',
                    )
                  ],
                  child: Text(_s.license),
                )
              ],
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
            color: primaryColor,
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
    await locator<ServerProvider>().loadLocalData();
    await doUpdate(context);
    await Analysis.init();
  }
}
