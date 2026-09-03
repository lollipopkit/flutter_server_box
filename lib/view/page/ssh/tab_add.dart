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
    // Installing or deleting a system used to leave this page drawing the list
    // it was built with: the picker is a cached widget, so nothing rebuilt it.
    // It mattered less when the systems were chips inside one card; it is the
    // whole page now.
    Rootfs.changed.addListener(_onSortChanged);
  }

  @override
  void dispose() {
    widget.sortVersion.removeListener(_onSortChanged);
    Rootfs.changed.removeListener(_onSortChanged);
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

    // Sections rather than one flow of cards. The systems on this device and
    // the servers are two kinds of thing, and a masonry grid says only "here
    // are some cards" — which is why the systems used to be pinned above it in
    // a card of their own, collapsed behind a title that named them in a
    // subtitle. One row each, under a heading, says the same thing without a
    // control to open first.
    // One column at every width. The sections used to be laid side by side
    // above 600pt, which is a width this tab has already decided is too narrow
    // for a rail — so between 600 and 800 the picker answered with two columns
    // of cards on a screen that was not getting a second column anywhere else.
    return ListView(
      padding: context.padBottom(UIs.roundRectCardPadding),
      children: [
        // First, and for the same reason the file tab lists it first: it is
        // always reachable, and it needs no credential to be.
        if (LocalShellBackend.isSupported) ...[
          CenterGreyTitle(libL10n.device),
          CardTile(
            icon: Icons.smartphone,
            title: libL10n.device,
            subtitle: LocalShellBackend.shellPath,
            onTap: widget.onLocal,
          ),
        ],
        if (Rootfs.isAvailable) ...[
          // Where the beta is said. It used to be the collapsed tile's
          // title; with a row per system there is no one row it belongs to.
          const CenterGreyTitle('Linux (Beta)'),
          for (final profile in Rootfs.profiles)
            _LinuxTile(
              key: ValueKey(profile.id),
              profile: profile,
              onTap: () => widget.onRootfsOpen(profile.id),
              onLongPress: () => widget.onRootfsRemove(profile),
            ),
          CardTile(
            icon: Icons.add,
            title: Rootfs.profiles.isEmpty ? libL10n.install : libL10n.add,
            // Only where there is nothing yet: the line explains what a
            // Linux system on this device *is*, which is a question the
            // second one does not raise.
            subtitle: Rootfs.profiles.isEmpty ? l10n.rootfsSubtitle : null,
            onTap: widget.onRootfsAdd,
          ),
        ],
        if (order.isNotEmpty) ...[
          CenterGreyTitle(libL10n.servers),
          for (final id in order)
            if (state.servers[id] case final spi?)
              _ServerTile(
                key: ValueKey(id),
                spi: spi,
                onTap: () => widget.onTap(spi),
                onLongPress: () => widget.onLongPress(spi),
              ),
        ],
      ],
    );
  }
}

/// One Linux system on this device, shaped like the server rows beside it.
///
/// The same row a server gets, because it is the same choice: somewhere to
/// open a shell. They were chips inside a collapsible card, which made the set
/// of them one control to open before any of them could be picked, and put the
/// distribution's name in a subtitle listing all of them at once.
class _LinuxTile extends StatelessWidget {
  const _LinuxTile({
    super.key,
    required this.profile,
    required this.onTap,
    required this.onLongPress,
  });

  final LinuxProfile profile;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final outdated = Rootfs.isOutdated(profile);
    return CardX(
      child: ListTile(
        // The distribution's own mark, from the same place a server's comes
        // from: these are Alpine, Ubuntu and Rocky, and a server running one
        // of them is drawn with exactly this icon.
        leading: distIconOf(_distOf(profile.distro), size: 26),
        title: Text(
          profile.label,
          style: UIs.text18,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        // What a server puts its address on. The label is the user's to
        // change, so on its own it need not say what is installed.
        subtitle: Text(
          _describe(),
          style: UIs.text12Grey,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        // The update mark the chip carried as an avatar. It says there is a
        // newer release of this system, which is not what a chevron says.
        trailing: Icon(outdated ? Icons.update : Icons.chevron_right),
        // Which one a restored tab that names no profile opens in — the only
        // sense in which one of several is current, and what the chip's
        // selected state used to show.
        selected: profile.id == Rootfs.selected?.id,
        onTap: onTap,
        onLongPress: onLongPress,
      ).onSecondary(asSecondary(onLongPress)),
    );
  }

  String _describe() {
    final name = profile.distro.label;
    final version = profile.version;
    return version.isEmpty ? name : '$name · $version';
  }

  /// The [Dist] this [LinuxDistro] is, for the icon.
  ///
  /// By name, and null for anything unmatched: the two enums are separate
  /// lists that happen to overlap — one is what can be installed here, the
  /// other everything a server might report — and a system whose distribution
  /// has no mark simply gets no mark.
  static Dist? _distOf(LinuxDistro distro) =>
      Dist.values.firstWhereOrNull((e) => e.name == distro.name);
}

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
    // As in the picker: nothing else tells this rail that a system was
    // installed or deleted.
    Rootfs.changed.addListener(_onSortChanged);
  }

  @override
  void dispose() {
    widget.sortVersion.removeListener(_onSortChanged);
    Rootfs.changed.removeListener(_onSortChanged);
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
                  key: ValueKey(profile.id),
                  title: profile.label,
                  onTap: () => widget.onRootfsOpen(profile.id),
                  onLongPress: () => widget.onRootfsRemove(profile),
                ),
              // Offered whether or not there is one already, as the picker
              // does. The rail used to show this only while nothing was
              // installed, so the second system could be added from one of the
              // two layouts and not the other.
              SideBarTile(
                title: Rootfs.profiles.isEmpty
                    ? 'Linux'
                    : '${libL10n.add} Linux',
                onTap: widget.onRootfsAdd,
              ),
            ],
          ],
          SideBarSection(libL10n.servers),
          for (final id in order)
            if (state.servers[id] case final spi?)
              SideBarTile(
                key: ValueKey(id),
                title: spi.name,
                leading: distIcon(spi.id, size: 17),
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
        leading: distIcon(spi.id, size: 26),
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
