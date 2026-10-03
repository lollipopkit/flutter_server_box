import 'dart:convert';

import 'package:collection/collection.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:server_box/data/model/virt/virt.dart';
import 'package:server_box/data/model/virt/virt_rust.dart';
import 'package:server_box/src/rust/api/resource.dart' as res;
import 'package:server_box/src/rust/api/virt.dart' as ffi;

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

    /// Kept outside the disk image (`snapshot='external'`): the guest was
    /// left on a qcow2 overlay of the file the snapshot records.
    @Default(false) bool external,

    /// Which file each disk was left on, for an external one. Empty for an
    /// internal snapshot, which is one image.
    @Default(<VirtSnapshotLayer>[]) List<VirtSnapshotLayer> layers,
  }) = _VirtGuestSnapshot;

  const VirtGuestSnapshot._();

  /// Whether a later snapshot sits on this one. Reverting to a snapshot that
  /// has one is refused: on libvirt 11.3 such a revert of an external
  /// snapshot failed, leaving the guest shut off on a new file and its
  /// running overlay deleted (see `sbm_virt::libvirt::snapshot`).
  bool hasChildren(Iterable<VirtGuestSnapshot> all) =>
      all.any((s) => s.parent == name);
}

/// The file one disk of a snapshot was left on.
@freezed
abstract class VirtSnapshotLayer with _$VirtSnapshotLayer {
  const factory VirtSnapshotLayer({
    required String target,

    /// The file the snapshot left this disk on. An external layer's file is
    /// the one the *guest* is on until the next snapshot moves it on.
    String? file,

    /// `snapshot='external'`: the layer is a file of its own rather than
    /// something inside the image.
    @Default(false) bool external,
  }) = _VirtSnapshotLayer;
}

/// [snapshots] depth-first from the roots, each with its depth — how the
/// list draws a tree without drawing one. Siblings oldest first, undated
/// ones last. A snapshot
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
    // Undated after dated, so the order stays transitive: a dated/undated
    // pair compared by name would not be.
    if (at == null) {
      if (bt != null) return 1;
    } else if (bt == null) {
      return -1;
    } else if (at != bt) {
      return at.compareTo(bt);
    }
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
  // Whatever a cycle kept out of reach of the roots, each with what hangs
  // under it.
  for (final s in snapshots) {
    if (seen.add(s.name)) {
      out.add((s, 0));
      walk(s.name, 1);
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
/// with [caps] (`sbm_virt::snapshot::memory`).
VirtSnapshotMemory virtSnapshotMemory(
  VirtCapabilities caps,
  VirtGuest guest,
  VirtGuestState state,
) => switch (ffi.virtSnapshotMemory(
  lxc: guest.kind == VirtGuestKind.lxc,
  active: state == VirtGuestState.running || state == VirtGuestState.paused,
  memoryRequired: caps.snapshotMemoryRequired,
)) {
  ffi.SnapshotMemoryKind.none => VirtSnapshotMemory.none,
  ffi.SnapshotMemoryKind.optional => VirtSnapshotMemory.optional,
  ffi.SnapshotMemoryKind.always => VirtSnapshotMemory.always,
};

/// Why a name cannot be a new snapshot's, or null when it can.
enum VirtSnapshotNameIssue { empty, invalid, taken }

/// PVE's own rule (`pve-configid`), used for libvirt as well
/// (`sbm_virt::snapshot::name_issue`).
VirtSnapshotNameIssue? virtSnapshotNameIssue(
  String name,
  Iterable<VirtGuestSnapshot> existing,
) => switch (ffi.virtSnapshotNameIssue(
  name: name,
  existing: [for (final s in existing) s.name],
)) {
  ffi.SnapshotNameIssue.empty => VirtSnapshotNameIssue.empty,
  ffi.SnapshotNameIssue.invalid => VirtSnapshotNameIssue.invalid,
  ffi.SnapshotNameIssue.taken => VirtSnapshotNameIssue.taken,
  null => null,
};

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

    /// The volumes made on this one — whose [backing] it is — in any active
    /// pool, by path (libvirt). A base image a guest's disk is a thin clone
    /// of is attached to nothing, and deleting it breaks every one of them.
    @Default(<String>[]) List<String> backs,
  }) = _VirtVolume;

  const VirtVolume._();

  /// Something depends on it: a guest has it, or a volume is made on it.
  bool get inUse => users.isNotEmpty || backs.isNotEmpty;
}

/// A static DHCP host entry: one address handed to one MAC (libvirt).
@freezed
abstract class VirtNetHost with _$VirtNetHost {
  const factory VirtNetHost({
    required String mac,
    required String ip,

    /// The name dnsmasq is told, where one is given.
    String? name,
  }) = _VirtNetHost;
}

/// A virtual network (libvirt) or a node network interface (PVE).
@freezed
abstract class VirtNetwork with _$VirtNetwork {
  const VirtNetwork._();

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

