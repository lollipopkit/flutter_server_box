part of 'tab.dart';

/// The server list as a narrow column beside the detail pane.
///
/// Reuses the card's title row rather than inventing a second way to say the
/// same things. That row is already exactly what a card shows when the server
/// is not connected — name, connection state, the actions that apply — so a
/// separate list style would be a second thing to keep in sync for no gain.
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
      body: filtered.isEmpty
          ? Center(child: Text(libL10n.empty, textAlign: TextAlign.center))
          : ListView.builder(
              controller: _scrollController,
              // The grid gets its side margins from the column layout; a
              // single column has none of its own, so the cards would sit
              // against the window edge.
              padding: const EdgeInsets.fromLTRB(7, 7, 7, 77),
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
    final scheme = Theme.of(context).colorScheme;
    final tile = CardX(
      // The selected card carries the tint the rest of the app uses for a
      // current choice; the others keep the default card colour.
      color: selected ? scheme.secondaryContainer : null,
      child: InkWell(
        onTap: () => _onTapCard(context, srv),
        onLongPress: () => _onLongPressCard(srv),
        child: Padding(
          padding: _kPaneTilePadding,
          child: _buildServerCardTitle(srv),
        ),
      ),
    );

    return _flyingId.listenVal((flyingId) {
      if (flyingId != srv.spi.id) return tile;
      // Laid out but not drawn: the flight needs this row's rectangle to know
      // where it is going, and showing the row while a copy of it is still on
      // its way would put the same card on screen twice.
      return Visibility(
        key: _flightTargetKey,
        visible: false,
        maintainSize: true,
        maintainAnimation: true,
        maintainState: true,
        child: tile,
      );
    });
  }
}
