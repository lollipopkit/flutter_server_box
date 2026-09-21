part of 'tab.dart';

extension _Bar on _ServerPageState {
  /// The tag filter and the way to add a server, in the strip every other tab
  /// has: a switcher on the left that opens the rest in a sheet, buttons on
  /// the right.
  ///
  /// It was a pill floating over the grid, which withdrew on a timer and came
  /// back on a tap. That is one more thing to know about this tab than about
  /// any of the others, and the add button had to float with it — so the two
  /// controls this page has were both somewhere that had to be discovered.
  ///
  /// [SessionTabBar.height] rather than a bar of its own measurements: the
  /// strips are read as one line down the app, and a taller one here would
  /// shift the page contents by that much on every switch between tabs.
  PreferredSizeWidget _buildTagBar(String? openId, List<String> filtered) {
    if (_selecting) return _buildSelectionBar(filtered);
    return PreferredSizeListenBuilder(
      // Which tag is on, what tags there are to choose between, and how the
      // list is ordered — the sort button draws its own current icon.
      listenable: Listenable.merge([_tags, _tag, _sortVersion, _autoDensity]),
      // The wrapper is what the `Scaffold` measures, so it has to be told; its
      // own default is a full toolbar.
      preferSize: const Size.fromHeight(SessionTabBar.height),
      builder: () {
        return SizedBox(
          height: SessionTabBar.height,
          child: InlineSearchBar(
            controller: _search,
            child: LayoutBuilder(
              builder: (_, cons) => Row(
                children: [
                  // The way back comes first and takes no room when there is
                  // nowhere to go back to.
                  //
                  // Inset to where the switcher's own glyph sits when there is
                  // nothing open — `SessionSwitcherLabel` holds it 14 off the
                  // edge, and a button's own 7 is half of that — so the first
                  // thing in the bar is in the same place either way.
                  if (openId != null) const SizedBox(width: 7),
                  if (openId != null)
                    Btn.icon(
                      text: libL10n.close,
                      icon: const Icon(Icons.arrow_back_ios_new, size: 17),
                      onTap: _closeDetail,
                    ),
                  Expanded(
                    child: openId == null
                        ? _buildTagSwitcher()
                        : _buildServerSwitcher(openId, filtered),
                  ),
                  // Not while one is open: the page is one machine then, and
                  // how many of them fit on a screen is not a question it has.
                  if (openId == null)
                    _buildDensityControl(filtered.length, room: cons.maxWidth),
                  // The rest act on the list, and the list is still the page
                  // with one of its cards open — so they stay where they are
                  // rather than following a server into its own page.
                  ..._listActions(),
                  const SizedBox(width: 7),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /// How much of each machine the list draws.
  ///
  /// A real control where the bar has room for one — four positions with the
  /// current one filled, so what the other three are is visible rather than
  /// something to go looking for. Where it has not, the same four are a sheet
  /// behind a button, which is what the tag and the sort already do.
  Widget _buildDensityControl(int count, {required double room}) {
    final stored = ServerDensityPref.of(_tag.value);

    // Room for four labelled positions, the switcher beside them and the four
    // buttons after them. Below it the labels are what would have to shrink,
    // and a segmented control with no labels is four unexplained icons.
    if (room < 860) {
      final resolved = _resolvedDensity(stored, count);
      return Btn.icon(
        text: resolved.label,
        icon: Icon(resolved.icon, size: 18),
        onTap: () => _showDensitySheet(count),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 7),
      child: SegmentedTabs<ServerListDensity>(
        // Closed to the one it is set to until a pointer is over it. This is
        // changed once in a while and sits in a bar beside things used all
        // the time: four labelled positions were the widest and the brightest
        // thing in it, to say what one of them says. The room is still kept
        // for all four — see above — because it opens where it stands.
        collapse: true,
        segments: [
          for (final density in ServerListDensity.values)
            SegmentedTab(
              value: density,
              label: density.label,
              icon: density.icon,
            ),
        ],
        selected: stored,
        onSelected: _setDensity,
      ),
    );
  }

  /// How much larger than drawn the list's text is, which is what rules a
  /// tile out: the page's own scale, asked of the size a tile's name is.
  ///
  /// The system's share counts. It was the setting alone, so a phone set to
  /// large text was still given tiles its names did not fit in.
  double get _textScale =>
      ServerTextScale.of(context).scale(ServerCardSizes.name) /
      ServerCardSizes.name;

  /// What [stored] comes to, for the bar — which is not where the list is
  /// measured.
  ///
  /// For [ServerListDensity.auto] that is the grid's own answer when it has
  /// given one, since it is decided by how big the list is and only the grid
  /// knows. Before that — the globe is up, so there has been no grid — the
  /// window stands in for the list: the same question of a box a bar or two
  /// taller.
  ServerListDensity _resolvedDensity(ServerListDensity stored, int count) {
    if (stored == ServerListDensity.auto) {
      if (_autoDensity.value case final known?) return known;
    }
    return stored.resolve(
      count: count,
      textScale: _textScale,
      viewport: MediaQuery.sizeOf(context),
      folded: Stores.setting.collapseUIDefault.fetch(),
    );
  }

  /// Tells the bar what `auto` came to, once the frame that found out is over.
  ///
  /// Found during layout, which is too late to build the bar with and no time
  /// to mark it dirty in. Only when it changes: this runs on every layout of
  /// the grid, and a window being dragged wider is hundreds of them.
  void _publishAuto(ServerListDensity auto) {
    if (_autoDensity.value == auto) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _autoDensity.value = auto;
    });
  }

  void _setDensity(ServerListDensity density) {
    ServerDensityPref.put(_tag.value, density);
    _sortVersion.notify();
  }

  Widget _buildTagSwitcher() {
    final tags = _tags.value.toList();
    final current = _tag.value;
    final at = tags.indexOf(current);

    return SessionSwitcherLabel(
      name: current.isEmpty ? libL10n.all : '#$current',
      // Counting from 1, and null on "all" — which is not one of the tags but
      // the absence of a choice among them, so it shows the icon instead.
      position: at < 0 ? null : at + 1,
      total: tags.length,
      icon: MingCute.hashtag_line,
      // Opens even with no tags anywhere. It used to be a plain label then —
      // the rule the session strips follow with nothing open — but the two
      // cases are not alike: a terminal strip with no sessions is a feature
      // nobody has started using, while this is a filter whose whole
      // vocabulary is defined elsewhere. Someone looking for tags taps the
      // thing marked with a `#`, and a control that does nothing answers
      // neither "there are none" nor "here is where they come from". The
      // sheet says both.
      onTap: () => _showTagSheet(tags),
    );
  }

  /// Which machine is open, as the one control the detail needs of its own.
  ///
  /// The same shape the terminal tab's switcher has — position, name, chevron
  /// — because it answers the same question: this is one of several, and here
  /// is how to reach the others. The strip of pills over the card is the same
  /// list; this is what is left of it once there are more machines than pills
  /// that fit.
  Widget _buildServerSwitcher(String openId, List<String> filtered) {
    final at = filtered.indexOf(openId);
    final spi = ref.read(serversProvider).servers[openId];

    return SessionSwitcherLabel(
      name: spi?.name ?? openId,
      position: at < 0 ? null : at + 1,
      total: filtered.length,
      icon: BoxIcons.bx_server,
      onTap: () => _showServerSheet(filtered, openId),
    );
  }

  /// What acts on the list rather than on one server in it.
  ///
  /// Built by the tag bar alone, so the globe button carries [_globeBtnKey]
  /// for the guide to point at. A second caller drawing these while the bar is
  /// mounted would need its own key: two widgets holding one `GlobalKey` at
  /// the same time is an exception rather than a bad layout.
  List<Widget> _listActions() => [
    Btn.icon(
      text: libL10n.search,
      icon: const Icon(Icons.search, size: 18),
      onTap: _search.start,
    ),
    Btn.icon(
      text: libL10n.sort,
      icon: Icon(ServerSortOrder.of(_tag.value).icon, size: 18),
      onTap: _showSortSheet,
    ),
    // Absent, not disabled, when the feature is off: a button that explains
    // itself by doing nothing is worse than one that is not offered.
    if (Stores.setting.globeEnabled.fetch())
      _globe.listenVal(
        (on) => Btn.icon(
          key: _globeBtnKey,
          text: l10n.globe,
          icon: Icon(
            on ? Icons.grid_view_rounded : Icons.public,
            size: 18,
            color: on ? Theme.of(context).colorScheme.primary : null,
          ),
          onTap: _toggleGlobe,
        ),
      ),
    Btn.icon(
      text: libL10n.add,
      icon: const Icon(Icons.add, size: 18),
      onTap: _onTapAddServer,
    ),
  ];

  /// Starts the wait before [_maybeShowGlobeGuide], if there is anything to
  /// wait for.
  ///
  /// The two conditions checked here are the ones that do not change by
  /// waiting — the guide has been seen, or the feature is off — so a launch
  /// that fails either never arms a timer at all.
  void _scheduleGlobeGuide() {
    if (Stores.setting.globeGuided.fetch()) return;
    if (!Stores.setting.globeEnabled.fetch()) return;
    // Long enough for the launch notices to be up if there are any, so the
    // `isCurrent` check below has something to see. They are dialogs on the
    // root navigator and the guide draws above every route, so it would cover
    // one rather than wait for it.
    _globeGuideTimer = Timer(
      const Duration(seconds: 2),
      () => unawaited(_maybeShowGlobeGuide()),
    );
  }

  /// Points at the globe button, once per install.
  ///
  /// The server tab looks finished without it: a grid of cards with a row of
  /// icons over them, one of which happens to replace the whole list with a
  /// sphere. Nothing about the icon says that, and a view mode nobody presses
  /// is a view mode that does not exist.
  ///
  /// Every early return here leaves the guide for the *next launch* rather
  /// than retrying — the same rule the tab strip's guide follows, and the
  /// reason this runs once from [initState] rather than from a build.
  Future<void> _maybeShowGlobeGuide() async {
    final flag = Stores.setting.globeGuided;
    if (!mounted) return;
    // Already using it. Being shown where the button that is already pressed
    // is reads as the app not knowing what is on screen.
    if (_globe.value) return;
    // One walkthrough per launch, and the tab strip's comes first: it is about
    // how to reach anything at all. On a fresh install that puts this on the
    // second launch, which is also when there is something to look at.
    if (!Stores.setting.navTabMenuGuided.fetch()) return;
    // Nothing to place on a globe, and nothing worth interrupting a first run
    // with.
    if (ref.read(serversProvider).serverOrder.isEmpty) return;
    if (ModalRoute.of(context)?.isCurrent != true) return;
    // The tab is kept alive behind the others, so the wait above can finish
    // after the user has moved on — and the overlay draws above every route,
    // so it would point at a button on a page nobody is looking at. Null is
    // "nobody said", which is this widget mounted outside the home page.
    final tab = ref.read(currentHomeTabProvider);
    if (tab != null && tab != AppTab.server) return;

    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) return;
    // Null when the button is not built — the actions row is gone in full
    // screen landscape.
    final spot = rectInOverlay(_globeBtnKey.currentContext, overlay);
    if (spot == null) return;

    await GuideOverlay.show(context, [
      GuideStep(body: context.l10n.globeGuide, spot: spot),
    ]);
    // At most one per install, and the open half of a funnel `globe.open`
    // closes. The guide exists because an icon that replaces the list with a
    // sphere explains nothing about itself; whether it works is whether the
    // installs that saw it are the ones that later pressed the button, and
    // every early return above leaves an install that never saw it.
    Diag.crumb(SbDiag.globe, 'guide');
    // Written when it has been seen through, not when it was scheduled.
    flag.put(true);
  }

  void _toggleGlobe() {
    if (!_globe.value &&
        _filterServers(ref.read(serversProvider).serverOrder).isEmpty) {
      Toast.show(l10n.serverTabEmpty);
      return;
    }
    final on = !_globe.value;
    _globe.value = on;
    Stores.setting.serverPageGlobe.put(on);
    // The button is the feature's only front door, so this is what says whether
    // it is used at all. The pair matters rather than the opening alone: the
    // choice is remembered across launches, so a globe that is turned back off
    // is the one signal that someone tried it and did not keep it.
    Diag.crumb(SbDiag.globe, on ? 'open' : 'close');
  }

  /// [immersive] is the globe having the window rather than sharing it with a
  /// pane, which is what decides whether it has to carry its own way out: the
  /// bar holding the toggle is not on screen then, and neither is the
  /// navigation.
  Widget _buildGlobe(List<String> filtered, {bool immersive = false}) {
    return ServerGlobe(
      key: const ValueKey('globe'),
      ids: filtered,
      onTapServer: (spi) =>
          _onTapCard(context, ref.read(serverProvider(spi.id))),
      onEditServer: (spi) =>
          ServerEditPage.route.go(context, args: SpiRequiredArgs(spi)),
      action: immersive ? _buildGlobeExit() : null,
    );
  }

  /// The way back to the list, over the globe itself.
  ///
  /// The same icon the bar's toggle wears while the globe is up, because it is
  /// the same control — what is offered is the grid, and the icon says so.
  ///
  /// On a surface of its own rather than a bare icon: it sits over a sphere,
  /// a coastline or a card, and none of those is a background an icon reads
  /// against on its own.
  Widget _buildGlobeExit() {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surfaceContainerHigh.withValues(alpha: 0.92),
      elevation: 3,
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: IconButton(
        icon: const Icon(Icons.close, size: 18),
        tooltip: libL10n.close,
        onPressed: _toggleGlobe,
      ),
    );
  }

  /// Says whether the globe is filling this tab.
  ///
  /// Called from a build and applied after the frame, which is the same shape
  /// `_syncFullscreenSystemUi` on the home page has and for the same reason:
  /// the answer is only knowable while laying the page out — it depends on the
  /// split, the filter and the toggle — and a provider must not be written to
  /// during a build.
  void _publishImmersive(bool on) {
    if (_immersive == on) return;
    _immersive = on;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(immersiveTabProvider.notifier).update(AppTab.server, wants: on);
    });
  }
}