    /// The static DHCP entries it hands out (libvirt). Empty where there
    /// are none, and on PVE, which keeps no such list here.
    @Default(<VirtNetHost>[]) List<VirtNetHost> hosts,

    /// libvirt: the definition **as saved** (`net-dumpxml --inactive`),
    /// which is what an edit is made from and what a restart puts the
    /// running network on. Refused once the host's has changed since.
    /// Empty where the host did not say (PVE).
    @Default('') String xml,

    /// Whether the running network is on something other than its
    /// definition: libvirt applies `net-define` at the next start, so a
    /// change made while it runs waits, and the view offers the restart
    /// that applies it.
    @Default(false) bool pendingRestart,

    /// Whether this app may change it at all. PVE: a bridge, and not the
    /// interface carrying the node's management address — applying that
    /// would cut the host off. libvirt: every network. The backend decides
    /// (`virtPveManagedIface`), so the view never re-derives it.
    @Default(true) bool managementEditable,

    /// Guests with a NIC on it.
    @Default(<VirtGuestRef>[]) List<VirtGuestRef> users,
  }) = _VirtNetwork;

  /// The first IPv4 address with its prefix (`192.168.150.1/24`); null where
  /// there is none. PVE lists `cidr6` among [cidrs] too — first, on a bridge
  /// with only an IPv6 one — and what reads an address here edits IPv4.
  String? get ipv4Cidr => cidrs.firstWhereOrNull(
    (c) => !c.contains(':') && c.split('/').length == 2,
  );

  /// [ipv4Cidr] without its prefix (`192.168.150.1`); null where there is
  /// none.
  String? get address => ipv4Cidr?.split('/').first;

  /// [ipv4Cidr]'s prefix; null where there is none.
  int? get prefix {
    final cidr = ipv4Cidr;
    return cidr == null ? null : int.tryParse(cidr.split('/').last);
  }

  /// The first DHCP range, as its two ends; null where there is none.
  (String, String)? get dhcpRange {
    final range = dhcpRanges.firstOrNull;
    if (range == null) return null;
    final at = range.indexOf('-');
    if (at < 0) return null;
    return (range.substring(0, at), range.substring(at + 1));
  }

}

/// One file in the chain a guest's disk is on: the file the guest writes to,
/// then its backing file, down to the base image.
///
/// An external snapshot (libvirt) puts a qcow2 overlay on the disk the guest
/// was using, so the guest ends up on a chain rather than on one file. `snap`
/// is the snapshot that left the guest on this layer, where one did: depth 1
/// is the base image, which no snapshot of the chain created.
@freezed
abstract class VirtSnapChainFile with _$VirtSnapChainFile {
  const factory VirtSnapChainFile({
    required String path,

    /// `qcow2`, `raw`, ...
    String? format,

    /// Bytes it takes on the host.
    int? allocation,

    /// The layer below it; null for the base image.
    String? backing,

    /// The snapshot this layer belongs to, where one does.
    String? snap,

    /// The file the guest is on now.
    @Default(false) bool active,
  }) = _VirtSnapChainFile;

  const VirtSnapChainFile._();

  /// What the file is called, without its directory.
  String get name => path.split('/').last;
}

/// One disk of a guest and the chain of files it is on, topmost first.
@freezed
abstract class VirtSnapChainDisk with _$VirtSnapChainDisk {
  const factory VirtSnapChainDisk({
    required String target,

    /// Topmost first: `files.first` is what the guest writes to now.
    @Default(<VirtSnapChainFile>[]) List<VirtSnapChainFile> files,

    /// The pool whose directory holds the topmost file, where one does.
    String? pool,

    /// Why the host could not read the disk's chain, in its words.
    String? error,
  }) = _VirtSnapChainDisk;

  const VirtSnapChainDisk._();

  /// Whether the disk is on an overlay: a file with a backing one. An
  /// external snapshot puts it there, and so does a thin clone of a base
  /// image, which has no snapshot at all — whether the guest has external
  /// snapshots is the list's to say (`VirtGuestSnapshot.external`).
  bool get isChain => files.length > 1;
}

/// The chain every disk of a guest is on, and why it cannot be read when it
/// cannot.
@freezed
abstract class VirtSnapChain with _$VirtSnapChain {
  const factory VirtSnapChain({
    @Default(<VirtSnapChainDisk>[]) List<VirtSnapChainDisk> disks,

    /// Why no snapshot at all can be taken: a disk known not to be qcow2.
    String? refusal,

    /// Why an external snapshot cannot be taken, asked of the host's own
    /// read: everything [refusal] says, and a disk whose chain could not be
    /// read or cannot be trusted.
    String? externalRefusal,

    /// The pools an overlay can be placed in, by name: active pools that
    /// hold files in a directory (`virtPoolHoldsFiles`).
    @Default(<String>[]) List<String> pools,
  }) = _VirtSnapChain;

