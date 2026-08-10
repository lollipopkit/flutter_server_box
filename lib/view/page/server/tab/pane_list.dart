part of 'tab.dart';

/// The server list as a narrow column beside the detail pane.
///
/// A different widget from the card grid rather than the grid squeezed: at
/// 320pt a card's charts and buttons have nowhere to go, and the two lists
/// answer different questions anyway. The grid is for looking over the fleet;
/// this is for moving between two servers without losing your place.
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
              padding: const EdgeInsets.only(bottom: 77),
              itemCount: filtered.length,
              itemBuilder: (context, index) {
                final id = filtered[index];
                final srv = ref.watch(serverProvider(id));
                return _buildPaneListTile(srv, selected: selected == id);
              },
            ),
    );
  }

  Widget _buildPaneListTile(ServerState srv, {required bool selected}) {
    final theme = Theme.of(context);
    return ListTile(
      dense: true,
      selected: selected,
      selectedTileColor: theme.colorScheme.secondaryContainer,
      leading: _ServerConnDot(conn: srv.conn),
      title: Text(
        srv.spi.name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: UIs.text13Bold,
      ),
      subtitle: Text(
        srv.spi.displayAddr,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: UIs.text11Grey,
      ),
      onTap: () => _onTapCard(srv),
      onLongPress: () => _onLongPressCard(srv),
    );
  }
}

/// Connection state as a dot.
///
/// The grid says the same thing with a spinner and a row of icons, which needs
/// more room than a 320pt column has. Colour only, and the tooltip carries the
/// word for anyone who cannot separate these hues.
class _ServerConnDot extends StatelessWidget {
  const _ServerConnDot({required this.conn});

  final ServerConn conn;

  @override
  Widget build(BuildContext context) {
    final (color, label) = switch (conn) {
      ServerConn.finished => (Colors.green, libL10n.success),
      ServerConn.connected ||
      ServerConn.connecting ||
      ServerConn.loading => (Colors.orange, libL10n.loadingEllipsis),
      ServerConn.failed => (Colors.red, libL10n.fail),
      ServerConn.disconnected => (Colors.grey, libL10n.disabled),
    };
    return Tooltip(
      message: label,
      child: Icon(Icons.circle, size: 10, color: color),
    );
  }
}
