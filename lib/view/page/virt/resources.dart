import 'dart:async';

import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/data/model/app/error.dart';
import 'package:server_box/data/model/virt/virt.dart';
import 'package:server_box/data/model/virt/virt_resources.dart';
import 'package:server_box/data/provider/virt/virt.dart';
import 'package:server_box/data/res/chart_palette.dart';
import 'package:server_box/view/page/virt/common.dart';
import 'package:server_box/view/page/virt/guest.dart';
import 'package:server_box/view/widget/progress_line.dart';

/// The Storage and Network sections of the Virtualization tab: a host's
/// storage pools with their volumes, and its networks with the guests on
/// them. Read-only.
///
/// Each is a list for the list column ([VirtPoolList], [VirtNetworkList]) and
/// a detail for beside it or, with one column, pushed over it
/// ([VirtPoolView] / [VirtPoolPage], [VirtNetworkView] / [VirtNetworkPage]).
/// Both halves watch the same provider, so one refresh serves both.

/// The guest [ref] names, among [st]'s guests.
VirtGuest? virtGuestOf(VirtHostState st, VirtGuestRef ref) {
  final guests = st.data?.guests ?? const <VirtGuest>[];
  final id = ref.guestId;
  if (id != null) return guests.firstWhereOrNull((g) => g.id == id);
  final vmid = ref.vmid;
  if (vmid == null) return null;
  return guests.firstWhereOrNull((g) => g.vmid == vmid);
}

/// [ref]'s guest by name, or what the host said of it when it is not in the
/// list (a guest this account may not see).
String virtGuestLabel(VirtHostState st, VirtGuestRef ref) =>
    virtGuestOf(st, ref)?.name ??
    ref.vmid?.toString() ??
    ref.guestId?.split('-').first ??
    '?';

extension VirtNetworkModeUi on VirtNetwork {
  /// libvirt's forward modes by what they do; PVE's interface types by
  /// PVE's own names for them.
  String get modeLabel => switch (mode) {
    'nat' => 'NAT',
    'isolated' => l10n.virtNetIsolated,
    'bridge' when node == null => l10n.virtNetBridged,
    'route' => l10n.virtNetRouted,
    'bridge' => 'Linux Bridge',
    'bond' => 'Linux Bond',
    'vlan' => 'Linux VLAN',
    'eth' => 'Ethernet',
    final m => m,
  };

  /// Guests attach here: every libvirt network, and a PVE bridge.
  bool get takesGuests =>
      node == null || mode == 'bridge' || mode == 'OVSBridge';
}

// -----------------------------------------------------------------------------
// Lists
// -----------------------------------------------------------------------------

/// The host's storage pools, for the list column.
class VirtPoolList extends ConsumerWidget {
  const VirtPoolList({
    super.key,
    required this.serverId,
    required this.needle,
    required this.selectedId,
    required this.onOpen,
  });

  final String serverId;
  final String needle;
  final String? selectedId;
  final ValueChanged<String> onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pools = ref.watch(virtStoragePoolsProvider(serverId));
    final list = pools.value;
    final shown = [
      for (final p in list ?? const <VirtStoragePool>[])
        if (needle.isEmpty || p.name.toLowerCase().contains(needle)) p,
    ];
    final nodes = {for (final p in shown) ?p.node};
    return _ResourceColumn(
      loading: pools.isLoading,
      error: pools.hasError ? pools.error : null,
      onRefresh: () => ref.refresh(virtStoragePoolsProvider(serverId).future),
      children: [
        if (list != null && list.isEmpty) CenterGreyTitle(l10n.virtNoPools),
        if (list != null && list.isNotEmpty && shown.isEmpty)
          CenterGreyTitle(libL10n.empty),
        for (final (i, p) in shown.indexed) ...[
          if (nodes.length > 1 && (i == 0 || shown[i - 1].node != p.node))
            SideBarSection(p.node!),
          _ResourceRow(
            key: ValueKey('pool:${p.id}'),
            icon: Icons.storage_outlined,
            active: p.active,
            name: p.name,
            meta: switch (p.usedFraction) {
              final f? => '${(f * 100).toStringAsFixed(0)}%',
              null => p.active ? '' : libL10n.inactive,
            },
            sub: [
              p.type,
              if (p.capacity case final c?)
                '${(p.used ?? 0).bytes2Str} / ${c.bytes2Str}',
              if (!p.active && p.usedFraction != null) libL10n.inactive,
            ].join(' · '),
            selected: p.id == selectedId,
            onTap: () => onOpen(p.id),
          ),
        ],
      ],
    );
  }
}

