import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:server_box/data/model/virt/virt.dart';

part 'virt_resources.freezed.dart';

/// One snapshot of a guest.
///
/// libvirt: an internal snapshot (`snapshot-create-as`); PVE: `.../snapshot`.
/// Named "guest snapshot" because `VirtSnapshot` is one load of a host.
@freezed
abstract class VirtGuestSnapshot with _$VirtGuestSnapshot {
  const factory VirtGuestSnapshot({
    required String name,

    /// The snapshot this one was taken on top of; null for a root.
    String? parent,
    String? description,
    DateTime? createdAt,

    /// What the guest's disks were last created from or reverted to: the one
    /// a new snapshot would have as its parent.
    @Default(false) bool current,

    /// Holds the guest's memory: reverting resumes it where it was. Without,
    /// reverting leaves the guest stopped.
    @Default(false) bool withMemory,
  }) = _VirtGuestSnapshot;
}

/// [snapshots] depth-first from the roots, each with its depth — how the
/// list draws a tree without drawing one. Siblings oldest first. A snapshot
/// whose parent is not in the list (deleted, or a cycle in bad data) is a
/// root.
List<(VirtGuestSnapshot, int)> virtSnapshotTree(
  List<VirtGuestSnapshot> snapshots,
) {
  final names = {for (final s in snapshots) s.name};
  final children = <String?, List<VirtGuestSnapshot>>{};
  for (final s in snapshots) {
    final parent = s.parent;
    final key = parent != null && names.contains(parent) && parent != s.name
        ? parent
        : null;
    children.putIfAbsent(key, () => []).add(s);
  }
  int byTime(VirtGuestSnapshot a, VirtGuestSnapshot b) {
    final at = a.createdAt;
    final bt = b.createdAt;
    if (at != null && bt != null && at != bt) return at.compareTo(bt);
    return a.name.compareTo(b.name);
  }

  for (final list in children.values) {
    list.sort(byTime);
  }
  final out = <(VirtGuestSnapshot, int)>[];
  final seen = <String>{};
  void walk(String? parent, int depth) {
    for (final s in children[parent] ?? const <VirtGuestSnapshot>[]) {
      if (!seen.add(s.name)) continue;
      out.add((s, depth));
      walk(s.name, depth + 1);
    }
  }

  walk(null, 0);
  // Whatever a cycle kept out of reach of the roots.
  for (final s in snapshots) {
    if (seen.add(s.name)) {
      out.add((s, 0));
    }
  }
  return out;
}

/// Where a snapshot may take the guest's memory from.
enum VirtSnapshotMemory {
  /// Not at all: a container, or a guest that is not running.
  none,

  /// The user chooses (PVE `vmstate`).
  optional,

  /// Always, and there is no choice: libvirt's internal snapshot of an active
  /// domain (QEMU refuses one without it).
  always,
}

/// Whether a snapshot of [guest], [state] now, can hold its memory on a host
/// with [caps].
///
/// Only an active VM's: a container has nothing to save it with (PVE), and a
/// stopped guest has none. Paused counts: QEMU saves a paused guest's memory
/// as well.
VirtSnapshotMemory virtSnapshotMemory(
  VirtCapabilities caps,
  VirtGuest guest,
  VirtGuestState state,
) {
  if (guest.kind == VirtGuestKind.lxc) return VirtSnapshotMemory.none;
  if (state != VirtGuestState.running && state != VirtGuestState.paused) {
    return VirtSnapshotMemory.none;
  }
  return caps.snapshotMemoryRequired
      ? VirtSnapshotMemory.always
      : VirtSnapshotMemory.optional;
}

/// Why a name cannot be a new snapshot's, or null when it can.
enum VirtSnapshotNameIssue { empty, invalid, taken }

/// What a new snapshot's name may be: PVE's own rule (`pve-configid`: a
/// letter, then up to 39 letters, digits, `-` and `_`), used for libvirt as
/// well so a name never needs quoting to be read back.
final virtSnapshotNamePattern = RegExp(r'^[A-Za-z][A-Za-z0-9_-]{1,39}$');

VirtSnapshotNameIssue? virtSnapshotNameIssue(
  String name,
  Iterable<VirtGuestSnapshot> existing,
) {
  if (name.isEmpty) return VirtSnapshotNameIssue.empty;
  if (!virtSnapshotNamePattern.hasMatch(name)) {
    return VirtSnapshotNameIssue.invalid;
  }
  // PVE reserves `current` for the "you are here" entry of its listing.
  if (name == 'current' || existing.any((s) => s.name == name)) {
    return VirtSnapshotNameIssue.taken;
  }
  return null;
}

