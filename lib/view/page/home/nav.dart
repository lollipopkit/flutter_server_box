part of '../home.dart';

/// What the navigation rail takes from the width a tab gets.
///
/// Its shut width, which is the only one it ever takes: the rail opens under
/// the pointer and is painted *over* the tab beside it, so a tab is never laid
/// out twice for the sake of a hover.
const _kRailWidth = NavRailMetrics.width;

/// What the `Row` holds open for it, which is the number above and not the one
/// the rail reaches when it opens.
@visibleForTesting
const railWidth = _kRailWidth;

/// What the rail spends on things that are not destinations.
///
/// Its own padding and the settings at its foot. Subtracted before the
/// destinations are counted.
const _kRailChromeHeight = NavRailMetrics.chromeHeight;

/// How tall one rail destination is.
///
/// Exact rather than an estimate, now that a shut item is an icon in a pill
/// and nothing that moves with the text scale. Still measured against the
/// widget in `test/widget/home_rail_tabs_test.dart`, because being a point
/// under is a rail that overflows its box.
@visibleForTesting
const railDestinationExtent = NavRailMetrics.itemExtent;

/// How many destinations fit in [height].
///
/// **Never fewer than two**, and that floor is what makes the arithmetic in
/// [railShownCount] exact. Below two there is no arrangement that both says
/// which tab is open and reaches the others: one slot is either a tab with the
/// rest unreachable, or a "more" with nothing saying where you are. So a rail
/// too short for two plans for two anyway and scrolls — which is a window under
/// 200pt tall, where the tab's own contents have about 130 and nothing on
/// screen is usable either way.
@visibleForTesting
int railCapacity({required double height, required double destinationExtent}) {
  if (destinationExtent <= 0) return 2;
  final room = height - _kRailChromeHeight;
  return math.max(2, room ~/ destinationExtent);
}

/// How many tabs the rail draws, of the [wanted] the user put in it.
///
/// The rest are behind "more", **which is a destination itself** — so a rail
/// that cannot hold everything holds one fewer than it has room for.
///
/// [total] is every tab there is. The tabs the user left out of the bar are
/// already behind "more" whatever the height, and this is where a rail too
/// short for the ones they kept sends those as well.
///
/// The result **plus that slot** is what the rail draws, and it never exceeds
/// [capacity] — which holds because [railCapacity] is at least 2. The `max(1,
/// ...)` is only a floor against a smaller one arriving from somewhere else:
/// with `capacity` 1 it answers one tab and a "more" beside it, two
/// destinations in room for one, and the rail scrolls.
@visibleForTesting
int railShownCount({
  required int wanted,
  required int total,
  required int capacity,
}) {
  if (wanted >= total && wanted <= capacity) return wanted;
  return math.max(1, math.min(wanted, capacity - 1));
}

/// The tab strip: the bar on a phone, the rail beside a window, and the
/// "more" both of them open.
extension _HomePageStrip on _HomePageState {
  /// Whether the window gets a rail rather than a bar.
  bool _hasRail(bool narrow) => !narrow && !_wantsWindow;

  Widget _buildBottomBar() {
    return ListenableBuilder(
      listenable: _selectIndex,
      builder: (context, child) {
        if (_isServerFullscreenMode) return UIs.placeholder;
        final shown = _barTabs;
        final overflow = _tabs.length - shown.length;
        final selected = _selectIndex.value;
        return NavigationBar(
          key: _navKey,
          // Past the bar's own tabs, what is open is inside "more" — which is
          // then what the last destination stands for, and is lit to say so.
          // The settings light that slot too, when they are what it holds.
          selectedIndex: _settingsOpen && overflow == 0
              ? shown.length
              : (selected < shown.length ? selected : shown.length),
          height: kBottomNavigationBarHeight * 1.1,
          animationDuration: const Duration(milliseconds: 250),
          onDestinationSelected: (index) {
            if (index < shown.length) return _onDestinationSelected(index);
            // The last slot is one or the other, never both.
            if (overflow > 0) {
              unawaited(_showMoreSheet(shown.length));
              return;
            }
            _openSettings();
          },
          labelBehavior: NavigationDestinationLabelBehavior.onlyShowSelected,
          destinations: [
            for (final tab in shown)
              tab.navDestination(onMenu: _navMenuFor(tab)),
            // One slot, holding whichever of the two is needed. While
            // anything is behind "more" that is where the settings live, as
            // they always have; with every tab turned on there is nothing left
            // for "more" to hold, and the slot becomes the settings themselves
            // rather than a sheet with one row in it.
            //
            // Settings is not an `AppTab` either way: it is never arranged,
            // never stored, and never one of the pages the index above
            // addresses — tapping it pushes rather than switches.
            if (overflow > 0)
              NavigationDestination(
                icon: const ThemedIcon(Icons.more_horiz),
                selectedIcon: const ThemedIcon(Icons.more_horiz),
                label: libL10n.more,
              )
            else
              NavigationDestination(
                icon: const ThemedIcon(Icons.settings_outlined),
                selectedIcon: const ThemedIcon(Icons.settings),
                label: libL10n.setting,
              ),
          ],
        );
      },
    );
  }

