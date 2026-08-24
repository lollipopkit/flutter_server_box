part of 'tab.dart';

/// The server list as a rail beside the detail pane.
///
/// The same rail the terminal and file pages use, because it is the same job:
/// a narrow index of everything, marking what is live and what is on screen,
/// read while your attention is on the pane beside it. A card belongs at full
/// width where its charts can be read; in a column this narrow they are a
/// smaller copy of what the detail pane is already showing.
extension _PaneList on _ServerPageState {
  Widget _buildPaneList(List<String> filtered) {
    final selected = ref.watch(serverSelectionProvider);

    return Scaffold(
      appBar: _TopBar(
        tags: _tags,
        onTagChanged: (p0) => _tag.value = p0,
        initTag: _tag.value,
      ),
      floatingActionButton: FloatingActionButton.small(
        heroTag: 'addServerPane',
        onPressed: _onTapAddServer,
        tooltip: libL10n.add,
        child: const Icon(Icons.add),
      ),
      // With nothing selected there is no detail pane, so `AdaptivePanes`
      // hands this the whole width: what a wide window shows when the tab is
      // empty is this, not a rail beside something. So the same mark as the
      // narrow layout, rather than a rail's worth of text.
      body: filtered.isEmpty
          ? const EmptyPane(icon: BoxIcons.bx_server)
          : ListView.builder(
              controller: _scrollController,
              // Room at the bottom for the add button to float over.
              padding: const EdgeInsets.only(top: 4, bottom: 77),
              itemCount: filtered.length,
              itemBuilder: (context, index) {
                final id = filtered[index];
                final srv = ref.watch(serverProvider(id));
                return _buildPaneListTile(
                  context,
                  srv,
                  selected: selected == id,
                );
              },
            ),
    );
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
      leading: distIconOf(srv.status.dist, size: 17),
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