/// The host's networks, for the list column.
class VirtNetworkList extends ConsumerWidget {
  const VirtNetworkList({
    super.key,
    required this.serverId,
    required this.needle,
    required this.selectedId,
    required this.onOpen,
  });

  final String serverId;
  final String needle;
  final String? selectedId;
  final ValueChanged<String> onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final nets = ref.watch(virtNetworksProvider(serverId));
    final list = nets.value;
    final shown = [
      for (final n in list ?? const <VirtNetwork>[])
        if (needle.isEmpty || n.name.toLowerCase().contains(needle)) n,
    ];
    final nodes = {for (final n in shown) ?n.node};
    return _ResourceColumn(
      loading: nets.isLoading,
      error: nets.hasError ? nets.error : null,
      onRefresh: () => ref.refresh(virtNetworksProvider(serverId).future),
      children: [
        if (list != null && list.isEmpty) CenterGreyTitle(l10n.virtNoNetworks),
        if (list != null && list.isNotEmpty && shown.isEmpty)
          CenterGreyTitle(libL10n.empty),
        for (final (i, n) in shown.indexed) ...[
          if (nodes.length > 1 && (i == 0 || shown[i - 1].node != n.node))
            SideBarSection(n.node!),
          _ResourceRow(
            key: ValueKey('net:${n.id}'),
            icon: Icons.lan_outlined,
            active: n.active,
            name: n.name,
            meta: n.takesGuests ? '${n.users.length}' : '',
            metaIcon: n.takesGuests ? Icons.view_in_ar_outlined : null,
            sub: [
              n.modeLabel,
              ?n.cidrs.firstOrNull,
              if (n.bridge case final b? when b != n.name) b,
              if (!n.active) libL10n.inactive,
            ].join(' · '),
            selected: n.id == selectedId,
            onTap: () => onOpen(n.id),
          ),
        ],
      ],
    );
  }
}

/// A list under the section pills: progress, failure, rows, pull to refresh.
class _ResourceColumn extends StatelessWidget {
  const _ResourceColumn({
    required this.loading,
    required this.error,
    required this.onRefresh,
    required this.children,
  });

