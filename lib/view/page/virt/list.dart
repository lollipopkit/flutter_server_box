// ignore_for_file: invalid_use_of_protected_member

part of 'tab.dart';

// --- Widgets ---

/// How long the list column takes to become another host's, or the picker's.
///
/// `medium2`, as the server page's list ⇄ globe swap is: a scale needs room to
/// read as a movement, and at 150 ms it has arrived before the eye has decided
/// anything moved.
const _kListSwapDuration = Durations.medium2;

/// The column's contents arriving and leaving.
///
/// Fade, with the arriving contents growing from 0.9 about the centre: the
/// app's default for one thing in a place being replaced by another (the
/// design system's `--transition-swap`). Which host comes next is not
/// something the switcher says — it opens a list and the user picks from it —
/// so there is no direction to draw and none is invented.
Widget _listSwapTransition(Widget child, Animation<double> animation) {
  return FadeTransition(
    opacity: animation,
    // `drive` rather than a `CurvedAnimation`, which owns resources and would
    // be built and dropped on every frame of the transition.
    child: ScaleTransition(
      scale: animation.drive(
        Tween(
          begin: 0.9,
          end: 1.0,
        ).chain(CurveTween(curve: Curves.easeOutCubic)),
      ),
      child: child,
    ),
  );
}

/// Both bodies in the same box, so a short one is not centred inside the tall
/// one it is replacing while the crossing runs.
Widget _listSwapLayout(Widget? current, List<Widget> previous) =>
    Stack(fit: StackFit.expand, children: [...previous, ?current]);

extension _List on _VirtTabPageState {
  /// The list column: which host, what it has, and the way to the rest.
  ///
  /// The same column in both layouts. With one column it is the tab, which is
  /// right here: a host's guests are what the tab is opened for, and a guest
  /// is one tap further in either way.
  Widget _buildList(
    VirtHostsState hosts,
    Map<String, Spi> servers,
    String? hostId,
    bool split,
    VirtCapabilities? caps,
  ) {
    final hostIds = hosts.hostIds;
    final at = hostId == null ? -1 : hostIds.indexOf(hostId);
    final picking = split && _showHosts;

    final bar = SizedBox(
      height: SessionTabBar.height,
      child: InlineSearchBar(
        controller: _search,
        hint: libL10n.name,
        child: Row(
          children: [
            Expanded(
              child: SessionSwitcherLabel(
                name: servers[hostId]?.name ?? l10n.virtualization,
                icon: Icons.dns_outlined,
                position: at < 0 ? null : at + 1,
                total: hostIds.length,
                // The picker below this bar, where there is a column to open
                // it in; a sheet over it otherwise, which needs no `open`.
                open: picking,
                onTap: () => split
                    ? setState(() => _showHosts = !_showHosts)
                    : unawaited(_showHostSheet(hostId)),
              ),
            ),
            if (hostId != null && !picking) ...[
              Btn.icon(
                text: libL10n.search,
                icon: const Icon(Icons.search, size: 18),
                onTap: _search.start,
              ),
              Btn.icon(
                text: libL10n.refresh,
                icon: const Icon(Icons.refresh, size: 18),
                onTap: () => _refresh(hostId),
              ),
              // In the section a new one lands in; the host's answer says
              // whether it takes one.
              if (_createLabel(caps) case final label?)
                Btn.icon(
                  key: const ValueKey('virt:create'),
                  text: label,
                  icon: const Icon(Icons.add, size: 18),
                  onTap: () => unawaited(_startCreate(hostId, split)),
                ),
            ],
            const SizedBox(width: 7),
          ],
        ),
      ),
    );

    final Widget body;
    if (picking) {
      body = _VirtHostPicker(
        key: const ValueKey('picker'),
        selectedId: hostId,
        onSelect: _selectHost,
        onCheck: _check,
        onSetUpPve: _setUpPve,
      );
    } else if (hostId == null) {
      body = KeyedSubtree(
        key: const ValueKey('no-hosts'),
        child: _buildNoHosts(hosts),
      );
    } else {
      body = ListenBuilder(
        // Keyed by the host, which is what the switcher above reads to tell
        // one host's list from another's — the `_VirtHostColumn` inside is
        // rebuilt in place by the search, so it cannot say that itself.
        key: ValueKey('host:$hostId'),
        listenable: _search,
        builder: () => _VirtHostColumn(
          serverId: hostId,
          needle: _search.needle,
          section: _section,
          onSection: _selectSection,
          selectedId: split ? _openId : null,
          onOpen: (id) => _openResource(hostId, id, split),
        ),
      );
    }

    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(SessionTabBar.height),
        child: bar,
      ),
      // Crossed rather than cut, so the bar above does not look like it was
      // pointing at one host's guests and now, between two frames, at
      // another's. See [_listSwapTransition].
      body: AnimatedSwitcher(
        duration: context.motion(_kListSwapDuration),
        reverseDuration: context.motion(_kListSwapDuration),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        transitionBuilder: _listSwapTransition,
        layoutBuilder: _listSwapLayout,
        child: body,
      ),
    );
  }

  /// What the add button makes in the section on screen, as the design
  /// names it; null where the host makes none.
  String? _createLabel(VirtCapabilities? caps) {
    if (caps == null) return null;
    // PVE's pending network configuration is the mark of its words: a
    // storage is added, a network is a Linux bridge.
    final pve = caps.networkApply;
    return switch (_section) {
      VirtSection.guests when caps.create =>
        caps.lxc ? l10n.virtCreateGuest : l10n.virtCreateVm,
      VirtSection.storage when caps.storageEdit && caps.poolTypes.isNotEmpty =>
        pve ? l10n.virtStorageAdd : l10n.virtPoolNew,
      VirtSection.network when caps.networkEdit && caps.networkModes.isNotEmpty =>
        pve ? l10n.virtNetNewBridge : l10n.virtNetNew,
      _ => null,
    };
  }

  /// No server is a host yet — or none has answered yet.
  Widget _buildNoHosts(VirtHostsState hosts) {
    final probing = hosts.probes.values.any(
      (p) => p.status == VirtProbeStatus.probing,
    );
    return Column(
      children: [
        if (probing) const ProgressLine(),
        Expanded(
          child: EmptyPane(
            icon: Icons.view_in_ar_outlined,
            title: l10n.virtNoHosts,
            label: l10n.virtNoHostsTip,
            action: Btn.text(
              text: l10n.virtCheckAll,
              onTap: probing
                  ? null
                  : () => unawaited(
                      ref.read(virtHostsProvider.notifier).refresh(),
                    ),
            ),
          ),
        ),
      ],
    );
  }
}

