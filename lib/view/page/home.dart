import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/foundation.dart' show kReleaseMode, visibleForTesting;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:icons_plus/icons_plus.dart';
import 'package:server_box/core/chan.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/core/service/tray.dart';
import 'package:server_box/core/sync.dart';
import 'package:server_box/core/utils/desktop_shortcuts.dart';
import 'package:server_box/data/model/app/tab.dart';
import 'package:server_box/data/provider/app/session_requests.dart';
import 'package:server_box/data/provider/server/all.dart';
import 'package:server_box/data/res/build_data.dart';
import 'package:server_box/data/res/store.dart';
import 'package:server_box/data/res/url.dart';
import 'package:server_box/data/ssh/session_manager.dart';
import 'package:server_box/view/page/floating_panels.dart';
import 'package:server_box/view/page/home_tab.dart';
import 'package:server_box/view/page/macos_menu_bar.dart';
import 'package:server_box/view/page/setting/entries/home_tabs.dart';
import 'package:server_box/view/page/setting/entry.dart';
import 'package:server_box/view/widget/dmg_notice.dart';
import 'package:server_box/view/widget/legacy_status_notice.dart';
import 'package:server_box/view/widget/nav_rail.dart';
import 'package:server_box/view/widget/server_share.dart';
import 'package:server_box/view/widget/themed_icon.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