  final bool loading;
  final Object? error;
  final Future<void> Function() onRefresh;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final err = error;
    return Column(
      children: [
        SizedBox(height: 3, child: loading ? const ProgressLine() : null),
        Expanded(
          child: RefreshIndicator(
            onRefresh: onRefresh,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(9, 5, 9, 17),
              children: [
                if (err != null) VirtErrCard(err, onRetry: onRefresh),
                if (loading && children.isEmpty && err == null)
                  const Padding(
                    padding: EdgeInsets.all(27),
                    child: Center(child: SizedLoading.medium),
                  ),
                ...children,
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// A failure where a list or a card would be, with a way to ask again.
class VirtErrCard extends StatelessWidget {
  const VirtErrCard(this.error, {super.key, this.onRetry});

  final Object error;
  final Future<void> Function()? onRetry;

  @override
  Widget build(BuildContext context) {
    final e = error;
    final retry = onRetry;
    return VirtCard(
      icon: Icons.error_outline,
      title: e is VirtErr ? e.title : libL10n.error,
      trailing: retry == null
          ? null
          : Btn.icon(
              text: libL10n.retry,
              icon: const Icon(Icons.refresh, size: 18),
              onTap: () => unawaited(retry()),
            ),
      children: [
        if (e is! VirtErr)
          Text('$e', style: UIs.text12Grey)
        else if (e.detail case final d?)
          Text(d, style: UIs.text12Grey),
      ],
    );
  }
}

/// A pool or a network in the list column, drawn like a guest row.
class _ResourceRow extends StatelessWidget {
  const _ResourceRow({
    super.key,
    required this.icon,
    required this.active,
    required this.name,
    required this.meta,
    required this.sub,
    required this.selected,
    required this.onTap,
    this.metaIcon,
  });

  final IconData icon;
  final bool active;
  final String name;
  final String meta;
  final IconData? metaIcon;
  final String sub;
  final bool selected;
  final VoidCallback onTap;

  static final _radius = BorderRadius.circular(9);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
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
                    Icon(
                      icon,
                      size: 15,
                      color: active ? StatePalette.running : StatePalette.idle,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        name,
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
                    if (metaIcon case final i?) ...[
                      Icon(i, size: 13, color: Colors.grey),
                      const SizedBox(width: 3),
                    ],
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
                    padding: const EdgeInsets.only(left: 23, top: 2),
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

// -----------------------------------------------------------------------------
// Details
// -----------------------------------------------------------------------------

/// The bar of a pool or network detail: its name — which opens the others
/// where [onSwitch] is given — and a refresh.
PreferredSizeWidget _detailBar({
  required String name,
  required IconData icon,
  Widget? leading,
  int? position,
  int total = 0,
  VoidCallback? onSwitch,
  required VoidCallback onRefresh,
}) {
  return PreferredSize(
    preferredSize: const Size.fromHeight(SessionTabBar.height),
    child: SizedBox(
      height: SessionTabBar.height,
      child: Row(
        children: [
          ?leading,
          Expanded(
            child: SessionSwitcherLabel(
              name: name,
              icon: icon,
              position: position,
              total: total,
              onTap: onSwitch,
            ),
          ),
          Btn.icon(
            text: libL10n.refresh,
            icon: const Icon(Icons.refresh, size: 18),
            onTap: onRefresh,
          ),
          const SizedBox(width: 7),
        ],
      ),
    ),
  );
}

/// One storage pool: how full, what it is, and its volumes with the guests
/// using them.
class VirtPoolView extends ConsumerStatefulWidget {
  const VirtPoolView({
    super.key,
    required this.serverId,
    required this.poolId,
    this.leading,
    this.onSwitch,
  });

  final String serverId;
  final String poolId;
  final Widget? leading;

  /// Moves to another pool in place; null where the list is beside this.
  final ValueChanged<String>? onSwitch;

  @override
  ConsumerState<VirtPoolView> createState() => _VirtPoolViewState();
}

class _VirtPoolViewState extends ConsumerState<VirtPoolView> {
  /// Open volume rows, by id.
  final _open = <String>{};

  @override
  Widget build(BuildContext context) {
    final pools = ref.watch(virtStoragePoolsProvider(widget.serverId));
    final all = pools.value ?? const <VirtStoragePool>[];
    final pool = all.firstWhereOrNull((p) => p.id == widget.poolId);
    final at = pool == null ? -1 : all.indexOf(pool);
    final onSwitch = widget.onSwitch;
    final bar = _detailBar(
      name: pool?.name ?? '',
      icon: Icons.storage_outlined,
      leading: widget.leading,
      position: onSwitch != null && at >= 0 ? at + 1 : null,
      total: onSwitch != null ? all.length : 0,
      onSwitch: onSwitch != null && all.length > 1
          ? () => unawaited(_pick(all, onSwitch))
          : null,
      onRefresh: () =>
          ref.invalidate(virtStoragePoolsProvider(widget.serverId)),
    );
    if (pool == null) {
      return Scaffold(
        appBar: bar,
        body: pools.isLoading
            ? const Center(child: SizedLoading.medium)
            : pools.hasError
            ? ListView(
                padding: const EdgeInsets.all(13),
                children: [VirtErrCard(pools.error!)],
              )
            : EmptyPane(icon: Icons.storage_outlined, label: libL10n.empty),
      );
    }
    final vols = ref.watch(virtVolumesProvider(widget.serverId, pool.id));
    final host = ref.watch(virtHostProvider(widget.serverId));
    return Scaffold(
      appBar: bar,
      body: Column(
        children: [
          SizedBox(
            height: 3,
            child: pools.isLoading || vols.isLoading
                ? const ProgressLine()
                : null,
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(13, 3, 13, 17),
              children: [
                _buildUsage(pool),
                _buildInfo(pool),
                _buildVolumes(pool, vols, host),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUsage(VirtStoragePool pool) {
    final frac = pool.usedFraction;
    final cap = pool.capacity;
    return VirtCard(
      icon: Icons.pie_chart_outline,
      title: libL10n.capacity,
      trailing: VirtChip(pool.active ? libL10n.active : libL10n.inactive),
      children: [
        if (cap == null)
          Text('--', style: UIs.text13Grey)
        else ...[
          Row(
            children: [
              Text(
                '${(pool.used ?? 0).bytes2Str} / ${cap.bytes2Str}',
                style: const TextStyle(fontSize: 13),
              ),
              const Spacer(),
              if (frac != null)
                Text(
                  '${(frac * 100).toStringAsFixed(1)}%',
                  style: UIs.text12Grey,
                ),
            ],
          ),
          if (frac != null) ...[
            const SizedBox(height: 7),
            ProgressLine(value: frac.clamp(0, 1)),
          ],
          if (pool.available case final a?)
            VirtFact(libL10n.available, a.bytes2Str),
        ],
      ],
    );
  }

  Widget _buildInfo(VirtStoragePool pool) {
    final chips = [
      if (pool.autostart ?? false) l10n.virtAutostart,
      if (pool.shared ?? false) l10n.virtShared,
      if (pool.enabled == false) libL10n.disabled,
    ];
    return VirtCard(
      icon: Icons.info_outline,
      title: libL10n.storage,
      children: [
        VirtFact(libL10n.type, pool.type.isEmpty ? '--' : pool.type),
        if (pool.node case final n?) VirtFact(libL10n.node, n),
        if (pool.path case final p?) VirtFact(libL10n.path, p),
        if (pool.source case final s?) VirtFact(libL10n.source, s),
        if (pool.content.isNotEmpty)
          VirtFact(libL10n.content, pool.content.join(', ')),
        if (chips.isNotEmpty) ...[
          UIs.height7,
          Wrap(
            spacing: 5,
            runSpacing: 5,
            children: [for (final c in chips) VirtChip(c)],
          ),
        ],
      ],
    );
  }

  Widget _buildVolumes(
    VirtStoragePool pool,
    AsyncValue<List<VirtVolume>> vols,
    VirtHostState host,
  ) {
    final list = vols.value;
    return VirtCard(
      icon: Icons.inventory_2_outlined,
      title: list == null
          ? l10n.virtVolumes
          : '${l10n.virtVolumes} · ${list.length}',
      children: [
        if (!pool.active)
          Text(l10n.virtPoolInactive, style: UIs.text12Grey)
        else if (vols.hasError)
          VirtErrCard(
            vols.error!,
            onRetry: () => ref.refresh(
              virtVolumesProvider(widget.serverId, pool.id).future,
            ),
          )
        else if (list == null)
          const Padding(
            padding: EdgeInsets.all(13),
            child: Center(child: SizedLoading.small),
          )
        else if (list.isEmpty)
          Text(libL10n.empty, style: UIs.text12Grey)
        else
          for (final v in list) _buildVolume(v, host),
      ],
    );
  }

  Widget _buildVolume(VirtVolume v, VirtHostState host) {
    final open = _open.contains(v.id);
    final users = [for (final u in v.users) virtGuestLabel(host, u)];
    final size = switch ((v.allocation, v.capacity)) {
      (final a?, final c?) when a != c => '${a.bytes2Str} / ${c.bytes2Str}',
      (_, final c?) => c.bytes2Str,
      (final a?, null) => a.bytes2Str,
      _ => null,
    };
    final sub = [
      ?v.format,
      ?size,
      users.isEmpty ? l10n.unused : users.join(', '),
    ].join(' · ');
    return Column(
      key: ValueKey('volume:${v.id}'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          leading: Icon(_volumeIcon(v), size: 20),
          title: Text(
            v.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 13),
          ),
          subtitle: Text(
            sub,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: UIs.text11Grey,
          ),
          trailing: Icon(open ? Icons.expand_less : Icons.expand_more),
          onTap: () => setState(() {
            if (!_open.remove(v.id)) _open.add(v.id);
          }),
        ),
        if (open)
          Padding(
            padding: const EdgeInsets.fromLTRB(40, 0, 0, 9),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (v.path case final p?) VirtFact(libL10n.path, p),
                if (v.id != v.name) VirtFact('ID', v.id),
                if (v.format case final f?) VirtFact(libL10n.format, f),
                if (v.content case final c?) VirtFact(libL10n.content, c),
                if (v.capacity case final c?)
                  VirtFact(libL10n.capacity, c.bytes2Str),
                if (v.allocation case final a?)
                  VirtFact(libL10n.used, a.bytes2Str),
                if (v.backing case final b?) VirtFact(l10n.virtBackingFile, b),
                if (v.createdAt case final t?)
                  VirtFact(libL10n.time, t.simple()),
                for (final u in v.users)
                  VirtFact(
                    virtGuestLabel(host, u),
                    u.device ?? virtGuestOf(host, u)?.kind.label ?? '',
                  ),
              ],
            ),
          ),
      ],
    );
  }

  static IconData _volumeIcon(VirtVolume v) => switch (v.content) {
    'iso' => Icons.album_outlined,
    'vztmpl' => Icons.inventory_2_outlined,
    'backup' => Icons.backup_outlined,
    'snippets' || 'import' => Icons.description_outlined,
    _ when v.format == 'iso' || v.name.toLowerCase().endsWith('.iso') =>
      Icons.album_outlined,
    _ => Icons.save_outlined,
  };

  Future<void> _pick(
    List<VirtStoragePool> all,
    ValueChanged<String> onSwitch,
  ) async {
    final picked = await showRowsSheet<String>(
      context,
      rows: (ctx) => [
        for (final p in all)
          ListTile(
            selected: p.id == widget.poolId,
            leading: const Icon(Icons.storage_outlined),
            title: Text(p.name, maxLines: 1, overflow: TextOverflow.ellipsis),
            subtitle: Text(
              [p.type, ?p.node].join(' · '),
              style: UIs.textGrey,
            ),
            onTap: () => Navigator.of(ctx).pop(p.id),
          ),
      ],
    );
    if (picked == null || picked == widget.poolId || !mounted) return;
    onSwitch(picked);
  }
}

/// One network: how it is set up, and the guests on it.
class VirtNetworkView extends ConsumerWidget {
  const VirtNetworkView({
    super.key,
    required this.serverId,
    required this.netId,
    required this.onOpenGuest,
    this.leading,
    this.onSwitch,
  });

  final String serverId;
  final String netId;
  final Widget? leading;

  /// Opens a guest on it.
  final ValueChanged<String> onOpenGuest;

  /// Moves to another network in place; null where the list is beside this.
  final ValueChanged<String>? onSwitch;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final nets = ref.watch(virtNetworksProvider(serverId));
    final all = nets.value ?? const <VirtNetwork>[];
    final net = all.firstWhereOrNull((n) => n.id == netId);
    final at = net == null ? -1 : all.indexOf(net);
    final switchTo = onSwitch;
    final bar = _detailBar(
      name: net?.name ?? '',
      icon: Icons.lan_outlined,
      leading: leading,
      position: switchTo != null && at >= 0 ? at + 1 : null,
      total: switchTo != null ? all.length : 0,
      onSwitch: switchTo != null && all.length > 1
          ? () => unawaited(_pick(context, all, switchTo))
          : null,
      onRefresh: () => ref.invalidate(virtNetworksProvider(serverId)),
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
    final host = ref.watch(virtHostProvider(serverId));
    return Scaffold(
      appBar: bar,
      body: Column(
        children: [
          SizedBox(height: 3, child: nets.isLoading ? const ProgressLine() : null),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(13, 3, 13, 17),
              children: [
                _buildConfig(net),
                if (net.takesGuests) _buildGuests(net, host),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConfig(VirtNetwork net) {
    final chips = [
      net.active ? libL10n.active : libL10n.inactive,
      if (net.autostart ?? false) l10n.virtAutostart,
      if (net.vlanAware ?? false) 'VLAN aware',
    ];
    return VirtCard(
      icon: Icons.settings_ethernet,
      title: libL10n.network,
      children: [
        VirtFact(libL10n.mode, net.modeLabel),
        if (net.node case final n?) VirtFact(libL10n.node, n),
        if (net.bridge case final b?) VirtFact(l10n.virtBridge, b),
        if (net.cidrs.isNotEmpty) VirtFact(libL10n.addr, net.cidrs.join('\n')),
        if (net.gateway case final g?) VirtFact(libL10n.gateway, g),
        if (net.dhcpRanges.isNotEmpty)
          VirtFact('DHCP', net.dhcpRanges.join('\n')),
        if (net.ports.isNotEmpty) VirtFact(l10n.virtPorts, net.ports.join(', ')),
        if (net.vlanId case final id?)
          VirtFact('VLAN', [id, ?net.vlanDevice].join(' · ')),
        if (net.bondMode case final m?) VirtFact(libL10n.mode, m),
        if (net.comment case final c? when c.isNotEmpty)
          VirtFact(libL10n.note, c),
        UIs.height7,
        Wrap(
          spacing: 5,
          runSpacing: 5,
          children: [for (final c in chips) VirtChip(c)],
        ),
      ],
    );
  }

  Widget _buildGuests(VirtNetwork net, VirtHostState host) {
    return VirtCard(
      icon: Icons.view_in_ar_outlined,
      title: '${l10n.virtAttachedGuests} · ${net.users.length}',
      children: [
        if (net.users.isEmpty)
          Text(l10n.virtNoAttachedGuests, style: UIs.text12Grey),
        for (final (i, u) in net.users.indexed)
          _GuestLink(
            key: ValueKey('netguest:$i'),
            host: host,
            user: u,
            onOpen: onOpenGuest,
          ),
      ],
    );
  }

  static Future<void> _pick(
    BuildContext context,
    List<VirtNetwork> all,
    ValueChanged<String> onSwitch,
  ) async {
    final picked = await showRowsSheet<String>(
      context,
      rows: (ctx) => [
        for (final n in all)
          ListTile(
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
    if (picked == null) return;
    onSwitch(picked);
  }
}

/// A guest on a network: its state, name, and how it is attached; a tap opens
/// it.
class _GuestLink extends StatelessWidget {
  const _GuestLink({
    super.key,
    required this.host,
    required this.user,
    required this.onOpen,
  });

  final VirtHostState host;
  final VirtGuestRef user;
  final ValueChanged<String> onOpen;

  @override
  Widget build(BuildContext context) {
    final guest = virtGuestOf(host, user);
    final state = guest == null ? null : host.displayState(guest);
    final sub = [?user.device, ?user.ip, ?user.mac].join(' · ');
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: state == null
          ? const Icon(Icons.help_outline, size: 18)
          : VirtStateDot(state, size: 9),
      minLeadingWidth: 18,
      title: Text(
        virtGuestLabel(host, user),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 13),
      ),
      subtitle: sub.isEmpty ? null : Text(sub, style: UIs.text11Grey),
      trailing: guest == null ? null : const Icon(Icons.chevron_right),
      onTap: guest == null ? null : () => onOpen(guest.id),
    );
  }
}

// -----------------------------------------------------------------------------
// Pages, for one column
// -----------------------------------------------------------------------------

final class VirtResourceArgs {
  const VirtResourceArgs({required this.serverId, required this.id});

  final String serverId;
  final String id;
}

/// A pool over the list, for a window with room for one column. Moving to
/// another pool is the switcher in its bar, in place.
class VirtPoolPage extends StatefulWidget {
  const VirtPoolPage({super.key, required this.args});

  final VirtResourceArgs args;

  static const route = AppRouteArg<void, VirtResourceArgs>(
    page: VirtPoolPage.new,
    path: '/virt/pool',
  );

  @override
  State<VirtPoolPage> createState() => _VirtPoolPageState();
}

class _VirtPoolPageState extends State<VirtPoolPage> {
  late String _id = widget.args.id;

  @override
  Widget build(BuildContext context) {
    return VirtPoolView(
      serverId: widget.args.serverId,
      poolId: _id,
      leading: const BackButton(),
      onSwitch: (id) => setState(() => _id = id),
    );
  }
}

/// A network over the list, for a window with room for one column. A guest
/// on it opens as a page of its own.
class VirtNetworkPage extends StatefulWidget {
  const VirtNetworkPage({super.key, required this.args});

  final VirtResourceArgs args;

  static const route = AppRouteArg<void, VirtResourceArgs>(
    page: VirtNetworkPage.new,
    path: '/virt/network',
  );

  @override
  State<VirtNetworkPage> createState() => _VirtNetworkPageState();
}

class _VirtNetworkPageState extends State<VirtNetworkPage> {
  late String _id = widget.args.id;

  @override
  Widget build(BuildContext context) {
    final serverId = widget.args.serverId;
    return VirtNetworkView(
      serverId: serverId,
      netId: _id,
      leading: const BackButton(),
      onSwitch: (id) => setState(() => _id = id),
      onOpenGuest: (guestId) => VirtGuestPage.route.go(
        context,
        VirtGuestArgs(serverId: serverId, guestId: guestId),
      ),
    );
  }
}