/// One host's column under the bar: its sections, its failure if it has one,
/// and its guests grouped by state — or its pools or networks.
class _VirtHostColumn extends ConsumerWidget {
  const _VirtHostColumn({
    required this.serverId,
    required this.needle,
    required this.section,
    required this.onSection,
    required this.selectedId,
    required this.onOpen,
  });

  final String serverId;
  final String needle;
  final VirtSection section;
  final ValueChanged<VirtSection> onSection;

  /// What is open beside the list, in [section].
  final String? selectedId;
  final ValueChanged<String> onOpen;

  /// Headed groups, in the order a reader wants them: what is running, what
  /// is on its way somewhere, what is paused, what is off.
  static const _groupOrder = [
    VirtGuestState.running,
    VirtGuestState.starting,
    VirtGuestState.stopping,
    VirtGuestState.rebooting,
    VirtGuestState.migrating,
    VirtGuestState.backup,
    VirtGuestState.paused,
    VirtGuestState.stopped,
    VirtGuestState.unknown,
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final st = ref.watch(virtHostProvider(serverId));
    final data = st.data;
    final busy =
        st.loading ||
        st.busy.isNotEmpty ||
        st.snapshotOps.isNotEmpty ||
        (data?.guests.any((g) => st.displayState(g).isTransient) ?? false);

    final caps = data?.capabilities;
    // A section the host does not have (the host changed, or its answer
    // did): the guests, which every host has.
    final shownSection = switch (section) {
      VirtSection.storage when caps?.storage ?? false => section,
      VirtSection.network when caps?.network ?? false => section,
      _ => VirtSection.guests,
    };
    final Widget body = switch (shownSection) {
      VirtSection.storage => VirtPoolList(
        serverId: serverId,
        needle: needle,
        selectedId: selectedId,
        onOpen: onOpen,
      ),
      VirtSection.network => VirtNetworkList(
        serverId: serverId,
        needle: needle,
        selectedId: selectedId,
        onOpen: onOpen,
      ),
      VirtSection.guests => _buildGuestList(context, ref, st),
    };

    return Column(
      children: [
        SizedBox(
          height: 3,
          child: busy && shownSection == VirtSection.guests
              ? const ProgressLine()
              : null,
        ),
        _buildSections(caps, shownSection),
        Expanded(child: body),
      ],
    );
  }

