import 'dart:convert';

import 'package:after_layout/after_layout.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/l10n.dart';
import 'package:get_it/get_it.dart';
import 'package:toolbox/core/channel/bg_run.dart';
import 'package:toolbox/core/channel/home_widget.dart';
import 'package:toolbox/core/extension/context/dialog.dart';
import 'package:toolbox/core/extension/context/locale.dart';
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
import '../widget/cardx.dart';
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
    l10n = S.of(context)!;
  }

  @override
  void dispose() {
    super.dispose();
    WidgetsBinding.instance.removeObserver(this);
    Pros.server.closeServer();
    _pageController.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (isDesktop) return;

    switch (state) {
      case AppLifecycleState.resumed:
        _auth();
        if (!Pros.server.isAutoRefreshOn) {
          Pros.server.startAutoRefresh();
        }
        updateHomeWidget();
        break;
      case AppLifecycleState.paused:
        // Keep running in background on Android device
        if (isAndroid && Stores.setting.bgRun.fetch()) {
          if (Pros.app.moveBg) {
            BgRunMC.moveToBg();
          }
        } else {
          //Pros.server.setDisconnected();
          Pros.server.stopAutoRefresh();
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
      appBar: CustomAppBar(
        title: const Text(BuildData.name),
        actions: <Widget>[
          IconButton(
            icon: const Icon(Icons.developer_mode, size: 23),
            tooltip: l10n.debug,
            onPressed: () => AppRoute.debug().go(context),
          ),
        ],
      ),
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
          label: l10n.server,
          selectedIcon: const Icon(Icons.cloud),
        ),
        const NavigationDestination(
          icon: Icon(Icons.terminal_outlined),
          label: 'SSH',
          selectedIcon: Icon(Icons.terminal),
        ),
        NavigationDestination(
          icon: const Icon(Icons.snippet_folder_outlined),
          label: l10n.snippet,
          selectedIcon: const Icon(Icons.snippet_folder),
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
            title: Text(l10n.setting),
            onTap: () => AppRoute.settings().go(context),
            onLongPress: _onLongPressSetting,
          ),
          ListTile(
            leading: const Icon(Icons.vpn_key),
            title: Text(l10n.privateKey),
            onTap: () => AppRoute.keyList().go(context),
          ),
          ListTile(
            leading: const Icon(Icons.file_open),
            title: Text(l10n.files),
            onTap: () => AppRoute.localStorage().go(context),
          ),
          ListTile(
            leading: const Icon(Icons.import_export),
            title: Text(l10n.backupAndRestore),
            onTap: () => AppRoute.backup().go(context),
          ),
          ListTile(
            leading: const Icon(Icons.text_snippet),
            title: Text('${l10n.about} & ${l10n.feedback}'),
            onTap: _showAboutDialog,
          )
        ].map((e) => CardX(e)).toList(),
      ),
    );
  }

  void _showAboutDialog() {
    context.showRoundDialog(
      title: Text(l10n.about),
      child: _buildAboutContent(),
      actions: [
        TextButton(
          onPressed: () => openUrl(Urls.appWiki),
          child: const Text('Wiki'),
        ),
        TextButton(
          onPressed: () => openUrl(Urls.appHelp),
          child: Text(l10n.feedback),
        ),
        TextButton(
          onPressed: () => showLicensePage(context: context),
          child: Text(l10n.license),
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
            text: l10n.madeWithLove(Urls.myGithub),
            replace: 'lollipopkit',
          ),
          UIs.height13,
          // Use [UrlText] for same text style
          Text(l10n.aboutThanks),
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
    await Pros.server.load();
    await Pros.server.refreshData();
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
      title: l10n.setting,
    ).go<String>(context);
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
        title: Text(l10n.error),
        child: Text('${l10n.save}:\n$e'),
      );
      Loggers.app.warning('Update json settings failed', e, trace);
    }
  }

  void _auth() {
    if (Stores.setting.useBioAuth.fetch()) {
      if (!_isAuthing) {
        _isAuthing = true;
        BioAuth.auth(l10n.authRequired).then(
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
