// ignore_for_file: invalid_use_of_protected_member

part of 'entry.dart';

/// How the settings are laid out: the menu beside the content on a wide
/// window, and on a narrow one the list with the tabs floating over it.
extension _SettingsLayout on _SettingsPageState {
  /// The subject [id] is under, and null for a page that is its own subject.
  static SettingsNode? _branchOf(List<SettingsNode> nodes, String id) {
    for (final node in nodes) {
      if (node.isLeaf) continue;
      if (node.children.any((e) => e.id == id)) return node;
    }
    return null;
  }

  /// The pages shown beside the one selected: what its subject holds, or it
  /// alone.
  ///
  /// A top-level page gets no tabs. It used to be given the other top-level
  /// pages as siblings — Container, Private key, BMC accounts and About in one
  /// row — which is the menu's job and not a level's.
  static List<SettingsNode> _levelFor(List<SettingsNode> nodes, String id) {
    final branch = _branchOf(nodes, id);
    if (branch != null) return branch.children.where((e) => e.isLeaf).toList();
    final leaf = nodes.firstWhereOrNull((e) => e.isLeaf && e.id == id);
    return leaf == null ? const [] : [leaf];
  }

  /// The level [node] leads to: what is inside a branch, and a leaf alone.
  ///
  /// A leaf on its own gets no tabs. There is one page and nothing to move
  /// between, and a bar with a single tab on it says only what the title bar
  /// above it already said.
  static List<SettingsNode> _levelOf(SettingsNode node) {
    return node.isLeaf ? [node] : node.children;
  }

