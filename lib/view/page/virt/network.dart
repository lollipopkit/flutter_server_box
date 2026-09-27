part of 'hardware.dart';

/// One network — the design's network view: how it is set up, the guests on
/// it, and what can be done to it.
///
/// libvirt applies a change as it is made. PVE writes it to the node's
/// `interfaces.new` and applies it only when told to, as its own web UI
/// does: [VirtNetworkPendingCard] says what waits, with Apply and Revert.
/// A network with guests on it cannot be deleted.
class VirtNetworkView extends ConsumerStatefulWidget {
  const VirtNetworkView({
    super.key,
    required this.serverId,
    required this.netId,
    required this.onOpenGuest,
    this.leading,
    this.onSwitch,
    this.onDeleted,
  });

  final String serverId;
  final String netId;
  final Widget? leading;

  /// Opens a guest on it.
  final ValueChanged<String> onOpenGuest;

  /// Moves to another network in place; null where the list is beside this.
  final ValueChanged<String>? onSwitch;

  /// The network was deleted: whatever showed it closes it.
  final VoidCallback? onDeleted;

  @override
  ConsumerState<VirtNetworkView> createState() => _VirtNetworkViewState();
}

class _VirtNetworkViewState extends ConsumerState<VirtNetworkView>
    with _PaneRows<VirtNetworkView> {
  String get _serverId => widget.serverId;

  @override
  Widget build(BuildContext context) {
    final nets = ref.watch(virtNetworksProvider(_serverId));
    final all = nets.value ?? const <VirtNetwork>[];
    final net = all.firstWhereOrNull((n) => n.id == widget.netId);
    final at = net == null ? -1 : all.indexOf(net);
    final host = ref.watch(virtHostProvider(_serverId));
    final caps = host.data?.capabilities ?? const VirtCapabilities();
    final switchTo = widget.onSwitch;
    final busy = net != null && host.resourceOps.contains('net:${net.id}');
    final bar = virtResourceBar(
      name: net?.name ?? '',
      icon: Icons.lan_outlined,
      leading: widget.leading,
      position: switchTo != null && at >= 0 ? at + 1 : null,
      total: switchTo != null ? all.length : 0,
      onSwitch: switchTo != null && all.length > 1
          ? () => unawaited(_pick(all, switchTo))
          : null,
      actions: [
        // A PVE interface the app must not touch is not offered at all.
        if (net != null && caps.networkEditExisting && net.managementEditable)
          Btn.icon(
            key: const ValueKey('net:edit'),
            text: l10n.virtNetEdit,
            icon: const Icon(Icons.edit_outlined, size: 18),
            onTap: busy ? null : () => unawaited(_edit(net)),
          ),
        if (net != null && caps.networkStart)
          Btn.icon(
            key: const ValueKey('net:toggle'),
            text: net.active ? libL10n.stop : libL10n.start,
            icon: Icon(
              net.active ? Icons.stop_circle_outlined : Icons.play_circle_outline,
              size: 18,
            ),
            onTap: busy ? null : () => unawaited(_setActive(net, !net.active)),
          ),
      ],
      onRefresh: () {
        ref.invalidate(virtNetworksProvider(_serverId));
        ref.invalidate(virtNetworkChangesProvider(_serverId));
      },
    );
    if (net == null) {
      return Scaffold(
        appBar: bar,
        body: nets.isLoading
            ? const Center(child: SizedLoading.medium)
            : nets.hasError
            ? ListView(
                padding: const EdgeInsets.all(13),
                children: [VirtErrCard(nets.error!)],
              )
            : EmptyPane(icon: Icons.lan_outlined, label: libL10n.empty),
      );
    }
    return Scaffold(
      appBar: bar,
      body: Column(
        children: [
          SizedBox(
            height: 3,
            child: nets.isLoading || busy ? const ProgressLine() : null,
          ),
          Expanded(
            child: _buildGroups(
              [
                _configGroup(net, caps, busy),
                if (net.takesGuests) _usersGroup(net, host),
                if (caps.networkEdit && net.takesGuests)
                  _opsGroup(net, caps, busy),
              ],
              header: [
                if (caps.networkApply && net.node != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 9),
                    child: VirtNetworkPendingCard(
                      serverId: _serverId,
                      node: net.node,
                    ),
                  ),
              ],
              onRefresh: () {
                ref.invalidate(virtNetworkChangesProvider(_serverId));
                return ref.refresh(virtNetworksProvider(_serverId).future);
              },
            ),
          ),
        ],
      ),
    );
  }

  _Group _configGroup(VirtNetwork net, VirtCapabilities caps, bool busy) {
    final pveBridge = net.node != null && net.mode == 'bridge';
    return _Group(
      key: 'cfg',
      title: pveBridge ? 'Linux bridge' : l10n.virtNetConfig,
      right: net.active ? libL10n.active : libL10n.inactive,
      warn: !net.active,
      dot: net.active ? StatePalette.running : StatePalette.idle,
      indexNote: [net.modeLabel, net.bridge ?? l10n.virtNetInternal].join(' · '),
      rows: [
        _field(Icons.router_outlined, libL10n.mode, net.modeLabel),
        if (net.node case final n?) _field(Icons.dns_outlined, libL10n.node, n),
        if (net.bridge case final b?)
          _field(Icons.settings_ethernet, l10n.virtBridge, b, mono: true),
        if (pveBridge)
          _field(
            Icons.settings_ethernet,
            l10n.virtNetBridgePorts,
            net.ports.isEmpty ? l10n.virtNetInternal : net.ports.join(' '),
            mono: true,
          )
        else if (net.ports.isNotEmpty)
          _field(Icons.settings_ethernet, l10n.virtPorts, net.ports.join(', '), mono: true),
        _field(
          Icons.language,
          'IPv4 / CIDR',
          net.cidrs.isEmpty ? '--' : net.cidrs.join('\n'),
          mono: true,
        ),
        if (net.gateway case final g?)
          _field(Icons.alt_route, libL10n.gateway, g, mono: true),
        if (net.dhcpRanges.isNotEmpty)
          _field(
            Icons.format_list_numbered,
            l10n.virtNetDhcpRange,
            net.dhcpRanges.join('\n'),
            mono: true,
          ),
        if (net.vlanAware case final v?)
          _field(Icons.segment, l10n.virtNetVlanAware, v ? libL10n.enabled : libL10n.disabled),
        if (net.vlanId case final id?)
          _field(Icons.segment, 'VLAN', [id, ?net.vlanDevice].join(' · ')),
        if (net.bondMode case final m?) _field(Icons.merge_type, libL10n.mode, m),
        if (net.comment case final c? when c.isNotEmpty)
          _field(Icons.notes, libL10n.note, c),
        if (caps.networkStart)
          _toggle(
            Icons.power_settings_new,
            l10n.virtHwAutostart,
            net.autostart ?? false,
            key: 'net:autostart',
            onChanged: busy
                ? null
                : (on) => unawaited(
                    _manage(VirtNetworkSetAutostart(net, on: on)),
                  ),
          )
        else if (net.autostart case final a?)
          _field(
            Icons.power_settings_new,
            l10n.virtHwAutostart,
            a ? libL10n.enabled : libL10n.disabled,
          ),
        if (caps.networkApply && !net.active) _text(l10n.virtNetInactivePve),
        if (caps.networkApply && net.node != null && !net.managementEditable)
          _text(
            net.mode == 'bridge'
                ? l10n.virtNetManagementTip
                : l10n.virtNetPhysicalTip,
          ),
        if (caps.networkRestart && net.pendingRestart) ...[
          _text(l10n.virtNetEditPending, error: true),
          _actions([
            _Action(
              l10n.virtNetRestart,
              key: 'net:restart',
              icon: Icons.restart_alt,
              onTap: busy ? null : () => unawaited(_restart(net)),
            ),
          ]),
        ],
        if (net.hosts.isNotEmpty) ...[
          _text(l10n.virtNetHosts),
          for (final (i, h) in net.hosts.indexed)
            _field(
              Icons.link,
              h.name?.isNotEmpty ?? false ? h.name! : h.mac,
              '${h.mac} → ${h.ip}',
              key: ValueKey('net:host:$i'),
              mono: true,
            ),
        ] else if (net.node == null)
          _text(l10n.virtNetHostEmpty),
      ],
    );
  }

  _Group _usersGroup(VirtNetwork net, VirtHostState host) {
    final scheme = Theme.of(context).colorScheme;
    return _Group(
      key: 'users',
      title: l10n.virtAttachedGuests,
      right: '${net.users.length}',
      warn: false,
      indexNote: '${net.users.length}',
      rows: [
        if (net.users.isEmpty) _text(l10n.virtNoAttachedGuests),
        for (final (i, u) in net.users.indexed)
          Builder(
            key: ValueKey('netguest:$i'),
            builder: (context) {
              final guest = virtGuestOf(host, u);
              final state = guest == null ? null : host.displayState(guest);
              final sub = [?u.device, ?u.ip, ?u.mac].join(' · ');
              return _box(
                onTap: guest == null ? null : () => widget.onOpenGuest(guest.id),
                child: Row(
                  children: [
                    SizedBox(
                      width: 19,
                      child: state == null
                          ? _icon(Icons.help_outline)
                          : Center(child: VirtStateDot(state, size: 9)),
                    ),
                    UIs.width13,
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            virtGuestLabel(host, u),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: UIs.text13,
                          ),
                          if (sub.isNotEmpty)
                            Text(
                              sub,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: UIs.text11Grey.copyWith(fontFamily: 'monospace'),
                            ),
                        ],
                      ),
                    ),
                    if (guest != null)
                      Icon(Icons.chevron_right, size: 17, color: scheme.outline),
                  ],
                ),
              );
            },
          ),
      ],
    );
  }

  _Group _opsGroup(VirtNetwork net, VirtCapabilities caps, bool busy) {
    final inUse = net.users.isNotEmpty;
    return _Group(
      key: 'ops',
      title: l10n.virtOps,
      right: '',
      warn: false,
      dot: Theme.of(context).colorScheme.error,
      indexNote: inUse ? l10n.virtInUse : l10n.virtCanDelete,
      rows: [
        if (inUse) _text(l10n.virtNetInUse(net.users.length)),
        _actions([
          if (caps.networkStart)
            net.active
                ? _Action(
                    libL10n.stop,
                    key: 'net:stop',
                    icon: Icons.stop_circle_outlined,
                    danger: true,
                    onTap: busy ? null : () => unawaited(_setActive(net, false)),
                  )
                : _Action(
                    libL10n.start,
                    key: 'net:start',
                    icon: Icons.play_circle_outline,
                    onTap: busy ? null : () => unawaited(_setActive(net, true)),
                  ),
          _Action(
            l10n.virtNetDelete,
            key: 'net:delete',
            icon: Icons.delete_outline,
            danger: true,
            onTap: busy || inUse || !net.managementEditable
                ? null
                : () => unawaited(_delete(net, caps)),
          ),
        ]),
      ],
    );
  }

  Future<bool> _manage(VirtResourceChange change) =>
      virtManage(ref, _serverId, change);

  /// Opens the configuration of [net] for editing: the design's own form in
  /// the detail pane, with everything it costs said before it is saved.
  ///
  /// libvirt: the mode, the address, the DHCP range and the static hosts.
  /// The running network keeps what it has until it is restarted, so the
  /// restart is a choice of its own, and a network with guests on it says
  /// what restarting does to them.
  ///
  /// PVE: a bridge's ports, address, VLAN awareness and autostart, written
  /// into the node's pending configuration — the same pending/apply model
  /// the app already uses. A bridge carrying the node's management traffic
  /// is not offered at all (the bar has no edit action for it).
  Future<void> _edit(VirtNetwork net) async {
    await showVirtNetworkEdit(
      context,
      ref,
      serverId: _serverId,
      network: net,
    );
  }

  /// Stops and starts the network so its definition is what runs — what a
  /// change written without a restart waits for. Asked first, with the
  /// guests on it named: they lose their link meanwhile.
  Future<void> _restart(VirtNetwork net) async {
    final ok = await context.showRoundDialog<bool>(
      title: l10n.virtNetRestart,
      child: Text(
        net.users.isEmpty
            ? l10n.virtNetRestartAskNone(net.name)
            : l10n.virtNetRestartAsk(net.name, net.users.length),
      ),
      actions: Btnx.cancelRedOk,
    );
    if (ok != true || !mounted) return;
    await _manage(VirtNetworkRestart(net));
  }

  /// Stopping one with guests on it cuts them off: asked first.
  Future<void> _setActive(VirtNetwork net, bool active) async {
    if (!active && net.users.isNotEmpty) {
      final ok = await context.showRoundDialog<bool>(
        title: libL10n.attention,
        child: Text(l10n.virtNetStopAsk(net.name, net.users.length)),
        actions: Btnx.cancelRedOk,
      );
      if (ok != true || !mounted) return;
    }
    await _manage(VirtNetworkSetActive(net, active: active));
  }

  Future<void> _delete(VirtNetwork net, VirtCapabilities caps) async {
    final ok = await context.showRoundDialog<bool>(
      title: libL10n.attention,
      child: Text(
        caps.networkApply
            ? l10n.virtNetDeleteAskPve(net.name, net.node ?? '')
            : l10n.virtNetDeleteAsk(net.name),
      ),
      actions: Btnx.cancelRedOk,
    );
    if (ok != true || !mounted) return;
    if (await _manage(VirtNetworkDelete(net))) widget.onDeleted?.call();
  }

  Future<void> _pick(
    List<VirtNetwork> all,
    ValueChanged<String> onSwitch,
  ) async {
    final picked = await showRowsSheet<String>(
      context,
      rows: (ctx) => [
        for (final n in all)
          ListTile(
            selected: n.id == widget.netId,
            leading: const Icon(Icons.lan_outlined),
            title: Text(n.name, maxLines: 1, overflow: TextOverflow.ellipsis),
            subtitle: Text(
              [n.modeLabel, ?n.node].join(' · '),
              style: UIs.textGrey,
            ),
            onTap: () => Navigator.of(ctx).pop(n.id),
          ),
      ],
    );
    if (picked == null || picked == widget.netId || !mounted) return;
    onSwitch(picked);
  }
}