  const VirtSnapChain._();

  /// The deepest chain any disk is on: 1 is a plain image.
  int get depth =>
      disks.map((d) => d.files.length).fold(1, (a, b) => a > b ? a : b);

  /// Some disk is on an overlay.
  bool get hasOverlays => disks.any((d) => d.isChain);
}

/// What a libvirt snapshot can be: an internal one, or an external (disk-only
/// while the guest runs) one, which puts every disk on a chain.
enum VirtSnapshotForm {
  /// Inside the image: the guest stops being written to while it is made,
  /// and an active guest's memory goes with it.
  internal,

  /// A qcow2 overlay on each disk: the guest keeps running, the memory is
  /// left alone, and the guest ends up on a chain.
  external,
}

/// Why an external snapshot cannot be taken here, for the form to say before
/// the host is asked.
enum VirtExternalIssue {
  /// The guest has no disk (or none QEMU would open).
  noDisk,

  /// A disk is raw: an external snapshot needs a qcow2 image under it.
  rawDisk,

  /// The chain could not be read, so nothing is known about it.
  unknown,
}

/// Whether a volume of [pool] can be resized on its host
/// (`sbm_virt::resource::volume_resizable`).
bool virtVolumeResizable(VirtStoragePool pool, VirtHostKind host) =>
    res.virtVolumeResizable(
      poolJson: jsonEncode(VirtRust.poolJson(pool)),
      pve: host == VirtHostKind.pve,
    );

/// An active pool of files: where an overlay can go
/// (`sbm_virt::libvirt::host::pool_holds_files`).
bool virtPoolHoldsFiles(VirtStoragePool pool) =>
    ffi.virtLibvirtPoolHoldsFiles(pool: virtPoolRef(pool));

/// The libvirt pool of files whose directory holds [file] itself, or null.
VirtStoragePool? virtPoolOfFile(Iterable<VirtStoragePool> pools, String file) {
  final name = ffi.virtLibvirtPoolOfFile(
    pools: [for (final p in pools) virtPoolRef(p)],
    file: file,
  );
  return pools.firstWhereOrNull((p) => p.name == name);
}

/// [pool] as `sbm_virt` reads a libvirt pool.
ffi.LibvirtPoolRef virtPoolRef(VirtStoragePool pool) => ffi.LibvirtPoolRef(
  name: pool.name,
  poolType: pool.type,
  active: pool.active,
  target: pool.path,
);

/// Why a snapshot cannot be taken, from what the host answered about its
/// storage, in the host's own words; null when one can.
///
/// [supported] is `false` only where the host said so (PVE's own
/// `feature?feature=snapshot`, which its web UI asks before offering the
/// button). A storage that does not support snapshots is the usual reason: a
/// disk on a `dir` storage is a raw file, and PVE snapshots need qcow2.
String? virtSnapshotSupportIssue({
  required bool? supported,
  required VirtGuest guest,
  required Iterable<String> storageNames,
}) {
  if (supported != false) return null;
  final where = storageNames.isEmpty ? '' : ' (${storageNames.join(', ')})';
  return '${guest.name}$where';
}

/// Whether a disk on a storage of [content] kinds can be snapshotted on PVE.
///
/// PVE has no `snapshot` content kind: `content` lists what may be *stored*
/// (`images`, `rootdir`, `iso`, ...), and snapshot support follows the
/// storage's type and the disk's format instead — a `dir` storage holds raw
/// files, an `lvmthin` or `zfspool` one makes a snapshot per volume. So this
/// is a hint for the form, never a refusal: the host's own answer
/// (`snapshotSupported`) is what decides.
bool virtPveStorageMaySnapshot(String type) =>
    type == 'lvmthin' || type == 'zfspool' || type == 'rbd' || type == 'btrfs';

/// What one difference between a snapshot's configuration and the guest's
/// current one is about, as the view groups it.
enum VirtSnapDiffGroup {
  cpu,
  memory,
  disks,
  nics,
  firmware,
  boot,
  other,
}

/// One difference between a snapshot's configuration and the guest's current
/// one. Values are as the host writes them (`262144`, `e1000e · bridge=vmbr0`
/// or `local-lvm:vm-900-disk-0,size=8G`), for the view to show with a label.
@freezed
abstract class VirtSnapDiff with _$VirtSnapDiff {
  const factory VirtSnapDiff({
    required VirtSnapDiffGroup group,

    /// The configuration key, e.g. `vcpu`, `scsi0`, `net0`.
    required String key,

    /// What the snapshot has.
    String? before,

    /// What the guest has now.
    String? after,
  }) = _VirtSnapDiff;

  const VirtSnapDiff._();

  /// The value left the configuration since the snapshot.
  bool get removed => before != null && after == null;

  /// The value is new since the snapshot.
  bool get added => before == null && after != null;
}
