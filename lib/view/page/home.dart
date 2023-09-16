import 'dart:convert';

import 'package:after_layout/after_layout.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/l10n.dart';
import 'package:get_it/get_it.dart';
import 'package:toolbox/core/channel/bg_run.dart';
import 'package:toolbox/core/channel/home_widget.dart';
import 'package:toolbox/core/extension/context/dialog.dart';
import 'package:toolbox/core/utils/platform/auth.dart';
import 'package:toolbox/core/utils/platform/base.dart';
import 'package:toolbox/data/res/github_id.dart';
import 'package:toolbox/data/res/logger.dart';
import 'package:toolbox/data/res/provider.dart';
import 'package:toolbox/data/res/store.dart';

import '../../core/analysis.dart';
import '../../core/route.dart';
import '../../core/update.dart';
import '../../core/utils/ui.dart';
import '../../data/model/app/github_id.dart';
import '../../data/model/app/tab.dart';
import '../../data/res/build_data.dart';
import '../../data/res/misc.dart';
import '../../data/res/ui.dart';
import '../../data/res/url.dart';
import '../widget/custom_appbar.dart';
import '../widget/round_rect_card.dart';
import '../widget/url_text.dart';
import '../widget/value_notifier.dart';

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
  late final PageController _pageController;

  final _selectIndex = ValueNotifier(0);
  late S _s;

  bool _switchingPage = false;
  bool _isAuthing = false;

  @override
  void initState() {
    super.initState();
    switchStatusBar(hide: false);
    WidgetsBinding.instance.addObserver(this);
    _selectIndex.value = Stores.setting.launchPage.fetch();
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
    Providers.server.closeServer();
    _pageController.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (isDesktop) return;

    switch (state) {
      case AppLifecycleState.resumed:
        _auth();
        if (!Providers.server.isAutoRefreshOn) {
          Providers.server.startAutoRefresh();
        }
        updateHomeWidget();
        break;
      case AppLifecycleState.paused:
        // Keep running in background on Android device
        if (isAndroid && Stores.setting.bgRun.fetch()) {
          if (Providers.app.moveBg) {
            BgRunMC.moveToBg();
          }
        } else {
          Providers.server.setDisconnected();
          Providers.server.stopAutoRefresh();
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
              onPressed: () => Providers.server.refreshData(onlyFailed: true),
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
            onPressed: () => context.showRoundDialog(
              title: Text(_versionStr),
              child: const Text(
                  '${BuildData.buildAt}\nFlutter ${BuildData.engine}'),
            ),
            child: Text(
              '${BuildData.name}\n$_versionStr',
              textAlign: TextAlign.center,
              style: UIs.textSize13,
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
    context.showRoundDialog(
      title: Text(_s.about),
      child: _buildAboutContent(),
      actions: [
        TextButton(
          onPressed: () => openUrl(Urls.appWiki),
          child: const Text('Wiki'),
        ),
        TextButton(
          onPressed: () => openUrl(Urls.appHelp),
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
            text: _s.madeWithLove(Urls.myGithub),
            replace: 'lollipopkit',
          ),
          UIs.height13,
          // Use [UrlText] for same text style
          Text(_s.aboutThanks),
          UIs.height13,
          const Text('Contributors:'),
          ...GithubIds.contributors.map(
            (name) => UrlText(
              text: name.url,
              replace: name,
            ),
          ),
          UIs.height13,
          const Text('Participants:'),
          ...GithubIds.participants.map(
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
      child: UIs.appIcon,
    );
  }

  String get _versionStr {
    var mod = '';
    if (BuildData.modifications != 0) {
      mod = '(+${BuildData.modifications})';
    }
    return 'v1.0.${BuildData.build}$mod';
  }

  @override
  bool get wantKeepAlive => true;

  @override
  Future<void> afterFirstLayout(BuildContext context) async {
    // Auth required for first launch
    _auth();
    if (Stores.setting.autoCheckAppUpdate.fetch()) {
      doUpdate(context);
    }
    updateHomeWidget();
    await GetIt.I.allReady();
    await Providers.server.loadLocalData();
    await Providers.server.refreshData();
    if (!Analysis.enabled) {
      Analysis.init();
    }
  }

  void updateHomeWidget() {
    if (Stores.setting.autoUpdateHomeWidget.fetch()) {
      HomeWidgetMC.update();
    }
  }

  Future<void> _onLongPressSetting() async {
    final map = Stores.setting.toJson();
    final keys = map.keys;

    /// Encode [map] to String with indent `\t`
    final text = Miscs.jsonEncoder.convert(map);
    final result = await AppRoute.editor(
      text: text,
      langCode: 'json',
      title: _s.setting,
    ).go(context);
    if (result == null) {
      return;
    }
    try {
      final newSettings = json.decode(result) as Map<String, dynamic>;
      Stores.setting.box.putAll(newSettings);
      final newKeys = newSettings.keys;
      final removedKeys = keys.where((e) => !newKeys.contains(e));
      for (final key in removedKeys) {
        Stores.setting.box.delete(key);
      }
    } catch (e, trace) {
      context.showRoundDialog(
        title: Text(_s.error),
        child: Text('${_s.save}:\n$e'),
      );
      Loggers.app.warning('Update json settings failed', e, trace);
    }
  }

  void _auth() {
    if (Stores.setting.useBioAuth.fetch()) {
      if (!_isAuthing) {
        _isAuthing = true;
        BioAuth.auth(_s.authRequired).then(
          (val) {
            switch (val) {
              case AuthResult.success:
                // wait for animation
                Future.delayed(
                    const Duration(seconds: 1), () => _isAuthing = false);
                break;
              case AuthResult.fail:
              case AuthResult.cancel:
                _isAuthing = false;
                _auth();
                break;
              case AuthResult.notAvail:
                _isAuthing = false;
                Stores.setting.useBioAuth.put(false);
                break;
            }
          },
        );
      }
    }
  }
}
