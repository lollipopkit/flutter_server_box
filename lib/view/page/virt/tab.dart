// ignore_for_file: invalid_use_of_protected_member

import 'dart:async';

import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/data/model/server/server_private_info.dart';
import 'package:server_box/data/model/virt/virt.dart';
import 'package:server_box/data/provider/app/session_requests.dart';
import 'package:server_box/data/provider/server/all.dart';
import 'package:server_box/data/provider/virt/virt.dart';
import 'package:server_box/data/res/chart_palette.dart';
import 'package:server_box/view/page/virt/common.dart';
import 'package:server_box/view/page/virt/guest.dart';
import 'package:server_box/view/page/virt/host_error.dart';
import 'package:server_box/view/widget/pane_settings.dart';
import 'package:server_box/view/widget/progress_line.dart';

part 'hosts.dart';
part 'list.dart';

/// What the list column is showing. Only [guests] exists yet; the other two
/// are drawn, disabled, so the shape of the tab does not change when they
/// arrive.
enum VirtSection { guests, storage, network }

/// The Virtualization tab: libvirt/KVM and Proxmox VE hosts and their guests.
///
/// The subject is a host. Its guests are the list; a guest's overview and
/// console are the detail beside it, or a page over it on a narrow window —
/// the host's guest list is what a single column is for, and the other hosts
/// are behind the switcher at its head. See virt.md, "UI (phase 1)".
class VirtTabPage extends ConsumerStatefulWidget {
  const VirtTabPage({super.key});

  @override
  ConsumerState<VirtTabPage> createState() => _VirtTabPageState();
}

class _VirtTabPageState extends ConsumerState<VirtTabPage>
    with AutomaticKeepAliveClientMixin {
  /// The host chosen, or null for "the first there is".
  String? _hostId;

  /// The guest open beside the list. Null while nothing is — which is what
  /// tells `NestedNavigator` a change is the detail closing.
  String? _guestId;

  /// The host switcher, opened inside the list column (two columns only; one
  /// column raises it as a sheet instead).
  bool _showHosts = false;

  final _search = InlineSearchController();

  /// Kept alive like the other home tabs: switching away and back keeps the
  /// host and guest chosen, and a graphical console open here stays open —
  /// paused while another tab is on screen (`currentHomeTabProvider`, read by
  /// the console view), rather than closed with the page.
  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // A request made before this tab existed — the PVE card on a server's
      // page, which switches here — is waiting already. After the frame,
      // because clearing it is a provider write, which a build may not make.
      _drainRequest();
      // The first listing asks the servers not asked yet that are connected
      // or connecting anyway — a probe is a connection, and one the user did
      // not ask for must not open a server they keep closed. The rest are
      // behind "Check this server" and "Check all". Cached for the session by
      // the provider, so coming back here asks nobody again.
      unawaited(
        ref.read(virtHostsProvider.notifier).probeAll(onlyConnected: true),
      );
    });
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    ref.listen(virtHostRequestProvider, (_, _) => _drainRequest());
    final hosts = ref.watch(virtHostsProvider);
    // Watched here, on this page's element: the list builder below runs on
    // the pane's, where a watch would subscribe the wrong widget.
    final servers = ref.watch(serversProvider).servers;
    final hostId = _resolveHost(hosts);

    return PaneSettings.listenAll((paneWidth, paneCollapsed) {
      return AdaptivePanes.detail(
        listWidth: paneWidth,
        onListWidthChanged: PaneSettings.saveWidth,
        collapsed: paneCollapsed,
        onCollapsedChanged: PaneSettings.saveCollapsed,
        collapseTooltip: libL10n.fold,
        expandTooltip: libL10n.open,
        // Null whenever no guest is open, so a return to the host's own
        // column animates as a way back. Keyed on the host as well, because
        // the same id on two hosts is two different guests.
        detailId: hostId == null || _guestId == null
            ? null
            : '$hostId/$_guestId',
        onCloseDetail: () => setState(() => _guestId = null),
        // A widget with its own `ref`: this builder runs on the pane's
        // element, not this page's.
        detailBuilder: (_) => _buildDetail(hostId),
        listBuilder: (_, split) => _buildList(hosts, servers, hostId, split),
      );
    });
  }

  /// The host on screen: the one chosen, while it is still a host, otherwise
  /// the first. A host can stop being one — its PVE row deleted, a re-probe
  /// that no longer finds virsh — and the tab moves on rather than showing a
  /// server that has nothing here.
  String? _resolveHost(VirtHostsState hosts) {
    final chosen = _hostId;
    if (chosen != null && hosts.hosts.containsKey(chosen)) return chosen;
    return hosts.hostIds.firstOrNull;
  }

  Widget _buildDetail(String? hostId) {
    final guestId = _guestId;
    if (hostId == null || guestId == null) {
      return const EmptyPane(icon: Icons.view_in_ar_outlined);
    }
    return VirtGuestView(
      key: ValueKey('$hostId/$guestId'),
      serverId: hostId,
      guestId: guestId,
    );
  }
}

// --- Actions ---

extension _Actions on _VirtTabPageState {
  void _drainRequest() {
    final id = ref.read(virtHostRequestProvider);
    if (id == null) return;
    ref.read(virtHostRequestProvider.notifier).done();
    _selectHost(id);
  }

  void _selectHost(String id) {
    if (!mounted) return;
    setState(() {
      if (_hostId != id) _guestId = null;
      _hostId = id;
      _showHosts = false;
    });
  }

  /// Opens [guestId]: beside the list with two columns, over it with one.
  void _openGuest(String hostId, String guestId, bool split) {
    if (split) {
      setState(() => _guestId = guestId);
      return;
    }
    VirtGuestPage.route.go(
      context,
      VirtGuestArgs(serverId: hostId, guestId: guestId),
    );
  }

  /// Probes [serverId] and, if it turns out to be a host, shows it — asking
  /// is what someone does when they expect it to be one.
  ///
  /// True when it is one.
  Future<bool> _check(String serverId) async {
    final notifier = ref.read(virtHostsProvider.notifier);
    await notifier.probe(serverId, force: true);
    if (!mounted) return false;
    if (!ref.read(virtHostsProvider).hosts.containsKey(serverId)) return false;
    _selectHost(serverId);
    return true;
  }

  /// The host switcher, where there is no column to open it in.
  Future<void> _showHostSheet(String? hostId) async {
    await showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      useSafeArea: true,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => FractionallySizedBox(
        heightFactor: 0.7,
        child: _VirtHostPicker(
          selectedId: hostId,
          onSelect: (id) {
            Navigator.of(sheetContext).pop();
            _selectHost(id);
          },
          // A server that turns out to be a host is shown at once, so the
          // sheet has done its job.
          onCheck: (id) async {
            final found = await _check(id);
            if (found && sheetContext.mounted) Navigator.of(sheetContext).pop();
            return found;
          },
        ),
      ),
    );
  }
}
