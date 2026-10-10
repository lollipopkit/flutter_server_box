// ignore_for_file: invalid_use_of_protected_member

import 'dart:async';

import 'package:fl_lib/fl_lib.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/data/model/server/server_private_info.dart';
import 'package:server_box/data/model/virt/virt.dart';
import 'package:server_box/data/provider/app/session_requests.dart';
import 'package:server_box/data/provider/server/all.dart';
import 'package:server_box/data/provider/virt/virt.dart';
import 'package:server_box/data/res/chart_palette.dart';
import 'package:server_box/view/page/server/edit/edit.dart';
import 'package:server_box/view/page/virt/common.dart';
import 'package:server_box/view/page/virt/guest.dart';
import 'package:server_box/view/page/virt/hardware.dart';
import 'package:server_box/view/page/virt/host_error.dart';
import 'package:server_box/view/page/virt/resources.dart';
import 'package:server_box/view/widget/pane_settings.dart';
import 'package:server_box/view/widget/progress_line.dart';

part 'hosts.dart';
part 'list.dart';

/// What the list column is showing. Storage, network and backup are offered
/// where the host's capabilities say (`VirtCapabilities.storage` /
/// `.network` / `.backupJobs`); a section the host does not have is not
/// drawn at all, so the shape of the tab follows the host.
enum VirtSection { guests, storage, network, backup }

/// The Virtualization tab: libvirt/KVM and Proxmox VE hosts and their guests.
///
/// The subject is a host. Its guests are the list; a guest's overview,
/// console and snapshots are the detail beside it, or a page over it on a
/// narrow window — the host's guest list is what a single column is for, and
/// the other hosts are behind the switcher at its head. The Storage and
/// Network sections swap the list for the host's pools or networks, the same
/// way. See docs/dev/virt.md, "UI".
class VirtTabPage extends ConsumerStatefulWidget {
  const VirtTabPage({super.key});

  @override
  ConsumerState<VirtTabPage> createState() => _VirtTabPageState();
}

class _VirtTabPageState extends ConsumerState<VirtTabPage>
    with AutomaticKeepAliveClientMixin {
  /// The host chosen, or null for "the first there is".
  String? _hostId;

  /// The host the selection below belongs to: the one last on screen. The
  /// host on screen can change without being chosen (see [_resolveHost]),
  /// and an id open on one host is not the same thing on another — a VMID,
  /// a pool or network name.
  String? _shownHostId;

  /// The guest open beside the list. Null while nothing is — which is what
  /// tells `NestedNavigator` a change is the detail closing.
  String? _guestId;

  /// The section on screen, and what is open beside it in the others.
  var _section = VirtSection.guests;
  String? _poolId;
  String? _netId;
  String? _jobId;

  /// Something new is being filled in beside the list — a guest, a pool or
  /// a network, as the section on screen says (two columns; one column
  /// pushes a page instead). Takes the place of what is open there.
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
    // Before anything reads the selection: what was open belongs to the host
    // shown before, whether it was switched away from or went away.
    if (hostId != _shownHostId) {
      _shownHostId = hostId;
      _clearSelection();
    }
    final caps = hostId == null
        ? null
        : ref.watch(
            virtHostProvider(hostId).select((s) => s.data?.capabilities),
          );
    // A section the host does not have (the host changed, or its answer
    // did) is the guests, which every host has — here, where the list, the
    // detail and every action read it, so none of them acts on the other.
    // Kept while the host's answer is not in yet.
    if (caps != null && !_section.availableOn(caps)) {
      _section = VirtSection.guests;
      _creating = false;
    }
    final refreshing = hostId != null && _refreshing(hostId);

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
          _ when _creating && hostId != null => '$hostId/${_section.name}/create',
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
            _buildList(hosts, servers, hostId, split, caps, refreshing),
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

  /// What is open beside the list in the section on screen. The backup
  /// section's id is a job's, or the empty string for a new one.
  String? get _openId => switch (_section) {
    VirtSection.guests => _guestId,
    VirtSection.storage => _poolId,
    VirtSection.network => _netId,
    VirtSection.backup => _jobId,
  };

  /// Nothing open, nothing being made: what [_shownHostId] had.
  void _clearSelection() {
    _guestId = null;
    _poolId = null;
    _netId = null;
    _jobId = null;
    _creating = false;
  }

  void _closeDetail() {
    switch (_section) {
      case VirtSection.guests:
        _guestId = null;
      case VirtSection.storage:
        _poolId = null;
      case VirtSection.network:
        _netId = null;
      case VirtSection.backup:
        _jobId = null;
    }
  }

  Widget _buildDetail(String? hostId) {
    if (_creating && hostId != null) {
      final key = ValueKey('$hostId/${_section.name}/create');
      void cancel() => setState(() => _creating = false);
      return switch (_section) {
        VirtSection.guests => VirtCreateView(
          key: key,
          serverId: hostId,
          onCancel: cancel,
          onCreated: (id) => setState(() {
            _creating = false;
            _guestId = id;
          }),
        ),
        VirtSection.storage => VirtPoolCreateView(
          key: key,
          serverId: hostId,
          onCancel: cancel,
          onCreated: (id) => setState(() {
            _creating = false;
            _poolId = id;
          }),
        ),
        VirtSection.network => VirtNetworkCreateView(
          key: key,
          serverId: hostId,
          onCancel: cancel,
          onCreated: (id) => setState(() {
            _creating = false;
            _netId = id;
          }),
        ),
        // A new backup job is the editor with no id, saved into the list.
        VirtSection.backup => VirtBackupJobView(
          key: key,
          serverId: hostId,
          jobId: null,
          leading: BackButton(onPressed: cancel),
          onDeleted: cancel,
        ),
      };
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
        // The job in the Backup section, beside its list; the guest stays
        // open under the guests section for the way back.
        onOpenBackupJob: (jobId) => setState(() {
          _section = VirtSection.backup;
          _jobId = jobId;
          _creating = false;
        }),
      ),
      VirtSection.storage => VirtPoolView(
        key: key,
        serverId: hostId,
        poolId: id,
        onDeleted: () => setState(() => _poolId = null),
      ),
      VirtSection.network => VirtNetworkView(
        key: key,
        serverId: hostId,
        netId: id,
        onOpenGuest: (guestId) => _openGuest(hostId, guestId, true),
        onDeleted: () => setState(() => _netId = null),
      ),
      VirtSection.backup => VirtBackupJobView(
        key: key,
        serverId: hostId,
        jobId: id,
        onSwitch: (jobId) => setState(() => _jobId = jobId),
        onDeleted: () => setState(() => _jobId = null),
      ),
    };
  }
}

