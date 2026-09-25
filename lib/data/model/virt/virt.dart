import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:server_box/core/utils/version.dart';

part 'virt.freezed.dart';
part 'virt.g.dart';

/// Which kind of hypervisor manager a virtualization host is reached as.
enum VirtHostKind {
  /// Proxmox VE, through its HTTP API (`/api2/json`).
  pve,

  /// libvirt, through `virsh` run on the server.
  libvirt,
}

enum VirtGuestKind { qemu, lxc }

/// A guest's state as the Virtualization tab shows it.
///
/// Mapped from PVE's `status` + `lock` and from libvirt's state + reason — see
/// `PveResources.stateOf` and `LibvirtBackend`. [rebooting] is never reported
/// by either API: it is what a guest reads as while this app has a reboot in
/// flight (`VirtHostState.displayState`).
enum VirtGuestState {
  running,
  paused,
  stopped,
  starting,
  stopping,
  rebooting,
  migrating,
  backup,
  unknown;

  /// Something is running: the guest holds CPU and memory on the host.
  bool get isActive => switch (this) {
    running || paused || starting || stopping || rebooting || migrating => true,
    stopped || backup || unknown => false,
  };

  /// In the middle of a change; the UI shows progress rather than actions.
  bool get isTransient => switch (this) {
    starting || stopping || rebooting || migrating || backup => true,
    running || paused || stopped || unknown => false,
  };
}

/// Power actions. Which of them a guest offers is [VirtGuest.actions], decided
/// by the backend from its state and the host's [VirtCapabilities].
enum VirtPowerAction {
  start,

  /// ACPI shutdown request; the guest may ignore it.
  shutdown,

  /// ACPI reboot request.
  reboot,

  /// Stops the guest at once, like pulling the plug (PVE `stop`, libvirt
  /// `destroy`).
  forceStop,

  /// Pauses the vCPUs; memory stays allocated.
  suspend,
  resume;

  /// Loses the guest's unsaved state, so the UI asks more insistently.
  bool get destructive => this == forceStop;

  /// What a guest in [state] offers.
  ///
  /// [pause] is whether suspend and resume exist for this guest at all (the
  /// host's `VirtCapabilities.pause`, and not PVE containers). [resumable]
  /// false is a paused guest that `resume` does not wake — libvirt's
  /// `pmsuspended`, which needs `dompmwakeup`. A guest in the middle of a
  /// transition can still be force-stopped, which is the way out of a
  /// shutdown the guest ignores; one held by a backup or a migration offers
  /// nothing.
  static Set<VirtPowerAction> offered(
    VirtGuestState state, {
    required bool pause,
    bool resumable = true,
  }) => switch (state) {
    VirtGuestState.running => {
      shutdown,
      reboot,
      forceStop,
      if (pause) suspend,
    },
    VirtGuestState.paused => {
      if (pause && resumable) resume,
      forceStop,
    },
    VirtGuestState.stopped => {start},
    VirtGuestState.starting ||
    VirtGuestState.stopping ||
    VirtGuestState.rebooting => {forceStop},
    VirtGuestState.migrating ||
    VirtGuestState.backup ||
    VirtGuestState.unknown => {},
  };

  /// The state a guest reads as while this action is in flight.
  VirtGuestState get transientState => switch (this) {
    start || resume => VirtGuestState.starting,
    shutdown || forceStop || suspend => VirtGuestState.stopping,
    reboot => VirtGuestState.rebooting,
  };
}

/// One machine of a host: a PVE cluster node, or the libvirt host itself.
///
/// Every figure is nullable: libvirt's overview does not read the host's own
/// CPU and memory (the server's status page has them), and PVE omits them for
/// an offline node.
@freezed
abstract class VirtNode with _$VirtNode {
  const factory VirtNode({
    required String name,
    @Default(true) bool online,

    /// Fraction of [maxCpu] in use, 0..1.
    double? cpu,
    int? maxCpu,
    int? memUsed,
    int? memTotal,
    Duration? uptime,
  }) = _VirtNode;

  factory VirtNode.fromJson(Map<String, dynamic> json) =>
      _$VirtNodeFromJson(json);
}

/// A virtualization host: one server, and what manages its guests.
@freezed
abstract class VirtHost with _$VirtHost {
  const VirtHost._();

  const factory VirtHost({
    required String serverId,
    required VirtHostKind kind,

    /// PVE's release (`8.2`), or libvirt's library version (`10.0.0`).
    String? version,

    /// The hypervisor as the host names it, e.g. `QEMU 8.2.2`. libvirt only.
    String? hypervisor,
    @Default(<VirtNode>[]) List<VirtNode> nodes,
  }) = _VirtHost;

  factory VirtHost.fromJson(Map<String, dynamic> json) =>
      _$VirtHostFromJson(json);

  /// More than one node, so a guest's node is worth naming.
  bool get isCluster => nodes.length > 1;

