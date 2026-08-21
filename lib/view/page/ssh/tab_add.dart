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
    required this.onLocal,
    required this.onRootfsOpen,
    required this.onRootfsAdd,
    required this.onRootfsRemove,
    required this.onLongPress,
  });

  /// Bumped when the sort changes. The order lives in the settings store, not
  /// in a provider, so nothing else would tell this page to rebuild.
  final Listenable sortVersion;

  final void Function(Spi spi) onTap;

  /// Opens a shell on the machine the app is running on.
  final VoidCallback onLocal;

  /// Opens a shell inside one of the installed Linux systems.
  final void Function(String profileId) onRootfsOpen;

  /// Installs another, and opens a shell in it.
  final VoidCallback onRootfsAdd;

  /// Deletes one, and the terminals that were inside it.
  final void Function(LinuxProfile profile) onRootfsRemove;

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

    // Not "empty" while this device is on the list: with no servers
    // configured, a shell here is still something this page can open.
    if (order.isEmpty &&
        !LocalShellBackend.isSupported &&
        !Rootfs.isAvailable) {
      return Center(child: Text(libL10n.empty, textAlign: TextAlign.center));
    }

    final grid = MasonryList(
      columnWidth: _kServerColumnWidth,
      children: [
        // First, and for the same reason the file tab lists it first: it is
        // always reachable, and it needs no credential to be.
        if (LocalShellBackend.isSupported)
          CardTile(
            icon: Icons.smartphone,
            title: libL10n.device,
            subtitle: LocalShellBackend.shellPath,
            onTap: widget.onLocal,
          ),
        for (final id in order)
          if (state.servers[id] case final spi?) _ServerTile(
            key: ValueKey(id),
            spi: spi,
            onTap: () => widget.onTap(spi),
            onLongPress: () => widget.onLongPress(spi),
          ),
      ],
    );

    // Above the grid and outside it. The systems are one subject with several
    // members, and a card each would have put them among the servers as though
    // each were another machine — they are all this one.
    if (!Rootfs.isAvailable) return grid;
    return Column(
      children: [
        _LinuxSection(
          onOpen: widget.onRootfsOpen,
          onAdd: widget.onRootfsAdd,
          onRemove: widget.onRootfsRemove,
        ),
        Expanded(child: grid),
      ],
    );
  }
}

/// The Linux systems on this device, pinned above the servers.
///
/// A row of chips rather than a dialog on the way in: they can all run at once,
/// so which one to open is a thing to see and tap, not a question to answer
/// before the page will do anything.
///
/// Starts open. It is the one control on this page that is not self-evident
/// from its title, and collapsing it is one tap away.
class _LinuxSection extends StatefulWidget {
  const _LinuxSection({
    required this.onOpen,
    required this.onAdd,
    required this.onRemove,
  });

  final void Function(String profileId) onOpen;
  final VoidCallback onAdd;
  final void Function(LinuxProfile profile) onRemove;

  @override
  State<_LinuxSection> createState() => _LinuxSectionState();
}

class _LinuxSectionState extends State<_LinuxSection> {
  var _expanded = true;

  @override
  Widget build(BuildContext context) {
    final profiles = Rootfs.profiles;
    // The grid below keeps its cards off the window edge with
    // [MasonryList.kPadding]. This one is above the grid rather than in it, so
    // all it had was the `Card`'s own 4pt margin — a band running edge to edge
    // over a column of cards that stop well short of it. Taken from the same
    // constant, so the two cannot drift apart.
    //
    // No bottom: the grid's own top padding is the gap between them.
    return Padding(
      padding: MasonryList.kPadding.copyWith(bottom: 0),
      child: CardX(
        child: Column(
          children: [
            ListTile(
              leading: const Icon(Icons.terminal),
              title: const Text('Linux'),
              subtitle: Text(
                profiles.isEmpty
                    ? l10n.rootfsSubtitle
                    : profiles.map((e) => e.label).join(' · '),
                style: UIs.textGrey,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: Icon(
                _expanded ? Icons.expand_less : Icons.expand_more,
              ),
              onTap: () => setState(() => _expanded = !_expanded),
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
              alignment: Alignment.topCenter,
              child: _expanded ? _buildChips(profiles) : UIs.placeholder,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChips(List<LinuxProfile> profiles) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(17, 0, 17, 13),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final profile in profiles)
            GestureDetector(
              // The gesture the card used to carry, kept where the thing it
              // deletes now is.
              onLongPress: () => widget.onRemove(profile),
              child: ChoiceChip(
                // Marks the one a restored tab without a profile would open in,
                // which is the only sense in which one of them is current.
                // Tapping is opening, not selecting — see `onSelected`.
                selected: profile.id == Rootfs.selected?.id,
                label: Text(profile.label),
                avatar: Rootfs.isOutdated(profile)
                    ? const Icon(Icons.update, size: 16)
                    : null,
                onSelected: (_) => widget.onOpen(profile.id),
              ),
            ),
          ActionChip(
            avatar: const Icon(Icons.add, size: 18),
            label: Text(profiles.isEmpty ? libL10n.install : libL10n.add),
            onPressed: widget.onAdd,
          ),
        ],
      ),
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
    required this.onLocal,
    required this.onRootfsOpen,
    required this.onRootfsAdd,
    required this.onRootfsRemove,
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

  /// Opens a shell on the machine the app is running on.
  final VoidCallback onLocal;

  /// Opens a shell inside one of the installed Linux systems.
  final void Function(String profileId) onRootfsOpen;

  /// Installs another, and opens a shell in it.
  final VoidCallback onRootfsAdd;

  /// Deletes one, and the terminals that were inside it.
  final void Function(LinuxProfile profile) onRootfsRemove;
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
          // Above the servers, the way the file rail puts this device above
          // them: it is the one place that is always reachable, and it needs
          // no credential to be.
          if (LocalShellBackend.isSupported || Rootfs.isAvailable) ...[
            SideBarSection(libL10n.device),
            if (LocalShellBackend.isSupported)
              SideBarTile(title: libL10n.device, onTap: widget.onLocal),
            // One row each rather than chips: a rail is for switching while
            // something else has your attention, and it is too narrow to lay
            // them out side by side.
            if (Rootfs.isAvailable) ...[
              for (final profile in Rootfs.profiles)
                SideBarTile(
                  title: profile.label,
                  onTap: () => widget.onRootfsOpen(profile.id),
                  onLongPress: () => widget.onRootfsRemove(profile),
                ),
              if (Rootfs.profiles.isEmpty)
                SideBarTile(title: 'Linux', onTap: widget.onRootfsAdd),
            ],
          ],
          SideBarSection(libL10n.servers),
          for (final id in order)
            if (state.servers[id] case final spi?)
              SideBarTile(
                key: ValueKey(id),
                title: spi.name,
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
      ).onSecondary(asSecondary(onLongPress)),
    );
  }
}
