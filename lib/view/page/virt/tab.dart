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
import 'package:server_box/view/page/server/edit/edit.dart';
import 'package:server_box/view/page/virt/common.dart';
import 'package:server_box/view/page/virt/create.dart';
import 'package:server_box/view/page/virt/guest.dart';
import 'package:server_box/view/page/virt/host_error.dart';
import 'package:server_box/view/page/virt/resources.dart';
import 'package:server_box/view/widget/pane_settings.dart';
import 'package:server_box/view/widget/progress_line.dart';

part 'hosts.dart';
part 'list.dart';

/// What the list column is showing. Storage and network are offered where
/// the host's capabilities say (`VirtCapabilities.storage` / `.network`),
/// and drawn disabled elsewhere, so the shape of the tab does not change
/// between hosts.
enum VirtSection { guests, storage, network }

/// The Virtualization tab: libvirt/KVM and Proxmox VE hosts and their guests.
///
/// The subject is a host. Its guests are the list; a guest's overview,
/// console and snapshots are the detail beside it, or a page over it on a
/// narrow window — the host's guest list is what a single column is for, and
/// the other hosts are behind the switcher at its head. The Storage and
/// Network sections swap the list for the host's pools or networks, the same
/// way. See virt.md, "UI".
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

  /// The section on screen, and what is open beside it in the other two.
  var _section = VirtSection.guests;
  String? _poolId;
  String? _netId;

  /// A new guest is being filled in beside the list (two columns; one column
  /// pushes a page instead). Takes the place of the guest open there.
  bool _creating = false;

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
    final caps = hostId == null
        ? null
        : ref.watch(
            virtHostProvider(hostId).select((s) => s.data?.capabilities),
          );

    return PaneSettings.listenAll((paneWidth, paneCollapsed) {
      return AdaptivePanes.detail(
        listWidth: paneWidth,
        onListWidthChanged: PaneSettings.saveWidth,
        collapsed: paneCollapsed,
        onCollapsedChanged: PaneSettings.saveCollapsed,
        collapseTooltip: libL10n.fold,
        expandTooltip: libL10n.open,
        // Null whenever nothing is open, so a return to the host's own
        // column animates as a way back. Keyed on the host and the section
        // as well, because the same id on two hosts is two different guests
        // and a pool may share a network's name.
        detailId: switch (_openId) {
          _ when _creating && hostId != null => '$hostId/create',
          final id? when hostId != null => '$hostId/${_section.name}/$id',
          _ => null,
        },
        onCloseDetail: () => setState(() {
          _creating = false;
          _closeDetail();
        }),
        // A widget with its own `ref`: this builder runs on the pane's
        // element, not this page's.
        detailBuilder: (_) => _buildDetail(hostId),
        listBuilder: (_, split) =>
            _buildList(hosts, servers, hostId, split, caps),
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

  /// What is open beside the list in the section on screen.
  String? get _openId => switch (_section) {
    VirtSection.guests => _guestId,
    VirtSection.storage => _poolId,
    VirtSection.network => _netId,
  };

  void _closeDetail() {
    switch (_section) {
      case VirtSection.guests:
        _guestId = null;
      case VirtSection.storage:
        _poolId = null;
      case VirtSection.network:
        _netId = null;
    }
  }

  Widget _buildDetail(String? hostId) {
    if (_creating && hostId != null) {
      return VirtCreateView(
        key: ValueKey('$hostId/create'),
        serverId: hostId,
        onCancel: () => setState(() => _creating = false),
        onCreated: (id) => setState(() {
          _creating = false;
          _section = VirtSection.guests;
          _guestId = id;
        }),
      );
    }
    final id = _openId;
    if (hostId == null || id == null) {
      return EmptyPane(icon: _section.icon);
    }
    final key = ValueKey('$hostId/${_section.name}/$id');
    return switch (_section) {
      VirtSection.guests => VirtGuestView(
        key: key,
        serverId: hostId,
        guestId: id,
        onDeleted: () => setState(() => _guestId = null),
        onOpenGuest: (guestId) => _openGuest(hostId, guestId, true),
      ),
      VirtSection.storage => VirtPoolView(
        key: key,
        serverId: hostId,
        poolId: id,
      ),
      VirtSection.network => VirtNetworkView(
        key: key,
        serverId: hostId,
        netId: id,
        onOpenGuest: (guestId) => _openGuest(hostId, guestId, true),
      ),
    };
  }
}

extension VirtSectionUi on VirtSection {
  IconData get icon => switch (this) {
    VirtSection.guests => Icons.view_in_ar_outlined,
    VirtSection.storage => Icons.storage_outlined,
    VirtSection.network => Icons.lan_outlined,
  };
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
      if (_hostId != id) {
        _guestId = null;
        _poolId = null;
        _netId = null;
        _creating = false;
      }
      _hostId = id;
      _showHosts = false;
    });
  }

  void _selectSection(VirtSection section) {
    setState(() {
      _section = section;
      _creating = false;
    });
  }

  /// The form for a new guest: beside the list with two columns, over it
  /// with one — and then the new guest, as it would be opened from the list.
  Future<void> _startCreate(String hostId, bool split) async {
    if (split) {
      setState(() {
        _section = VirtSection.guests;
        _creating = true;
      });
      return;
    }
    final id = await VirtCreatePage.route.go(
      context,
      VirtCreateArgs(serverId: hostId),
    );
    if (id == null || !mounted) return;
    _openGuest(hostId, id, false);
  }

  /// Opens [guestId]: beside the list with two columns, over it with one.
  /// From another section (a guest on a network), with the guest list.
  void _openGuest(String hostId, String guestId, bool split) {
    if (split) {
      setState(() {
        _section = VirtSection.guests;
        _guestId = guestId;
        _creating = false;
      });
      return;
    }
    VirtGuestPage.route.go(
      context,
      VirtGuestArgs(serverId: hostId, guestId: guestId),
    );
  }

  /// Opens the pool or network [id] of the section on screen, as [_openGuest]
  /// opens a guest.
  void _openResource(String hostId, String id, bool split) {
    if (split) {
      setState(() {
        _creating = false;
        switch (_section) {
          case VirtSection.guests:
            _guestId = id;
          case VirtSection.storage:
            _poolId = id;
          case VirtSection.network:
            _netId = id;
        }
      });
      return;
    }
    final args = VirtResourceArgs(serverId: hostId, id: id);
    switch (_section) {
      case VirtSection.guests:
        _openGuest(hostId, id, split);
      case VirtSection.storage:
        VirtPoolPage.route.go(context, args);
      case VirtSection.network:
        VirtNetworkPage.route.go(context, args);
    }
  }

  /// Asks the host again, and what the section on screen lists with it.
  void _refresh(String hostId) {
    unawaited(ref.read(virtHostProvider(hostId).notifier).refresh());
    switch (_section) {
      case VirtSection.guests:
        break;
      case VirtSection.storage:
        ref.invalidate(virtStoragePoolsProvider(hostId));
      case VirtSection.network:
        ref.invalidate(virtNetworksProvider(hostId));
    }
  }

  /// Probes [serverId] and, if it turns out to be a host, shows it — asking
  /// is what someone does when they expect it to be one.
  ///
  /// True when it is one.
  Future<bool> _check(String serverId) async {
    final notifier = ref.read(virtHostsProvider.notifier);
    await notifier.probe(serverId, force: true);
    if (!mounted) return false;
    final hosts = ref.read(virtHostsProvider);
    if (hosts.probes[serverId]?.status == VirtProbeStatus.pve) {
      return _setUpPve(serverId);
    }
    if (!hosts.hosts.containsKey(serverId)) return false;
    _selectHost(serverId);
    return true;
  }

  /// Offers the server editor's PVE group for a server found running PVE
  /// with no API access configured, and shows the host once it is.
  ///
  /// True when it became a host.
  Future<bool> _setUpPve(String serverId) async {
    final spi = ref.read(serversProvider).servers[serverId];
    if (spi == null) return false;
    final line = ref.read(virtHostsProvider).probes[serverId]?.pve;
    final version = RegExp(r'pve-manager/([^/\s]+)').firstMatch(line ?? '');
    final go = await context.showRoundDialog<bool>(
      title: 'Proxmox VE',
      child: Text(
        l10n.virtPveSetupTip(
          version == null ? 'Proxmox VE' : 'Proxmox VE ${version[1]}',
        ),
      ),
      actions: [
        Btn.cancel(),
        Btn.text(text: libL10n.setting, onTap: () => context.popDialog(true)),
      ],
    );
    if (go != true || !mounted) return false;
    await ServerEditPage.route.go(
      context,
      args: ServerEditArgs(spi, section: ServerEditSection.pve),
    );
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
          onSetUpPve: (id) async {
            final found = await _setUpPve(id);
            if (found && sheetContext.mounted) Navigator.of(sheetContext).pop();
            return found;
          },
        ),
      ),
    );
  }
}
