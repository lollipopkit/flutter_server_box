part of 'tab.dart';

extension _Grid on _ServerPageState {
  /// The list, and the one card of it that has grown into the page.
  ///
  /// One widget for both, because they are one thing: opening a server does
  /// not replace the list with a page, it takes a card out of the grid and
  /// gives it the width. What is below the card once it has the width — the
  /// readings in full, the facts, the row of things to do — arrives after the
  /// movement has finished, so that only one thing is ever moving.
  Widget _buildGrid(List<String> filtered, String? openId) {
    // What the bar and the readings are of, and what the grid is animating.
    // The two are the same while a machine is open and differ on the way back
    // out: the selection goes first so that the page's chrome can leave, and
    // the card still has to shrink.
    final open = openId != null && filtered.contains(openId);
    final heroId = _heroId;
    final hero = heroId != null && filtered.contains(heroId);
    // What the list draws each machine as is asked inside the grid, where how
    // big the list is is known — see [ServerListDensity.autoFor].
    final stored = ServerDensityPref.of(_tag.value);
    final textScale = _textScale;
    final folded = Stores.setting.collapseUIDefault.fetch();

    // The sections, or null for one list. Cut before the sort is applied to
    // nothing — `filtered` is already in the chosen order, and grouping keeps
    // that order inside each section rather than replacing it.
    final servers = ref.read(serversProvider).servers;
    final groups = ServerListGrouping.of(_tag.value) == ServerListGrouping.tag
        ? groupByTag(filtered, (id) => servers[id]?.tags)
        : null;

    // Cards are as tall as what they have to say — a server that has not
    // connected is one line, one that has is several charts. Splitting them
    // round-robin into a `ListView` per column left a short column beside a
    // long one and gave each its own scroll position; they flow into whichever
    // column is shortest now, in one scrollable.
    //
    // The animated form, because everything that rearranges this grid does so
    // for a reason worth seeing: a server connects and its card grows, a tag
    // is picked and half of them leave, one is added or deleted. See
    // [AnimatedMasonry] — the card that moves is usually not the card anything
    // happened to, which is exactly why it has to be carried rather than
    // moved.
    //
    // Rebuilt on every frame of the opening, and only the one card that is
    // opening: what that card looks like at each point between is a lerp
    // inside it, so it has to be rebuilt to change, and the rest of them do
    // not change at all. Their widgets are built once out here, and Flutter
    // skips an element whose widget is the one it already has — otherwise
    // every card on screen, chart included, was rebuilt sixty times a second
    // to be drawn fainter. The grid's own geometry is not rebuilt either; the
    // render object is told the width directly.
    // Whose rows are unfolded, asked once for the whole grid: the answer is a
    // query, and the card being opened is built again on every frame.
    final unfolded = ServerCardExpanded.reader;

    // Kept between the builder's runs, and thrown away whenever this method is
    // called again — which is whenever anything that decides what a card looks
    // like has changed.
    //
    // A `LayoutBuilder` runs its builder again whenever anything inside it is
    // dirty, not only when its constraints change, and during the movement
    // that is every frame. So this is where the cards would be built afresh
    // sixty times a second, each one to be drawn a little fainter.
    //
    // By the shape as well as the width: a window made shorter can be what
    // takes the list from cards to lines, with its width unchanged.
    final others = <(double, ServerListDensity), Map<String, Widget>>{};

    final grid = LayoutBuilder(
      builder: (_, cons) {
        // What `auto` comes to here, whether or not it is what is chosen: the
        // bar says so beside the choice — see [_publishAuto].
        final auto = ServerListDensity.auto.resolve(
          count: filtered.length,
          textScale: textScale,
          viewport: cons.biggest,
          folded: folded,
        );
        _publishAuto(auto);
        final density = stored == ServerListDensity.auto
            ? auto
            : stored.resolve(
                count: filtered.length,
                textScale: textScale,
                viewport: cons.biggest,
                folded: folded,
              );
        final rest = others.putIfAbsent(
          (cons.maxWidth, density),
          () => {
            for (final id in filtered)
              if (id != heroId)
                id: Consumer(
                  key: ValueKey(id),
                  builder: (_, ref, _) => _buildEachServerCard(
                    ref.watch(serverProvider(id)),
                    // How far the *page* has taken over, which is what fades
                    // the cards that are not the one being opened. An
                    // animation rather than a number, so the widget this
                    // returns is the one it returned last frame and Flutter
                    // skips it outright.
                    fade: hero ? _othersOpacity : null,
                    density: density,
                    pageWidth: cons.maxWidth,
                    expanded: unfolded(id),
                  ),
                ),
          },
        );
        // Every one of them, the whole way through. The rest used to be
        // taken out of the list while one was open, which made them leave
        // and then arrive again — a card growing in and shuffling into
        // place for each of them, on a page nobody had asked to rearrange.
        // They fade instead, and their slots are held for them.
        //
        // Its own `Consumer` per card, so a status poll rebuilds the one card
        // whose server answered rather than the grid. Watched from this page's
        // `ref` — which is what a builder would have to do — any server's
        // reading landing rebuilt every card on screen.
        Widget cardOf(String id) =>
            rest[id] ??
            Consumer(
              key: ValueKey(id),
              builder: (_, ref, _) => _buildEachServerCard(
                ref.watch(serverProvider(id)),
                openness: _open.value,
                density: density,
                // The box the page will have, which is this same box: the
                // grid and the page it becomes are the two children of one
                // crossing. The page asks its own width the same question, so
                // both arrive at the same answer about the facts column.
                pageWidth: cons.maxWidth,
                expanded: unfolded(id),
              ),
            );

        // One section, or the whole list as one. [scrollable] is off for a
        // grouped list, where the page owns the scrolling and each section is
        // laid out inside it.
        AnimatedMasonry masonry(List<String> ids, {required bool scrollable}) =>
            AnimatedMasonry(
              controller: scrollable ? _scrollController : null,
              scrollable: scrollable,
              // Constant. The card growing out of the grid needs the page's
              // inset rather than the grid's, but taking it from here would
              // change every column's width — so every other card would slide
              // sideways for a movement that is not about them. The card makes
              // up the difference in its own padding instead.
              padding: scrollable ? MasonryList.kPadding : EdgeInsets.zero,
              // The cards make way at the same pace as the one growing, so the
              // whole thing reads as one movement rather than as a card
              // growing into a grid that is still settling.
              moveDuration: context.motion(_kOpenDuration),
              changeDuration: context.motion(Durations.medium2),
              // The column each shape wants: a line per machine takes the
              // width, a tile takes as little as a name needs, and a card
              // takes the one width the rest of the app lays a column out at.
              columnWidth: switch (density) {
                ServerListDensity.grid => 170.0,
                ServerListDensity.rows => double.infinity,
                _ => UIs.columnWidth,
              },
              // And how much air each shape wants around it: a wall of tiles
              // reads as a wall at the design's 5, and a list of lines as a
              // list at nothing at all.
              spacing: switch (density) {
                ServerListDensity.grid => 5.0,
                ServerListDensity.rows => 0.0,
                _ => MasonryList.kSpacing,
              },
              // Only the section the card is in: the others have no card to
              // expand, and a key they do not hold is one they ignore.
              expandedKey: hero && ids.contains(heroId)
                  ? ValueKey(heroId)
                  : null,
              expansion: _open.value,
              // One for every section: a card is known by its server, and is
              // the same height whichever section it is in.
              memory: _gridMemory,
              children: [for (final id in ids) cardOf(id)],
            );

        if (groups == null) {
          return AnimatedBuilder(
            animation: _open,
            builder: (_, _) => masonry(filtered, scrollable: true),
          );
        }

        // A section each, under one scroll position. A masonry per section
        // rather than one with headings in it: the headings span the row and a
        // masonry lays its children into columns, so a heading placed in one
        // would sit in a column beside the cards it is a heading for.
        //
        // The cost is that a card moving between sections — a tag edited — is
        // a card leaving one grid and arriving in another rather than one
        // travelling, which is a fade rather than a flight. That is the right
        // way round: what moved it was not the list rearranging itself.
        return AnimatedBuilder(
          animation: _open,
          builder: (_, _) => SingleChildScrollView(
            controller: _scrollController,
            padding: MasonryList.kPadding,
            physics: const AlwaysScrollableScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final (at, group) in groups.indexed) ...[
                  ServerGroupHeading(
                    label: group.label,
                    ids: group.items,
                    first: at == 0,
                  ),
                  masonry(group.items, scrollable: false),
                ],
              ],
            ),
          ),
        );
      },
    );

    // The page is mounted for the whole movement, under the card that is
    // becoming it. What it has that a card has not — the facts beside the
    // readings, the tables under them — comes in while the chart is still
    // growing, rather than after: a card growing into a page and then the page
    // filling in is two arrivals for one tap. Its own readings are laid out
    // and not painted until the card hands them over, since the card is
    // already drawing exactly those widgets in exactly those boxes.
    //
    // The strip above both belongs to neither: it is what the list becomes
    // while one of its cards is open, so it stays whichever of the two is on
    // screen.
    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ServerStrip(
          ids: filtered,
          openId: openId,
          open: _open,
          onOpen: _openDetail,
        ),
        Expanded(
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (hero) _buildOpenDetail(heroId),
              // Dropped the moment the page takes the readings over rather
              // than crossed with it: at that point both are drawing the same
              // widgets in the same places, so a crossing would have nothing
              // to carry and 200ms to carry it in.
              if (!_detailShowing)
                KeyedSubtree(key: const ValueKey('cards'), child: grid),
              // Above both, and the tab's rather than the page's — see
              // [ServerOpenFuncBar].
              if (hero)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: ServerOpenFuncBar(
                    id: heroId,
                    open: _open,
                    visible: _funcBarVisible,
                  ),
                ),
            ],
          ),
        ),
      ],
    );

    // Pulling is how a phone asks for this, and the only place anything asks
    // for the whole list at once — the bar's refresh button is gone. Nothing
    // is lost that a pointer cannot reach: the status poll runs on its own,
    // and each card carries its own refresh for the one server behind it.
    if (!isMobile) return body;
    // Around the body whether or not a machine is open, and told not to
    // listen while one is. Left off instead, it was a parent the body had at
    // one moment and not the next: the page, the grid, the strip and the row
    // of things to do were all unmounted and built again when a card was
    // tapped, and again when the selection was cleared — which is the first
    // frame of the way back.
    return RefreshIndicator(
      onRefresh: _refreshAll,
      notificationPredicate: open
          ? (_) => false
          : defaultScrollNotificationPredicate,
      child: body,
    );
  }


  Future<void> _refreshAll() async {
    await ref.read(serversProvider.notifier).refresh();
  }

  Widget _buildEachServerCard(
    ServerState srv, {
    double openness = 0,
    Animation<double>? fade,
    ServerListDensity density = ServerListDensity.cards,
    double pageWidth = 0,
    bool expanded = false,
  }) {
    final card = Builder(
      // A context from inside the built tree, so the tap can ask whether a
      // detail pane is on screen, and a menu can be hung off the box this
      // built. The state's own context is an ancestor of the layout that
      // installs the scope, and the lookup only goes up.
      builder: (context) {
        return ServerCard(
          key: ValueKey(srv.spi.id),
          srv: srv,
          promoted: _promotedOf(srv.spi.id),
          onPromote: (kind) => _promote(srv.spi.id, kind),
          expanded: expanded,
          onToggleExpanded: () => _toggleExpanded(srv.spi.id),
          // While a set is being built up, a tap is what adds to it: there is
          // nothing else a tap could mean with boxes beside every name, and
          // having to hit the box itself is a 19pt target on a 40pt row.
          onTap: () => _selecting
              ? _toggleSelected(srv.spi.id)
              : _onTapCard(context, srv),
          onLongPress: () =>
              _onLongPressCard(context, srv, density: density),
          openness: openness,
          density: density,
          pageWidth: pageWidth,
          // The same answer `_onTapCard` acts on.
          opensInPlace: _opensInPlace(context),
          selected: _selecting ? _selected.contains(srv.spi.id) : null,
          // Do not show the list highlight while the card is becoming a page.
          highlighted: openness <= 0 && srv.spi.id == _menuId,
        ).onSecondary(
          (at) => _onLongPressCard(context, srv, at: at, density: density),
        );
      },
    );

    // Out of the way of the one being opened, and out of reach while it is:
    // a card that cannot be seen should not be what a tap lands on.
    //
    // The boundary is what makes the fade cheap. Without it the card is
    // rasterised into the opacity layer again on every frame; with it the
    // layer keeps the card's own picture and only its alpha changes.
    //
    // Around every card the whole time, the open one and a grid at rest
    // included, with nothing to fade by. Put on when a machine opened and
    // taken off when it closed, these were a different widget at the same
    // place: every card but the open one was unmounted and built from nothing
    // on the first frame of the movement and again on the last. Fully opaque,
    // the transition paints its child directly and costs no layer.
    return IgnorePointer(
      ignoring: fade != null,
      child: FadeTransition(
        opacity: fade ?? kAlwaysCompleteAnimation,
        child: RepaintBoundary(child: card),
      ),
    );
  }
}
