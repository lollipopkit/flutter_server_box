import 'dart:async';
import 'dart:io';

import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/foundation.dart' show kReleaseMode;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:responsive_framework/responsive_framework.dart';
import 'package:server_box/core/chan.dart';
import 'package:server_box/core/sync.dart';
import 'package:server_box/core/utils/desktop_shortcuts.dart';
import 'package:server_box/data/model/app/tab.dart';
import 'package:server_box/data/provider/app/session_requests.dart';
import 'package:server_box/data/provider/server/all.dart';
import 'package:server_box/data/res/build_data.dart';
import 'package:server_box/data/res/store.dart';
import 'package:server_box/data/res/url.dart';
import 'package:server_box/view/page/agent/shell.dart';
import 'package:server_box/view/page/home_tab.dart';
import 'package:server_box/view/page/macos_menu_bar.dart';
import 'package:server_box/view/page/setting/entry.dart';
import 'package:server_box/view/widget/dmg_notice.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();

  static const route = AppRouteNoArg(page: HomePage.new, path: '/');
}

class _HomePageState extends ConsumerState<HomePage>
    with
        AutomaticKeepAliveClientMixin,
        AfterLayoutMixin,
        WidgetsBindingObserver,
        GlobalRef,
        RestorationMixin {
  // Restorable state for current tab index
  final RestorableInt _restorableTabIndex = RestorableInt(0);

  @override
  String get restorationId => 'home_page';

  @override
  void restoreState(RestorationBucket? oldBucket, bool initialRestore) {
    registerForRestoration(_restorableTabIndex, 'tab_index');
  }

  late final PageController _pageController;

  final _selectIndex = ValueNotifier(0);

  bool _switchingPage = false;
  bool _shouldAuth = false;
  bool? _lastFullscreenMode;
  DateTime? _pausedTime;

  late final _notifier = ref.read(serversProvider.notifier);
  late List<AppTab> _tabs = Stores.setting.homeTabs.fetch();

  @override
  void dispose() {
    _restorableTabIndex.dispose();
    if (isMobile) {
      SystemUIs.switchStatusBar(hide: false);
    }
    WidgetsBinding.instance.removeObserver(this);
    Stores.setting.homeTabs.listenable().removeListener(_handleHomeTabsChanged);
    Stores.setting.serverStatusUpdateInterval.listenable().removeListener(
      _handleRefreshIntervalChanged,
    );
    // In release builds (real app exit), close connections.
    // In debug (hot reload), avoid forcing disconnects.
    if (kReleaseMode) {
      Future(() => _notifier.closeServer());
    }
    _pageController.dispose();
    WakelockPlus.disable();

    _selectIndex.removeListener(_publishCurrentTab);
    _selectIndex.dispose();
    super.dispose();
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
    Stores.setting.homeTabs.listenable().addListener(_handleHomeTabsChanged);
    Stores.setting.serverStatusUpdateInterval.listenable().addListener(
      _handleRefreshIntervalChanged,
    );

    // One listener rather than a call beside every assignment: the index is
    // set from the bar, the rail, a request from another page and restoration,
    // and one of those would eventually be forgotten.
    _selectIndex.addListener(_publishCurrentTab);
  }

  /// Re-announces the tab after a hot reload.
  ///
  /// Neither `initState` nor `afterFirstLayout` runs again when the code
  /// changes under a running app, so a value published once from those is
  /// whatever it was before — and for the first reload after this provider was
  /// added, that is nothing at all. The floating Agent then believes it is
  /// never on the Agent tab and shows itself beside the page it duplicates.
  @override
  void reassemble() {
    super.reassemble();
    _publishCurrentTab();
  }

  /// Tells [currentHomeTabProvider] where the app ended up.
  ///
  /// Only ever called from a callback or a post-frame hook — never from
  /// `build`, which is not allowed to write to a provider.
  void _publishCurrentTab() {
    final index = _selectIndex.value;
    if (index < 0 || index >= _tabs.length) return;
    ref.read(currentHomeTabProvider.notifier).update(_tabs[index]);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (isDesktop) return;

    switch (state) {
      case AppLifecycleState.resumed:
        _lastFullscreenMode = null;
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
        unawaited(serverNotifier.startAutoRefresh());
        unawaited(serverNotifier.refresh());
        unawaited(MethodChans.updateHomeWidget());
        _syncFullscreenSystemUi();
        break;
      case AppLifecycleState.paused:
        _lastFullscreenMode = null;
        _pausedTime = DateTime.now();
        _shouldAuth = true;
        if (!(isAndroid && Stores.setting.bgRun.fetch())) {
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
    // Something elsewhere asked for a tab — opening a terminal from the server
    // list, say. Acted on here because this page owns the controller and the
    // animation; the caller only says where it wants to be.
    ref.listen(homeTabRequestProvider, (_, tab) {
      if (tab == null) return;
      final index = _tabs.indexOf(tab);
      if (index >= 0) _onDestinationSelected(index);
      ref.read(homeTabRequestProvider.notifier).done();
    });
    final isMobile = ResponsiveBreakpoints.of(context).isMobile;
    _syncFullscreenSystemUi();

    final Widget mainContent = Scaffold(
      appBar: _AppBar(MediaQuery.paddingOf(context).top),
      body: Row(
        children: [
          if (!isMobile) _buildRailBar(),
          Expanded(
            child: PageView.builder(
              controller: _pageController,
              itemCount: _tabs.length,
              physics: const NeverScrollableScrollPhysics(),
              // Each tab keeps its own stack, so a page opened inside one —
              // a server's details, its files — covers the tab and not the
              // window. The bar or rail that got you here stays put, and
              // coming back to a tab returns you to where you were in it.
              itemBuilder: (_, index) => NestedNavigator(
                key: ValueKey(_tabs[index]),
                rootBuilder: (_) => _tabs[index].page,
              ),
              onPageChanged: (value) {
                FocusScope.of(context).unfocus();
                if (!_switchingPage) {
                  _selectIndex.value = value;
                  _restorableTabIndex.value = value;
                }
                _syncFullscreenSystemUi();
              },
            ),
          ),
        ],
      ),
      bottomNavigationBar: isMobile ? _buildBottomBar() : null,
    );

    // Above the `PageView` rather than inside a tab: the Agent floats over
    // whichever tab you are on, so it cannot belong to one of them.
    //
    // The shell is told how big this box actually is rather than reading
    // `MediaQuery.sizeOf`. Those are not the same number — everything between
    // the window and here, the responsive builder included, is free to hand
    // down less than it got — and keeping a panel inside the window is not the
    // same as keeping it inside the area it is painted in.
    final withShell = LayoutBuilder(
      builder: (_, constraints) => Stack(
        children: [
          mainContent,
          AgentFloatingShell(area: constraints.biggest),
        ],
      ),
    );

    // The shortcuts, on every desktop. macOS additionally gets a menu bar,
    // which is where a shortcut is *discovered* — but the menu bar is a macOS
    // API, and until now it was also the only thing that bound the keys, so
    // Linux and Windows had no way to switch tabs from the keyboard at all.
    final withKeys = !isDesktop
        ? withShell
        : CallbackShortcuts(
            bindings: desktopShortcuts(
              tabCount: _tabs.length,
              onTab: _onDestinationSelected,
              onSettings: () => SettingsPage.route.go(context),
            ),
            // Focused so the bindings are reachable without clicking
            // something first, and skipping traversal so Tab still walks the
            // actual controls.
            child: Focus(
              autofocus: true,
              skipTraversal: true,
              child: withShell,
            ),
          );

    if (Platform.isMacOS) {
      return PlatformMenuBar(
        menus: MacOSMenuBarManager.buildMenuBar(
          context,
          _onDestinationSelected,
        ),
        child: withKeys,
      );
    }
    return withKeys;
  }

  Widget _buildBottomBar() {
    return ListenableBuilder(
      listenable: _selectIndex,
      builder: (context, child) {
        if (_isServerFullscreenMode) return UIs.placeholder;
        return NavigationBar(
          selectedIndex: _selectIndex.value,
          height: kBottomNavigationBarHeight * 1.1,
          animationDuration: const Duration(milliseconds: 250),
          onDestinationSelected: _onDestinationSelected,
          labelBehavior: NavigationDestinationLabelBehavior.onlyShowSelected,
          destinations: _tabs.map((tab) => tab.navDestination).toList(),
        );
      },
    );
  }

  Widget _buildRailBar({bool extended = false}) {
    return SafeArea(
      child: Stack(
        children: [
          ListenableBuilder(
            listenable: _selectIndex,
            builder: (context, _) {
              if (_isServerFullscreenMode) return UIs.placeholder;
              return NavigationRail(
                extended: extended,
                minExtendedWidth: 150,
                leading: extended ? const SizedBox(height: 20) : null,
                trailing: extended ? const SizedBox(height: 20) : null,
                labelType: extended
                    ? NavigationRailLabelType.none
                    : NavigationRailLabelType.all,
                selectedIndex: _selectIndex.value,
                destinations: _tabs
                    .map((tab) => tab.navRailDestination)
                    .toList(),
                onDestinationSelected: _onDestinationSelected,
              );
            },
          ),
          // Settings Btn
          ListenableBuilder(
            listenable: _selectIndex,
            builder: (context, _) {
              if (_isServerFullscreenMode) return UIs.placeholder;
              return Positioned(
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
              );
            },
          ),
        ],
      ),
    );
  }

  @override
  bool get wantKeepAlive => true;

  @override
  Future<void> afterFirstLayout(BuildContext context) async {
    // Auth required for first launch
    // Restore tab index from restoration if available
    if (_restorableTabIndex.value >= 0 && _restorableTabIndex.value < _tabs.length) {
      _selectIndex.value = _restorableTabIndex.value;
      if (_pageController.hasClients) {
        _pageController.jumpToPage(_restorableTabIndex.value);
      }
    }
    // Explicitly, because the listener above only fires on a change: the first
    // tab is usually already the value, and nothing would have announced it.
    _publishCurrentTab();
    _goAuth();

    if (Stores.setting.autoCheckAppUpdate.fetch()) {
      AppUpdateIface.doUpdate(
        build: BuildData.build,
        githubReleasesUrl: Urls.githubReleasesApi,
        storeUrl: Urls.appStore,
        context: context,
        noticeBuilder: (ctx) => DmgNotice.forUpdate(
          ctx,
          build: AppUpdateIface.newestBuild.value ?? BuildData.build,
        ),
      );
    }

    // Says so when this launch took over the sandboxed build's data, or when
    // it could not — see [SandboxImport].
    unawaited(SandboxImportNotice.showIfNeeded(context));
    unawaited(MethodChans.updateHomeWidget());
    await _notifier.refresh();

    bakSync.sync(milliDelay: 1000);
  }

  void _goAuth() {
    if (Stores.setting.useBioAuth.fetch()) {
      if (LocalAuthPage.route.alreadyIn) return;
      LocalAuthPage.route.go(
        context,
        args: LocalAuthPageArgs(onAuthSuccess: () => _shouldAuth = false),
      );
    }
  }

  void _onDestinationSelected(int index) {
    if (_selectIndex.value == index) return;
    if (index < 0 || index >= _tabs.length) return;
    _selectIndex.value = index;
    _restorableTabIndex.value = index;
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

  bool get _isServerFullscreenMode {
    if (!Stores.setting.fullScreen.fetch()) return false;
    if (_tabs.isEmpty) return false;
    final selectedIndex = _selectIndex.value;
    if (selectedIndex < 0 || selectedIndex >= _tabs.length) return false;
    final isLandscape =
        MediaQuery.orientationOf(context) == Orientation.landscape;
    return isLandscape && _tabs[selectedIndex] == AppTab.server;
  }

  void _syncFullscreenSystemUi({bool? forceHide}) {
    if (!isMobile) return;
    final hide = forceHide ?? _isServerFullscreenMode;
    if (_lastFullscreenMode == hide) return;
    _lastFullscreenMode = hide;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      SystemUIs.switchStatusBar(hide: hide);
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

extension _HomePageStateActions on _HomePageState {
  void _handleHomeTabsChanged() {
    final newTabs = Stores.setting.homeTabs.fetch();
    if (!mounted || newTabs == _tabs) return;

    final previousIndex = _selectIndex.value;
    final clampedIndex = newTabs.isEmpty
        ? 0
        : previousIndex.clamp(0, newTabs.length - 1);

    // ignore: invalid_use_of_protected_member
    setState(() {
      _tabs = newTabs;
      _selectIndex.value = clampedIndex;
      _restorableTabIndex.value = clampedIndex;
    });

    // The index alone does not say which tab it is any more — the list under
    // it just changed — and it may well not have moved.
    _publishCurrentTab();

    if (clampedIndex != previousIndex && _pageController.hasClients) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_pageController.hasClients) return;
        _pageController.jumpToPage(clampedIndex);
      });
    }
  }

  void _handleRefreshIntervalChanged() {
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    if (isDesktop ||
        lifecycle == null ||
        lifecycle == AppLifecycleState.resumed) {
      unawaited(_notifier.startAutoRefresh());
      unawaited(_notifier.refresh());
    }
  }
}
