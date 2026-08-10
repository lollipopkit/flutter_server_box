part of 'tab.dart';

/// The first tab: pick a server to open a shell on.
///
/// Sorting is recomputed on every build rather than cached. The previous cache
/// rebuilt a name map on each build purely to decide whether it was still
/// valid, so it did the linear work regardless and saved only the sort — for a
/// list of servers, that is nothing worth the three fields of state it took to
/// arrange.
class _AddPage extends ConsumerStatefulWidget {
  const _AddPage({
    required this.sortVersion,
    required this.onTap,
    required this.onLongPress,
  });

  /// Bumped when the sort changes. The order lives in the settings store, not
  /// in a provider, so nothing else would tell this page to rebuild.
  final Listenable sortVersion;

  final void Function(Spi spi) onTap;
  final void Function(Spi spi) onLongPress;

  @override
  ConsumerState<_AddPage> createState() => _AddPageState();
}

class _AddPageState extends ConsumerState<_AddPage> {
  @override
  void initState() {
    super.initState();
    widget.sortVersion.addListener(_onSortChanged);
  }

  @override
  void dispose() {
    widget.sortVersion.removeListener(_onSortChanged);
    super.dispose();
  }

  void _onSortChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(serversProvider);
    final order = _SortOrder.stored.apply(state.serverOrder, state.servers);

    if (order.isEmpty) {
      return Center(child: Text(libL10n.empty, textAlign: TextAlign.center));
    }

    return AutoMultiList(
      columnWidth: _kServerColumnWidth,
      children: [
        for (final id in order)
          if (state.servers[id] case final spi?) _ServerTile(
            key: ValueKey(id),
            spi: spi,
            onTap: () => widget.onTap(spi),
            onLongPress: () => widget.onLongPress(spi),
          ),
      ],
    );
  }
}

/// Wide enough for a server name and the chevron beside it, and narrow enough
/// that a desktop window gets more than one column.
const _kServerColumnWidth = 300.0;

/// The same two things as [_AddPage], in a column too narrow for cards: the
/// shells that are running, and the servers one could be started on.
///
/// Not a variant of [_AddPage] with a `compact` flag. A grid of cards is for
/// browsing and picking; a rail is for switching while something else has your
/// attention, and it carries the running sessions that the picker has no
/// business knowing about.
class _SideBar extends ConsumerStatefulWidget {
  const _SideBar({
    required this.sessions,
    required this.sortVersion,
    required this.actions,
    required this.onOpen,
    required this.onEdit,
    required this.onSelect,
    required this.onClose,
  });

  final SessionTabsController<_SshSession> sessions;

  /// Bumped when the sort changes. The order lives in the settings store, not
  /// in a provider, so nothing else would tell this rail to rebuild.
  final Listenable sortVersion;

  final List<Widget> actions;
  final void Function(Spi spi) onOpen;
  final void Function(Spi spi) onEdit;
  final void Function(int index) onSelect;
  final void Function(int index) onClose;

  @override
  ConsumerState<_SideBar> createState() => _SideBarState();
}

class _SideBarState extends ConsumerState<_SideBar> {
  @override
  void initState() {
    super.initState();
    widget.sortVersion.addListener(_onSortChanged);
  }

  @override
  void dispose() {
    widget.sortVersion.removeListener(_onSortChanged);
    super.dispose();
  }

  void _onSortChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(serversProvider);
    final order = _SortOrder.stored.apply(state.serverOrder, state.servers);

    return ListenBuilder(
      listenable: widget.sessions,
      builder: () => SessionSideBar(
        names: widget.sessions.names,
        index: widget.sessions.index,
        onTap: widget.onSelect,
        onClose: widget.onClose,
        actions: widget.actions,
        targets: [
          SessionSideBarSection(libL10n.servers),
          for (final id in order)
            if (state.servers[id] case final spi?)
              SessionSideBarTile(
                key: ValueKey(id),
                title: spi.name,
                subtitle: spi.displayAddr,
                // Always a new shell, never a jump to one that is already
                // open: the section above is where switching happens, and a
                // second shell on one server is an ordinary thing to want.
                onTap: () => widget.onOpen(spi),
                onLongPress: () => widget.onEdit(spi),
              ),
        ],
      ),
    );
  }
}

class _ServerTile extends StatelessWidget {
  const _ServerTile({
    super.key,
    required this.spi,
    required this.onTap,
    required this.onLongPress,
  });

  final Spi spi;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    return CardX(
      child: ListTile(
        title: Text(spi.name, style: UIs.text18, maxLines: 2, overflow: TextOverflow.ellipsis),
        subtitle: Text(
          spi.displayAddr,
          style: UIs.text12Grey,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
        onLongPress: onLongPress,
      ),
    );
  }
}