  Widget _buildGuestList(
    BuildContext context,
    WidgetRef ref,
    VirtHostState st,
  ) {
    final data = st.data;
    final err = st.error;
    return RefreshIndicator(
      onRefresh: () => _onRefresh(ref),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(9, 5, 9, 17),
        children: [
          if (err != null) VirtHostError(serverId: serverId, err: err),
          if (data?.host.pveUntested ?? false)
            _UntestedNotice(version: data!.host.version!),
          if (data == null && err == null)
            const Padding(
              padding: EdgeInsets.all(27),
              child: Center(child: SizedLoading.medium),
            ),
          if (data != null) ..._buildGuests(context, st, data),
        ],
      ),
    );
  }

  /// A pull asks the host again and the connected servers again: the host
  /// for its guests, the rest because a server that just got virsh is a
  /// reason to pull. Only the connected ones, since a pull is about this host
  /// and must not open servers the user keeps closed — "Check all" does that.
  /// Only the first is waited on, since the second talks to many servers.
  Future<void> _onRefresh(WidgetRef ref) async {
    unawaited(
      ref.read(virtHostsProvider.notifier).refresh(onlyConnected: true),
    );
    await ref.read(virtHostProvider(serverId).notifier).refresh();
  }

  /// Guests, and storage and network where the host has them. Until the
  /// host has answered, only the guests.
  Widget _buildSections(VirtCapabilities? caps, VirtSection shown) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(9, 3, 9, 0),
      child: SegmentedTabs<VirtSection>(
        expand: true,
        selected: shown,
        onSelected: onSection,
        segments: [
          SegmentedTab(
            value: VirtSection.guests,
            icon: VirtSection.guests.icon,
            // Containers included where the host has them: one short word
            // for the section, as the design names it.
            label: l10n.virtGuests,
          ),
          if (caps?.storage ?? false)
            SegmentedTab(
              value: VirtSection.storage,
              icon: VirtSection.storage.icon,
              label: libL10n.storage,
            ),
          if (caps?.network ?? false)
            SegmentedTab(
              value: VirtSection.network,
              icon: VirtSection.network.icon,
              label: libL10n.network,
            ),
        ],
      ),
    );
  }

  List<Widget> _buildGuests(
    BuildContext context,
    VirtHostState st,
    VirtSnapshot data,
  ) {
    if (data.guests.isEmpty) return [CenterGreyTitle(l10n.virtNoGuests)];
    final cluster = data.host.isCluster;
    final shown = [
      for (final g in data.guests)
        if (needle.isEmpty ||
            g.name.toLowerCase().contains(needle) ||
            '${g.vmid ?? ''}'.contains(needle))
          g,
    ];
    final templates = [for (final g in shown) if (g.template) g];
    final groups = <VirtGuestState, List<VirtGuest>>{};
    for (final g in shown) {
      if (g.template) continue;
      groups.putIfAbsent(st.displayState(g), () => []).add(g);
    }

    Widget row(VirtGuest g) => _GuestRow(
      key: ValueKey('guest:${g.id}'),
      guest: g,
      state: st.displayState(g),
      stats: st.statsOf(g.id),
      cluster: cluster,
      selected: g.id == selectedId,
      onTap: () => onOpen(g.id),
    );

    return [
      if (needle.isEmpty) _Allocation(st: st, data: data),
      if (shown.isEmpty) CenterGreyTitle(libL10n.empty),
      for (final state in _groupOrder)
        if (groups[state] case final list?) ...[
          SideBarSection('${state.label} · ${list.length}'),
          for (final g in list) row(g),
        ],
      if (templates.isNotEmpty) ...[
        SideBarSection('${l10n.virtTemplate} · ${templates.length}'),
        for (final g in templates) row(g),
      ],
    ];
  }
}

/// A PVE release older than the ones this app was tested on
/// (`VirtHost.pveUntested`). A notice beside the guests, not a failure: the
/// host works, and the user decides.
class _UntestedNotice extends StatelessWidget {
  const _UntestedNotice({required this.version});

  final String version;

