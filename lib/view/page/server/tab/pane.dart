part of 'tab.dart';

extension _Pane on _ServerPageState {
  /// The list as a column beside the open machine, and the surface that
  /// machine is grown into.
  ///
  /// The column is the list making way: it arrives as the card grows and
  /// leaves as the card shrinks back, on the card's own movement rather than
  /// a clock of its own — see [AdaptivePanes.presence]. With nothing open it
  /// is not there at all, and the grid has the width.
  ///
  /// [heroId] is the card out of the grid, or on its way back into it — not
  /// the selection, which is cleared before the way back starts.
  Widget _buildPanes({
    required List<String> filtered,
    required String? openId,
    required String? heroId,
    required Widget Function(double pageInset) grid,
  }) {
    // Built once out here: the panes rebuild the column on every frame of the
    // movement, and the same widget is one Flutter skips.
    final column = _buildServerColumn(filtered, openId);

    return LayoutBuilder(
      builder: (_, outer) => PaneSettings.listenAll(
        (width, collapsed) => AdaptivePanes.surface(
          // Not when a card opening in place has no room for a column beside
          // it: the bar's switcher still reaches every machine.
          enabled: heroId != null && _opensInPlace(context),
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
              // Where the column will end, from where it is now: the panes
              // grow it by the same [_open] this reads, so what it has taken
              // so far divided by how far along that is, is all of it. The
              // card grows to that edge rather than to the column's current
              // one, so it is never under the column on the way.
              final t = _open.value;
              final pageInset = t > 0
                  ? (outer.maxWidth - inner.maxWidth) / t
                  : 0.0;
              return Stack(
                fit: StackFit.expand,
                children: [
                  if (heroId != null) _buildOpenDetail(heroId),
                  // Dropped the moment the page takes the readings over
                  // rather than crossed with it: at that point both are
                  // drawing the same widgets in the same places, so a
                  // crossing would have nothing to carry and 200ms to carry
                  // it in.
                  if (!_detailShowing)
                    KeyedSubtree(
                      key: const ValueKey('cards'),
                      // Laid out at the whole width and anchored to the right,
                      // so the column slides in over the grid instead of
                      // narrowing it: a grid laid out narrower on every frame
                      // re-flows its columns under the card that is leaving
                      // it. What is under the column is cut off, and is the
                      // cards that are fading out anyway.
                      child: ClipRect(
                        child: OverflowBox(
                          alignment: Alignment.centerRight,
                          minWidth: outer.maxWidth,
                          maxWidth: outer.maxWidth,
                          child: grid(pageInset),
                        ),
                      ),
                    ),
                  // Above both, and the tab's rather than the page's — see
                  // [ServerOpenFuncBar].
                  if (heroId != null)
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
              );
            },
          ),
        ),
      ),
    );
  }

  /// The list, as an index beside the open machine, laid out as the file
  /// tab's rail is: the machines under their tags.
  ///
  /// Grouped whatever the grid is set to. The grid's grouping is a way of
  /// reading a page of cards; a column of names is found by its headings, and
  /// without them it is as long as the list and says nothing about it.
  ///
  /// No search of its own: the bar's switcher over the open machine is one,
  /// and it searches the tags as well.
  Widget _buildServerColumn(List<String> filtered, String? openId) {
    final servers = ref.read(serversProvider).servers;
    Widget tile(String id) => Consumer(
      key: ValueKey(id),
      builder: (_, ref, _) {
        final srv = ref.watch(serverProvider(id));
        return SideBarTile(
          leading: distIcon(id, size: 22),
          title: srv.spi.name,
          // Whether it answers, which the grid said with the card and this
          // says with a dot — after the name, so the names start on one edge.
          trailing: Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: serverStateDot(srv),
            ),
          ),
          selected: id == openId,
          onTap: id == openId ? null : () => _openDetail(id),
        );
      },
    );

    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 4),
      children: [
        for (final group in groupByTag(filtered, (id) => servers[id]?.tags)) ...[
          if (group.label case final label?) SideBarSection(label),
          for (final id in group.items) tile(id),
        ],
      ],
    );
  }
}