extension VirtSectionUi on VirtSection {
  IconData get icon => switch (this) {
    VirtSection.guests => Icons.view_in_ar_outlined,
    VirtSection.storage => Icons.storage_outlined,
    VirtSection.network => Icons.lan_outlined,
    VirtSection.backup => Icons.backup_outlined,
  };

  /// Whether a host with [caps] has this section.
  bool availableOn(VirtCapabilities caps) => switch (this) {
    VirtSection.guests => true,
    VirtSection.storage => caps.storage,
    VirtSection.network => caps.network,
    VirtSection.backup => caps.backupJobs,
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
    // What was open is cleared by `build` when the host on screen changes.
    setState(() {
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

  /// The form for a new guest, pool, network or backup job — whichever the
  /// section on screen lists: beside the list with two columns, over it with
  /// one — and then what was made, as it would be opened from the list.
  Future<void> _startCreate(String hostId, bool split) async {
    if (split) {
      setState(() => _creating = true);
      return;
    }
    final section = _section;
    if (section == VirtSection.backup) {
      await VirtBackupJobPage.route.go(
        context,
        VirtBackupJobArgs(serverId: hostId),
      );
      return;
    }
    final id = switch (section) {
      VirtSection.guests => await VirtCreatePage.route.go(
        context,
        VirtCreateArgs(serverId: hostId),
      ),
      VirtSection.storage || VirtSection.network =>
        await VirtResourceCreatePage.route.go(
          context,
          VirtResourceCreateArgs(
            serverId: hostId,
            network: section == VirtSection.network,
          ),
        ),
      VirtSection.backup => null,
    };
    if (id == null || !mounted) return;
    _openResource(hostId, id, false);
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
          case VirtSection.backup:
            _jobId = id;
        }
      });
      return;
    }
    switch (_section) {
      case VirtSection.guests:
        _openGuest(hostId, id, split);
      case VirtSection.storage:
        VirtPoolPage.route.go(
          context,
          VirtResourceArgs(serverId: hostId, id: id),
        );
      case VirtSection.network:
        VirtNetworkPage.route.go(
          context,
          VirtResourceArgs(serverId: hostId, id: id),
        );
      case VirtSection.backup:
        VirtBackupJobPage.route.go(
          context,
          VirtBackupJobArgs(serverId: hostId, jobId: id),
        );
    }
  }

  /// Whether what the refresh button asks for is being read: the host, and
  /// the section on screen's own list. Watched on this page's element — see
  /// `build`.
  bool _refreshing(String hostId) {
    if (ref.watch(virtHostProvider(hostId).select((s) => s.loading))) {
      return true;
    }
    return switch (_section) {
      VirtSection.guests => false,
      VirtSection.storage => ref.watch(
        virtStoragePoolsProvider(hostId).select((a) => a.isLoading),
      ),
      VirtSection.network => ref.watch(
        virtNetworksProvider(hostId).select((a) => a.isLoading),
      ),
      VirtSection.backup => ref.watch(
        virtBackupJobsProvider(hostId).select((a) => a.isLoading),
      ),
    };
  }

  /// Asks the host again, and what the section on screen lists with it.
  void _refresh(String hostId) {
    unawaited(ref.read(virtHostProvider(hostId).notifier).refresh());
    switch (_section) {
      case VirtSection.guests:
        // The open guest's configuration too: a pull does that on a touch
        // screen, and a pointer has no pull — this button is its refresh.
        if (_guestId case final id?) {
          ref.invalidate(virtHardwareProvider(hostId, id));
          // PVE's cloud-init is in the same configuration. A draft stays on
          // the read it was made from.
          ref.invalidate(virtCloudInitProvider(hostId, id));
        }
      case VirtSection.storage:
        ref.invalidate(virtStoragePoolsProvider(hostId));
      case VirtSection.network:
        ref.invalidate(virtNetworksProvider(hostId));
      case VirtSection.backup:
        ref.invalidate(virtBackupJobsProvider(hostId));
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
