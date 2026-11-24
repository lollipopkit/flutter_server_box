part of 'tab.dart';

extension _Pane on _ServerPageState {
  Widget _buildPanes({
    required List<StatusCardItem> filtered,
    required StatusCardItem? openItem,
    required StatusCardItem? heroItem,
    required Widget Function(double pageInset) grid,
  }) {
    // Wrap the sidebar list in a RepaintBoundary so sliding it in/out does
    // not repaint every tile on every frame.
    final column = RepaintBoundary(child: _buildServerColumn(filtered, openItem));
    final morphHero = heroItem is ServerCardItem;
    // Built once per pane build (not inside `surfaceBuilder`), wrapped in a
    // RepaintBoundary so animating the pane width never reconstructs the detail
    // tree or invalidates its cached GPU layer on every frame.
    final detailChild = heroItem == null
        ? null
        : RepaintBoundary(child: _buildOpenDetail(heroItem));
    // Cache the non-morphing grid by width alone so folding `ServerStrip`
    // (which changes height each frame) does not rebuild it.
    final staticCardsByWidth = <double, Widget>{};

    return LayoutBuilder(
      builder: (_, outer) => PaneSettings.listenAll((width, collapsed) {
        final splitEnabled = heroItem != null && _opensInPlace(context);
        // Mirror `AdaptivePanes`'s own `roomForTwo` breakpoint & width clamp
        // so `detailChild` is laid out at its final resting width from frame 0
        // (including on 800..872pt windows where the rail leaves < 800pt).
        final roomForTwo =
            splitEnabled && outer.maxWidth >= AdaptivePanes.kSplitWidth;
        final maxList = (outer.maxWidth / 2).clamp(160.0, 520.0);
        final restingInset = roomForTwo && !collapsed
            ? width.clamp(160.0, maxList) + PaneDivider.hitWidth
            : 0.0;

        return AdaptivePanes.surface(
          enabled: splitEnabled,
          presence: _open,
          listWidth: width,
          onListWidthChanged: PaneSettings.saveWidth,
          collapsed: collapsed,
          onCollapsedChanged: PaneSettings.saveCollapsed,
          collapseTooltip: libL10n.fold,
          expandTooltip: libL10n.open,
          listBuilder: (_, _) => column,
          surfaceBuilder: (_, _) => LayoutBuilder(
            builder: (_, inner) {
              final t = _open.value;
              // Guard tiny `t` (e.g. first frame of `easeInOutCubic` ≈ 4e-6)
              // against floating-point division amplification.
              final pageInset = t > 0.01
                  ? (outer.maxWidth - inner.maxWidth) / t
                  : restingInset;
              final detailWidth = t >= 1
                  ? inner.maxWidth
                  : (outer.maxWidth - pageInset).clamp(0.0, outer.maxWidth);

              final cardsChild = !morphHero
                  ? staticCardsByWidth.putIfAbsent(
                      outer.maxWidth,
                      () => KeyedSubtree(
                        key: const ValueKey('cards'),
                        child: ClipRect(
                          child: OverflowBox(
                            alignment: Alignment.centerRight,
                            minWidth: outer.maxWidth,
                            maxWidth: outer.maxWidth,
                            child: grid(0),
                          ),
                        ),
                      ),
                    )
                  : KeyedSubtree(
                      key: const ValueKey('cards'),
                      child: ClipRect(
                        child: OverflowBox(
                          alignment: Alignment.centerRight,
                          minWidth: outer.maxWidth,
                          maxWidth: outer.maxWidth,
                          child: grid(pageInset),
                        ),
                      ),
                    );

              // Unify Server morph and BMC/Uptimer crossfade under ONE Stack
              // with constant keyed wrapper chains so:
              // 1. Opening/closing BMC or Uptimer never unmounts the Grid.
              // 2. Switching Server ↔ BMC/Uptimer keeps `DirectionalSwap`
              //    alive without losing its directional slide.
              // 3. `detailChild` keeps a constant layout width across flight.
              final cardsSlot = IgnorePointer(
                key: const ValueKey('cards_slot'),
                ignoring: !morphHero && heroItem != null && t > 0.05,
                child: FadeTransition(
                  opacity: (!morphHero && heroItem != null)
                      ? _cardsFadeOut
                      : kAlwaysCompleteAnimation,
                  child: cardsChild,
                ),
              );

              final detailSlot = detailChild == null
                  ? null
                  : IgnorePointer(
                      key: const ValueKey('detail_slot'),
                      ignoring: !morphHero && t < 0.15,
                      child: FadeTransition(
                        opacity: morphHero
                            ? kAlwaysCompleteAnimation
                            : _detailFadeIn,
                        child: ColoredBox(
                          color: morphHero
                              ? Colors.transparent
                              : Theme.of(context).scaffoldBackgroundColor,
                          child: ClipRect(
                            child: OverflowBox(
                              // For BMC/Uptimer, pin to `topRight` (final
                              // screen position `[restingInset, outer.maxWidth]`)
                              // so `StatusElementFlight` flies along a straight
                              // line with zero seam; for Server, keep `topLeft`
                              // so `ServerDetailPage.left` tracks the sliding
                              // sidebar edge cleanly.
                              alignment: morphHero
                                  ? Alignment.topLeft
                                  : Alignment.topRight,
                              minWidth: detailWidth,
                              maxWidth: detailWidth,
                              minHeight: inner.maxHeight,
                              maxHeight: inner.maxHeight,
                              child: detailChild,
                            ),
                          ),
                        ),
                      ),
                    );

              final showCards = !_detailShowing || heroItem == null;

              return Stack(
                fit: StackFit.expand,
                children: [
                  if (morphHero) ...[
                    ?detailSlot,
                    if (showCards) cardsSlot,
                    if (heroItem case ServerCardItem(:final id))
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
                        child: ServerOpenFuncBar(
                          id: id,
                          open: _open,
                          visible: _funcBarVisible,
                        ),
                      ),
                  ] else ...[
                    if (showCards) cardsSlot,
                    ?detailSlot,
                  ],
                ],
              );
            },
          ),
        );
      }),
    );
  }

  Widget _buildServerColumn(
    List<StatusCardItem> filtered,
    StatusCardItem? openItem,
  ) {
    Widget tile(StatusCardItem item) => switch (item) {
      ServerCardItem(:final id) => Consumer(
        key: ValueKey(item.cardKey),
        builder: (_, ref, _) {
          final srv = ref.watch(serverProvider(id));
          final isOpen = item.cardKey == openItem?.cardKey;
          return ServerSideTile(
            spi: srv.spi,
            state: serverStateDot(srv),
            selected: isOpen,
            onTap: isOpen ? null : () => _openDetail(item),
          );
        },
      ),
      BmcCardItem(:final target) => Consumer(
        key: ValueKey(item.cardKey),
        builder: (_, ref, _) {
          final isOpen = item.cardKey == openItem?.cardKey;
          // Reuse the open detail page's session instead of polling the same
          // BMC concurrently via `bmcSummaryProvider`.
          final dotColor = isOpen
              ? BmcCard.statusDotColorFromBmc(ref.watch(bmcProvider(target.id)))
              : BmcCard.statusDotColor(
                  ref.watch(bmcSummaryProvider(target.id)),
                );
          return SideBarTile(
            title: target.name,
            live: true,
            liveColor: dotColor,
            selected: isOpen,
            onTap: isOpen ? null : () => _openDetail(item),
          );
        },
      ),
      UptimerCardItem(:final monitor) => SideBarTile(
        key: ValueKey(item.cardKey),
        title: monitor.name,
        live: true,
        liveColor: uptimerStatusColor(monitor.status),
        selected: item.cardKey == openItem?.cardKey,
        onTap: item.cardKey == openItem?.cardKey
            ? null
            : () => _openDetail(item),
      ),
    };

    return ListView(
      padding: EdgeInsets.only(
        top: 4,
        bottom: 4 + MediaQuery.paddingOf(context).bottom,
      ),
      children: [
        for (final group in groupByTag(filtered, (i) => i.tags)) ...[
          if (group.label case final label?) SideBarSection(label),
          for (final item in group.items) tile(item),
        ],
      ],
    );
  }
}
