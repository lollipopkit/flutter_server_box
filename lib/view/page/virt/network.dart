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
          _field(Icons.segment, 'VLAN aware', v ? libL10n.enabled : libL10n.disabled),
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
            onTap: busy || inUse ? null : () => unawaited(_delete(net, caps)),
          ),
        ]),
      ],
    );
  }

  Future<bool> _manage(VirtResourceChange change) =>
      virtManage(ref, _serverId, change);

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
                        'VLAN aware',
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