  Widget _buildScaffold({
    required bool wide,
    required Widget menu,
    required List<SettingsNode> nodes,
    required SettingsNode selected,
    required List<SettingsHit> hits,
  }) {
    // What the search found, built here because both layouts need it and
    // neither may build the other's: only one of the two is in the tree.
    //
    // Drawn by [AppSettingsPage] rather than by this page, because what it
    // looks through is the rows that page builds — and it draws them as they
    // are drawn on their own page, so a switch found by searching is a switch.
    final results = _searching
        ? AppSettingsPage(
            // Ignored while searching, which looks at every section. It is
            // still the one this page would otherwise have been showing.
            section: SettingsSection.app,
            search: SettingsSearch(
              query: _query,
              pages: hits,
              onPage: _onHit,
            ),
          )
        : null;

    final content = _buildContent(
      wide: wide,
      nodes: nodes,
      selected: selected,
      results: results,
    );

    // The subject being read, and what else is in it. Its own row over the
    // content rather than the bar's title: the bar spans the menu column too,
    // and a row of tabs starting above the menu points at nothing there.
    final level = _levelFor(nodes, selected.id);
    final actions = _buildActions();
    final header = _SettingsContentHeader(
      title: _branchOf(nodes, selected.id)?.title ?? selected.title,
      nodes: level,
      selectedId: selected.id,
      onTap: _onSelect,
      actions: actions,
    );

    final scaffold = Scaffold(
      // None on a wide window. The menu says which subject, the header over
      // the content says which page and carries the two buttons that act on
      // the settings as a whole, and the settings are shown beside the rail
      // rather than over it — so a bar here named the page a third time and
      // spent 46 points saying it.
      //
      // A narrow one keeps it: there is no menu column beside the content to
      // name anything, and the way back out of a level is its button.
      appBar: wide
          ? null
          : CustomAppBar(
              // The list names itself; everything else is named by what it
              // shows.
              title: Text(
                // The count is a heading over the results, where the design
                // puts it — and it is one this page cannot work out anyway,
                // since most of what matched is rows rather than pages.
                _searching
                    ? libL10n.search
                    : (_path.isEmpty ? libL10n.setting : selected.title),
              ),
              // Out of the level rather than out of the settings, while there
              // is a level to leave. A leaf shown on its own has no tabs and
              // so no other way back to the list. A search is left the same
              // way, since on a narrow window it took the list's place.
              leading: _searching || _path.isNotEmpty
                  ? BackButton(
                      onPressed: _searching ? _clearSearch : _onTabBack,
                    )
                  : null,
              actions: actions,
            ),
      // The same column every other list-beside-content page has, rather than
      // a `Row` of its own. It used to be one, at a fixed 232 and with a plain
      // divider — so this was the one such column in the app that could not be
      // resized and, once folding arrived, the one that could not be folded.
      // Nothing about a menu of settings makes it a different kind of column.
      //
      // `minWidthForSide: 0` hands the decision to [wide], which is read from
      // the `LayoutBuilder` above and is what the app bar and the content are
      // already built from. Left to decide for itself it would be measuring
      // inside the `SafeArea` — a few points narrower — and a window sitting
      // on the breakpoint would get a title naming a page the layout was not
      // showing.
      body: SafeArea(
        child: PaneSettings.listenAll(
          (paneWidth, paneCollapsed) => AdaptivePanes.surface(
            enabled: wide,
            minWidthForSplit: 0,
            listWidth: paneWidth,
            onListWidthChanged: PaneSettings.saveWidth,
            collapsed: paneCollapsed,
            onCollapsedChanged: PaneSettings.saveCollapsed,
            collapseTooltip: libL10n.fold,
            expandTooltip: libL10n.open,
            listBuilder: (_, _) => menu,
            // A `Builder` so the insets read below are the ones this body
            // actually has: the state's own context is above the `Scaffold`,
            // where `padding` is still the whole window's — the status bar the
            // app bar already covers, and the home indicator the `SafeArea`
            // just above here already cleared.
            surfaceBuilder: (ctx, split) => split
                ? Column(
                    children: [
                      // Hidden rather than taken out of the tree: `Offstage`
                      // in a column takes no height, and a `Column` whose
                      // children come and go rebuilds what is under them —
                      // which here is the navigator, and rebuilding that is
                      // losing every page in it.
                      Offstage(offstage: _searching, child: header),
                      Expanded(
                        child: Stack(
                          children: [
                            // Still laid out under the results, which is what
                            // keeps the navigator and every page in it alive.
                            // Taken out of the focus chain though: Tab walking
                            // into a form nobody can see is the same bug as
                            // the caret leaving the field.
                            ExcludeFocus(excluding: _searching, child: content),
                            // Over the content rather than a page *of* it.
                            //
                            // As a page it was a route arriving, and a route
                            // arriving takes the focus — `ModalRoute.didPush`
                            // hands it to the new route's own scope. The field
                            // that put it there is in the menu column, outside
                            // this navigator, so the first character typed
                            // pushed a route and the field lost the caret.
                            if (results != null)
                              Positioned.fill(
                                // Faded in, because it arrives over a page
                                // that stays where it is: without it the first
                                // character typed replaced the form in one
                                // frame and read as the page having changed
                                // rather than as a search having started.
                                child: FadeIn(
                                  duration: Durations.short3,
                                  child: _opaque(
                                    ListView(
                                      padding: const EdgeInsets.fromLTRB(
                                        13,
                                        13,
                                        13,
                                        17,
                                      ),
                                      children: [results],
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  )
                : Builder(
                    builder: (ctx) => _buildNarrow(ctx, nodes, content),
                  ),
          ),
        ),
      ),
    );

    // The chord the field advertises, actually bound. `Focus` so the binding
    // has somewhere on this page to be reached from — `CallbackShortcuts`
    // reads the focus chain, and a page nobody has clicked in yet has nothing
    // on it. Traversal skipped, so Tab still walks the real controls.
    if (!isDesktop) return scaffold;
    return CallbackShortcuts(
      bindings: {_kSearchShortcut: _searchFocus.requestFocus},
      child: Focus(autofocus: true, skipTraversal: true, child: scaffold),
    );
  }

  /// What acts on the settings as a whole: the log, and clearing everything.
  List<Widget> _buildActions() {
    return [
      Btn.text(
        text: context.libL10n.logs,
        onTap: () => DebugPage.route.go(
          context,
          args: DebugPageArgs(
            title: '${context.libL10n.logs}(${BuildData.build})',
          ),
        ),
        // The crash menu, behind a long press on the button next to the thing
        // it is for, rather than a second button in a bar that is already four
        // wide.
        //
        // `kDebugMode` is a const, so a release does not register the gesture
        // and `CrashDebugMenu` — with everything it reaches — is tree shaken
        // out rather than shipped behind a gesture nobody is told about.
        onLongTap: kDebugMode ? () => CrashDebugMenu.show(context) : null,
      ),
      Btn.icon(
        text: libL10n.delete,
        icon: const Icon(Icons.delete),
        onTap: () => context.showRoundDialog(
          title: libL10n.attention,
          child: SimpleMarkdown(
            data: libL10n.askContinue(
              '${libL10n.delete} **${libL10n.all}** ${libL10n.setting}',
            ),
          ),
          actions: [
            CountDownBtn(
              onTap: () {
                context.popDialog();
                _clearAllSettings();
              },
              afterColor: Colors.red,
            ),
          ],
        ),
      ),
    ];
  }

  /// A background and the width cap, round whatever the content pane shows.
  ///
  /// A route sliding in has to be opaque, or what it is covering shows through
  /// it for the length of the transition. The pages under here are
  /// `embedded: true` and drop their own `Scaffold`, so without this nothing
  /// gives them a background at all — the one behind belongs to the `Scaffold`
  /// this whole page is in, and both routes were letting it, and each other,
  /// through.
  ///
  /// The `Scaffold`'s colour and not `colorScheme.surface`: that is the slot
  /// `toAmoled` overrides, and the surface one it leaves alone.
  ///
  /// The cap goes on what is *in* the page, never on the page. A route sliding
  /// in is as wide as the pane; a navigator inside a narrower box slides the
  /// whole transition inside that box, so the page appeared to come out of a
  /// panel in the middle rather than in from the edge. The `Material` stays
  /// full width for the same reason — it is the background the transition is
  /// drawn against.
  Widget _opaque(Widget child) => Material(
    color: Theme.of(context).scaffoldBackgroundColor,
    // Told to expand inside the cap: a `Center` hands down loose constraints,
    // under which a page's list takes the height of its content rather than
    // the height of the pane.
    child: Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: _kContentMaxWidth),
        child: SizedBox.expand(child: child),
      ),
    ),
  );

  Widget _buildSearchField() => _SettingsSearchField(
    controller: _searchCtrl,
    focusNode: _searchFocus,
    onChanged: _onSearch,
    onClear: _clearSearch,
  );

  /// The levels, as pages of a navigator.
  ///
  /// Declarative rather than pushed by hand: [_path] already says which levels
  /// are open, and letting the navigator read it means the two cannot disagree.
  /// A level arriving or leaving the list is a `MaterialPage` doing so, which is
  /// where the transition comes from.
  Widget _buildContent({
    required bool wide,
    required List<SettingsNode> nodes,
    required SettingsNode selected,
    required Widget? results,
  }) {
    /// Keyed by the group it shows, never by what is selected inside it.
    ///
    /// Selecting is what a drag *does*: `onPageChanged` fires mid-settle and
    /// changes the selection, so a key naming the selection made every swipe
    /// throw away the state — and with it the `PageController` — that the
    /// settle was running on. It reappeared at the new page with the movement
    /// cut off, which is the swipe not feeling like a swipe.
    Widget pagesOf(List<SettingsNode> level) {
      final leaves = level.where((e) => e.isLeaf).toList();
      return _SettingsPages(
        key: ValueKey('pages_${leaves.firstOrNull?.id ?? 'none'}'),
        leaves: leaves,
        selectedId: selected.id,
        onChanged: _onSelect,
      );
    }

    final level = _levelFor(nodes, selected.id);

    final navigator = Navigator(
      key: _contentNav,
      pages: [
        if (wide)
          // Never keyed by the search: the results are drawn over this
          // navigator, not as a page of it — see where they are laid out.
          MaterialPage<void>(
            key: ValueKey(level.firstOrNull?.id ?? 'root'),
            child: _opaque(pagesOf(level)),
          )
        else ...[
          // What settings there are, which is where a narrow window starts.
          MaterialPage<void>(
            key: const ValueKey('root'),
            child: _opaque(
              _SettingsList(
                nodes: nodes,
                onTap: _onTab,
                search: _buildSearchField(),
                results: results,
              ),
            ),
          ),
          for (final entered in _path)
            MaterialPage<void>(
              key: ValueKey(entered.id),
              child: _opaque(pagesOf(_levelOf(entered))),
            ),
        ],
      ],
      onDidRemovePage: (page) {
        // A page can also go because the system back gesture took it. What the
        // tabs show comes from [_path], so it has to hear about that.
        if (_path.isEmpty) return;
        if ((page.key as ValueKey?)?.value == _path.last.id) {
          setState(_path.removeLast);
        }
      },
    );

    // Platform back belongs to this stack while it has somewhere to go. Without
    // a pop handler the enclosing navigator removes the whole settings route,
    // skipping whichever level or manually pushed page is currently on top.
    return NavigatorPopHandler(
      onPopWithResult: (_) => _contentNav.currentState?.pop(),
      child: navigator,
    );
  }

  /// The content with the tabs floating over its foot.
  ///
  /// The content fills the body and the bar sits over it, so what is on the page
  /// carries on under the bar instead of stopping at a bare strip above it. The
  /// room a list needs to bring its last row into the clear arrives as
  /// [MediaQuery] padding, which `context.padBottom` puts on the scrollable —
  /// padding a list can scroll through, rather than a strip taken out of the
  /// page's box.
  ///
  /// [context] has to be one from inside the body — see where this is called.
  Widget _buildNarrow(
    BuildContext context,
    List<SettingsNode> nodes,
    Widget content,
  ) {
    final mediaQuery = MediaQuery.of(context);
    // Nothing over the list — a bar of tabs there would be the same names
    // twice — and nothing over a leaf, which has no level under it to show.
    final entered = _path.lastOrNull;
    final level = entered == null || entered.isLeaf ? null : entered;
    final space = level == null ? 0.0 : _kTabsHeight + _kTabsMargin * 2;

    return Stack(
      // Nothing here should reach past the floor of this box — the page is
      // pushed into the home tab's navigator, and the `Scaffold` paints its
      // bottom bar after the body, so anything that does is covered rather than
      // shown. `none` only keeps the clip from being what cuts it: the bar
      // carries its own margin, so it stops short of the floor on its own.
      clipBehavior: Clip.none,
      children: [
        MediaQuery(
          data: mediaQuery.copyWith(
            padding: mediaQuery.padding.copyWith(
              bottom: mediaQuery.padding.bottom + space,
            ),
          ),
          child: content,
        ),
        // Edge to edge, and the bar centres itself within that: it is as wide
        // as the level it is showing, and only scrolls when that is too wide.
        //
        // Flush with the floor, because the gap the bar stands in is padding
        // inside it now. Lifting it from here as well would move it up by that
        // much again, and put the shadow back outside the clip it just left.
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: AnimatedSwitcher(
            duration: Durations.medium2,
            // Springs up past its place and settles, as displacement does
            // elsewhere. No fade with it: the curve overshoots, and an opacity
            // past 1 asserts.
            switchInCurve: _kTabsCurve,
            switchOutCurve: Curves.easeIn,
            transitionBuilder: (child, animation) => SlideTransition(
              position: Tween(
                // Far enough to take the shadow with it.
                begin: const Offset(0, 1.4),
                end: Offset.zero,
              ).animate(animation),
              child: child,
            ),
            child: level == null
                ? const SizedBox(key: ValueKey('no_tabs'), width: double.infinity)
                : _SettingsTabs(
                    key: ValueKey(level.id),
                    nodes: _levelOf(level),
                    selectedId: _selectedId,
                    onTap: _onTab,
                  ),
          ),
        ),
      ],
    );
  }
}