  @override
  Widget build(BuildContext context) {
    return CardX(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(17, 11, 17, 11),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(
              Icons.info_outline,
              size: 18,
              color: StatePalette.warn,
            ),
            UIs.width7,
            Expanded(
              child: Text(
                'PVE $version\n${l10n.pveVersionLow}',
                style: UIs.text12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// What the running guests hold of the host: vCPUs and memory, against what
/// the host has where it says.
class _Allocation extends StatelessWidget {
  const _Allocation({required this.st, required this.data});

  final VirtHostState st;
  final VirtSnapshot data;

  @override
  Widget build(BuildContext context) {
    final guests = [for (final g in data.guests) if (!g.template) g];
    final active = [
      for (final g in guests)
        if (st.displayState(g).isActive) g,
    ];
    final running = guests
        .where((g) => st.displayState(g) == VirtGuestState.running)
        .length;
    var vcpu = 0;
    var mem = 0;
    for (final g in active) {
      vcpu += g.vcpu ?? 0;
      mem += g.memBytes ?? 0;
    }
    // Only where every node says: a sum over nodes that left some out is a
    // capacity smaller than the host's, and the bar would overstate the load.
    final nodes = data.host.nodes;
    int? sum(int? Function(VirtNode) of) {
      if (nodes.isEmpty) return null;
      var total = 0;
      for (final n in nodes) {
        final v = of(n);
        if (v == null || v <= 0) return null;
        total += v;
      }
      return total;
    }

    final cpuCap = sum((n) => n.maxCpu);
    final memCap = sum((n) => n.memTotal);

    Widget meter(String k, String v, double? frac) => Padding(
      padding: const EdgeInsets.only(top: 7),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text(k, style: UIs.text12Grey),
              UIs.width7,
              Expanded(
                child: Text(
                  v,
                  textAlign: TextAlign.end,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            ],
          ),
          if (frac != null) ...[
            const SizedBox(height: 5),
            ProgressLine(value: frac.clamp(0, 1)),
          ],
        ],
      ),
    );

    return CardX(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(17, 11, 17, 13),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Wraps rather than squeezes: the list column is as narrow as
            // 160 points, and neither half reads when cut.
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.end,
              spacing: 7,
              children: [
                Text(l10n.virtAllocated, style: UIs.text13Bold),
                Text(
                  l10n.virtRunningCount(running, guests.length),
                  style: UIs.text12Grey,
                ),
              ],
            ),
            meter(
              'vCPU',
              cpuCap == null ? '$vcpu' : '$vcpu / $cpuCap',
              cpuCap == null ? null : vcpu / cpuCap,
            ),
            meter(
              libL10n.memory,
              memCap == null
                  ? mem.bytes2Str
                  : '${mem.bytes2Str} / ${memCap.bytes2Str}',
              memCap == null ? null : mem / memCap,
            ),
          ],
        ),
      ),
    );
  }
}

/// A guest in the list: its state, its name, how busy it is, and what it is.
class _GuestRow extends StatelessWidget {
  const _GuestRow({
    super.key,
    required this.guest,
    required this.state,
    required this.stats,
    required this.cluster,
    required this.selected,
    required this.onTap,
  });

  final VirtGuest guest;
  final VirtGuestState state;
  final VirtStats? stats;
  final bool cluster;
  final bool selected;
  final VoidCallback onTap;

  static final _radius = BorderRadius.circular(9);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final cpu = stats?.cpu;
    // A running guest's load is the thing worth a glance; anything else says
    // what it is doing instead.
    final meta = state == VirtGuestState.running && cpu != null
        ? '${cpu.toStringAsFixed(0)}%'
        : state.label;
    final sub = [
      if (guest.vmid case final vmid?) '$vmid',
      if (guest.kind == VirtGuestKind.lxc) guest.kind.label,
      if (guest.vcpu case final n?) '$n vCPU',
      if (guest.memBytes case final m?) m.bytes2Str,
      if (cluster) ?guest.node,
    ].join(' · ');
    final fg = selected ? scheme.onSecondaryContainer : scheme.onSurface;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Material(
        color: selected ? scheme.secondaryContainer : Colors.transparent,
        borderRadius: _radius,
        child: InkWell(
          borderRadius: _radius,
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(13, 8, 11, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    VirtStateDot(state),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Text(
                        guest.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: fg,
                        ),
                      ),
                    ),
                    UIs.width7,
                    Text(
                      meta,
                      maxLines: 1,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
                if (sub.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(left: 16, top: 2),
                    child: Text(
                      sub,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: UIs.text11Grey,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
