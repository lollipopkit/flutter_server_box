import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:responsive_framework/responsive_framework.dart';
import 'package:server_box/core/chan.dart';
import 'package:server_box/core/sync.dart';
import 'package:server_box/data/model/app/tab.dart';
import 'package:server_box/data/provider/server/all.dart';
import 'package:server_box/data/res/build_data.dart';
import 'package:server_box/data/res/store.dart';
import 'package:server_box/data/res/url.dart';
import 'package:server_box/view/page/setting/entry.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();

  static const route = AppRouteNoArg(page: HomePage.new, path: '/');
}

class _HomePageState extends ConsumerState<HomePage>
    with AutomaticKeepAliveClientMixin, AfterLayoutMixin, WidgetsBindingObserver, GlobalRef {
  late final PageController _pageController;

  final _selectIndex = ValueNotifier(0);

  bool _switchingPage = false;
  bool _shouldAuth = false;
  DateTime? _pausedTime;

  late final _notifier = ref.read(serversNotifierProvider.notifier);
  late final _provider = ref.read(serversNotifierProvider);
  late List<AppTab> _tabs = Stores.setting.homeTabs.fetch();

  @override
  void dispose() {
    super.dispose();
    WidgetsBinding.instance.removeObserver(this);
    Future(() => _notifier.closeServer());
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
    if (_selectIndex.value >= _tabs.length || _selectIndex.value < 0) {
      _selectIndex.value = 0;
    }
    _pageController = PageController(initialPage: _selectIndex.value);
    if (Stores.setting.generalWakeLock.fetch()) {
      WakelockPlus.enable();
    }

    // Listen to homeTabs changes
    Stores.setting.homeTabs.listenable().addListener(() {
      final newTabs = Stores.setting.homeTabs.fetch();
      if (mounted && newTabs != _tabs) {
        setState(() {
          _tabs = newTabs;
          // Ensure current page index is valid
          if (_selectIndex.value >= _tabs.length) {
            _selectIndex.value = _tabs.length - 1;
          }
          if (_selectIndex.value < 0 && _tabs.isNotEmpty) {
            _selectIndex.value = 0;
          }
        });
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (isDesktop) return;

    switch (state) {
      case AppLifecycleState.resumed:
        if (_shouldAuth) {
          final delay = Stores.setting.delayBioAuthLock.fetch();
          if (delay > 0 && _pausedTime != null) {
            final now = DateTime.now();
            if (now.difference(_pausedTime ?? now).inSeconds > delay) {
              _goAuth();
            } else {
              _shouldAuth = false;
            }
            _pausedTime = null;
          } else {
            _goAuth();
          }
        }
        final serverNotifier = _notifier;
        if (_provider.autoRefreshTimer == null) {
          serverNotifier.startAutoRefresh();
        }
        MethodChans.updateHomeWidget();
        break;
      case AppLifecycleState.paused:
        _pausedTime = DateTime.now();
        _shouldAuth = true;
        // Keep running in background on Android device
        if (isAndroid && Stores.setting.bgRun.fetch()) {
          // Keep this if statement single
          // if (Pros.app.moveBg) {
          //   BgRunMC.moveToBg();
          // }
        } else {
          //Pros.server.setDisconnected();
          _notifier.stopAutoRefresh();
        }
        break;
      default:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final isMobile = ResponsiveBreakpoints.of(context).isMobile;

    return Scaffold(
      appBar: _AppBar(MediaQuery.paddingOf(context).top),
      body: Row(
        children: [
          if (!isMobile) _buildRailBar(),
          Expanded(
            child: PageView.builder(
              controller: _pageController,
              itemCount: _tabs.length,
              physics: const NeverScrollableScrollPhysics(),
              itemBuilder: (_, index) => _tabs[index].page,
              onPageChanged: (value) {
                FocusScope.of(context).unfocus();
                if (!_switchingPage) {
                  _selectIndex.value = value;
                }
              },
            ),
          ),
        ],
      ),
      bottomNavigationBar: isMobile ? _buildBottomBar() : null,
    );
  }

  Widget _buildBottomBar() {
    if (Stores.setting.fullScreen.fetch()) return UIs.placeholder;
    return ListenableBuilder(
      listenable: _selectIndex,
      builder: (context, child) => NavigationBar(
        selectedIndex: _selectIndex.value,
        height: kBottomNavigationBarHeight * 1.1,
        animationDuration: const Duration(milliseconds: 250),
        onDestinationSelected: _onDestinationSelected,
        labelBehavior: NavigationDestinationLabelBehavior.onlyShowSelected,
        destinations: _tabs.map((tab) => tab.navDestination).toList(),
      ),
    );
  }

  Widget _buildRailBar({bool extended = false}) {
    final fullscreen = Stores.setting.fullScreen.fetch();
    if (fullscreen) return UIs.placeholder;

    return Stack(
      children: [
        _selectIndex.listenVal(
          (idx) => NavigationRail(
            extended: extended,
            minExtendedWidth: 150,
            leading: extended ? const SizedBox(height: 20) : null,
            trailing: extended ? const SizedBox(height: 20) : null,
            labelType: extended ? NavigationRailLabelType.none : NavigationRailLabelType.all,
            selectedIndex: idx,
            destinations: _tabs.map((tab) => tab.navRailDestination).toList(),
            onDestinationSelected: _onDestinationSelected,
          ),
        ),
        // Settings Btn
        Positioned(
          bottom: 10,
          left: 0,
          right: 0,
          child: IconButton(
            icon: const Icon(Icons.settings),
            tooltip: libL10n.setting,
            onPressed: () {
              SettingsPage.route.go(context);
            },
          ),
        ),
      ],
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
      AppUpdateIface.doUpdate(build: BuildData.build, url: Urls.updateCfg, context: context);
    }
    MethodChans.updateHomeWidget();
    await _notifier.refresh();

    bakSync.sync(milliDelay: 1000);
  }

  // Future<void> _reqNotiPerm() async {
  //   if (!isAndroid) return;
  //   final suc = await PermUtils.request(Permission.notification);
  //   if (!suc) {
  //     final noNotiPerm = Stores.setting.noNotiPerm;
  //     context.showRoundDialog(
  //       title: l10n.error,
  //       child: Text(l10n.noNotiPerm),
  //       actions: [
  //         TextButton(
  //           onPressed: () {
  //             noNotiPerm.put(true);
  //             context.pop();
  //           },
  //     if (noNotiPerm.fetch()) return;
  //           child: Text(l10n.ok),
  //         ),
  //       ],
  //     );
  //   }
  // }

  void _goAuth() {
    if (Stores.setting.useBioAuth.fetch()) {
      if (LocalAuthPage.route.alreadyIn) return;
      LocalAuthPage.route.go(context, args: LocalAuthPageArgs(onAuthSuccess: () => _shouldAuth = false));
    }
  }

  void _onDestinationSelected(int index) {
    if (_selectIndex.value == index) return;
    if (index < 0 || index >= _tabs.length) return;
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

final class _AppBar extends StatelessWidget implements PreferredSizeWidget {
  final double paddingTop;

  const _AppBar(this.paddingTop);

  @override
  Widget build(BuildContext context) {
    return SizedBox(height: preferredSize.height);
  }

  @override
  Size get preferredSize {
    return Size.fromHeight(paddingTop);
  }
}