  /// The tabs that did not fit, and the way to change which ones those are.
  ///
  /// [shownCount] rather than the constant: the bar shows fewer than that when
  /// fewer are enabled, and the split has to be the one the bar actually made.
  Future<void> _showMoreSheet(int shownCount) async {
    final overflow = _tabs.skip(shownCount).toList();
    final selected = _selectIndex.value;

    await showRowsSheet<void>(
      context,
      rows: (ctx) => [
        for (final tab in overflow)
          ListTile(
            leading: tab.icon,
            title: tab.listTitle,
            selected: _tabs.indexOf(tab) == selected,
            onTap: () {
              // The sheet closes itself; the page it came from is what
              // switches tabs, on the navigator that owns the tabs.
              Navigator.of(ctx).pop();
              _onDestinationSelected(_tabs.indexOf(tab));
            },
          ),
        const Divider(height: 1),
        // Where the tabs are arranged, reachable from the bar they arrange
        // rather than only from four levels into the settings tree. The
        // same page either way — this pushes it, settings embeds it.
        ListTile(
          leading: const Icon(Icons.tab_outlined),
          title: Text(l10n.homeTabs),
          onTap: () {
            Navigator.of(ctx).pop();
            HomeTabsConfigPage.route.go(context);
          },
        ),
        // The bar has no settings slot of its own while this sheet exists —
        // the slot is the one this sheet came out of. It takes that slot back
        // when every tab is on and there is no sheet to raise.
        ListTile(
          leading: const Icon(Icons.settings),
          title: Text(libL10n.setting),
          onTap: () {
            Navigator.of(ctx).pop();
            _openSettings();
          },
        ),
      ],
    );
  }

  /// The rail, with the same "more" the bottom bar has.
  ///
  /// It had none, which was two things wrong at once. The tabs the user left
  /// out of the bar were unreachable on a wide window — nothing there listed
  /// them — and `_selectIndex` addresses every tab while the destinations were
  /// only the ones in the bar, so arriving on one of the others tripped
  /// `NavigationRail`'s own `selectedIndex < destinations.length` assert. That
  /// is reachable without any wide-window navigation at all: the tab the app
  /// reopens on is restored by name, and a window can be widened while one of
  /// them is showing.
  ///
  /// The rail also runs out of *height*, which the bar never does — so what is
  /// behind "more" here is the tabs the user hid plus however many of the rest
  /// do not fit. Both are the same thing to everything downstream, because the
  /// rail draws the first `shown` of [_tabs] and `_showMoreSheet` takes the
  /// remainder, exactly as the bar does.
  Widget _buildRailBar() {
    return SafeArea(
      // Anchored to the start, so the inset on the far side is not its to
      // keep clear: taking it would make the rail wider than the room the
      // `Row` holds open for it, by however much the other edge is cut off.
      right: false,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final capacity = railCapacity(
            height: constraints.maxHeight,
            destinationExtent: railDestinationExtent,
          );
          final shown = railShownCount(
            wanted: _barTabs.length,
            total: _tabs.length,
            capacity: capacity,
          );
          return _buildRail(shown: shown);
        },
      ),
    );
  }

  Widget _buildRail({required int shown}) {
    final more = shown < _tabs.length;
    return ListenableBuilder(
      listenable: _selectIndex,
      builder: (context, _) {
        if (_isServerFullscreenMode) return UIs.placeholder;
        return AppNavRail(
          key: _navKey,
          // Past the rail's own tabs, what is open is inside "more" — which is
          // then what the last item stands for, and is lit to say so. The bar
          // does the same.
          //
          // Out of range while the settings are showing, so that nothing in
          // the rail is lit but the foot of it: the tab underneath is still
          // the one that will come back, but it is not what is on screen.
          selectedIndex: _settingsOpen
              ? -1
              : (_selectIndex.value < shown ? _selectIndex.value : shown),
          items: [
            for (final tab in _tabs.take(shown))
              tab.navRailItem(onMenu: _navMenuFor(tab)),
            if (more)
              NavRailItem(
                icon: const ThemedIcon(Icons.more_horiz),
                selectedIcon: const ThemedIcon(Icons.more_horiz),
                label: libL10n.more,
              ),
          ],
          onSelected: (index) {
            if (index < shown) return _onDestinationSelected(index);
            unawaited(_showMoreSheet(shown));
          },
          // An item like the rest, laid out under them rather than stacked
          // over them: pinned by a `Positioned` it sat on top of the last tab
          // whenever the rail was full, and covered it. Lit like a destination
          // because that is what it is — what it shows arrives beside this
          // rail rather than over it.
          footer: NavRailItem(
            icon: const ThemedIcon(Icons.settings_outlined),
            selectedIcon: const ThemedIcon(Icons.settings),
            label: libL10n.setting,
          ),
          footerSelected: _settingsOpen,
          onFooterTap: _openSettings,
        );
      },
    );
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
      // Every server asked again whether it is a host: the one thing to do to
      // the whole set, and otherwise a trip into the host switcher.
      AppTab.virt => (
        title: l10n.virtualization,
        actions: [
          ContextMenuAction(
            text: l10n.virtCheckAll,
            icon: MingCute.refresh_2_line,
            onTap: () =>
                unawaited(ref.read(virtHostsProvider.notifier).refresh()),
          ),
        ],
      ),
      _ => null,
    };
    if (menu == null) return null;
    return (at) =>
        showContextMenu(context, menu.actions, title: menu.title, at: at);
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
        libL10n.askContinue(
          '${libL10n.close} ${libL10n.all} ${libL10n.terminal}',
        ),
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
