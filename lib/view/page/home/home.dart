import 'dart:convert';

import 'package:after_layout/after_layout.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/l10n.dart';
import 'package:get_it/get_it.dart';
import 'package:icons_plus/icons_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:toolbox/core/channel/bg_run.dart';
import 'package:toolbox/core/channel/home_widget.dart';
import 'package:toolbox/core/extension/build.dart';
import 'package:toolbox/core/extension/context/common.dart';
import 'package:toolbox/core/extension/context/dialog.dart';
import 'package:toolbox/core/extension/context/locale.dart';
import 'package:toolbox/core/persistant_store.dart';
import 'package:toolbox/core/route.dart';
import 'package:toolbox/core/update.dart';
import 'package:toolbox/core/utils/platform/auth.dart';
import 'package:toolbox/core/utils/platform/base.dart';
import 'package:toolbox/core/utils/platform/perm.dart';
import 'package:toolbox/core/utils/ui.dart';
import 'package:toolbox/data/model/app/github_id.dart';
import 'package:toolbox/data/model/app/tab.dart';
import 'package:toolbox/data/res/build_data.dart';
import 'package:toolbox/data/res/github_id.dart';
import 'package:toolbox/data/res/logger.dart';
import 'package:toolbox/data/res/misc.dart';
import 'package:toolbox/data/res/provider.dart';
import 'package:toolbox/data/res/store.dart';
import 'package:toolbox/data/res/ui.dart';
import 'package:toolbox/data/res/url.dart';
import 'package:toolbox/view/widget/appbar.dart';
import 'package:toolbox/view/widget/cardx.dart';
import 'package:toolbox/view/widget/markdown.dart';
import 'package:toolbox/view/widget/val_builder.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

part 'appbar.dart';

class HomePage extends StatefulWidget {
  final bool fullScreen;

  const HomePage({super.key, this.fullScreen = false});

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
  final _isLandscape = ValueNotifier(false);

  bool _switchingPage = false;
  bool _shouldAuth = false;

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
    if (Stores.setting.generalWakeLock.fetch()) {
      WakelockPlus.enable();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    l10n = S.of(context)!;
    _isLandscape.value =
        MediaQuery.of(context).orientation == Orientation.landscape;
  }

