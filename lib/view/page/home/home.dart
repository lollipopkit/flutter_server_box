import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/material.dart';
import 'package:flutter_adaptive_scaffold/flutter_adaptive_scaffold.dart';
import 'package:server_box/core/chan.dart';
import 'package:server_box/data/model/app/tab.dart';
import 'package:server_box/data/provider/app.dart';
import 'package:server_box/data/provider/server.dart';
import 'package:server_box/data/res/build_data.dart';
import 'package:server_box/data/res/store.dart';
import 'package:server_box/data/res/url.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

part 'appbar.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

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
  bool _shouldAuth = false;

  @override
  void dispose() {
    super.dispose();
    WidgetsBinding.instance.removeObserver(this);
    ServerProvider.closeServer();
    _pageController.dispose();
    WakelockPlus.disable();

    _selectIndex.dispose();
  }

  @override
  void initState() {
    super.initState();
    SystemUIs.switchStatusBar(hide: false);
    WidgetsBinding.instance.addObserver(this);
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
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (isDesktop) return;

    switch (state) {
      case AppLifecycleState.resumed:
        if (_shouldAuth) _goAuth();
        if (!ServerProvider.isAutoRefreshOn) {
          ServerProvider.startAutoRefresh();
        }
        MethodChans.updateHomeWidget();
        break;
      case AppLifecycleState.paused:
        _shouldAuth = true;
        // Keep running in background on Android device
        if (isAndroid && Stores.setting.bgRun.fetch()) {
          // Keep this if statement single
          // if (Pros.app.moveBg) {
          //   BgRunMC.moveToBg();
          // }
        } else {
          //Pros.server.setDisconnected();
          ServerProvider.stopAutoRefresh();
        }
        break;
      default:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    AppProvider.ctx = context;
    final sysPadding = MediaQuery.of(context).padding;

    return ColoredBox(
      color: context.theme.colorScheme.surface,
      child: AdaptiveLayout(
        transitionDuration: const Duration(milliseconds: 250),
        primaryNavigation: SlotLayout(
          config: {
            Breakpoints.medium: SlotLayout.from(
              key: const Key('primaryNavigation'),
              builder: (context) => _buildRailBar(),
            ),
            Breakpoints.mediumLarge: SlotLayout.from(
              key: const Key('MediumLarge primaryNavigation'),
              builder: (context) => _buildRailBar(extended: true),
            ),
            Breakpoints.large: SlotLayout.from(
              key: const Key('Large primaryNavigation'),
              builder: (context) => _buildRailBar(extended: true),
            ),
            Breakpoints.extraLarge: SlotLayout.from(
              key: const Key('ExtraLarge primaryNavigation'),
              builder: (context) => _buildRailBar(extended: true),
            ),
          },
        ),
        body: SlotLayout(
          config: {
            Breakpoint.standard(): SlotLayout.from(
              key: const Key('body'),
              builder: (context) => Scaffold(
                appBar: _AppBar(sysPadding.top),
                body: PageView.builder(
                  controller: _pageController,
                  itemCount: AppTab.values.length,
                  physics: const NeverScrollableScrollPhysics(),
                  itemBuilder: (_, index) => AppTab.values[index].page,
                  onPageChanged: (value) {
                    FocusScope.of(context).unfocus();
                    if (!_switchingPage) {
                      _selectIndex.value = value;
                    }
                  },
                ),
              ),
            ),
          },
        ),
        bottomNavigation: SlotLayout(
          config: {
            Breakpoints.small: SlotLayout.from(
              key: const Key('bottomNavigation'),
              builder: (context) => ListenableBuilder(
                listenable: _selectIndex,
                builder: (context, child) => _buildBottomBar(),
              ),
            ),
          },
        ),
      ),
    );
  }

  Widget _buildBottomBar() {
    return ListenableBuilder(
      listenable: _selectIndex,
      builder: (context, child) => NavigationBar(
        selectedIndex: _selectIndex.value,
        height: kBottomNavigationBarHeight * 1.1,
        animationDuration: const Duration(milliseconds: 250),
        onDestinationSelected: _onDestinationSelected,
        labelBehavior: NavigationDestinationLabelBehavior.onlyShowSelected,
        destinations: AppTab.navDestinations,
      ),
    );
  }

  Widget _buildRailBar({bool extended = false}) {
    return ListenableBuilder(
      listenable: _selectIndex,
      builder: (context, child) => AdaptiveScaffold.standardNavigationRail(
        extended: extended,
        padding: EdgeInsets.zero,
        selectedIndex: _selectIndex.value,
        destinations: AppTab.navRailDestinations,
        onDestinationSelected: _onDestinationSelected,
        labelType: extended ? null : NavigationRailLabelType.selected,
      ),
    );
  }

  @override
  bool get wantKeepAlive => true;

  @override
  Future<void> afterFirstLayout(BuildContext context) async {
    // Auth required for first launch
    _goAuth();

    //_reqNotiPerm();

    if (Stores.setting.autoCheckAppUpdate.fetch()) {
      AppUpdateIface.doUpdate(
        build: BuildData.build,
        url: Urls.updateCfg,
        context: context,
      );
    }
    MethodChans.updateHomeWidget();
    await ServerProvider.refresh();
  }

  // Future<void> _reqNotiPerm() async {
  //   if (!isAndroid) return;
  //   final suc = await PermUtils.request(Permission.notification);
  //   if (!suc) {
  //     final noNotiPerm = Stores.setting.noNotiPerm;
  //     if (noNotiPerm.fetch()) return;
  //     context.showRoundDialog(
  //       title: l10n.error,
  //       child: Text(l10n.noNotiPerm),
  //       actions: [
  //         TextButton(
  //           onPressed: () {
  //             noNotiPerm.put(true);
  //             context.pop();
  //           },
  //           child: Text(l10n.ok),
  //         ),
  //       ],
  //     );
  //   }
  // }

  void _goAuth() {
    if (Stores.setting.useBioAuth.fetch()) {
      if (BioAuthPage.route.isAlreadyIn) return;
      BioAuthPage.route.go(
        context,
        args: BioAuthPageArgs(onAuthSuccess: () => _shouldAuth = false),
      );
    }
  }

  void _onDestinationSelected(int index) {
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
  }
}
