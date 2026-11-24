part of 'tab.dart';

extension _Pane on _ServerPageState {
  Widget _buildPanes({
    required List<StatusCardItem> filtered,
    required StatusCardItem? openItem,
    required StatusCardItem? heroItem,
    required Widget Function(double pageInset) grid,
  }) {
    final column = _buildServerColumn(filtered, openItem);

    return LayoutBuilder(
      builder: (_, outer) => PaneSettings.listenAll(
        (width, collapsed) => AdaptivePanes.surface(
          enabled: heroItem != null && _opensInPlace(context),
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
              final pageInset = t > 0
                  ? (outer.maxWidth - inner.maxWidth) / t
                  : 0.0;
              return Stack(
                fit: StackFit.expand,
                children: [
                  if (heroItem != null) _buildOpenDetail(heroItem),
                  if (!_detailShowing || heroItem == null)
                    KeyedSubtree(
                      key: const ValueKey('cards'),
                      child: ClipRect(
                        child: OverflowBox(
                          alignment: Alignment.centerRight,
                          minWidth: outer.maxWidth,
                          maxWidth: outer.maxWidth,
                          child: grid(pageInset),
                        ),
                      ),
                    ),
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
                ],
              );
            },
          ),
        ),
      ),
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
