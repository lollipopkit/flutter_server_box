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
import 'package:server_box/view/page/virt/hardware.dart';
import 'package:server_box/view/widget/progress_line.dart';

/// The Storage and Network sections of the Virtualization tab: a host's
/// storage pools with their volumes, and its networks with the guests on
/// them.
///
/// Each is a list for the list column ([VirtPoolList], [VirtNetworkList]) and
/// a detail for beside it or, with one column, pushed over it
/// ([VirtPoolView] / [VirtPoolPage], [VirtNetworkView] / [VirtNetworkPage]);
/// a new one is a form in the detail's place ([VirtPoolCreateView],
/// [VirtNetworkCreateView]) or pushed ([VirtResourceCreatePage]). Both halves
/// watch the same provider, so one refresh serves both.

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
      onRefresh: () {
        ref.invalidate(virtNetworkChangesProvider(serverId));
        return ref.refresh(virtNetworksProvider(serverId).future);
      },
      children: [
        // PVE: what waits to be applied, for every node, where the list is.
        VirtNetworkPendingCard(serverId: serverId),
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
// Details (the views themselves: `storage.dart`, `network.dart`)
// -----------------------------------------------------------------------------

/// The bar of a pool or network detail, or of a form for a new one: its name
/// — which opens the others where [onSwitch] is given — its [actions], and a
/// refresh where [onRefresh] is given.
PreferredSizeWidget virtResourceBar({
  required String name,
  required IconData icon,
  Widget? leading,
  int? position,
  int total = 0,
  VoidCallback? onSwitch,
  List<Widget> actions = const [],
  VoidCallback? onRefresh,
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
          ...actions,
          if (onRefresh != null)
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
      onDeleted: () => Navigator.of(context).maybePop(),
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
      onDeleted: () => Navigator.of(context).maybePop(),
      onOpenGuest: (guestId) => VirtGuestPage.route.go(
        context,
        VirtGuestArgs(serverId: serverId, guestId: guestId),
      ),
    );
  }
}

/// A new pool or network over the list, for a window with room for one
/// column: the id of what was made, or null.
final class VirtResourceCreateArgs {
  const VirtResourceCreateArgs({required this.serverId, required this.network});

  final String serverId;

  /// A network; a pool otherwise.
  final bool network;
}

class VirtResourceCreatePage extends StatelessWidget {
  const VirtResourceCreatePage({super.key, required this.args});

  final VirtResourceCreateArgs args;

  static const route = AppRouteArg<String, VirtResourceCreateArgs>(
    page: VirtResourceCreatePage.new,
    path: '/virt/resource/create',
  );

  @override
  Widget build(BuildContext context) {
    void cancel() => Navigator.of(context).maybePop();
    void created(String id) => Navigator.of(context).pop(id);
    return args.network
        ? VirtNetworkCreateView(
            serverId: args.serverId,
            leading: const BackButton(),
            onCancel: cancel,
            onCreated: created,
          )
        : VirtPoolCreateView(
            serverId: args.serverId,
            leading: const BackButton(),
            onCancel: cancel,
            onCreated: created,
          );
  }
}