part 'home/lifecycle.dart';
part 'home/nav.dart';
part 'home/settings.dart';
part 'home/tabs.dart';

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
        SingleTickerProviderStateMixin,
        GlobalRef {
  /// Which tab to come back to, by [AppTab.name] — see
  /// [_HomePageTabs._rememberTab].
  ///
  /// A store, not a `Restorable*`. Flutter's restoration is dead in this app —
  /// `restoreState` runs, registration succeeds, the value reads back within
  /// the session, and a relaunch has nothing, because the route
  /// `MaterialApp.home` builds hands its subtree no bucket
  /// (`test/widget/restoration_bucket_test.dart`). So this always came back to the
  /// first tab, and nothing said so.
  final _lastTab = Stores.history.homeTab;

  late final PageController _pageController;

  final _selectIndex = ValueNotifier(0);

  bool _switchingPage = false;
  bool _shouldAuth = false;
  bool? _lastFullscreenMode;
  DateTime? _pausedTime;
  int _serverRefreshCycle = 0;

  /// Guards against two of [_HomePageLifecycle._consumePendingShare] being up
  /// at once.
  ///
  /// The launch path and a resume can both fire while the first is still
  /// waiting on the passphrase dialog, and `takeOpenedShare` clearing the
  /// native side is not enough on its own — the second call would find nothing
  /// and return, but only after the first had already been asked twice on
  /// platforms where opening a file also resumes the app.
  var _consumingShare = false;

  /// The lock screen currently up, if any. See where it is assigned.
  Future<void>? _authed;

  late final _notifier = ref.read(serversProvider.notifier);

  /// What the user arranged: the bar, and the rail.
  late List<AppTab> _barTabs = Stores.setting.homeTabs.fetch();

  /// Every page there is, the bar's first and "more"'s after. The index space
  /// for everything below, so a tab reached through "more" is a page like any
  /// other rather than something pushed over one.
  late List<AppTab> _tabs = [..._barTabs, ...AppTab.overflowOf(_barTabs)];

  /// The tab strip, whichever of the two is on screen. Only one is built at a
  /// time — the bar on a phone, the rail beside a window — so one key covers
  /// both, and it is null exactly when there is no strip to point at.
  final _navKey = GlobalKey();

  /// Whether the window is too narrow for a rail, read from the last build.
  ///
  /// A field because the callbacks that need it — see
  /// [_HomePageSettings._openSettings] — run outside the `LayoutBuilder` that
  /// works it out.
  bool _narrow = false;

  /// Whether the settings are what the content area is showing.
  ///
  /// Not an `AppTab`: it is never arranged, never stored and never one of the
  /// pages [_selectIndex] addresses. But it *is* shown where a tab is shown,
  /// over the same rail — it used to be pushed over the whole window, which
  /// took away the only navigation on screen to get back out with.
  bool _settingsOpen = false;

  /// The settings' own stack, so that back can be asked whether it has
  /// somewhere to go before it is taken to mean "put the settings away".
  final _settingsNavKey = GlobalKey<NavigatorState>();

  /// The settings arriving and leaving.
  ///
  /// A tab is swapped for a tab by the `PageView` sliding, which is a move
  /// between siblings. This is not one — it is a different kind of place, so
  /// it crosses rather than slides: each side fades, and each is displaced by
  /// a fraction of the pane in the direction it is going.
  late final _settingsCtrl = AnimationController(
    vsync: this,
    duration: Durations.medium2,
  );
  late final _settingsAnim = CurvedAnimation(
    parent: _settingsCtrl,
    curve: Curves.easeOutCubic,
    reverseCurve: Curves.easeInCubic,
  );

  /// Whether they have been opened at all since launch.
  ///
  /// They keep their place once they have been — which section, what was
  /// typed in the search, where the page was scrolled to — the way a tab
  /// keeps its own. Built for the first time only when asked for, because
  /// most launches never go near them.
  bool _settingsSeen = false;

  /// Whether the guide over that strip has been dealt with this launch.
  ///
  /// The stored flag is only written once the guide has been dismissed, so
  /// something has to stop a second attempt while the first is still up.
  bool _navGuideHandled = false;

  /// The tab that has asked for the whole window, or null. Kept in a field
  /// because the strips are built inside `ListenableBuilder`s on
  /// [_selectIndex], which is not a build this state's `ref` may watch from.
  AppTab? _immersiveTab;

  /// Whether the tab on screen is the one asking for the window.
  ///
  /// The claim names a tab rather than being a flag because a tab is kept alive
  /// behind the others: the server tab goes on drawing its globe while somebody
  /// reads a terminal, and the navigation has to be there for that one.
  bool get _wantsWindow {
    // Whatever the tab behind the settings wants, the settings are not it —
    // and a rail taken away here is the way back out taken away with it.
    if (_settingsOpen) return false;
    final tab = _immersiveTab;
    if (tab == null) return false;
    final index = _selectIndex.value;
    if (index < 0 || index >= _tabs.length) return false;
    return _tabs[index] == tab;
  }

  @override
  void dispose() {
    _stopServerRefreshCycle();
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
    _settingsAnim.dispose();
    _settingsCtrl.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    SystemUIs.switchStatusBar(hide: false);
    WidgetsBinding.instance.addObserver(this);
    // The one way in the lifecycle cannot report: a file opened into an app
    // that never left the foreground. See [MethodChans.onShareOpened].
    MethodChans.onShareOpened(() => unawaited(_consumePendingShare()));
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

    // Only at the ends. What moves in between is drawn by `FadeTransition`
    // and `SlideTransition`, which listen for themselves; what a rebuild is
    // for is [_tabsHidden] and [_settingsShowing], and both only change there.
    _settingsCtrl.addStatusListener((status) {
      switch (status) {
        case AnimationStatus.completed || AnimationStatus.dismissed:
          if (mounted) setState(() {});
        case _:
          break;
      }
    });
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

  // The listeners [initState] hands over by name are methods of this class
  // rather than of an extension. An extension method torn off is a new closure
  // each time, equal to no other, so the `removeListener` in [dispose] would be
  // handed something that was never added and remove nothing.

  /// Tells [currentHomeTabProvider] where the app ended up.
  ///
  /// Only ever called from a callback or a post-frame hook — never from
  /// `build`, which is not allowed to write to a provider.
  void _publishCurrentTab() {
    final index = _selectIndex.value;
    if (index < 0 || index >= _tabs.length) return;
    ref.read(currentHomeTabProvider.notifier).update(_tabs[index]);
  }

  void _handleHomeTabsChanged() {
    final newBar = Stores.setting.homeTabs.fetch();
    final newTabs = [...newBar, ...AppTab.overflowOf(newBar)];
    // The page list is every tab either way, so it only changes when the *bar*
    // does — which is what the setting says.
    if (!mounted || newBar.equals(_barTabs)) return;

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

    setState(() {
      _barTabs = newBar;
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
    if (_canRefreshServers) {
      unawaited(_restartServerRefreshCycle());
    } else {
      _stopServerRefreshCycle();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    // Above the desktop guard, deliberately. Opening a `.sbxsrv` foregrounds
    // the app, and on macOS — where AirDrop and "Open With" both land — that
    // is the *only* edge this ever arrives on, since everything below returns
    // before it.
    if (state == AppLifecycleState.resumed) {
      unawaited(_consumePendingShare());
    }

    if (isDesktop) return;
    _handleMobileLifecycle(state);
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
    // Watched, and from here, because this page outlives everything else the
    // app builds: the tray has to go on reporting while the window is hidden,
    // and a provider kept alive only by a page that comes and goes would take
    // the icon with it. Off desktop the service does nothing.
    ref.watch(trayServiceProvider);
    // A tab asking for the window — the globe, and nothing else so far. Read
    // here because a build is where a provider is watched; what it means is
    // decided in [_wantsWindow], which also has to know *which* tab is on
    // screen.
    _immersiveTab = ref.watch(immersiveTabProvider);
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
    //
    // Rebuilt on a tab change rather than only on its own state, because
    // whether there is a bar at all is a `Scaffold` argument and the answer
    // depends on which tab is showing — see [_wantsWindow]. A bar that is
    // present but drawing nothing is not the same as no bar: `Scaffold` takes
    // the bottom inset off the body whenever the slot is filled, on the
    // grounds that the bar will spend it. An empty one spends nothing, and the
    // globe ran under the home indicator.
    Widget mainContent(bool narrow) => ListenableBuilder(
      listenable: _selectIndex,
      builder: (_, _) => Scaffold(
        body: Stack(
          children: [
            Row(
              children: [
                // The room the rail stands in, and not the rail: it opens
                // under the pointer and is painted over what is beside it, so
                // a tab must not be laid out to one width and then another.
                //
                // Its own `SafeArea` rather than none, because the rail has
                // one too — on a landscape phone wide enough for a rail, the
                // left inset is width neither of them may spend.
                if (_hasRail(narrow))
                  const SafeArea(
                    top: false,
                    bottom: false,
                    right: false,
                    child: SizedBox(width: _kRailWidth),
                  ),
                Expanded(
                  child: Stack(
                    children: [
                      _buildTabPages(),
                      if (_settingsSeen) _buildSettingsPane(),
                    ],
                  ),
                ),
              ],
            ),
            // Painted last, so that opening it is a panel coming out over the
            // tab rather than the tab drawing over it: in a `Row` the rail is
            // the first child and so the first painted, and what it overflows
            // into is painted after.
            if (_hasRail(narrow))
              PositionedDirectional(
                top: 0,
                bottom: 0,
                start: 0,
                child: _buildRailBar(),
              ),
          ],
        ),
        bottomNavigationBar: narrow && !_wantsWindow ? _buildBottomBar() : null,
      ),
    );

    // Above the `PageView` rather than inside a tab: the Agent and a floated
    // terminal float over whichever tab you are on, so neither can belong to
    // one of them.
    //
    // They are told how big this box actually is rather than reading
    // `MediaQuery.sizeOf`. Those are not the same number — everything between
    // the window and here, the responsive builder included, is free to hand
    // down less than it got — and keeping a panel inside the window is not the
    // same as keeping it inside the area it is painted in.
    final withShell = LayoutBuilder(
      builder: (_, constraints) {
        // The same width the pages inside decide by, so the rail appears
        // exactly when a tab can start using the room it costs — see
        // [AdaptivePanes.kSplitWidth]. `ResponsiveBreakpoints`' MOBILE class,
        // which this used to ask, ends at 600.
        //
        // Measured against what a tab would be left with, not against the
        // window: the rail is taken off the top before any page sees the
        // width, so between 800 and 880 a rail appeared beside pages that were
        // still too narrow to split — the extra column bought nothing but its
        // own presence.
        //
        // And measured from this box for the same reason the panels above are:
        // everything between the window and here is free to hand down less
        // than it got, so `MediaQuery.sizeOf` is a different number and it is
        // not the one a tab is laid out in.
        final narrow =
            constraints.maxWidth - _kRailWidth < AdaptivePanes.kSplitWidth;
        _narrow = narrow;
        return Stack(
          children: [
            mainContent(narrow),
            FloatingPanels(area: constraints.biggest),
          ],
        );
      },
    );

    // Back, while the settings are shown in place of a tab, puts them away.
    //
    // On a phone they are a page and back pops it. Here they are not a route
    // at all, so back went to the only route there is — this one — and on a
    // wide Android window that is the app closing from inside its settings.
    //
    // What the settings have pushed goes first: their navigator asks for the
    // gesture itself while it has somewhere to go, and every scope on a route
    // is told of a back that was refused, so without asking it this would put
    // the settings away from under the page that was being left.
    final withBack = PopScope(
      canPop: !_settingsOpen,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (_settingsNavKey.currentState?.canPop() ?? false) return;
        _closeSettings();
      },
      child: withShell,
    );

    // The shortcuts, on every desktop. macOS additionally gets a menu bar,
    // which is where a shortcut is *discovered* — but the menu bar is a macOS
    // API, and until now it was also the only thing that bound the keys, so
    // Linux and Windows had no way to switch tabs from the keyboard at all.
    final withKeys = !isDesktop
        ? withBack
        : CallbackShortcuts(
            bindings: desktopShortcuts(
              tabCount: _tabs.length,
              onTab: _onDestinationSelected,
              onSettings: _openSettings,
            ),
            // Focused so the bindings are reachable without clicking
            // something first, and skipping traversal so Tab still walks the
            // actual controls.
            child: Focus(autofocus: true, skipTraversal: true, child: withBack),
          );

    if (Platform.isMacOS) {
      return PlatformMenuBar(
        menus: MacOSMenuBarManager.buildMenuBar(
          context,
          _onDestinationSelected,
          onSettings: _openSettings,
        ),
        child: withKeys,
      );
    }
    return withKeys;
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
    // Held in a field as well as locally: [_consumePendingShare] runs on the
    // resume edge too, where there is no such local to await, and it must not
    // draw over the lock screen either.
    final authed = _authed = _goAuth(showGuide: false);

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

    unawaited(MethodChans.updateHomeWidget());

    // In sequence, and awaited. Both are root-navigator dialogs, so firing
    // them together stacks one on the other; and the guide is an overlay above
    // every route, which would cover whichever was up rather than wait for it.
    // The guide checks for that and skips, so racing them cost the guide a
    // launch at a time.
    //
    // Before the refresh and not after it: that call waits on every server's
    // connection, and one machine slow to answer would hold all of this back
    // for as long as it takes to time out. The strip the guide points at is
    // already laid out — this runs after the first frame.
    unawaited(_showLaunchNotices(authed));

    unawaited(_restartServerRefreshCycle());

    bakSync.syncSoon();
  }
}
