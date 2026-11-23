part of 'tab.dart';

extension _Grid on _ServerPageState {
  EdgeInsets _scrollPadding(BuildContext context) =>
      MasonryList.kPadding.copyWith(
        bottom:
            MasonryList.kPadding.bottom + MediaQuery.paddingOf(context).bottom,
      );

  Widget _buildGrid(List<StatusCardItem> filtered, StatusCardItem? openItem) {
    final open = openItem != null;
    final heroKey = _heroId;
    final heroItem = heroKey == null
        ? null
        : filtered.firstWhereOrNull((i) => i.cardKey == heroKey);
    final hero = heroItem != null;
    final stored = ServerDensityPref.of(_tag.value);
    final textScale = _textScale;
    final folded = Stores.setting.collapseUIDefault.fetch();

    final groups = ServerListGrouping.of(_tag.value) == ServerListGrouping.tag
        ? groupByTag(filtered, (item) => item.tags)
        : null;

    final unfolded = ServerCardExpanded.reader;
    final others = <(double, ServerListDensity), Map<String, Widget>>{};

    Widget gridOf(
      BoxConstraints cons,
      ServerListDensity density,
      double pageInset,
    ) {
      final rest = others.putIfAbsent(
        (cons.maxWidth, density),
        () => {
          for (final item in filtered)
            if (item.cardKey != heroKey)
              item.cardKey: _buildItemConsumer(
                item,
                fade: hero ? _othersOpacity : null,
                density: density,
                pageWidth: cons.maxWidth,
                expanded: unfolded(item.id),
              ),
        },
      );

      Widget cardOf(StatusCardItem item) =>
          rest[item.cardKey] ??
          _buildItemConsumer(
            item,
            openness: _open.value,
            density: density,
            pageWidth: cons.maxWidth - pageInset,
            expanded: unfolded(item.id),
          );

      AnimatedMasonry masonry(
        List<StatusCardItem> items, {
        required bool scrollable,
      }) => AnimatedMasonry(
        controller: scrollable ? _scrollController : null,
        scrollable: scrollable,
        padding: scrollable ? _scrollPadding(context) : EdgeInsets.zero,
        moveDuration: context.motion(_kOpenDuration),
        changeDuration: context.motion(Durations.medium2),
        columnWidth: switch (density) {
          ServerListDensity.grid => 170.0,
          ServerListDensity.rows => double.infinity,
          _ => UIs.columnWidth,
        },
        spacing: switch (density) {
          ServerListDensity.grid => 5.0,
          ServerListDensity.rows => 0.0,
          _ => MasonryList.kSpacing,
        },
        expandedKey:
            heroItem != null && items.any((i) => i.cardKey == heroItem.cardKey)
                ? ValueKey(heroItem.cardKey)
                : null,
        expansion: _open.value,
        expandedInset: EdgeInsets.only(left: pageInset),
        memory: _gridMemory,
        children: [for (final item in items) cardOf(item)],
      );

      if (groups == null) {
        return AnimatedBuilder(
          animation: _open,
          builder: (_, _) => masonry(filtered, scrollable: true),
        );
      }

      return AnimatedBuilder(
        animation: _open,
        builder: (_, _) => SingleChildScrollView(
          controller: _scrollController,
          padding: _scrollPadding(context),
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final (at, group) in groups.indexed) ...[
                ServerGroupHeading(
                  label: group.label,
                  items: group.items,
                  first: at == 0,
                ),
                masonry(group.items, scrollable: false),
              ],
            ],
          ),
        ),
      );
    }

    Widget grid(double pageInset) => LayoutBuilder(
      builder: (_, cons) {
        if (hero ? _heroDensity : null case final held?) {
          return gridOf(cons, held, pageInset);
        }
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
        _heroDensity = hero ? density : null;
        return gridOf(cons, density, pageInset);
      },
    );

    final serverIds = [
      for (final item in filtered)
        if (item is ServerCardItem) item.id,
    ];

    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (serverIds.isNotEmpty)
          ValBuilder(
            listenable: Stores.setting.serverOverview.listenable(),
            builder: (shown) => shown
                ? ServerStrip(
                    ids: serverIds,
                    openId: openItem?.cardKey,
                    open: _open,
                  )
                : UIs.placeholder,
          ),
        Expanded(
          child: _buildPanes(
            filtered: filtered,
            openItem: openItem,
            heroItem: heroItem,
            grid: grid,
          ),
        ),
      ],
    );

    if (!isMobile) return body;
    return RefreshIndicator(
      onRefresh: _refreshAll,
      notificationPredicate: open
          ? (_) => false
          : defaultScrollNotificationPredicate,
      child: body,
    );
  }

  Widget _buildItemConsumer(
    StatusCardItem item, {
    double openness = 0,
    Animation<double>? fade,
    ServerListDensity density = ServerListDensity.cards,
    double pageWidth = 0,
    bool expanded = false,
  }) => switch (item) {
    ServerCardItem(:final id) => Consumer(
      key: ValueKey(item.cardKey),
      builder: (_, ref, _) {
        final srv = ref.watch(serverProvider(id));
        final linkedBmc = srv.conn == ServerConn.failed
            ? ref.watch(
                bmcTargetsProvider.select((s) => s.forServer(srv.spi.id)),
              )
            : null;
        final bmcSummary = linkedBmc != null && linkedBmc.isComplete
            ? ref.watch(bmcSummaryProvider(linkedBmc.id))
            : null;
        final bmcHealthy = bmcSummary != null && bmcSummary.failure == null;
        final bmcPower =
            bmcHealthy && bmcSummary.hasData ? bmcSummary.powerState : null;
        final bmcSystem = bmcHealthy ? bmcSummary.topology?.system : null;
        final canBmcPowerOn =
            linkedBmc != null &&
            bmcSystem != null &&
            bmcPlan(system: bmcSystem, intent: PowerIntent.on_) != null;
        return _buildEachServerCard(
          srv,
          openness: openness,
          fade: fade,
          density: density,
          pageWidth: pageWidth,
          expanded: expanded,
          bmcPower: bmcPower,
          bmcPowering: bmcSummary?.isPowering ?? false,
          onBmcPowerOn: canBmcPowerOn
              ? () => _onTapLinkedBmcPowerOn(srv.spi.id)
              : null,
        );
      },
    ),
    BmcCardItem(:final target) => _buildEachBmcCard(
      target,
      fade: fade,
      density: density,
    ),
  };

  Future<void> _onTapLinkedBmcPowerOn(String serverId) async {
    final target = ref.read(bmcTargetsProvider).forServer(serverId);
    if (target == null) return;
    await confirmAndRunBmcPowerOn(
      context: context,
      target: target,
      run: () {
        if (!mounted) return Future.value(BmcPowerResult.failed);
        final latest = ref.read(bmcTargetsProvider).forServer(serverId) ?? target;
        return ref
            .read(bmcSummaryProvider(latest.id).notifier)
            .power(PowerIntent.on_);
      },
    );
  }

  Future<void> _refreshAll() async {
    final futures = <Future<void>>[
      ref.read(serversProvider.notifier).refresh(),
      for (final item in _lastFiltered)
        if (item case BmcCardItem(:final target))
          ref.read(bmcSummaryProvider(target.id).notifier).refresh(force: true),
    ];
    await Future.wait(futures);
  }

  Widget _buildEachServerCard(
    ServerState srv, {
    double openness = 0,
    Animation<double>? fade,
    ServerListDensity density = ServerListDensity.cards,
    double pageWidth = 0,
    bool expanded = false,
    PowerState? bmcPower,
    bool bmcPowering = false,
    VoidCallback? onBmcPowerOn,
  }) {
    final cardKey = ServerCardItem.keyOf(srv.spi.id);
    final card = Builder(
      builder: (context) {
        return ServerCard(
          key: ValueKey(srv.spi.id),
          srv: srv,
          promoted: _promotedOf(srv.spi.id),
          onPromote: (kind) => _promote(srv.spi.id, kind),
          expanded: expanded,
          onToggleExpanded: () => _toggleExpanded(srv.spi.id),
          onTap: () => _selecting
              ? _toggleSelected(cardKey)
              : _onTapCard(context, srv),
          onLongPress: () => _onLongPressCard(context, srv, density: density),
          openness: openness,
          density: density,
          pageWidth: pageWidth,
          opensInPlace: _opensInPlace(context),
          selected: _selecting ? _selected.contains(cardKey) : null,
          highlighted: openness <= 0 && cardKey == _menuId,
          bmcPower: bmcPower,
          bmcPowering: bmcPowering,
          onBmcPowerOn: onBmcPowerOn,
        ).onSecondary(
          (at) => _onLongPressCard(context, srv, at: at, density: density),
        );
      },
    );

    return IgnorePointer(
      ignoring: fade != null,
      child: FadeTransition(
        opacity: fade ?? kAlwaysCompleteAnimation,
        child: RepaintBoundary(child: card),
      ),
    );
  }

  Widget _buildEachBmcCard(
    BmcTarget target, {
    Animation<double>? fade,
    ServerListDensity density = ServerListDensity.cards,
  }) {
    final cardKey = BmcCardItem.keyOf(target.id);
    final card = Builder(
      builder: (context) {
        return BmcCard(
          key: ValueKey(target.id),
          target: target,
          density: density,
          onTap: () => _selecting
              ? _toggleSelected(cardKey)
              : _onTapBmcCard(context, target),
          onLongPress: () => _onLongPressBmcCard(context, target),
          selected: _selecting ? _selected.contains(cardKey) : null,
          highlighted: cardKey == _menuId,
        ).onSecondary((at) => _onLongPressBmcCard(context, target, at: at));
      },
    );

    return IgnorePointer(
      key: ValueKey(cardKey),
      ignoring: fade != null,
      child: FadeTransition(
        opacity: fade ?? kAlwaysCompleteAnimation,
        child: RepaintBoundary(child: card),
      ),
    );
  }
}
