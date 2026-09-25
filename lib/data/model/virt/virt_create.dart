import 'package:server_box/data/model/virt/virt.dart';
import 'package:server_box/data/model/virt/virt_resources.dart';

/// A guest to create. Checked with [virtCreateIssue] before it is sent.
///
/// [storage], [media] and [network] are what the host listed
/// ([virtDiskStorages], [virtMediaStorages], [virtCreateNetworks]), so the
/// backend can name them as the host does: PVE's storage and volid, libvirt's
/// pool and the volume's path.
final class VirtCreateSpec {
  const VirtCreateSpec({
    required this.kind,
    required this.name,
    this.node,
    this.vmid,
    required this.cores,
    required this.memoryMiB,
    required this.storage,
    required this.diskGiB,
    this.media,
    this.network,
    this.password,
    this.sshKeys,
    this.unprivileged = true,
    this.start = false,
  });

  final VirtGuestKind kind;

  /// A VM's name, a container's hostname.
  final String name;

  /// PVE: the node it is created on, and its VMID.
  final String? node;
  final int? vmid;
  final int cores;
  final int memoryMiB;

  /// Where the disk (a container's root filesystem) is created.
  final VirtStoragePool storage;
  final int diskGiB;

  /// A VM's install media (an ISO), a container's template.
  final VirtVolume? media;

  /// The one NIC's network or bridge; null for none.
  final VirtNetwork? network;

  /// A container's root password or SSH public keys (one per line). Sent in
  /// the request body only, never logged.
  final String? password;
  final String? sshKeys;

  /// A container whose root is an unprivileged user on the host.
  final bool unprivileged;

  /// Started once created.
  final bool start;
}

/// What creating a guest came to.
final class VirtCreated {
  const VirtCreated({required this.id, this.startError});

  /// The new guest's [VirtGuest.id].
  final String id;

  /// Created, but it did not start: the host's words.
  final String? startError;
}

/// Why a [VirtCreateSpec] cannot be sent. First wins; see [virtCreateIssue].
enum VirtCreateIssue {
  nameEmpty,
  nameInvalid,
  nameTaken,
  vmidInvalid,
  vmidTaken,
  cores,
  memory,
  storage,
  diskSize,
  template,
  credentials,
  password,
  sshKeys,
}

/// libvirt: what AppArmor's `virt-aa-helper` accepts (a `"` in a domain name
/// makes it refuse to start the domain), what `vol-create-as` puts in its XML
/// unescaped (`&`, `<`), and what makes a file name: letters, digits, `.`,
/// `_`, `-`, not first a dot or dash.
final virtLibvirtNamePattern = RegExp(r'^[A-Za-z0-9][A-Za-z0-9._-]{0,62}$');

/// PVE: a DNS name (`pve-configid` `dns-name`), which is what a VM's name and
/// a container's hostname must be.
final virtPveNamePattern = RegExp(
  r'^(?=.{1,63}$)[A-Za-z0-9]([A-Za-z0-9-]*[A-Za-z0-9])?'
  r'(\.[A-Za-z0-9]([A-Za-z0-9-]*[A-Za-z0-9])?)*$',
);

/// An OpenSSH public key line.
final _sshKeyPattern = RegExp(
  r'^(ssh-(rsa|ed25519|dss)|ecdsa-sha2-nistp\d+|sk-(ssh-ed25519|ecdsa-sha2-nistp256)@openssh\.com) [A-Za-z0-9+/=]+( .*)?$',
);

/// PVE's own floor for a container's root password.
const virtLxcPasswordMin = 5;

/// VMIDs PVE accepts.
const virtVmidMin = 100;
const virtVmidMax = 999999999;