  @override
  void dispose() {
    super.dispose();
    WidgetsBinding.instance.removeObserver(this);
    Pros.server.closeServer();
    _pageController.dispose();
    WakelockPlus.disable();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (isDesktop) return;

    switch (state) {
      case AppLifecycleState.resumed:
        if (_shouldAuth) {
          BioAuth.go().then((_) => _shouldAuth = false);
        }
        if (!Pros.server.isAutoRefreshOn) {
          Pros.server.startAutoRefresh();
        }
        HomeWidgetMC.update();
        break;
      case AppLifecycleState.paused:
        _shouldAuth = true;
        // Keep running in background on Android device
        if (isAndroid && Stores.setting.bgRun.fetch()) {
          // Keep this if statement single
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
    Pros.app.ctx = context;

    final appBar = _AppBar(
      selectIndex: _selectIndex,
      landscape: _isLandscape,
      centerTitle: false,
      title: const Text(BuildData.name),
      actions: <Widget>[
        ValBuilder(
          listenable: Stores.setting.serverStatusUpdateInterval.listenable(),
          builder: (interval) {
            if (interval != 0) return UIs.placeholder;
            return IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'Refresh',
              onPressed: () async {
                await Pros.server.refresh();
              },
            );
          },
        ),
        IconButton(
          icon: const Icon(Icons.developer_mode, size: 21),
          tooltip: l10n.debug,
          onPressed: () => AppRoute.debug().go(context),
        ),
      ],
    );
    return Scaffold(
      drawer: _buildDrawer(),
      appBar: appBar,
      body: PageView.builder(
        controller: _pageController,
        itemCount: AppTab.values.length,
        physics: const NeverScrollableScrollPhysics(),
        itemBuilder: (_, index) => AppTab.values[index].page,
        onPageChanged: (value) {
          if (!_switchingPage) {
            _selectIndex.value = value;
          }
        },
      ),
      bottomNavigationBar: widget.fullScreen
          ? null
          : ValBuilder(
              listenable: _isLandscape,
              builder: (ls) {
                if (ls) return const SizedBox();
                return ListenableBuilder(
                  listenable: _selectIndex,
                  builder: (_, __) => _buildBottomBar(),
                );
              },
            ),
    );
  }

  Widget _buildBottomBar() {
    return NavigationBar(
      selectedIndex: _selectIndex.value,
      height: kBottomNavigationBarHeight * 1.1,
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
          icon: const Icon(BoxIcons.bx_server),
          label: l10n.server,
          selectedIcon: const Icon(BoxIcons.bxs_server),
        ),
        const NavigationDestination(
          icon: Icon(Icons.terminal_outlined),
          label: 'SSH',
          selectedIcon: Icon(Icons.terminal),
        ),
        NavigationDestination(
          icon: const Icon(MingCute.file_code_line),
          label: l10n.snippet,
          selectedIcon: const Icon(MingCute.file_code_fill),
        ),
        const NavigationDestination(
          icon: Icon(MingCute.planet_line),
          label: 'Ping',
          selectedIcon: Icon(MingCute.planet_fill),
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
              title: const Text(BuildDataX.versionStr),
              child: const Text(
                  '${BuildData.buildAt}\nFlutter ${BuildData.engine}'),
            ),
            child: const Text(
              '${BuildData.name}\n${BuildDataX.versionStr}',
              textAlign: TextAlign.center,
              style: UIs.text15,
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
            leading: const Icon(BoxIcons.bxs_file_blank),
            title: Text(l10n.files),
            onTap: () => AppRoute.localStorage().go(context),
          ),
          ListTile(
            leading: const Icon(MingCute.file_import_fill),
            title: Text(l10n.backup),
            onTap: () => AppRoute.backup().go(context),
          ),
          ListTile(
            leading: const Icon(OctIcons.feed_discussion),
            title: Text('${l10n.about} & ${l10n.feedback}'),
            onTap: _showAboutDialog,
          )
        ].map((e) => CardX(child: e)).toList(),
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
      child: SizedBox(
        width: MediaQuery.of(context).size.width * 0.8,
        child: SimpleMarkdown(
          data: '''
${l10n.madeWithLove('[lollipopkit](${Urls.myGithub})')}

#### Contributors
${GithubIds.contributors.map((e) => '[$e](${e.url})').join(' ')}

#### Participants
${GithubIds.participants.map((e) => '[$e](${e.url})').join(' ')}

#### My other apps
- [GPT Box](https://github.com/lollipopkit/flutter_gpt_box)
''',
        ),
      ),
    );
  }

  Widget _buildIcon() {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 57, maxWidth: 57),
      child: UIs.appIcon,
    );
  }

  @override
  bool get wantKeepAlive => true;

  @override
  Future<void> afterFirstLayout(BuildContext context) async {
    // Auth required for first launch
    BioAuth.go();

    _reqNotiPerm();

    if (Stores.setting.autoCheckAppUpdate.fetch()) {
      doUpdate(context);
    }
    HomeWidgetMC.update();
    await GetIt.I.allReady();
    await Pros.server.load();
    await Pros.server.refresh();
  }

  // It's required by RUpgrade to send update progress
  Future<void> _reqNotiPerm() async {
    if (!isAndroid) return;
    final suc = await PermUtils.request(Permission.notification);
    if (!suc) {
      final noNotiPerm = Stores.setting.noNotiPerm;
      if (noNotiPerm.fetch()) return;
      context.showRoundDialog(
        title: Text(l10n.error),
        child: Text(l10n.noNotiPerm),
        actions: [
          TextButton(
            onPressed: () {
              noNotiPerm.put(true);
              context.pop();
            },
            child: Text(l10n.ok),
          ),
        ],
      );
    }
  }

  Future<void> _onLongPressSetting() async {
    final map = Stores.setting.box.toJson(includeInternal: false);
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
}
