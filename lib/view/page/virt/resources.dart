
import 'package:fl_lib/fl_lib.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/data/model/virt/virt_resources.dart';
import 'package:server_box/data/provider/virt/virt.dart';
import 'package:server_box/view/page/virt/common.dart';
import 'package:server_box/view/page/virt/guest.dart';
import 'package:server_box/view/page/virt/hardware.dart';

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
    return VirtResourceColumn(
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
          VirtResourceRow(
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
    return VirtResourceColumn(
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
          VirtResourceRow(
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

// -----------------------------------------------------------------------------
// Details (the views themselves: `storage.dart`, `network.dart`)
// -----------------------------------------------------------------------------

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
    // Keyed by what it shows: the view's drafts (a growth, a target guest,
    // a new volume) are one pool's, and a libvirt volume id is a name only
    // unique in its pool.
    return VirtPoolView(
      key: ValueKey('${widget.args.serverId}/$_id'),
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
      key: ValueKey('$serverId/$_id'),
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