  /// The oldest PVE release this app was tested against.
  static const pveTested = [8, 0];

  /// A PVE host older than [pveTested]: shown, with a notice that it was not
  /// tested there. Not refused — PVE 7's API is the same for what this app
  /// asks, and a version it cannot read says nothing either way.
  bool get pveUntested =>
      kind == VirtHostKind.pve &&
      version != null &&
      isVersionLessThan(version!, pveTested);
}

/// One VM or container.
@freezed
abstract class VirtGuest with _$VirtGuest {
  const VirtGuest._();

  const factory VirtGuest({
    /// Stable within the host: PVE `qemu/100`, libvirt the domain's UUID.
    required String id,
    required String name,
    required VirtGuestKind kind,
    required VirtGuestState state,

    /// The raw detail behind [state], for display and for decisions the
    /// state alone cannot make: PVE's `lock` (`backup`, `snapshot`, ...) or
    /// QEMU status (`prelaunch`, `io-error`), libvirt's reason (`crashed`,
    /// `pmsuspended`, `user`, ...). Null when there is nothing to add.
    String? stateReason,

    /// PVE's numeric id.
    int? vmid,

    /// The PVE node the guest is on.
    String? node,
    int? vcpu,

    /// Memory assigned to the guest, bytes.
    int? memBytes,
    Duration? uptime,
    @Default(<String>[]) List<String> tags,

    /// A PVE template: not a guest that runs, and offers no actions.
    @Default(false) bool template,

    /// Starts with the host (libvirt autostart, PVE `onboot` is not in the
    /// resource list and is left null).
    bool? autostart,

    /// The power actions this guest offers now.
    @Default(<VirtPowerAction>{}) Set<VirtPowerAction> actions,
  }) = _VirtGuest;

  factory VirtGuest.fromJson(Map<String, dynamic> json) =>
      _$VirtGuestFromJson(json);
}

/// One reading of a guest's usage. Throughputs are rates, bytes per second.
///
/// Null means "not measured": a stopped guest, a first sample with nothing to
/// diff against, a counter the host does not report. Never read as zero.
@freezed
abstract class VirtStats with _$VirtStats {
  const factory VirtStats({
    required DateTime at,

    /// Percent of the guest's own vCPUs, 0..100.
    double? cpu,
    int? memUsed,
    int? memTotal,
    int? diskUsed,
    int? diskTotal,
    double? diskRead,
    double? diskWrite,
    double? netIn,
    double? netOut,
  }) = _VirtStats;

  factory VirtStats.fromJson(Map<String, dynamic> json) =>
      _$VirtStatsFromJson(json);
}

/// What the app can do with a host. The UI shows or hides by these, never by
/// [VirtHostKind].
///
/// They describe this build's support, not the hypervisor's in general:
/// PVE has backups, but until the app manages them [backup] is false.
@freezed
abstract class VirtCapabilities with _$VirtCapabilities {
  const factory VirtCapabilities({
    @Default(false) bool lxc,
    @Default(false) bool pause,

    /// Snapshots can be listed, taken, reverted to and deleted.
    @Default(false) bool snapshots,

    /// A snapshot of an active guest always holds its memory, with no way to
    /// leave it out (libvirt's internal snapshots: QEMU refuses one without).
    /// Otherwise it is the user's choice, where the guest is not a container.
    @Default(false) bool snapshotMemoryRequired,

    /// Storage pools and their volumes can be listed.
    @Default(false) bool storage,

    /// Networks and the guests on them can be listed.
    @Default(false) bool network,
    @Default(false) bool backup,

    /// More than one node: guests are grouped by node.
    @Default(false) bool cluster,

    /// A serial console in a terminal session (`virsh console`).
    @Default(false) bool serialConsole,

    /// A graphical (VNC) console.
    @Default(false) bool vncConsole,

    /// A text console through PVE's `termproxy`.
    @Default(false) bool termConsole,

    /// The host keeps a usage history, so a chart can show the last hour at
    /// once (PVE `rrddata`). Without it the chart fills from this session's
    /// samples.
    @Default(false) bool storedHistory,
  }) = _VirtCapabilities;

  factory VirtCapabilities.fromJson(Map<String, dynamic> json) =>
      _$VirtCapabilitiesFromJson(json);
}

/// What one load of a host yields.
@freezed
abstract class VirtSnapshot with _$VirtSnapshot {
  const factory VirtSnapshot({
    required VirtHost host,
    required List<VirtGuest> guests,

    /// By [VirtGuest.id]. A guest missing here has nothing measured yet.
    @Default(<String, VirtStats>{}) Map<String, VirtStats> stats,
    required VirtCapabilities capabilities,
  }) = _VirtSnapshot;
}

/// How far back [VirtStats] history reaches, in PVE `rrddata` terms.
enum VirtHistoryWindow {
  hour,
  day,
  week;

  String get pveTimeframe => name;
}
