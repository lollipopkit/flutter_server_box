import 'dart:async';
import 'dart:io';

import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/foundation.dart' show kReleaseMode;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:icons_plus/icons_plus.dart';
import 'package:responsive_framework/responsive_framework.dart';
import 'package:server_box/core/chan.dart';
import 'package:server_box/core/extension/context/locale.dart';
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
        GlobalRef {
  /// Which tab to come back to, by [AppTab.name] — see [_rememberTab].
  ///
  /// A store, not a `Restorable*`. Flutter's restoration is dead in this app —
  /// `restoreState` runs, registration succeeds, the value reads back within
  /// the session, and a relaunch has nothing, because the route
  /// `MaterialApp.home` builds hands its subtree no bucket
  /// (`test/restoration_bucket_test.dart`). So this always came back to the
  /// first tab, and nothing said so.
  final _lastTab = Stores.history.homeTab;

  late final PageController _pageController;

  final _selectIndex = ValueNotifier(0);

  bool _switchingPage = false;
  bool _shouldAuth = false;
  bool? _lastFullscreenMode;
  DateTime? _pausedTime;

  late final _notifier = ref.read(serversProvider.notifier);
  late List<AppTab> _tabs = Stores.setting.homeTabs.fetch();

  /// The tab strip, whichever of the two is on screen. Only one is built at a
  /// time — the bar on a phone, the rail beside a window — so one key covers
  /// both, and it is null exactly when there is no strip to point at.
  final _navKey = GlobalKey();

  /// Whether the guide over that strip has been dealt with this launch.
  ///
  /// The stored flag is only written once the guide has been dismissed, so
  /// something has to stop a second attempt while the first is still up.
  bool _navGuideHandled = false;

  @override
  void dispose() {
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

  /// Files the tab at [index] as where the app was left.
  ///
  /// By name. A position stops meaning the same thing the moment the tabs are
  /// reordered or one is hidden, and the reorder is a setting the user makes
  /// between launches.
  void _rememberTab(int index) {
    if (index < 0 || index >= _tabs.length) return;
    _lastTab.put(_tabs[index].name);
  }

  /// Where to reopen, or null to leave it on the first tab.
  ///
  /// A name this build cannot place, or a tab since hidden, is nothing to go
  /// back to rather than a position to clamp.
  int? _savedTabIndex() {
    final name = _lastTab.fetch();
    if (name.isNotEmpty) {
      final at = _tabs.indexWhere((tab) => tab.name == name);
      return at < 0 ? null : at;
    }
    // TODO: delete with `HistoryStore.homeTabIndex`. An install upgrading from
    // a build that stored the position has one and no name; reading it once
    // is what keeps that launch on the tab it was left on.
    final saved = Stores.history.homeTabIndex.fetch();
    if (saved < 0 || saved >= _tabs.length) return null;
    return saved;
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
              _releasePrivacyCover();
            }
            _pausedTime = null;
          } else {
            _goAuth();
          }
        } else {
          _releasePrivacyCover();
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
        // Decided here rather than on the way back: the native cover comes off
        // the moment the app is frontmost, which is several frames before
        // Flutter hears about it and can push the lock screen.
        if (Stores.setting.useBioAuth.fetch()) {
          unawaited(MethodChans.setPrivacyBlurLocked(true));
        }
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

    // No `appBar`, deliberately. It used to hold an empty box the height of
    // the status bar, which pushed the tabs clear of it — but a page pushed
    // inside a tab lives in `body`, under that box, so the strip stayed put
    // while the page animated below it and the transition read as two pieces
    // moving separately. Without it the tabs reach the top of the window and
    // each one takes its own top inset, which means a pushed page paints and
    // animates across the strip like every other part of it.
    //
    // The bottom bar is a different case and stays: it is chrome the tabs
    // share, and a page opened in a tab is meant to leave it in place.
    final Widget mainContent = Scaffold(
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
                // The top inset lands on the tab's own content and not on the
                // navigator around it, which is the whole point: a page pushed
                // here is a sibling route, outside this `SafeArea`, so it
                // reaches the top of the window and animates across the status
                // bar. Wrapping the navigator instead would inset the pushed
                // page too and put the seam back.
                //
                // Here rather than in each tab because a tab is not one shape:
                // three of them put a `Scaffold` *inside* a pane splitter, so
                // the splitter's own divider is above any app bar that could
                // have spent the inset.
                rootBuilder: (_) =>
                    SafeArea(bottom: false, child: _tabs[index].page),
              ),
              onPageChanged: (value) {
                FocusScope.of(context).unfocus();
                if (!_switchingPage) {
                  _selectIndex.value = value;
                  _rememberTab(value);
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
          key: _navKey,
          selectedIndex: _selectIndex.value,
          height: kBottomNavigationBarHeight * 1.1,
          animationDuration: const Duration(milliseconds: 250),
          onDestinationSelected: _onDestinationSelected,
          labelBehavior: NavigationDestinationLabelBehavior.onlyShowSelected,
          destinations: [
            for (final tab in _tabs) tab.navDestination(onMenu: _navMenuFor(tab)),
          ],
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
                key: _navKey,
                extended: extended,
                minExtendedWidth: 150,
                leading: extended ? const SizedBox(height: 20) : null,
                trailing: extended ? const SizedBox(height: 20) : null,
                labelType: extended
                    ? NavigationRailLabelType.none
                    : NavigationRailLabelType.all,
                selectedIndex: _selectIndex.value,
                destinations: [
                  for (final tab in _tabs)
                    tab.navRailDestination(onMenu: _navMenuFor(tab)),
                ],
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
    // Where it was left, if that is still a tab: the enabled set is a setting
    // and may have shrunk since.
    final saved = _savedTabIndex();
    if (saved != null) {
      _selectIndex.value = saved;
      if (_pageController.hasClients) {
        _pageController.jumpToPage(saved);
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

    // Before the refresh and not after it: that call waits on every server's
    // connection, and one machine that is slow to answer would hold the guide
    // back for as long as it takes to time out. The strip it points at is
    // already laid out — this runs after the first frame.
    unawaited(_maybeShowNavGuide());

    await _notifier.refresh();

    bakSync.sync(milliDelay: 1000);
  }

  void _goAuth() {
    // First, and on every path out of here. On iOS the cover is a view over the
    // Flutter window, so it is *above* every route drawn inside it — left up it
    // would hide the lock screen instead of protecting it. Releasing it before
    // the push costs at most the frames until the route appears, and in
    // practice the channel round trip outlasts the push.
    //
    // The path that matters is the early return below. Backgrounding *from* the
    // lock screen and coming back re-locks the cover and lands here, where
    // `alreadyIn` is true — and skipping this left the cover over that screen
    // with nothing that would ever take it off, since the next trip out and
    // back returns at exactly the same place.
    _releasePrivacyCover();

    if (!Stores.setting.useBioAuth.fetch()) return;
    if (LocalAuthPage.route.alreadyIn) return;

    // The route's own future, not `onAuthSuccess`. That callback runs from
    // inside `context.pop()`, while the lock screen is still the route the
    // navigator answers with — so the guide's "is the home page current"
    // check would say no and skip it every launch, on exactly the devices
    // this branch exists for. The future completes once the pop has.
    unawaited(
      LocalAuthPage.route
          .go(
            context,
            args: LocalAuthPageArgs(
              onAuthSuccess: () => _shouldAuth = false,
            ),
          )
          .then((_) => _maybeShowNavGuide()),
    );
  }

  /// Let the native privacy cover come off, now that either the lock screen is
  /// about to take over or it was established that none is coming.
  void _releasePrivacyCover() {
    unawaited(MethodChans.setPrivacyBlurLocked(false));
  }

  void _onDestinationSelected(int index) {
    if (_selectIndex.value == index) return;
    if (index < 0 || index >= _tabs.length) return;
    _selectIndex.value = index;
    _rememberTab(index);
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


extension _HomePageStateActions on _HomePageState {
  void _handleHomeTabsChanged() {
    final newTabs = Stores.setting.homeTabs.fetch();
    if (!mounted || newTabs == _tabs) return;

    final previousIndex = _selectIndex.value;
    // Which tab was open, not where it was. Dragging Files above Terminal in
    // the settings page moved neither of them under the user — position 2 was
    // kept and whatever now sits there was shown instead, which reads as the
    // reorder having opened a page at random.
    final previousTab = previousIndex >= 0 && previousIndex < _tabs.length
        ? _tabs[previousIndex]
        : null;
    final moved = previousTab == null ? -1 : newTabs.indexOf(previousTab);
    // It is gone from the set, so there is nothing to follow: stay where the
    // index points, which is the nearest thing to not moving.
    final nextIndex = moved >= 0
        ? moved
        : (newTabs.isEmpty ? 0 : previousIndex.clamp(0, newTabs.length - 1));

    // ignore: invalid_use_of_protected_member
    setState(() {
      _tabs = newTabs;
      _selectIndex.value = nextIndex;
      _rememberTab(nextIndex);
    });

    // The index alone does not say which tab it is any more — the list under
    // it just changed — and it may well not have moved.
    _publishCurrentTab();

    if (nextIndex != previousIndex && _pageController.hasClients) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_pageController.hasClients) return;
        _pageController.jumpToPage(nextIndex);
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

/// What a tab can be told to do to everything it holds.
///
/// Two tabs hold a set of live things — the servers, and the terminals — and
/// acting on all of them one row at a time is the tedious part of having more
/// than a few. The rest of the tabs hold records: a snippet is not connected
/// to anything, and a menu with nothing in it is worse than no menu.
///
/// On the tab and not on the page it opens, because that is the one control
/// reachable from anywhere in the app. Turning everything off is most wanted
/// from somewhere that is not the server list.
extension _HomePageNav on _HomePageState {
  ContextMenuOpener? _navMenuFor(AppTab tab) {
    final l10n = context.l10n;
    final menu = switch (tab) {
      AppTab.server => (
        title: libL10n.server,
        actions: [
          ContextMenuAction(
            text: l10n.connectAll,
            icon: MingCute.link_3_line,
            onTap: () => unawaited(_notifier.connectAll()),
          ),
          ContextMenuAction(
            text: l10n.disconnectAll,
            icon: MingCute.unlink_2_line,
            destructive: true,
            onTap: _notifier.closeServer,
          ),
        ],
      ),
      AppTab.ssh => (
        title: libL10n.terminal,
        actions: [
          ContextMenuAction(
            text: l10n.disconnectAll,
            icon: MingCute.unlink_2_line,
            destructive: true,
            onTap: () => unawaited(_confirmCloseAllTerminals()),
          ),
        ],
      ),
      _ => null,
    };
    if (menu == null) return null;
    return (at) => showContextMenu(context, menu.actions, title: menu.title, at: at);
  }

  /// Asked first, unlike disconnecting servers.
  ///
  /// A server that was disconnected reconnects with the entry above it and is
  /// back where it was. A terminal that was closed takes its scrollback with
  /// it, and whatever was still running in it.
  Future<void> _confirmCloseAllTerminals() async {
    final ok = await context.showRoundDialog<bool>(
      title: libL10n.attention,
      child: Text(
        libL10n.askContinue('${libL10n.close} ${libL10n.all} ${libL10n.terminal}'),
      ),
      actions: Btnx.okReds,
    );
    if (ok != true) return;
    // The tab that owns the sessions does the closing; see
    // [TerminalCloseAllRequest] for why it cannot be called directly.
    ref.read(terminalCloseAllRequestProvider.notifier).go();
  }

  /// Points at the tab strip, once per install.
  ///
  /// The menu above opens on a long press or a right-click and leaves no mark
  /// on screen — nothing about the strip says it is there. Everything else in
  /// this app that hides behind a long press has a visible way in as well;
  /// this one does not, because the tab's own tap already means "go there".
  Future<void> _maybeShowNavGuide() async {
    if (_navGuideHandled) return;
    final flag = Stores.setting.navTabMenuGuided;
    if (flag.fetch()) return;
    if (!mounted) return;
    // Nothing to act on in bulk yet. Someone who has just installed this has
    // enough in front of them without being told about a shortcut for a list
    // they have not made.
    if (ref.read(serversProvider).serverOrder.isEmpty) return;
    // The overlay goes above every route, so it would cover the lock screen,
    // an update notice or the sandbox-import dialog rather than wait for it.
    // Skipping leaves the guide for the next launch.
    if (ModalRoute.of(context)?.isCurrent != true) return;

    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) return;
    // Null when the strip is not built — fullscreen mode takes it away.
    final spot = rectInOverlay(_navKey.currentContext, overlay);
    if (spot == null) return;

    _navGuideHandled = true;
    // One step, so no title: a heading over a single sentence says it twice.
    // The same card the terminal's key walkthrough uses — see [GuideView].
    await GuideOverlay.show(context, [
      GuideStep(body: context.l10n.navTabMenuTip, spot: spot),
    ]);
    // Written when it has been seen through, not when it was scheduled.
    flag.put(true);
  }
}
