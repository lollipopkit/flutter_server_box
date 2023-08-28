import 'dart:convert';

import 'package:after_layout/after_layout.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/l10n.dart';
import 'package:get_it/get_it.dart';
import 'package:toolbox/core/extension/context.dart';
import 'package:toolbox/data/model/app/github_id.dart';
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
import '../widget/custom_appbar.dart';
import '../widget/url_text.dart';

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
  final _app = locator<AppProvider>();

  late final PageController _pageController;

  final _selectIndex = ValueNotifier(0);
  late S _s;

  bool _switchingPage = false;

  @override
  void initState() {
    super.initState();
    switchStatusBar(hide: false);
    WidgetsBinding.instance.addObserver(this);
    _selectIndex.value = _setting.launchPage.fetch();
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
    _pageController.dispose();
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
        updateHomeWidget();
        break;
      case AppLifecycleState.paused:
        // Keep running in background on Android device
        if (isAndroid && _setting.bgRun.fetch()) {
          if (_app.moveBg) {
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
      appBar: _buildAppBar(),
      body: PageView.builder(
        controller: _pageController,
        itemCount: AppTab.values.length,
        itemBuilder: (_, index) => AppTab.values[index].page,
        onPageChanged: (value) {
          if (!_switchingPage) {
            _selectIndex.value = value;
          }
        },
      ),
      bottomNavigationBar: ValueBuilder(
        listenable: _selectIndex,
        build: _buildBottomBar,
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    final actions = <Widget>[
      IconButton(
        icon: const Icon(Icons.developer_mode, size: 23),
        tooltip: _s.debug,
        onPressed: () => AppRoute.debug().go(context),
      ),
    ];
    if (isDesktop && _selectIndex.value == AppTab.server.index) {
      actions.add(
        ValueBuilder(
          listenable: _selectIndex,
          build: () {
            if (_selectIndex.value != AppTab.server.index) {
              return const SizedBox();
            }
            return IconButton(
              icon: const Icon(Icons.refresh, size: 23),
              tooltip: 'Refresh',
              onPressed: () => _serverProvider.refreshData(onlyFailed: true),
            );
          },
        ),
      );
    }
    return CustomAppBar(
      title: const Text(BuildData.name),
      actions: actions,
    );
  }

  Widget _buildBottomBar() {
    return NavigationBar(
      selectedIndex: _selectIndex.value,
      height: kBottomNavigationBarHeight * 1.2,
      animationDuration: const Duration(milliseconds: 250),
      onDestinationSelected: (int index) {
        if (_selectIndex.value == index) return;
        _selectIndex.value = index;
        _switchingPage = true;
        _pageController.animateToPage(
          index,
          duration: const Duration(milliseconds: 677),
          curve: Curves.fastLinearToSlowEaseIn,
        );
        Future.delayed(const Duration(milliseconds: 677), () {
          _switchingPage = false;
        });
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
          _buildTiles(),
        ],
      ),
    );
  }

  Widget _buildTiles() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 17),
      child: Column(
        children: [
          ListTile(
            leading: const Icon(Icons.settings),
            title: Text(_s.setting),
            onTap: () => AppRoute.setting().go(context),
            onLongPress: _onLongPressSetting,
          ),
          ListTile(
            leading: const Icon(Icons.vpn_key),
            title: Text(_s.privateKey),
            onTap: () => AppRoute.keyList().go(context),
          ),
          ListTile(
            leading: const Icon(Icons.file_open),
            title: Text(_s.files),
            onTap: () => AppRoute.localStorage().go(context),
          ),
          ListTile(
            leading: const Icon(Icons.code),
            title: Text(_s.convert),
            onTap: () => AppRoute.convert().go(context),
          ),
          ListTile(
            leading: const Icon(Icons.import_export),
            title: Text(_s.backupAndRestore),
            onTap: () => AppRoute.backup().go(context),
          ),
          ListTile(
            leading: const Icon(Icons.text_snippet),
            title: Text('${_s.about} & ${_s.feedback}'),
            onTap: _showAboutDialog,
          )
        ].map((e) => RoundRectCard(e)).toList(),
      ),
    );
  }

  void _showAboutDialog() {
    showRoundDialog(
      context: context,
      title: Text(_s.about),
      child: _buildAboutContent(),
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
  }

  Widget _buildAboutContent() {
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          UrlText(
            text: _s.madeWithLove(myGithub),
            replace: 'lollipopkit',
          ),
          height13,
          // Use [UrlText] for same text style
          Text(_s.aboutThanks),
          height13,
          const Text('Contributors:'),
          ...contributors.map(
            (name) => UrlText(
              text: name.url,
              replace: name,
            ),
          ),
          height13,
          const Text('Participants:'),
          ...participants.map(
            (name) => UrlText(
              text: name.url,
              replace: name,
            ),
          )
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
    if (_setting.autoCheckAppUpdate.fetch()) {
      doUpdate(context);
    }
    updateHomeWidget();
    await GetIt.I.allReady();
    await _serverProvider.loadLocalData();
    await _serverProvider.refreshData();
    if (!Analysis.enabled) {
      Analysis.init();
    }
  }

  void updateHomeWidget() {
    if (_setting.autoUpdateHomeWidget.fetch()) {
      homeWidgetChannel.invokeMethod('update');
    }
  }

  Future<void> _onLongPressSetting() async {
    final go = await showRoundDialog(
      context: context,
      title: Text(_s.attention),
      child: Text(_s.atOwnRisk),
      actions: [
        TextButton(
          onPressed: () => context.pop(true),
          child: Text(
            _s.ok,
            style: const TextStyle(color: Colors.red),
          ),
        ),
      ],
    );
    if (go != true) {
      return;
    }

    /// Encode [map] to String with indent `\t`
    final map = _setting.toJson();
    final text = jsonEncoder.convert(map);
    final result = await AppRoute.editor(
      text: text,
      langCode: 'json',
    ).go(context);
    if (result == null) {
      return;
    }
    _setting.box.putAll(json.decode(result) as Map<String, dynamic>);
  }
}
