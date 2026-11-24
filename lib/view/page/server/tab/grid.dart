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
    // Only [ServerCardItem] implements the pixel-matched in-place card morph
    // (`openness: 0..1`). Other resource cards (BMC, Uptimer) crossfade cleanly
    // in `_buildPanes` without stretching their card geometry.
    final morphHero = heroItem is ServerCardItem;
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
            if (!morphHero || item.cardKey != heroKey)
              item.cardKey: _buildItemConsumer(
                item,
                fade: morphHero ? _othersOpacity : null,
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
            openness: morphHero ? _open.value : 0,
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
            morphHero && items.any((i) => i.cardKey == heroItem.cardKey)
                ? ValueKey(heroItem.cardKey)
                : null,
        expansion: morphHero ? _open.value : 0,
        expandedInset: EdgeInsets.only(left: pageInset),
        memory: _gridMemory,
        children: [for (final item in items) cardOf(item)],
      );

      Widget buildBody() {
        if (groups == null) {
          return masonry(filtered, scrollable: true);
        }
        return SingleChildScrollView(
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
        );
      }

      // `AdaptivePanes.surface` already rebuilds `surfaceBuilder` on every
      // tick of `_open` when a Server card is morphing; avoid a redundant
      // inner `AnimatedBuilder` (and never rebuild the grid during BMC/Uptimer
      // GPU crossfades).
      return buildBody();
    }

    final uptimer = ref.watch(uptimerProvider);
    final itemGroups = groups?.map((g) => g.items).toList();

    Widget grid(double pageInset) => LayoutBuilder(
      builder: (_, cons) {
        _lastGridViewport = cons.biggest;
        _syncCardHeightCache(cons.biggest, textScale);
        if (hero ? _heroDensity : null case final held?) {
          return gridOf(cons, held, pageInset);
        }
        final auto = ServerListDensity.auto.resolveItems(
          filtered,
          groups: itemGroups,
          textScale: textScale,
          viewport: cons.biggest,
          folded: folded,
          uptimerHasBanner: uptimer.hasBanner,
          heightOf: (item) => _cardHeightOf(
            item,
            folded: folded,
            unfolded: unfolded,
            textScale: textScale,
            uptimer: uptimer,
          ),
        );
        _publishAuto(auto);
        final density = stored == ServerListDensity.auto
            ? auto
            : stored.resolveItems(
                filtered,
                groups: itemGroups,
                textScale: textScale,
                viewport: cons.biggest,
                folded: folded,
                uptimerHasBanner: uptimer.hasBanner,
                heightOf: (item) => _cardHeightOf(
                  item,
                  folded: folded,
                  unfolded: unfolded,
                  textScale: textScale,
                  uptimer: uptimer,
                ),
              );
        _heroDensity = hero ? density : null;
        return gridOf(cons, density, pageInset);
      },
    );

    final serverIds = [
      for (final item in filtered)
        if (item is ServerCardItem) item.id,
    ];
    final showUptimerErr =
        openItem == null && uptimer.signedIn && uptimer.error != null;

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
        if (showUptimerErr)
          UptimerSyncErrorBanner(
            error: uptimer.error!,
            loading: uptimer.isLoading,
            onRetry: () => unawaited(
              ref.read(uptimerProvider.notifier).refresh(force: true),
            ),
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

  void _invalidateCardHeights() {
    _cardHeights.clear();
    _pendingCardHeights.clear();
    _cardHeightCommitTimer?.cancel();
    _cardHeightsEpoch++;
  }

  void _syncCardHeightCache(Size viewport, double textScale) {
    final availWidth = math.max(
      0.0,
      viewport.width - MasonryList.kPadding.horizontal,
    );
    final cols = ServerListDensity.columnsFor(availWidth);
    final colWidth = (availWidth - MasonryList.kSpacing * (cols - 1)) / cols;
    final scaleChanged =
        _cardHeightsTextScale != null &&
        (_cardHeightsTextScale! - textScale).abs() > 0.01;
    final widthChanged =
        _cardHeightsColWidth != null &&
        (_cardHeightsColWidth! - colWidth).abs() > 48.0;
    if (scaleChanged || widthChanged) {
      _invalidateCardHeights();
      _cardHeightsTextScale = textScale;
      _cardHeightsColWidth = colWidth;
    } else {
      _cardHeightsTextScale ??= textScale;
      _cardHeightsColWidth ??= colWidth;
    }
  }

  PowerState? _linkedBmcPower(ServerState srv) {
    if (srv.conn != ServerConn.failed) return null;
    final linked = ref.read(bmcTargetsProvider).forServer(srv.spi.id);
    if (linked == null || !linked.isComplete) return null;
    final summary = ref.read(bmcSummaryProvider(linked.id));
    return summary.failure == null && summary.hasData
        ? summary.powerState
        : null;
  }

  /// Value-equal signature of the height-affecting layout state of [item] in
  /// `cards` density. Models actual rendered body dimensions (rather than
  /// transient reconnect steps) so cached heights stay hit across normal ticks
  /// and reconnects, while immediately invalidating on real height changes.
  Object _cardHeightState(
    StatusCardItem item, {
    required bool folded,
    required bool Function(String id) unfolded,
    required UptimerState uptimer,
  }) => switch (item) {
    ServerCardItem(:final id) => () {
      final srv = ref.read(serverProvider(id));
      final notice = ServerNotice.onCard(
        srv,
        bmcPower: _linkedBmcPower(srv),
      );
      if (notice != null) {
        return ('notice', notice.kind, notice.mono.isNotEmpty);
      }
      final hasBody = serverCardHasBody(srv);
      if (!hasBody) return 'compact';
      final stale = serverCardStaleSince(srv) != null;
      final expanded = !folded && unfolded(id);
      final foot = serverCardReadings(srv).all.any((m) => m.over);
      return ('body', stale, expanded, foot);
    }(),
    BmcCardItem(:final target) => () {
      final s = ref.read(bmcSummaryProvider(target.id));
      if (s.failure case final failure?) {
        final isCert = s.needsCertReview;
        final title = isCert ? l10n.bmcCert : bmcFailureText(failure, null);
        final detail = isCert
            ? bmcFailureText(failure, s.failureDetail)
            : s.failureDetail;
        final hasDetail =
            detail != null && detail.isNotEmpty && detail != title;
        return ('err', isCert, hasDetail);
      }
      if (!s.hasData) return 'compact';
      final model = s.topology?.system?.model?.trim();
      final hasModel = model != null && model.isNotEmpty;
      final health = s.topology?.system?.health;
      final healthAlert =
          health != null && health.isNotEmpty && health != 'OK';
      final isOff = s.powerState == PowerState.off;
      if (s.watts != null) {
        return ('watts', (isOff && hasModel) || healthAlert);
      }
      if (hasModel || healthAlert) return ('sub', hasModel, healthAlert);
      return 'compact';
    }(),
    UptimerCardItem(:final monitor) => uptimer.hasBanner(monitor.id),
  };

  double? _cardHeightOf(
    StatusCardItem item, {
    required bool folded,
    required bool Function(String id) unfolded,
    required double textScale,
    required UptimerState uptimer,
  }) {
    final factor = 1.0 + math.max(0.0, textScale - 1.0) * 0.35;
    // A single card manually unfolded while global UI Fold is active must not
    // push the whole list out of `cards` density.
    final manuallyUnfolded =
        item is ServerCardItem && folded && unfolded(item.id);
    if (!manuallyUnfolded) {
      if (_cardHeights[item.cardKey] case final cached?) {
        final state = _cardHeightState(
          item,
          folded: folded,
          unfolded: unfolded,
          uptimer: uptimer,
        );
        if (cached.state == state) return cached.height;
      }
    }
    final base = switch (item) {
      ServerCardItem(:final id) => () {
        final srv = ref.read(serverProvider(id));
        if (ServerNotice.onCard(srv, bmcPower: _linkedBmcPower(srv)) != null) {
          return ServerListDensity.cardServerFailed;
        }
        if (!serverCardHasBody(srv)) {
          return ServerListDensity.cardCompact;
        }
        return (manuallyUnfolded || !unfolded(id))
            ? ServerListDensity.cardFolded
            : ServerListDensity.cardUnfolded;
      }(),
      BmcCardItem(:final target) => () {
        final s = ref.read(bmcSummaryProvider(target.id));
        if (s.failure != null) return ServerListDensity.cardBmcFailed;
        if (s.watts != null) return ServerListDensity.cardBmc;
        if (s.hasData) {
          final model = s.topology?.system?.model?.trim();
          final health = s.topology?.system?.health;
          final hasSub =
              (model != null && model.isNotEmpty) ||
              (health != null && health.isNotEmpty && health != 'OK');
          if (hasSub) return ServerListDensity.cardBmc;
        }
        return ServerListDensity.cardCompact;
      }(),
      UptimerCardItem(:final monitor) =>
        uptimer.hasBanner(monitor.id)
            ? ServerListDensity.cardUptimerAlert
            : ServerListDensity.cardUptimer,
    };
    return base * factor;
  }

  void _recordCardHeight(StatusCardItem item, double height) {
    final cardKey = item.cardKey;
    final folded = Stores.setting.collapseUIDefault.fetch();
    final state = _cardHeightState(
      item,
      folded: folded,
      unfolded: ServerCardExpanded.reader,
      uptimer: ref.read(uptimerProvider),
    );
    final pending = _pendingCardHeights[cardKey];
    if (pending != null) {
      if (pending.state == state && (pending.height - height).abs() <= 1.5) {
        return;
      }
    } else if (_cardHeights[cardKey] case final cached?) {
      if (cached.state == state && (cached.height - height).abs() <= 1.5) {
        return;
      }
    }
    _pendingCardHeights[cardKey] = (state: state, height: height);
    // Trailing debounce waits for `ServerCard`'s `AnimatedSize` transitions to
    // settle so intermediate heights never pollute `_cardHeights`.
    _cardHeightCommitTimer?.cancel();
    _cardHeightCommitTimer = Timer(
      const Duration(milliseconds: 120),
      _commitPendingCardHeights,
    );
  }

  void _commitPendingCardHeights() {
    _cardHeightCommitTimer = null;
    if (!mounted || _pendingCardHeights.isEmpty) return;
    final folded = Stores.setting.collapseUIDefault.fetch();
    final unfolded = ServerCardExpanded.reader;
    final uptimer = ref.read(uptimerProvider);
    final itemsByKey = {for (final item in _lastFiltered) item.cardKey: item};
    for (final entry in _pendingCardHeights.entries) {
      final item = itemsByKey[entry.key];
      if (item == null) continue;
      final currentState = _cardHeightState(
        item,
        folded: folded,
        unfolded: unfolded,
        uptimer: uptimer,
      );
      // Commit only if the card's state has not moved on since the height was
      // measured (avoids tagging an old height with a newer state).
      if (currentState == entry.value.state) {
        _cardHeights[entry.key] = entry.value;
      }
    }
    _pendingCardHeights.clear();
    if (_cardHeights.length > _lastFiltered.length * 2 + 32) {
      _cardHeights.removeWhere((k, _) => !itemsByKey.containsKey(k));
    }
    if (_heroId != null) return;
    final viewport = _lastGridViewport;
    if (viewport == null || _lastFiltered.isEmpty) return;
    final groups = ServerListGrouping.of(_tag.value) == ServerListGrouping.tag
        ? groupByTag(_lastFiltered, (item) => item.tags)
              .map((g) => g.items)
              .toList()
        : null;
    final textScale = _textScale;
    final next = ServerListDensity.auto.resolveItems(
      _lastFiltered,
      groups: groups,
      textScale: textScale,
      viewport: viewport,
      folded: folded,
      uptimerHasBanner: uptimer.hasBanner,
      heightOf: (item) => _cardHeightOf(
        item,
        folded: folded,
        unfolded: unfolded,
        textScale: textScale,
        uptimer: uptimer,
      ),
    );
    final prevAuto = _autoDensity.value;
    if (next != prevAuto) {
      _autoDensity.value = next;
      if (ServerDensityPref.of(_tag.value) == ServerListDensity.auto) {
        _sortVersion.notify();
      }
    }
  }

  Widget _buildItemConsumer(
    StatusCardItem item, {
    double openness = 0,
    Animation<double>? fade,
    ServerListDensity density = ServerListDensity.cards,
    double pageWidth = 0,
    bool expanded = false,
  }) {
    final child = switch (item) {
      ServerCardItem(:final id) => Consumer(
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
      UptimerCardItem(:final monitor) => _buildEachUptimerCard(
        monitor,
        fade: fade,
        density: density,
      ),
    };
    final manuallyUnfolded =
        item is ServerCardItem &&
        expanded &&
        Stores.setting.collapseUIDefault.fetch();
    return _ReportCardHeight(
      key: ValueKey(item.cardKey),
      enabled:
          density == ServerListDensity.cards &&
          openness == 0 &&
          !manuallyUnfolded,
      epoch: _cardHeightsEpoch,
      onHeight: (h) => _recordCardHeight(item, h),
      child: child,
    );
  }

  Future<void> _onTapLinkedBmcPowerOn(String serverId) async {
    final target = ref.read(bmcTargetsProvider).forServer(serverId);
    if (target == null) return;
    await confirmAndRunBmcPowerOn(
      context: context,
      ref: ref,
      target: target,
      run: () {
        if (!mounted) return Future.value(BmcPowerResult.failed);
        return ref
            .read(bmcSummaryProvider(target.id).notifier)
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
      if (ref.read(uptimerProvider).signedIn)
        ref.read(uptimerProvider.notifier).refresh(force: true),
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
          markAnchor: _elementFlight.cardBinding(cardKey),
          hideMark: _elementFlight.isFlying(cardKey),
          opensInPlace: _opensInPlace(context),
        ).onSecondary((at) => _onLongPressBmcCard(context, target, at: at));
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

  Widget _buildEachUptimerCard(
    UptimerMonitorCard monitor, {
    Animation<double>? fade,
    ServerListDensity density = ServerListDensity.cards,
  }) {
    final cardKey = UptimerCardItem.keyOf(monitor.id);
    final card = Builder(
      builder: (context) {
        return UptimerCard(
          key: ValueKey(cardKey),
          monitor: monitor,
          density: density,
          onTap: () => _selecting
              ? _toggleSelected(cardKey)
              : _onTapUptimerCard(context, monitor),
          onLongPress: () => _onLongPressUptimerCard(context, monitor),
          selected: _selecting ? _selected.contains(cardKey) : null,
          highlighted: cardKey == _menuId,
          stripAnchor: _elementFlight.cardBinding(cardKey),
          hideStrip: _elementFlight.isFlying(cardKey),
          opensInPlace: _opensInPlace(context),
        ).onSecondary(
          (at) => _onLongPressUptimerCard(context, monitor, at: at),
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
}

/// Reports a card's actual laid-out height while [enabled] (resting `cards`
/// density) without wrapping or rebuilding its child subtree.
final class _ReportCardHeight extends SingleChildRenderObjectWidget {
  final bool enabled;
  final int epoch;
  final ValueChanged<double> onHeight;

  const _ReportCardHeight({
    super.key,
    required this.enabled,
    required this.epoch,
    required this.onHeight,
    required super.child,
  });

  @override
  _RenderReportCardHeight createRenderObject(BuildContext context) =>
      _RenderReportCardHeight(
        enabled: enabled,
        epoch: epoch,
        onHeight: onHeight,
      );

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderReportCardHeight renderObject,
  ) {
    renderObject
      ..enabled = enabled
      ..epoch = epoch
      ..onHeight = onHeight;
  }
}

final class _RenderReportCardHeight extends RenderProxyBox {
  bool _enabled;
  int _epoch;
  ValueChanged<double> _onHeight;
  double _reported = -1;

  _RenderReportCardHeight({
    required bool enabled,
    required int epoch,
    required ValueChanged<double> onHeight,
  }) : _enabled = enabled,
       _epoch = epoch,
       _onHeight = onHeight;

  set enabled(bool value) {
    if (_enabled == value) return;
    _enabled = value;
    if (_enabled) {
      _reported = -1;
      markNeedsLayout();
    }
  }

  set epoch(int value) {
    if (_epoch == value) return;
    _epoch = value;
    if (_enabled) {
      _reported = -1;
      markNeedsLayout();
    }
  }

  set onHeight(ValueChanged<double> value) {
    _onHeight = value;
  }

  @override
  void performLayout() {
    super.performLayout();
    if (!_enabled) return;
    final h = size.height;
    if (h > 0 && (h - _reported).abs() > 1.0) {
      _reported = h;
      _onHeight(h);
    }
  }
}