/// Makes [change] through the host's notifier and says what came of it.
/// True when the host took it.
Future<bool> virtManage(
  WidgetRef ref,
  String serverId,
  VirtResourceChange change, {
  bool quiet = false,
}) async {
  try {
    await ref.read(virtHostProvider(serverId).notifier).manage(change);
    if (!quiet) {
      Toast.success(
        change is VirtNetworkCreate || change is VirtNetworkDelete
            ? (ref.read(virtHostProvider(serverId)).data?.capabilities.networkApply ?? false)
                  ? l10n.virtNetPendingSaved
                  : libL10n.success
            : libL10n.success,
      );
    }
    return true;
  } on VirtErr catch (e) {
    Toast.error(e.title, body: e.detail);
  } catch (e, s) {
    Loggers.app.warning('Virtualization storage or network', e, s);
    Toast.error(libL10n.fail, body: '$e');
  }
  return false;
}

/// A node's network configuration written but not applied (PVE), with the
/// diff, Revert and Apply — PVE's own "Pending changes" and "Apply
/// Configuration". Nothing where nothing waits.
class VirtNetworkPendingCard extends ConsumerWidget {
  const VirtNetworkPendingCard({super.key, required this.serverId, this.node});

  final String serverId;

  /// Only this node's; every node's when null.
  final String? node;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final changes = ref.watch(virtNetworkChangesProvider(serverId)).value;
    final busy = ref.watch(
      virtHostProvider(serverId).select((s) => s.resourceOps.contains('nets')),
    );
    final shown = [
      for (final c in changes ?? const <VirtNetworkChanges>[])
        if (node == null || c.node == node) c,
    ];
    if (shown.isEmpty) return UIs.placeholder;
    final warn = StatePalette.warn;
    return Column(
      children: [
        for (final c in shown)
          CardX(
            key: ValueKey('net:pending:${c.node}'),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(13, 11, 9, 7),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.schedule, size: 18, color: warn),
                      UIs.width7,
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l10n.virtNetPendingTitle(c.node),
                              style: UIs.text13Bold.copyWith(color: warn),
                            ),
                            Text(l10n.virtNetPendingTip, style: UIs.text12Grey),
                          ],
                        ),
                      ),
                    ],
                  ),
                  Wrap(
                    alignment: WrapAlignment.end,
                    spacing: 3,
                    children: [
                      Btn.text(
                        text: l10n.virtNetPendingShow,
                        onTap: () => unawaited(_showDiff(context, c)),
                      ),
                      Btn.text(
                        key: ValueKey('net:pending:${c.node}:revert'),
                        text: l10n.virtHwRevert,
                        textStyle: TextStyle(color: Theme.of(context).colorScheme.error),
                        onTap: busy
                            ? null
                            : () => unawaited(_revert(context, ref, c)),
                      ),
                      Btn.text(
                        key: ValueKey('net:pending:${c.node}:apply'),
                        text: l10n.virtNetApply,
                        onTap: busy
                            ? null
                            : () => unawaited(_apply(context, ref, c)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  static Future<void> _showDiff(BuildContext context, VirtNetworkChanges c) =>
      context.showRoundDialog<void>(
        title: l10n.virtNetPendingTitle(c.node),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SelectableText(
            c.diff.trimRight(),
            style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
          ),
        ),
        actions: [Btn.ok()],
      );

  Future<void> _apply(
    BuildContext context,
    WidgetRef ref,
    VirtNetworkChanges c,
  ) async {
    final ok = await context.showRoundDialog<bool>(
      title: l10n.virtNetApply,
      child: Text(l10n.virtNetApplyAsk(c.node)),
      actions: Btnx.cancelRedOk,
    );
    if (ok != true) return;
    await virtManage(ref, serverId, VirtNetworkApply(c.node));
  }

  Future<void> _revert(
    BuildContext context,
    WidgetRef ref,
    VirtNetworkChanges c,
  ) async {
    final ok = await context.showRoundDialog<bool>(
      title: l10n.virtHwRevert,
      child: Text(l10n.virtNetRevertAsk(c.node)),
      actions: Btnx.cancelRedOk,
    );
    if (ok != true) return;
    await virtManage(ref, serverId, VirtNetworkRevert(c.node));
  }
}

/// A new network — the design's form in the detail pane: libvirt's virtual
/// network (NAT, routed, isolated, or a host bridge's), or a PVE Linux
/// bridge, which waits in the node's pending configuration until applied.
class VirtNetworkCreateView extends ConsumerStatefulWidget {
  const VirtNetworkCreateView({
    super.key,
    required this.serverId,
    required this.onCancel,
    required this.onCreated,
    this.leading,
  });

  final String serverId;
  final VoidCallback onCancel;

  /// The new network's id.
  final ValueChanged<String> onCreated;
  final Widget? leading;

  @override
  ConsumerState<VirtNetworkCreateView> createState() =>
      _VirtNetworkCreateViewState();
}

class _VirtNetworkCreateViewState extends ConsumerState<VirtNetworkCreateView>
    with _PaneRows<VirtNetworkCreateView> {
  final _name = TextEditingController();
  final _bridge = TextEditingController();
  final _cidr = TextEditingController();
  final _dhcpStart = TextEditingController();
  final _dhcpEnd = TextEditingController();
  String? _mode;
  String? _node;
  var _dhcp = true;
  var _vlanAware = false;
  var _creating = false;

  /// The DHCP range was typed, not filled from the address.
  var _rangeTyped = false;

  @override
  void initState() {
    super.initState();
    unawaited(
      ref
          .read(virtNetworksProvider(widget.serverId).future)
          .then((nets) {
            if (!mounted) return;
            final host = ref.read(virtHostProvider(widget.serverId));
            final pve = host.data?.capabilities.networkApply ?? false;
            final node = host.data?.host.nodes
                .firstWhereOrNull((n) => n.online)
                ?.name;
            setState(() => _prefill(pve, nets, node));
          })
          .catchError((Object _) {}),
    );
  }

  @override
  void dispose() {
    _name.dispose();
    _bridge.dispose();
    _cidr.dispose();
    _dhcpStart.dispose();
    _dhcpEnd.dispose();
    super.dispose();
  }

  /// A name and an address nothing else on the host has, as the design
  /// fills them in: `vmbrN` on PVE, a /24 in 192.168.150+ on libvirt.
  void _prefill(bool pve, List<VirtNetwork> nets, String? node) {
    if (pve) {
      final taken = {for (final n in nets) if (n.node == node) n.name};
      var i = 1;
      while (taken.contains('vmbr$i')) {
        i++;
      }
      _name.text = 'vmbr$i';
      return;
    }
    for (var third = 150; third < 255; third++) {
      final cidr = '192.168.$third.1/24';
      final issue = virtResourceIssue(
        VirtNetworkCreate(name: 'x', mode: 'nat', cidr: cidr),
        host: VirtHostKind.libvirt,
        networks: nets,
      );
      if (issue == null) {
        _cidr.text = cidr;
        _fillRange();
        return;
      }
    }
  }

  void _fillRange() {
    if (_rangeTyped) return;
    final r = virtDefaultDhcpRange(_cidr.text);
    _dhcpStart.text = r?.$1 ?? '';
    _dhcpEnd.text = r?.$2 ?? '';
  }

  @override
  Widget build(BuildContext context) {
    final host = ref.watch(virtHostProvider(widget.serverId));
    final caps = host.data?.capabilities ?? const VirtCapabilities();
    final pve = caps.networkApply;
    final nets = ref.watch(virtNetworksProvider(widget.serverId)).value;
    final nodes = [
      for (final n in host.data?.host.nodes ?? const <VirtNode>[])
        if (n.online) n.name,
    ];
    final node = pve ? (nodes.contains(_node) ? _node : nodes.firstOrNull) : null;
    final modes = caps.networkModes;
    final mode = modes.contains(_mode) ? _mode! : modes.firstOrNull ?? 'nat';
    final hostBridge = !pve && mode == 'bridge';
    final dhcp = !pve && !hostBridge && _dhcp;
    final change = VirtNetworkCreate(
      name: _name.text.trim(),
      mode: mode,
      node: node,
      bridge: pve || hostBridge ? _bridge.text.trim() : null,
      cidr: hostBridge ? null : _cidr.text.trim(),
      dhcpStart: dhcp ? _dhcpStart.text.trim() : null,
      dhcpEnd: dhcp ? _dhcpEnd.text.trim() : null,
      vlanAware: pve && _vlanAware,
    );
    final issue = virtResourceIssue(
      change,
      host: pve ? VirtHostKind.pve : VirtHostKind.libvirt,
      networks: nets ?? const [],
    );
    String? on(Set<VirtResIssue> which) => which.contains(issue)
        ? virtResIssueText(issue, pve: pve)
        : null;
    final ready = nets != null && issue == null && !_creating;
    return Scaffold(
      appBar: virtResourceBar(
        name: pve ? l10n.virtNetNewBridge : l10n.virtNetNew,
        icon: Icons.add_circle_outline,
        leading: widget.leading,
        actions: [
          Btn.icon(
            text: libL10n.cancel,
            icon: const Icon(Icons.close, size: 18),
            onTap: widget.onCancel,
          ),
        ],
      ),
      body: Column(
        children: [
          SizedBox(height: 3, child: _creating ? const ProgressLine() : null),
          Expanded(
            child: _buildGroups(
              [
                _Group(
                  key: 'new',
                  title: pve ? 'Linux bridge' : l10n.virtNetVirtual,
                  right:
                      ref.read(serversProvider).servers[widget.serverId]?.name ?? '',
                  warn: false,
                  indexNote: mode,
                  rows: [
                    Input(
                      key: const ValueKey('net:new:name'),
                      controller: _name,
                      label: libL10n.name,
                      icon: Icons.label_outline,
                      hint: pve ? 'vmbr2' : 'lab-2',
                      noWrap: true,
                      suggestion: false,
                      errorText: _name.text.isEmpty
                          ? null
                          : on(const {VirtResIssue.nameInvalid, VirtResIssue.nameTaken}),
                      onChanged: (_) => setState(() {}),
                    ),
                    if (pve && nodes.length > 1)
                      _seg(
                        Icons.dns_outlined,
                        libL10n.node,
                        nodes,
                        node,
                        key: 'net:new:node',
                        onSelected: (n) => setState(() => _node = n),
                      ),
                    if (!pve)
                      _choice([
                        for (final m in modes)
                          _Choice(
                            key: 'net:new:mode:$m',
                            icon: switch (m) {
                              'nat' => Icons.router_outlined,
                              'route' => Icons.alt_route,
                              'isolated' => Icons.link_off,
                              _ => Icons.lan_outlined,
                            },
                            label: switch (m) {
                              'nat' => 'NAT',
                              'route' => l10n.virtNetRouted,
                              'isolated' => l10n.virtNetIsolated,
                              _ => l10n.virtNetBridged,
                            },
                            sub: switch (m) {
                              'nat' => l10n.virtNetNatTip,
                              'route' => l10n.virtNetRoutedTip,
                              'isolated' => l10n.virtNetIsolatedTip,
                              _ => l10n.virtNetBridgedTip,
                            },
                            selected: m == mode,
                            onTap: () => setState(() => _mode = m),
                          ),
                      ]),
                    if (pve || hostBridge)
                      Input(
                        key: const ValueKey('net:new:bridge'),
                        controller: _bridge,
                        label: pve ? l10n.virtNetBridgePorts : l10n.virtNetHostBridge,
                        icon: Icons.settings_ethernet,
                        hint: pve ? l10n.virtNetPortsHint : 'br1',
                        noWrap: true,
                        suggestion: false,
                        errorText: on(const {VirtResIssue.bridgeInvalid}),
                        onChanged: (_) => setState(() {}),
                      ),
                    if (!hostBridge)
                      Input(
                        key: const ValueKey('net:new:cidr'),
                        controller: _cidr,
                        label: 'IPv4 / CIDR',
                        icon: Icons.language,
                        hint: pve ? '10.20.0.1/24' : '192.168.150.1/24',
                        noWrap: true,
                        suggestion: false,
                        errorText: on(const {
                          VirtResIssue.cidrInvalid,
                          VirtResIssue.subnetTaken,
                        }),
                        onChanged: (_) => setState(_fillRange),
                      ),
                    if (!pve && !hostBridge) ...[
                      _toggle(
                        Icons.dns_outlined,
                        'DHCP',
                        _dhcp,
                        key: 'net:new:dhcp',
                        note: l10n.virtNetDhcpTip,
                        onChanged: (v) => setState(() => _dhcp = v),
                      ),
                      if (_dhcp)
                        Row(
                          children: [
                            Expanded(
                              child: Input(
                                key: const ValueKey('net:new:dhcp:start'),
                                controller: _dhcpStart,
                                label: l10n.virtNetDhcpRange,
                                icon: Icons.format_list_numbered,
                                noWrap: true,
                                suggestion: false,
                                errorText: on(const {VirtResIssue.dhcpInvalid}),
                                onChanged: (_) => setState(() => _rangeTyped = true),
                              ),
                            ),
                            Expanded(
                              child: Input(
                                key: const ValueKey('net:new:dhcp:end'),
                                controller: _dhcpEnd,
                                label: '–',
                                noWrap: true,
                                suggestion: false,
                                onChanged: (_) => setState(() => _rangeTyped = true),
                              ),
                            ),
                          ],
                        ),
                    ],
                    if (pve) ...[
                      _toggle(
                        Icons.segment,
                        l10n.virtNetVlanAware,
                        _vlanAware,
                        key: 'net:new:vlan',
                        note: l10n.virtNetVlanTip,
                        onChanged: (v) => setState(() => _vlanAware = v),
                      ),
                      _text(l10n.virtNetPveApplyNote),
                    ],
                    _actions([
                      _Action(
                        libL10n.cancel,
                        icon: Icons.close,
                        onTap: widget.onCancel,
                      ),
                      _Action(
                        libL10n.create,
                        key: 'net:new:create',
                        primary: true,
                        onTap: ready
                            ? () => unawaited(_create(change, pve))
                            : null,
                      ),
                    ]),
                  ],
                ),
              ],
              header: [
                if (pve)
                  Padding(
                    padding: const EdgeInsets.only(top: 9),
                    child: VirtNetworkPendingCard(serverId: widget.serverId, node: node),
                  ),
              ],
              onRefresh: () async {},
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _create(VirtNetworkCreate change, bool pve) async {
    setState(() => _creating = true);
    final ok = await virtManage(ref, widget.serverId, change);
    if (!mounted) return;
    setState(() => _creating = false);
    if (ok) widget.onCreated(pve ? '${change.node}/${change.name}' : change.name);
  }
}

/// The configuration file of a network, as the design's "配置文件" group: the
/// definition libvirt would write, or PVE's `/etc/network/interfaces` entry,
/// with the one edit that changes it.
///
/// Shown from [showVirtNetworkEdit] as a fold, so what is being changed is
/// readable while it is changed.
String? virtNetworkConfigText(VirtNetwork net) {
  if (net.xml.isNotEmpty) return net.xml;
  if (net.node == null) return null;
  final lines = [
    'auto ${net.name}',
    'iface ${net.name} inet ${net.address == null ? 'manual' : 'static'}',
    if (net.address != null) ' address ${net.cidrs.first}',
    if (net.gateway case final g?) ' gateway $g',
    ' bridge-ports ${net.ports.isEmpty ? 'none' : net.ports.join(' ')}',
    ' bridge-stp off',
    ' bridge-fd 0',
    if (net.vlanAware ?? false) ...[' bridge-vlan-aware yes', ' bridge-vids 2-4094'],
  ];
  return lines.join('\n');
}

/// Opens [network]'s configuration for editing, as the design's form in the
/// detail pane.
///
/// One dialog for both backends, because it is one question — what the
/// network is — and the answers differ only in which of them apply. What
/// each backend then does with the answer differs, and is said in the
/// dialog:
///
/// - libvirt writes the definition (`net-define`); the running network
///   keeps what it has until it is restarted, and restarting it cuts off
///   its guests. Both are stated, and the restart is a switch of its own.
/// - PVE writes the node's pending configuration
///   (`PUT /nodes/{node}/network/{iface}`), which applies with the
///   configuration as a whole — the card above the list, as before.
Future<void> showVirtNetworkEdit(
  BuildContext context,
  WidgetRef ref, {
  required String serverId,
  required VirtNetwork network,
}) async {
  // The form publishes what it would send whenever it changes; OK sends
  // that, and is held back while the host would refuse it.
  final draft = ValueNotifier(const _NetworkDraft(null, null));
  final VirtResourceChange? change;
  try {
    change = await context.showRoundDialog<VirtResourceChange>(
      title: l10n.virtNetEdit,
      child: _VirtNetworkEditForm(
        serverId: serverId,
        network: network,
        draft: draft,
      ),
      actions: [
        Btn.cancel(),
        ValueListenableBuilder(
          valueListenable: draft,
          builder: (context, d, _) => Btn.ok(
            onTap: switch (d) {
              _NetworkDraft(change: final c?, issue: null) =>
                () => context.popDialog<VirtResourceChange>(c),
              _ => null,
            },
          ),
        ),
      ],
    );
  } finally {
    draft.dispose();
  }
  if (change == null) return;
  await virtManage(ref, serverId, change);
}

/// What the edit form would send, and why it cannot: read by the dialog's
/// OK button, published by the form whenever it changes.
final class _NetworkDraft {
  const _NetworkDraft(this.change, this.issue);

  final VirtResourceChange? change;
  final VirtResIssue? issue;
}

/// The edit form itself: a dialog's body, wide enough for a phone and no
/// wider.
class _VirtNetworkEditForm extends ConsumerStatefulWidget {
  const _VirtNetworkEditForm({
    required this.serverId,
    required this.network,
    required this.draft,
  });

  final String serverId;
  final VirtNetwork network;

  /// Given what the form would send, every time it changes.
  final ValueNotifier<_NetworkDraft> draft;

  @override
  ConsumerState<_VirtNetworkEditForm> createState() =>
      _VirtNetworkEditFormState();
}

class _VirtNetworkEditFormState extends ConsumerState<_VirtNetworkEditForm> {
  late final _bridge = TextEditingController(text: widget.network.bridge ?? '');
  late final _address = TextEditingController(
    text: widget.network.address ?? '',
  );
  late final _prefix = TextEditingController(
    text: '${widget.network.prefix ?? 24}',
  );
  late final _ports = TextEditingController(
    text: widget.network.ports.join(' '),
  );
  late final _dhcpStart = TextEditingController(
    text: widget.network.dhcpRange?.$1 ?? '',
  );
  late final _dhcpEnd = TextEditingController(
    text: widget.network.dhcpRange?.$2 ?? '',
  );
  late String _mode = widget.network.mode;
  late bool _dhcp = widget.network.dhcpRange != null;
  late bool _vlanAware = widget.network.vlanAware ?? false;
  late bool _autostart = widget.network.autostart ?? true;
  var _restart = true;

  /// The static hosts, as drafts of their own: a MAC, an address, a name.
  late final List<_HostDraft> _hosts = [
    for (final h in widget.network.hosts) _HostDraft(h.mac, h.ip, h.name),
  ];

  bool get _pve => widget.network.node != null;

  @override
  void initState() {
    super.initState();
    // After the first frame: the dialog's button is being built with it.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _publish();
    });
  }

  /// Every change to the form goes through here, so the OK button follows.
  @override
  void setState(VoidCallback fn) {
    super.setState(fn);
    _publish();
  }

  void _publish() => widget.draft.value = _NetworkDraft(_change, _issue);

  /// The address with its prefix, as a CIDR; empty when there is none.
  String get _cidr {
    final address = _address.text.trim();
    return address.isEmpty ? '' : '$address/${_prefix.text.trim()}';
  }

  @override
  void dispose() {
    for (final f in [
      _bridge,
      _address,
      _prefix,
      _ports,
      _dhcpStart,
      _dhcpEnd,
    ]) {
      f.dispose();
    }
    for (final h in _hosts) {
      h.dispose();
    }
    super.dispose();
  }

  VirtResourceChange get _change {
    if (_pve) {
      return VirtNetworkEditBridge(
        widget.network,
        ports: _ports.text.trim(),
        cidr: _cidr,
        vlanAware: _vlanAware,
        autostart: _autostart,
      );
    }
    return VirtNetworkEdit(
      widget.network,
      mode: _mode,
      bridge: _mode == 'bridge' ? _bridge.text.trim() : null,
      address: _mode == 'bridge' ? null : _address.text.trim(),
      prefix: _mode == 'bridge' || _address.text.trim().isEmpty
          ? null
          : int.tryParse(_prefix.text.trim()),
      dhcpStart: _dhcp && _mode != 'bridge' ? _dhcpStart.text.trim() : null,
      dhcpEnd: _dhcp && _mode != 'bridge' ? _dhcpEnd.text.trim() : null,
      hosts: [
        // A row left wholly empty is no host; one with anything in it is,
        // and is checked as one rather than dropped.
        for (final h in _hosts)
          if ([h.mac, h.ip, h.name].any((c) => c.text.trim().isNotEmpty))
            VirtNetHost(
              mac: h.mac.text.trim().toLowerCase(),
              ip: h.ip.text.trim(),
              name: h.name.text.trim().isEmpty ? null : h.name.text.trim(),
            ),
      ],
      restart: _restart,
    );
  }

  /// Whether the running network has to be restarted for what is in the
  /// form to apply — the same question `VirtNetEdit::needs_restart` answers
  /// on the host. The static hosts never do: `net-update` takes them live.
  /// A field the form does not show (`bridge` in another mode) is compared
  /// against what the network is, so turning a switch that is not there is
  /// never a restart.
  bool get _needsRestart {
    final n = widget.network;
    final change = _change;
    if (change is! VirtNetworkEdit) return false;
    final address = change.address?.trim() ?? '';
    final saved = n.address ?? '';
    return change.mode != n.mode ||
        (change.mode == 'bridge' && change.bridge != n.bridge) ||
        address != saved ||
        (address.isNotEmpty && change.prefix != n.prefix) ||
        (change.dhcpStart ?? '') != (n.dhcpRange?.$1 ?? '') ||
        (change.dhcpEnd ?? '') != (n.dhcpRange?.$2 ?? '');
  }

  VirtResIssue? get _issue => virtResourceIssue(
    _change,
    host: _pve ? VirtHostKind.pve : VirtHostKind.libvirt,
    networks: ref.read(virtNetworksProvider(widget.serverId)).value ?? const [],
  );

  @override
  Widget build(BuildContext context) {
    final issue = _issue;
    String? on(Set<VirtResIssue> which) => which.contains(issue)
        ? virtResIssueText(issue, pve: _pve)
        : null;
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!_pve) ...[
            _label(libL10n.mode),
            _modes(),
          ],
          if (_pve) ...[
            Input(
              key: const ValueKey('net:edit:ports'),
              controller: _ports,
              label: l10n.virtNetBridgePorts,
              icon: Icons.settings_ethernet,
              hint: l10n.virtNetPortsHint,
              noWrap: true,
              suggestion: false,
              errorText: on(const {VirtResIssue.bridgeInvalid}),
              onChanged: (_) => setState(() {}),
            ),
            _toggle(
              Icons.segment,
              l10n.virtNetVlanAware,
              _vlanAware,
              key: 'net:edit:vlan',
              onChanged: (v) => setState(() => _vlanAware = v),
            ),
          ],
          if (!_pve && _mode == 'bridge')
            Input(
              key: const ValueKey('net:edit:bridge'),
              controller: _bridge,
              label: l10n.virtNetHostBridge,
              icon: Icons.settings_ethernet,
              hint: 'br0',
              noWrap: true,
              suggestion: false,
              errorText: on(const {VirtResIssue.bridgeInvalid}),
              onChanged: (_) => setState(() {}),
            )
          else ...[
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Input(
                    key: const ValueKey('net:edit:address'),
                    controller: _address,
                    label: 'IPv4',
                    icon: Icons.language,
                    hint: '10.20.0.1',
                    noWrap: true,
                    suggestion: false,
                    errorText: on(const {
                      VirtResIssue.cidrInvalid,
                      VirtResIssue.subnetTaken,
                    }),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                Expanded(
                  child: Input(
                    key: const ValueKey('net:edit:prefix'),
                    controller: _prefix,
                    label: '/',
                    noWrap: true,
                    suggestion: false,
                    onChanged: (_) => setState(() {}),
                  ),
                ),
              ],
            ),
            if (!_pve) ...[
              _toggle(
                Icons.dns_outlined,
                'DHCP',
                _dhcp,
                key: 'net:edit:dhcp',
                note: l10n.virtNetDhcpTip,
                onChanged: (v) => setState(() => _dhcp = v),
              ),
              if (_dhcp)
                Row(
                  children: [
                    Expanded(
                      child: Input(
                        key: const ValueKey('net:edit:dhcp:start'),
                        controller: _dhcpStart,
                        label: l10n.virtNetDhcpRange,
                        icon: Icons.format_list_numbered,
                        noWrap: true,
                        suggestion: false,
                        errorText: on(const {VirtResIssue.dhcpInvalid}),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                    Expanded(
                      child: Input(
                        key: const ValueKey('net:edit:dhcp:end'),
                        controller: _dhcpEnd,
                        label: '–',
                        noWrap: true,
                        suggestion: false,
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                  ],
                ),
            ],
          ],
          _toggle(
            Icons.power_settings_new,
            l10n.virtHwAutostart,
            _autostart,
            key: 'net:edit:autostart',
            onChanged: _pve ? (v) => setState(() => _autostart = v) : null,
          ),
          if (!_pve && _mode != 'bridge') ...[
            _label(l10n.virtNetHosts),
            for (final (i, h) in _hosts.indexed)
              _hostRow(i, h, issue == VirtResIssue.hostInvalid),
            if (_hosts.isEmpty) _note(l10n.virtNetHostEmpty),
            Align(
              alignment: Alignment.centerLeft,
              child: Btn.text(
                key: const ValueKey('net:edit:host:add'),
                text: l10n.virtNetHostAdd,
                onTap: () => setState(() => _hosts.add(_HostDraft())),
              ),
            ),
          ],
          const SizedBox(height: 7),
          _note(
            _pve
                ? l10n.virtNetPveEditNote
                : widget.network.active
                ? (widget.network.users.isEmpty
                      ? l10n.virtNetEditAskNoGuest
                      : l10n.virtNetEditAsk(widget.network.users.length))
                : l10n.virtNetEditAsk(widget.network.users.length),
            warn: !_pve && widget.network.active,
          ),
          // Only where the change waits for one: a static host alone
          // applies live, and a switch that did nothing would be a lie.
          if (!_pve && widget.network.active && _needsRestart)
            _toggle(
              Icons.restart_alt,
              l10n.virtNetEditRestart,
              _restart,
              key: 'net:edit:restart',
              note: l10n.virtNetEditRestartNote,
              onChanged: (v) => setState(() => _restart = v),
            ),
          if (issue != null)
            _note(virtResIssueText(issue, pve: _pve) ?? '', error: true),
          if (virtNetworkConfigText(widget.network) case final text?)
            _fold(text),
        ],
      ),
    );
  }

  Widget _label(String text) => Padding(
    padding: const EdgeInsets.only(top: 7, bottom: 3),
    child: Text(text, style: UIs.text12Grey),
  );

  Widget _note(String text, {bool warn = false, bool error = false}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Text(
      text,
      style: UIs.text12Grey.copyWith(
        color: error
            ? Theme.of(context).colorScheme.error
            : warn
            ? StatePalette.warn
            : null,
      ),
    ),
  );

  /// The four modes as rows, the designs' choice: a label, what it means,
  /// and a tick on the one chosen.
  Widget _modes() {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        for (final (m, icon, label, sub) in const [
          ('nat', Icons.router_outlined, 'NAT', 'virtNetNatTip'),
          ('route', Icons.alt_route, 'virtNetRouted', 'virtNetRoutedTip'),
          ('isolated', Icons.link_off, 'virtNetIsolated', 'virtNetIsolatedTip'),
          ('bridge', Icons.lan_outlined, 'virtNetBridged', 'virtNetBridgedTip'),
        ])
          Material(
            key: ValueKey('net:edit:mode:$m'),
            color: m == _mode ? scheme.secondaryContainer : Colors.transparent,
            borderRadius: BorderRadius.circular(13),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () => setState(() => _mode = m),
              child: Padding(
                padding: const EdgeInsets.all(9),
                child: Row(
                  children: [
                    Icon(
                      icon,
                      size: 19,
                      color: m == _mode ? scheme.onSecondaryContainer : null,
                    ),
                    UIs.width13,
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            switch (label) {
                              'virtNetRouted' => l10n.virtNetRouted,
                              'virtNetIsolated' => l10n.virtNetIsolated,
                              'virtNetBridged' => l10n.virtNetBridged,
                              _ => label,
                            },
                            style: UIs.text13.copyWith(fontWeight: FontWeight.w500),
                          ),
                          Text(
                            switch (sub) {
                              'virtNetNatTip' => l10n.virtNetNatTip,
                              'virtNetRoutedTip' => l10n.virtNetRoutedTip,
                              'virtNetIsolatedTip' => l10n.virtNetIsolatedTip,
                              _ => l10n.virtNetBridgedTip,
                            },
                            style: UIs.text11Grey,
                          ),
                        ],
                      ),
                    ),
                    if (m == _mode) const Icon(Icons.check, size: 17),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  /// One static host: its MAC, its address and its name, with Remove.
  Widget _hostRow(int i, _HostDraft h, bool bad) {
    return Padding(
      key: ValueKey('net:edit:host:$i'),
      padding: const EdgeInsets.only(bottom: 3),
      child: Column(
        children: [
          Input(
            key: ValueKey('net:edit:host:$i:mac'),
            controller: h.mac,
            label: l10n.virtNetHostMac,
            icon: Icons.tag,
            hint: '52:54:00:00:00:01',
            noWrap: true,
            suggestion: false,
            errorText: bad ? l10n.virtNetHostInvalid : null,
            onChanged: (_) => setState(() {}),
          ),
          Row(
            children: [
              Expanded(
                flex: 3,
                child: Input(
                  key: ValueKey('net:edit:host:$i:ip'),
                  controller: h.ip,
                  label: l10n.virtNetHostIp,
                  icon: Icons.language,
                  noWrap: true,
                  suggestion: false,
                  onChanged: (_) => setState(() {}),
                ),
              ),
              Expanded(
                flex: 4,
                child: Input(
                  key: ValueKey('net:edit:host:$i:name'),
                  controller: h.name,
                  label: l10n.virtNetHostName,
                  icon: Icons.label_outline,
                  noWrap: true,
                  suggestion: false,
                  onChanged: (_) => setState(() {}),
                ),
              ),
              Btn.icon(
                key: ValueKey('net:edit:host:$i:remove'),
                text: l10n.virtHwRemove,
                icon: const Icon(Icons.delete_outline, size: 18),
                onTap: () => setState(() {
                  _hosts.removeAt(i).dispose();
                }),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// The definition the change is made from, folded: what is being edited,
  /// readable while it is edited.
  Widget _fold(String text) {
    return _Fold(
      title: l10n.virtNetConfig,
      text: text,
      right: widget.network.node == null
          ? 'net-dumpxml'
          : '/etc/network/interfaces',
    );
  }

  Widget _toggle(
    IconData icon,
    String label,
    bool value, {
    String? key,
    String? note,
    ValueChanged<bool>? onChanged,
  }) {
    return SwitchListTile(
      key: key == null ? null : ValueKey(key),
      dense: true,
      contentPadding: EdgeInsets.zero,
      secondary: Icon(icon, size: 19),
      value: value,
      title: Text(label, style: UIs.text13),
      subtitle: note == null ? null : Text(note, style: UIs.text11Grey),
      onChanged: onChanged,
    );
  }
}

/// A static DHCP entry being typed.
class _HostDraft {
  _HostDraft([String mac = '', String ip = '', String? name])
    : mac = TextEditingController(text: mac),
      ip = TextEditingController(text: ip),
      name = TextEditingController(text: name ?? '');

  final TextEditingController mac;
  final TextEditingController ip;
  final TextEditingController name;

  void dispose() {
    mac.dispose();
    ip.dispose();
    name.dispose();
  }
}

/// A fold of read-only text, as the design's "配置文件" group: a row that
/// opens the definition under it.
class _Fold extends StatefulWidget {
  const _Fold({required this.title, required this.text, this.right});

  final String title;
  final String text;
  final String? right;

  @override
  State<_Fold> createState() => _FoldState();
}

class _FoldState extends State<_Fold> {
  var _open = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ListTile(
          key: const ValueKey('net:edit:config'),
          dense: true,
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.code, size: 19),
          title: Text(widget.title, style: UIs.text13),
          subtitle: widget.right == null ? null : Text(widget.right!, style: UIs.text11Grey),
          trailing: Icon(_open ? Icons.expand_less : Icons.expand_more, size: 17),
          onTap: () => setState(() => _open = !_open),
        ),
        if (_open)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SelectableText(
              widget.text.trimRight(),
              style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
            ),
          ),
      ],
    );
  }
}
