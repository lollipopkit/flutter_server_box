part of 'hardware.dart';

/// One network — the design's network view: its configuration, edited in
/// place, the guests on it, its configuration file, and what can be done to
/// it.
///
/// The configuration rows are a draft held here, as Hardware's are: nothing
/// reaches the host until Save, and Revert puts them back to what the
/// network is. What saving costs is said beside Save:
///
/// - libvirt writes the definition (`net-define`); the running network
///   keeps what it has until it is restarted, and restarting it cuts off
///   its guests. Both are stated, and the restart is a switch of its own.
/// - PVE writes the node's pending configuration
///   (`PUT /nodes/{node}/network/{iface}`) and applies it only when told
///   to, as its own web UI does: [VirtNetworkPendingCard] says what waits,
///   with Apply and Revert. A bridge carrying the node's management
///   traffic, and any interface that is not a bridge, is shown read-only.
///
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

  // --- The configuration draft ---

  /// The read the rows were filled from: what the draft is compared with,
  /// and the base Save sends unless a newer read has the same definition
  /// ([_save]). Null until a build fills the rows.
  VirtNetwork? _seeded;

  final _bridge = TextEditingController();
  final _cidr = TextEditingController();
  final _ports = TextEditingController();
  final _dhcpStart = TextEditingController();
  final _dhcpEnd = TextEditingController();
  var _mode = '';
  var _dhcp = false;
  var _vlanAware = false;
  var _autostart = true;

  /// Restart the running network on Save, where the change waits for one.
  var _restartOnSave = true;

  /// The static hosts, as drafts of their own: a MAC, an address, a name.
  /// Kept through bridge mode, which does not send them, for switching
  /// back.
  var _hosts = <_HostDraft>[];
  var _saving = false;

  @override
  void dispose() {
    for (final c in [_bridge, _cidr, _ports, _dhcpStart, _dhcpEnd]) {
      c.dispose();
    }
    for (final h in _hosts) {
      h.dispose();
    }
    super.dispose();
  }

  /// Fills the rows from [net], leaving no draft.
  void _seed(VirtNetwork net) {
    _seeded = net;
    _bridge.text = net.bridge ?? '';
    // The IPv4 address the rows edit; an IPv6 one is left to the host.
    _cidr.text = net.ipv4Cidr ?? '';
    _ports.text = net.ports.join(' ');
    _dhcpStart.text = net.dhcpRange?.$1 ?? '';
    _dhcpEnd.text = net.dhcpRange?.$2 ?? '';
    _mode = net.mode;
    _dhcp = net.dhcpRange != null;
    _vlanAware = net.vlanAware ?? false;
    _autostart = net.autostart ?? true;
    _restartOnSave = true;
    for (final h in _hosts) {
      h.dispose();
    }
    _hosts = [for (final h in net.hosts) _HostDraft(h.mac, h.ip, h.name)];
  }

  /// Whether the rows say something other than [_seeded]: a draft to save
  /// or revert.
  bool get _dirty {
    final n = _seeded;
    if (n == null) return false;
    final cidr = _cidr.text.trim() != (n.ipv4Cidr ?? '');
    if (n.node != null) {
      return cidr ||
          _ports.text.trim() != n.ports.join(' ') ||
          _vlanAware != (n.vlanAware ?? false) ||
          _autostart != (n.autostart ?? true);
    }
    return cidr ||
        _mode != n.mode ||
        _bridge.text.trim() != (n.bridge ?? '') ||
        _dhcp != (n.dhcpRange != null) ||
        _dhcpStart.text.trim() != (n.dhcpRange?.$1 ?? '') ||
        _dhcpEnd.text.trim() != (n.dhcpRange?.$2 ?? '') ||
        !listEquals(
          [for (final h in _hosts) h.entry],
          [for (final h in n.hosts) (h.mac, h.ip, h.name ?? '')],
        );
  }

  /// What Save sends, made from [base].
  VirtResourceChange _change(VirtNetwork base) {
    final cidr = _cidr.text.trim();
    if (base.node != null) {
      return VirtNetworkEditBridge(
        base,
        ports: _ports.text.trim(),
        cidr: cidr,
        vlanAware: _vlanAware,
        autostart: _autostart,
      );
    }
    final bridged = _mode == 'bridge';
    // One row for the address and its prefix, as the design has it; the
    // host takes them apart. A missing or unreadable prefix is null, which
    // [virtResourceIssue] refuses as the CIDR it is not.
    final at = cidr.indexOf('/');
    final address = at < 0 ? cidr : cidr.substring(0, at);
    return VirtNetworkEdit(
      base,
      mode: _mode,
      bridge: bridged ? _bridge.text.trim() : null,
      address: bridged ? null : address,
      prefix: bridged || address.isEmpty || at < 0
          ? null
          : int.tryParse(cidr.substring(at + 1)),
      dhcpStart: _dhcp && !bridged ? _dhcpStart.text.trim() : null,
      dhcpEnd: _dhcp && !bridged ? _dhcpEnd.text.trim() : null,
      hosts: [
        // A row left wholly empty is no host; one with anything in it is,
        // and is checked as one rather than dropped.
        // Bridge mode serves no DHCP: the drafts stay for switching back,
        // and are not sent.
        for (final h in _hosts)
          if (!bridged && h.entry != ('', '', ''))
            VirtNetHost(
              mac: h.entry.$1.toLowerCase(),
              ip: h.entry.$2,
              name: h.entry.$3.isEmpty ? null : h.entry.$3,
            ),
      ],
      restart: _restartOnSave,
    );
  }

  /// Whether the running network has to be restarted for [change] to
  /// apply — the same question `VirtNetEdit::needs_restart` answers on the
  /// host. The static hosts never do: `net-update` takes them live. A field
  /// the rows do not show (`bridge` in another mode) is compared against
  /// what the network is, so a row that is not there is never a restart.
  bool _needsRestart(VirtResourceChange change) {
    final n = _seeded;
    if (n == null || change is! VirtNetworkEdit) return false;
    final address = change.address?.trim() ?? '';
    return change.mode != n.mode ||
        (change.mode == 'bridge' && change.bridge != n.bridge) ||
        address != (n.address ?? '') ||
        (address.isNotEmpty && change.prefix != n.prefix) ||
        (change.dhcpStart ?? '') != (n.dhcpRange?.$1 ?? '') ||
        (change.dhcpEnd ?? '') != (n.dhcpRange?.$2 ?? '');
  }

  @override
  Widget build(BuildContext context) {
    final nets = ref.watch(virtNetworksProvider(_serverId));
    final all = nets.value ?? const <VirtNetwork>[];
    final net = all.firstWhereOrNull((n) => n.id == widget.netId);
    // Another network, or a new read of this one with no draft on it: the
    // rows follow. A draft stays on the read it was made from.
    if (net != null &&
        (_seeded?.id != net.id || (_seeded != net && !_dirty))) {
      _seed(net);
    }
    final at = net == null ? -1 : all.indexOf(net);
    final host = ref.watch(virtHostProvider(_serverId));
    final caps = host.data?.capabilities ?? const VirtCapabilities();
    final switchTo = widget.onSwitch;
    final busy =
        _saving ||
        net != null &&
            (host.resourceOps.contains('net:${net.id}') ||
                (net.node != null &&
                    host.resourceOps.contains(
                      VirtResourceChange.netNodeScope(net.node!),
                    )));
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
          BarAction(
            key: const ValueKey('net:toggle'),
            icon: net.active
                ? Icons.stop_circle_outlined
                : Icons.play_circle_outline,
            label: net.active ? libL10n.stop : libL10n.start,
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
                _configGroup(net, all, caps, busy),
                if (net.takesGuests) _usersGroup(net, host),
                if (virtNetworkConfigText(net) case final text?)
                  _fileGroup(net, text),
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

  /// The design's `cfg` group: the rows that edit the network where the app
  /// may edit it, what it is otherwise, and the draft's Save and Revert.
  _Group _configGroup(
    VirtNetwork net,
    List<VirtNetwork> all,
    VirtCapabilities caps,
    bool busy,
  ) {
    final pve = net.node != null;
    final pveBridge = pve && net.mode == 'bridge';
    // A PVE interface the app must not touch, or one that is not a bridge,
    // is not offered at all.
    final editable =
        caps.networkEditExisting &&
        net.managementEditable &&
        (!pve || pveBridge);
    return _Group(
      key: 'cfg',
      title: pveBridge ? 'Linux bridge' : l10n.virtNetConfig,
      right: net.active ? libL10n.active : libL10n.inactive,
      warn: !net.active,
      dot: net.active ? StatePalette.running : StatePalette.idle,
      indexNote: [net.modeLabel, net.bridge ?? l10n.virtNetInternal].join(' · '),
      rows: [
        if (!editable)
          ..._facts(net, caps, busy)
        else if (pve)
          ..._pveRows(net, all, busy)
        else
          ..._libvirtRows(net, all, caps, busy),
        if (caps.networkApply && !net.active) _text(l10n.virtNetInactivePve),
        if (caps.networkApply && pve && !net.managementEditable)
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
      ],
    );
  }

  /// What [net] is, read-only: where the app does not edit it.
  List<Widget> _facts(VirtNetwork net, VirtCapabilities caps, bool busy) {
    final pveBridge = net.node != null && net.mode == 'bridge';
    return [
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
      _autostartRow(net, caps, busy),
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
    ];
  }

  /// libvirt's autostart: marked on the network itself, at once, outside the
  /// definition the draft edits.
  Widget _autostartRow(VirtNetwork net, VirtCapabilities caps, bool busy) {
    if (caps.networkStart) {
      return _toggle(
        Icons.power_settings_new,
        l10n.virtHwAutostart,
        net.autostart ?? false,
        key: 'net:autostart',
        onChanged: busy
            ? null
            : (on) => unawaited(_manage(VirtNetworkSetAutostart(net, on: on))),
      );
    }
    return _field(
      Icons.power_settings_new,
      l10n.virtHwAutostart,
      (net.autostart ?? false) ? libL10n.enabled : libL10n.disabled,
    );
  }

  /// libvirt's rows, as the design's: the mode, the address or the host
  /// bridge, DHCP and its range, autostart — and the static hosts, which
  /// the design leaves out and the host takes.
  List<Widget> _libvirtRows(
    VirtNetwork net,
    List<VirtNetwork> all,
    VirtCapabilities caps,
    bool busy,
  ) {
    final bridged = _mode == 'bridge';
    final (issue, text) = _issue(net, all);
    String? on(Set<VirtResIssue> which) => which.contains(issue) ? text : null;
    final change = _change(_seeded ?? net);
    return [
      _choice([
        for (final (m, icon, label, sub) in [
          ('nat', Icons.router_outlined, 'NAT', l10n.virtNetNatTip),
          ('route', Icons.alt_route, l10n.virtNetRouted, l10n.virtNetRoutedTip),
          ('isolated', Icons.link_off, l10n.virtNetIsolated, l10n.virtNetIsolatedTip),
          ('bridge', Icons.lan_outlined, l10n.virtNetBridged, l10n.virtNetBridgedTip),
        ])
          _Choice(
            key: 'net:edit:mode:$m',
            icon: icon,
            label: label,
            sub: sub,
            selected: m == _mode,
            onTap: busy ? null : () => setState(() => _mode = m),
          ),
      ]),
      if (bridged)
        _inputRow([Input(
          key: const ValueKey('net:edit:bridge'),
          controller: _bridge,
          label: l10n.virtNetHostBridge,
          icon: Icons.settings_ethernet,
          hint: 'br0',
          noWrap: true,
          suggestion: false,
          enabled: !busy,
          errorText: on(const {VirtResIssue.bridgeInvalid}),
          onChanged: (_) => setState(() {}),
        )])
      else ...[
        _cidrInput(busy, hint: '192.168.150.1/24', errorText: on(const {
          VirtResIssue.cidrInvalid,
          VirtResIssue.subnetTaken,
        })),
        // The device libvirt makes for it: not edited here.
        if (net.bridge case final b?)
          _field(Icons.settings_ethernet, l10n.virtBridge, b, mono: true),
        _toggle(
          Icons.dns_outlined,
          'DHCP',
          _dhcp,
          key: 'net:edit:dhcp',
          note: l10n.virtNetDhcpTip,
          onChanged: busy ? null : (v) => setState(() => _dhcp = v),
        ),
        if (_dhcp)
          _inputRow([
            Input(
              key: const ValueKey('net:edit:dhcp:start'),
              controller: _dhcpStart,
              label: l10n.virtNetDhcpRange,
              icon: Icons.format_list_numbered,
              noWrap: true,
              suggestion: false,
              enabled: !busy,
              errorText: on(const {VirtResIssue.dhcpInvalid}),
              onChanged: (_) => setState(() {}),
            ),
            Input(
              key: const ValueKey('net:edit:dhcp:end'),
              controller: _dhcpEnd,
              label: '–',
              noWrap: true,
              suggestion: false,
              enabled: !busy,
              onChanged: (_) => setState(() {}),
            ),
          ]),
      ],
      _autostartRow(net, caps, busy),
      if (!bridged) ...[
        _text(l10n.virtNetHosts),
        for (final (i, h) in _hosts.indexed)
          _hostRow(i, h, busy, bad: issue == VirtResIssue.hostInvalid),
        _empty(
          _hosts.isEmpty ? l10n.virtNetHostEmpty : l10n.virtNetHostOthers,
          l10n.virtNetHostAdd,
          key: 'net:edit:host:add',
          onTap: busy ? null : () => setState(() => _hosts.add(_HostDraft())),
        ),
      ],
      // Only where the change waits for one: a static host alone applies
      // live, and a switch that did nothing would be a lie.
      if (_dirty && net.active && _needsRestart(change)) ...[
        _callout(
          libL10n.attention,
          net.users.isEmpty
              ? l10n.virtNetEditAskNoGuest
              : l10n.virtNetEditAsk(net.users.length),
        ),
        _toggle(
          Icons.restart_alt,
          l10n.virtNetEditRestart,
          _restartOnSave,
          key: 'net:edit:restart',
          note: l10n.virtNetEditRestartNote,
          onChanged: busy ? null : (v) => setState(() => _restartOnSave = v),
        ),
      ],
      ..._draftRows(net, busy, issue, text),
    ];
  }

  /// A PVE bridge's rows, as the design's: its ports, its address, VLAN
  /// awareness and autostart, and that they wait for the configuration to
  /// be applied.
  List<Widget> _pveRows(VirtNetwork net, List<VirtNetwork> all, bool busy) {
    final (issue, text) = _issue(net, all);
    String? on(Set<VirtResIssue> which) => which.contains(issue) ? text : null;
    final ipv4 = net.ipv4Cidr;
    final others = [for (final c in net.cidrs) if (c != ipv4) c];
    return [
      _field(Icons.dns_outlined, libL10n.node, net.node!),
      _inputRow([Input(
        key: const ValueKey('net:edit:ports'),
        controller: _ports,
        label: l10n.virtNetBridgePorts,
        icon: Icons.settings_ethernet,
        hint: l10n.virtNetPortsHint,
        noWrap: true,
        suggestion: false,
        enabled: !busy,
        errorText: on(const {VirtResIssue.bridgeInvalid}),
        onChanged: (_) => setState(() {}),
      )]),
      _cidrInput(busy, hint: '10.20.0.1/24', errorText: on(const {VirtResIssue.cidrInvalid})),
      // Sent back as they are: the rows edit IPv4 only.
      if (others.isNotEmpty)
        _field(Icons.language, 'IPv6', others.join('\n'), mono: true),
      if (net.gateway case final g?)
        _field(Icons.alt_route, libL10n.gateway, g, mono: true),
      _toggle(
        Icons.segment,
        l10n.virtNetVlanAware,
        _vlanAware,
        key: 'net:edit:vlan',
        note: l10n.virtNetVlanTip,
        onChanged: busy ? null : (v) => setState(() => _vlanAware = v),
      ),
      _toggle(
        Icons.power_settings_new,
        l10n.virtHwAutostart,
        _autostart,
        key: 'net:edit:autostart',
        onChanged: busy ? null : (v) => setState(() => _autostart = v),
      ),
      if (net.comment case final c? when c.isNotEmpty)
        _field(Icons.notes, libL10n.note, c),
      _text(l10n.virtNetPveApplyNote),
      ..._draftRows(net, busy, issue, text),
    ];
  }

  Widget _cidrInput(bool busy, {required String hint, String? errorText}) {
    return _inputRow([Input(
      key: const ValueKey('net:edit:cidr'),
      controller: _cidr,
      label: 'IPv4 / CIDR',
      icon: Icons.language,
      hint: hint,
      noWrap: true,
      suggestion: false,
      enabled: !busy,
      errorText: errorText,
      onChanged: (_) => setState(() {}),
    )]);
  }

  /// Why the draft cannot be saved, and that said for the rows; nothing
  /// while there is no draft — the network as the host has it is not the
  /// user's to fix.
  (VirtResIssue?, String?) _issue(VirtNetwork net, List<VirtNetwork> all) {
    if (!_dirty) return (null, null);
    final pve = net.node != null;
    final issue = virtResourceIssue(
      _change(_seeded ?? net),
      host: pve ? VirtHostKind.pve : VirtHostKind.libvirt,
      networks: all,
    );
    return (issue, issue == null ? null : virtResIssueText(issue));
  }

  /// Save and Revert, with why Save is held back; nothing without a draft.
  List<Widget> _draftRows(
    VirtNetwork net,
    bool busy,
    VirtResIssue? issue,
    String? text,
  ) {
    if (!_dirty) return const [];
    return [
      if (issue != null) _text(text ?? libL10n.fail, error: true),
      _actions([
        _Action(
          l10n.virtHwRevert,
          key: 'net:edit:revert',
          icon: Icons.undo,
          onTap: _saving ? null : () => setState(() => _seed(net)),
        ),
        _Action(
          libL10n.save,
          key: 'net:edit:save',
          primary: true,
          onTap: busy || issue != null ? null : () => unawaited(_save(net)),
        ),
      ]),
    ];
  }

  /// One static host: its MAC, its address and its name, with Remove — one
  /// box, since the two lines of fields are one entry.
  Widget _hostRow(int i, _HostDraft h, bool busy, {required bool bad}) {
    return _box(
      key: ValueKey('net:edit:host:$i'),
      padding: const EdgeInsets.fromLTRB(13, 2, 7, 2),
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
            enabled: !busy,
            errorText: bad ? l10n.virtNetHostInvalid : null,
            onChanged: (_) => setState(() {}),
          ),
          _inputLine(
            [
              Expanded(
                flex: 3,
                child: Input(
                  key: ValueKey('net:edit:host:$i:ip'),
                  controller: h.ip,
                  label: l10n.virtNetHostIp,
                  icon: Icons.language,
                  noWrap: true,
                  suggestion: false,
                  enabled: !busy,
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
                  enabled: !busy,
                  onChanged: (_) => setState(() {}),
                ),
              ),
            ],
            trailing: Btn.icon(
              key: ValueKey('net:edit:host:$i:remove'),
              text: l10n.virtHwRemove,
              icon: const Icon(Icons.delete_outline, size: 18),
              onTap: busy
                  ? null
                  : () => setState(() => _hosts.removeAt(i).dispose()),
            ),
          ),
        ],
      ),
    );
  }

  /// Saves the draft.
  ///
  /// Made from the read the rows were filled from, unless a newer one has
  /// the same definition: nothing the draft edits changed under it. Where
  /// it did change, libvirt refuses the old one as a conflict, which drops
  /// the draft — its base is gone. Any other failure keeps it, to be saved
  /// again. PVE's pending configuration has no revision to send; it is
  /// made from the newest read.
  Future<void> _save(VirtNetwork net) async {
    final seeded = _seeded;
    if (seeded == null) return;
    final base = seeded.xml == net.xml ? net : seeded;
    setState(() => _saving = true);
    final applied = await _virtManageFor(ref, _serverId, _change(base));
    if (!mounted) return;
    setState(() {
      _saving = false;
      // Filled again from the network as it is read next.
      if (applied == _Applied.done || applied == _Applied.conflict) {
        _seeded = null;
      }
    });
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

  /// The design's `file` group: the definition as the host keeps it,
  /// folded — what the rows above are read from.
  _Group _fileGroup(VirtNetwork net, String text) {
    final libvirt = net.node == null;
    return _Group(
      key: 'file',
      title: l10n.virtNetConfigFile,
      right: '',
      warn: false,
      indexNote: libvirt ? 'net-dumpxml' : 'interfaces',
      rows: [
        _disc(
          'config',
          Icons.code,
          libvirt ? 'virsh net-dumpxml ${net.name}' : '/etc/network/interfaces',
          '',
        ),
        _reveal('config', [
          _box(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SelectableText(
                text.trimRight(),
                style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
              ),
            ),
          ),
        ]),
      ],
    );
  }

  Future<bool> _manage(VirtResourceChange change) =>
      virtManage(ref, _serverId, change);

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
}) async =>
    await _virtManageFor(ref, serverId, change, quiet: quiet) == _Applied.done;

