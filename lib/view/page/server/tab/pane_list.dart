part of 'tab.dart';

/// One row of the rail: a group heading, or a server under one.
typedef _RailRow = ({String? heading, String? id});

/// The server list as a rail beside the detail pane.
///
/// The same rail the terminal and file pages use, because it is the same job:
/// a narrow index of everything, marking what is live and what is on screen,
/// read while your attention is on the pane beside it. A card belongs at full
/// width where its charts can be read; in a column this narrow they are a
/// smaller copy of what the detail pane is already showing.
extension _PaneList on _ServerPageState {
  /// [order] is every server, not what the grid's tag filter left — the rail
  /// groups by tag rather than filtering to one, and has no switcher of its
  /// own to undo a filter with. See the call site.
  Widget _buildPaneList(List<String> order) {
    final selected = ref.watch(serverSelectionProvider);
    // Watched, not read: a tag added or removed in the editor regroups the
    // rail, and the row it moves is one this page is already rebuilding for.
    final servers = ref.watch(serversProvider.select((s) => s.servers));
    final rows = _railRows(_filterByQuery(order), servers);

    return Scaffold(
      // With nothing selected there is no detail pane, so `AdaptivePanes`
      // hands this the whole width: what a wide window shows when the tab is
      // empty is this, not a rail beside something. So the same mark as the
      // narrow layout, rather than a rail's worth of text.
      //
      // The app bar used to be what kept this clear of a notch or a status
      // bar — a `Scaffold` insets that and nothing else.
      body: SafeArea(
        bottom: false,
        child: order.isEmpty
            ? const EmptyPane(icon: BoxIcons.bx_server)
            : ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.only(bottom: 12),
                // One more row than there are: the buttons sit at the head of
                // the list rather than over it, which is where the terminal
                // and file rails put theirs — see `SessionSideBar`. They were
                // a small floating button in the corner here, which is a
                // second place to look for the same thing.
                itemCount: rows.length + 1,
                itemBuilder: (context, index) {
                  if (index == 0) return _buildRailActions();
                  final row = rows[index - 1];
                  if (row.heading case final heading?) {
                    return SideBarSection(heading);
                  }
                  final id = row.id!;
                  final srv = ref.watch(serverProvider(id));
                  return _buildPaneListTile(
                    context,
                    srv,
                    selected: selected == id,
                  );
                },
              ),
      ),
    );
  }

  /// The rail's own buttons, at the measurements `SessionSideBar` uses for the
  /// same row.
  ///
  /// No tag switcher among them. It filtered to one tag at a time, which is
  /// the question the headings below answer for every tag at once — and a
  /// filter above a grouped index only takes rows out of it.
  Widget _buildRailActions() {
    return ListenableBuilder(
      listenable: Listenable.merge([_sortVersion, _query]),
      builder: (_, _) => Padding(
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
        // The field takes the row's place while searching, as it takes the
        // switcher's place in the bar on one column.
        child: _query.value != null
            ? _buildSearchBar()
            : Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Btn.icon(
              text: libL10n.search,
              icon: const Icon(Icons.search, size: 18),
              onTap: _startSearch,
            ),
            const SizedBox(width: 4),
            Btn.icon(
              text: libL10n.sort,
              icon: Icon(_SortOrder.stored.icon, size: 18),
              onTap: _showSortSheet,
            ),
            const SizedBox(width: 4),
            Btn.icon(
              text: libL10n.refresh,
              icon: const Icon(Icons.refresh, size: 18),
              onTap: _refreshAll,
            ),
            const SizedBox(width: 4),
            Btn.icon(
              text: libL10n.add,
              icon: const Icon(Icons.add, size: 18),
              onTap: _onTapAddServer,
            ),
            const SizedBox(width: 4),
          ],
        ),
      ),
    );
  }

  /// The rail as one flat list of rows, grouped by tag the way the snippet
  /// rail is — see [groupByTag] for what the groups are and what order they
  /// come in.
  ///
  /// Flattened rather than a list of lists because the rail scrolls as one
  /// column, and a heading is a row in it like any other. Flat rather than
  /// built eagerly into children because a row here watches its server and the
  /// rail is rebuilt on every status poll: building the rows that are off
  /// screen is work repeated every few seconds.
  ///
  /// Exactly one of [_RailRow.heading] and [_RailRow.id] is set on any row.
  List<_RailRow> _railRows(List<String> order, Map<String, Spi> servers) {
    return [
      for (final group in groupByTag(order, (id) => servers[id]?.tags)) ...[
        if (group.label case final label?) (heading: label, id: null),
        for (final id in group.items) (heading: null, id: id),
      ],
    ];
  }

  Widget _buildPaneListTile(
    BuildContext context,
    ServerState srv, {
    required bool selected,
  }) {
    final tile = SideBarTile(
      title: srv.spi.name,
      // The distribution, in the column the rail keeps for a mark. A list of
      // servers reads faster without the *same* icon down the side of it — the
      // reason `icon` is left null here — but this one differs per row and is
      // the thing being scanned for.
      leading: distIcon(srv.spi.id, size: 17),
      selected: selected,
      // The same mark the terminal rail uses for a running shell: this one is
      // connected and has something to show.
      live: srv.conn == ServerConn.finished,
      onTap: () => _onTapCard(context, srv),
      onLongPress: () => _onLongPressCard(srv),
    );

    return _flyingId.listenVal((flyingId) {
      // Marked while selected as well as while flying: closing the pane has to
      // measure this row *before* the layout goes back to a grid, and by then
      // there is nothing left to ask.
      if (flyingId != srv.spi.id) {
        return selected ? KeyedSubtree(key: _flightAnchorKey, child: tile) : tile;
      }
      // Laid out but not drawn: the flight needs this row's rectangle to know
      // where it is going, and showing the row while a copy of it is still on
      // its way would put the same card on screen twice.
      return Visibility(
        key: _flightAnchorKey,
        visible: false,
        maintainSize: true,
        maintainAnimation: true,
        maintainState: true,
        child: tile,
      );
    });
  }
}