/// A guest something on a host belongs to: the owner of a volume, a guest on
/// a network. By [guestId] (libvirt's UUID) or [vmid] (PVE), whichever the
/// host says; the UI finds the guest in the host's list.
@freezed
abstract class VirtGuestRef with _$VirtGuestRef {
  const factory VirtGuestRef({
    String? guestId,
    int? vmid,

    /// How it uses the thing: the disk's target (`vda`, `scsi0`), the NIC's
    /// key or host device.
    String? device,

    /// What else is known: its MAC and address on a network.
    String? mac,
    String? ip,
  }) = _VirtGuestRef;
}

/// A storage pool (libvirt) or storage (PVE) of one host.
@freezed
abstract class VirtStoragePool with _$VirtStoragePool {
  const VirtStoragePool._();

  const factory VirtStoragePool({
    /// Unique on the host: libvirt's pool name, PVE `<node>/<storage>`.
    required String id,
    required String name,

    /// The PVE node it is listed for; storage is per node there.
    String? node,

    /// `dir`, `logical`, `netfs`, ... (libvirt); `dir`, `lvmthin`, `zfspool`,
    /// `nfs`, ... (PVE).
    required String type,

    /// Where volumes live: a directory, a volume group, a thin pool.
    String? path,

    /// Where the pool comes from: `host:/export`, a device.
    String? source,
    int? capacity,
    int? used,
    int? available,
    @Default(true) bool active,

    /// Started with the host (libvirt).
    bool? autostart,

    /// Configured on (PVE `enabled`).
    bool? enabled,

    /// Shared between PVE nodes.
    bool? shared,

    /// What PVE allows in it: `images`, `rootdir`, `iso`, `vztmpl`,
    /// `backup`, `snippets`, `import`.
    @Default(<String>[]) List<String> content,

    /// Volumes in it, when listing the pools already says.
    int? volumeCount,
  }) = _VirtStoragePool;

  /// Fraction used, 0..1; null when unknown or empty.
  double? get usedFraction {
    final c = capacity;
    final u = used;
    if (c == null || u == null || c <= 0) return null;
    return u / c;
  }
}

/// One volume in a pool: a disk image, an ISO, a template, a backup.
@freezed
abstract class VirtVolume with _$VirtVolume {
  const factory VirtVolume({
    /// libvirt's volume name; PVE's `volid` (`local-lvm:vm-100-disk-0`).
    required String id,
    required String name,
    String? path,

    /// `qcow2`, `raw`, `iso`, `tzst`, ...
    String? format,

    /// PVE's content kind: `images`, `rootdir`, `iso`, `vztmpl`, `backup`.
    String? content,

    /// Bytes the guest sees.
    int? capacity,

    /// Bytes it takes on the host, where the host says.
    int? allocation,

    /// A qcow2 overlay's backing file (libvirt).
    String? backing,
    DateTime? createdAt,
    @Default(<VirtGuestRef>[]) List<VirtGuestRef> users,
  }) = _VirtVolume;
}

/// A virtual network (libvirt) or a node network interface (PVE).
@freezed
abstract class VirtNetwork with _$VirtNetwork {
  const factory VirtNetwork({
    /// Unique on the host: libvirt's network name, PVE `<node>/<iface>`.
    required String id,
    required String name,
    String? node,

    /// libvirt's forward mode: `nat`, `isolated`, `route`, `open`, `bridge`,
    /// `passthrough`, ...; PVE's interface type: `bridge`, `bond`, `vlan`,
    /// `eth`, `OVSBridge`, ...
    required String mode,

    /// libvirt: the bridge device (`virbr0`, or the host bridge a
    /// bridge-mode network uses).
    String? bridge,

    /// Addresses with their prefix, e.g. `192.168.122.1/24`.
    @Default(<String>[]) List<String> cidrs,
    String? gateway,

    /// `start-end` of each DHCP range (libvirt).
    @Default(<String>[]) List<String> dhcpRanges,

    /// PVE bridge ports or bond slaves; libvirt forward devices.
    @Default(<String>[]) List<String> ports,

    /// PVE `bridge_vlan_aware`.
    bool? vlanAware,

    /// PVE: the VLAN tag and the device it is on.
    int? vlanId,
    String? vlanDevice,

    /// PVE bond mode (`active-backup`, `802.3ad`, ...).
    String? bondMode,
    @Default(true) bool active,
    bool? autostart,
    String? comment,

    /// Guests with a NIC on it.
    @Default(<VirtGuestRef>[]) List<VirtGuestRef> users,
  }) = _VirtNetwork;
}