/// [virtManage], saying why it did not: a draft is kept through a failure
/// that retrying could get past, and dropped on a conflict, which says the
/// read it was made from is gone.
Future<_Applied> _virtManageFor(
  WidgetRef ref,
  String serverId,
  VirtResourceChange change, {
  bool quiet = false,
}) async {
  // Read before the await: the page may be left while the host works, and
  // a disposed ref throws — which would report a change that was made as
  // failed.
  final pending =
      (change is VirtNetworkCreate || change is VirtNetworkDelete) &&
      (ref.read(virtHostProvider(serverId)).data?.capabilities.networkApply ??
          false);
  try {
    await ref.read(virtHostProvider(serverId).notifier).manage(change);
    if (!quiet) {
      Toast.success(pending ? l10n.virtNetPendingSaved : libL10n.success);
    }
    return _Applied.done;
  } on VirtErr catch (e) {
    if (e.type == VirtErrType.conflict) {
      Toast.warn(e.title, body: e.detail);
      return _Applied.conflict;
    }
    Toast.error(e.title, body: e.detail);
  } catch (e, s) {
    Loggers.app.warning('Virtualization storage or network', e, s);
    Toast.error(libL10n.fail, body: '$e');
  }
  return _Applied.failed;
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
    final ops = ref.watch(
      virtHostProvider(serverId).select((s) => s.resourceOps),
    );
    // Any change to a node's networks holds its Apply and Revert.
    bool busyOn(String node) =>
        ops.contains('nets') ||
        ops.contains(VirtResourceChange.netNodeScope(node));
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
                        onTap: busyOn(c.node)
                            ? null
                            : () => unawaited(_revert(context, ref, c)),
                      ),
                      Btn.text(
                        key: ValueKey('net:pending:${c.node}:apply'),
                        text: l10n.virtNetApply,
                        onTap: busyOn(c.node)
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
    if (ok != true || !context.mounted) return;
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
    if (ok != true || !context.mounted) return;
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
        ? virtResIssueText(issue)
        : null;
    final ready = nets != null && issue == null && !_creating;
    return Scaffold(
      appBar: virtResourceBar(
        name: pve ? l10n.virtNetNewBridge : l10n.virtNetNew,
        icon: Icons.add_circle_outline,
        leading: widget.leading,
        actions: [
          BarAction(
            icon: Icons.close,
            label: libL10n.cancel,
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
                    _inputRow([Input(
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
                    )]),
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
                      _inputRow([Input(
                        key: const ValueKey('net:new:bridge'),
                        controller: _bridge,
                        label: pve ? l10n.virtNetBridgePorts : l10n.virtNetHostBridge,
                        icon: Icons.settings_ethernet,
                        hint: pve ? l10n.virtNetPortsHint : 'br1',
                        noWrap: true,
                        suggestion: false,
                        errorText: on(const {VirtResIssue.bridgeInvalid}),
                        onChanged: (_) => setState(() {}),
                      )]),
                    if (!hostBridge)
                      _inputRow([Input(
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
                      )]),
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
                        _inputRow([
                          Input(
                            key: const ValueKey('net:new:dhcp:start'),
                            controller: _dhcpStart,
                            label: l10n.virtNetDhcpRange,
                            icon: Icons.format_list_numbered,
                            noWrap: true,
                            suggestion: false,
                            errorText: on(const {VirtResIssue.dhcpInvalid}),
                            onChanged: (_) => setState(() => _rangeTyped = true),
                          ),
                          Input(
                            key: const ValueKey('net:new:dhcp:end'),
                            controller: _dhcpEnd,
                            label: '–',
                            noWrap: true,
                            suggestion: false,
                            onChanged: (_) => setState(() => _rangeTyped = true),
                          ),
                        ]),
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
/// definition libvirt would write, or PVE's `/etc/network/interfaces` entry.
String? virtNetworkConfigText(VirtNetwork net) {
  if (net.xml.isNotEmpty) return net.xml;
  if (net.node == null) return null;
  final ipv4 = net.ipv4Cidr;
  final ipv6 = net.cidrs.where((c) => c != ipv4).firstOrNull;
  final lines = [
    'auto ${net.name}',
    'iface ${net.name} inet ${ipv4 == null ? 'manual' : 'static'}',
    if (ipv4 != null) ' address $ipv4',
    if (net.gateway case final g?) ' gateway $g',
    ' bridge-ports ${net.ports.isEmpty ? 'none' : net.ports.join(' ')}',
    ' bridge-stp off',
    ' bridge-fd 0',
    if (net.vlanAware ?? false) ...[' bridge-vlan-aware yes', ' bridge-vids 2-4094'],
    if (ipv6 != null) ...['', 'iface ${net.name} inet6 static', ' address $ipv6'],
  ];
  return lines.join('\n');
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

  /// What it says, trimmed: the MAC, the address, the name.
  (String, String, String) get entry =>
      (mac.text.trim(), ip.text.trim(), name.text.trim());

  void dispose() {
    mac.dispose();
    ip.dispose();
    name.dispose();
  }
}