/// Why [spec] cannot be created on [host], whose guests are [guests]; null
/// when it can. [maxCores] is the host's limit where it says one.
VirtCreateIssue? virtCreateIssue(
  VirtCreateSpec spec, {
  required VirtHostKind host,
  required List<VirtGuest> guests,
  int? maxCores,
}) {
  final name = spec.name;
  if (name.isEmpty) return VirtCreateIssue.nameEmpty;
  final pattern = host == VirtHostKind.pve
      ? virtPveNamePattern
      : virtLibvirtNamePattern;
  if (!pattern.hasMatch(name)) return VirtCreateIssue.nameInvalid;
  // PVE lets two guests share a name; one list with two of a name is a
  // question nobody wants to answer later.
  if (guests.any((g) => g.name == name)) return VirtCreateIssue.nameTaken;
  if (host == VirtHostKind.pve) {
    final vmid = spec.vmid;
    if (vmid == null || vmid < virtVmidMin || vmid > virtVmidMax) {
      return VirtCreateIssue.vmidInvalid;
    }
    if (guests.any((g) => g.vmid == vmid)) return VirtCreateIssue.vmidTaken;
  }
  if (spec.cores < 1 || spec.cores > (maxCores ?? 512)) {
    return VirtCreateIssue.cores;
  }
  final minMem = spec.kind == VirtGuestKind.lxc ? 64 : 128;
  if (spec.memoryMiB < minMem || spec.memoryMiB > 16 << 20) {
    return VirtCreateIssue.memory;
  }
  if (!spec.storage.active) return VirtCreateIssue.storage;
  if (spec.diskGiB < 1 || spec.diskGiB > 65536) return VirtCreateIssue.diskSize;
  if (spec.kind == VirtGuestKind.lxc) {
    if (spec.media == null) return VirtCreateIssue.template;
    final password = spec.password ?? '';
    final keys = (spec.sshKeys ?? '').trim();
    if (password.isEmpty && keys.isEmpty) return VirtCreateIssue.credentials;
    if (password.isNotEmpty && password.length < virtLxcPasswordMin) {
      return VirtCreateIssue.password;
    }
    if (keys.isNotEmpty &&
        !keys
            .split('\n')
            .map((l) => l.trim())
            .where((l) => l.isNotEmpty)
            .every(_sshKeyPattern.hasMatch)) {
      return VirtCreateIssue.sshKeys;
    }
  }
  return null;
}

/// libvirt pool types no disk image is created in: a whole device, iSCSI
/// LUNs, multipath and SCSI adapters hold volumes the host made, not ones
/// `vol-create-as` can.
const _libvirtNoCreate = {'disk', 'iscsi', 'iscsi-direct', 'scsi', 'mpath'};

/// libvirt pool types whose volumes are raw: block devices and datasets.
const _libvirtRawOnly = {'logical', 'zfs', 'rbd', 'vstorage'};

/// Where a new [kind] guest's disk can go on [host] ([node] for PVE).
List<VirtStoragePool> virtDiskStorages(
  List<VirtStoragePool> pools, {
  required VirtHostKind host,
  required VirtGuestKind kind,
  String? node,
}) => [
  for (final p in pools)
    if (p.active &&
        switch (host) {
          VirtHostKind.pve =>
            p.node == node &&
                p.enabled != false &&
                p.content.contains(
                  kind == VirtGuestKind.lxc ? 'rootdir' : 'images',
                ),
          VirtHostKind.libvirt => !_libvirtNoCreate.contains(p.type),
        })
      p,
];

/// Where install media ([kind] VM: ISOs) or templates (container) can be
/// found on [host] ([node] for PVE). libvirt keeps no content kinds: every
/// active pool is looked in, and [virtIsMedia] picks the ISOs.
List<VirtStoragePool> virtMediaStorages(
  List<VirtStoragePool> pools, {
  required VirtHostKind host,
  required VirtGuestKind kind,
  String? node,
}) => [
  for (final p in pools)
    if (p.active &&
        switch (host) {
          VirtHostKind.pve =>
            p.node == node &&
                p.enabled != false &&
                p.content.contains(kind == VirtGuestKind.lxc ? 'vztmpl' : 'iso'),
          VirtHostKind.libvirt => true,
        })
      p,
];

/// Whether [volume] is install media ([kind] VM) or a template (container).
bool virtIsMedia(VirtVolume volume, VirtGuestKind kind) {
  final content = volume.content;
  if (content != null) {
    return content == (kind == VirtGuestKind.lxc ? 'vztmpl' : 'iso');
  }
  if (kind == VirtGuestKind.lxc) return false;
  return volume.format == 'iso' || volume.name.toLowerCase().endsWith('.iso');
}

/// The networks a new guest's NIC can be on: libvirt's active networks, a
/// PVE node's bridges.
List<VirtNetwork> virtCreateNetworks(
  List<VirtNetwork> networks, {
  required VirtHostKind host,
  String? node,
}) => [
  for (final n in networks)
    if (n.active &&
        switch (host) {
          VirtHostKind.pve =>
            n.node == node && (n.mode == 'bridge' || n.mode == 'OVSBridge'),
          VirtHostKind.libvirt => n.mode != 'hostdev',
        })
      n,
];

/// The image format a libvirt pool of [type] takes: qcow2 (thin, snapshots)
/// where it can.
String virtLibvirtDiskFormat(String type) =>
    _libvirtRawOnly.contains(type) ? 'raw' : 'qcow2';
