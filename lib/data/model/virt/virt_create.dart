import 'package:server_box/data/model/virt/virt.dart';
import 'package:server_box/data/model/virt/virt_resources.dart';

/// A guest to create. Checked with [virtCreateIssue] before it is sent.
///
/// [storage], [media], [image] and [network] are what the host listed
/// ([virtDiskStorages], [virtMediaStorages], [virtImageStorages],
/// [virtCreateNetworks]), so the backend can name them as the host does:
/// PVE's storage and volid, libvirt's pool and the volume's path.
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
    this.image,
    this.network,
    this.password,
    this.sshKeys,
    this.unprivileged = true,
    this.bus,
    this.nicModel,
    this.uefi = false,
    this.tpm = false,
    this.cloudInit,
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

  /// A cloud image the VM's disk is a copy of, grown to [diskGiB]: a disk
  /// with a system on it already, set up at its first boot by [cloudInit].
  /// Never with [media].
  final VirtVolume? image;

  /// The one NIC's network or bridge; null for none.
  final VirtNetwork? network;

  /// A container's root password or SSH public keys (one per line). Sent in
  /// the request body only, never logged.
  final String? password;
  final String? sshKeys;

  /// A container whose root is an unprivileged user on the host.
  final bool unprivileged;

  /// A VM's disk bus and NIC model ([VirtCreateOptions]); null for the
  /// backend's default (virtio; PVE's disk on SCSI).
  final String? bus;
  final String? nicModel;

  /// A VM booting from UEFI (Secure Boot off), and with a TPM 2.0.
  final bool uefi;
  final bool tpm;

  /// What a cloud [image] is told at its first boot.
  final VirtCloudInit? cloudInit;

  /// Started once created.
  final bool start;
}

/// What a new VM's cloud-init sets up: an account with sudo, how to log in
/// to it, the hostname and the one NIC's address.
final class VirtCloudInit {
  const VirtCloudInit({
    required this.user,
    this.password,
    this.sshKeys,
    this.hostname,
    this.address,
    this.gateway,
    this.dns = const [],
    this.searchDomain,
  });

  final String user;

  /// Never sent as it is to libvirt: hashed here (SHA-512 crypt) and only
  /// the hash written to the host. PVE takes it in the request body and
  /// hashes it itself. Never logged.
  final String? password;

  /// OpenSSH public keys, one per line.
  final String? sshKeys;

  /// libvirt; PVE's cloud-init uses the VM's name.
  final String? hostname;

  /// IPv4 with its prefix (`10.0.0.5/24`); null for DHCP.
  final String? address;
  final String? gateway;
  final List<String> dns;
  final String? searchDomain;

  List<String> get keys => [
    for (final l in (sshKeys ?? '').split('\n'))
      if (l.trim().isNotEmpty) l.trim(),
  ];

  @override
  String toString() =>
      'VirtCloudInit(user: $user, password: ${password == null ? null : '[redacted]'}, '
      'keys: ${keys.length}, hostname: $hostname, address: ${address ?? 'dhcp'})';
}

/// What a new VM on this host can be given, beyond what every host offers.
final class VirtCreateOptions {
  const VirtCreateOptions({
    this.buses = const [],
    this.nicModels = const [],
    this.uefi = false,
    this.tpm = false,
    this.cloudImages = false,
    this.cloudInit = false,
    this.cloudInitMissing,
  });

  /// Disk buses, the default first.
  final List<String> buses;

  /// NIC models, the default first.
  final List<String> nicModels;

  /// UEFI firmware is installed (libvirt: OVMF), and a software TPM (swtpm).
  final bool uefi;
  final bool tpm;

  /// A VM's disk can be a copy of a cloud image.
  final bool cloudImages;

  /// A cloud image can be set up with cloud-init; where not,
  /// [cloudInitMissing] says what the host lacks.
  final bool cloudInit;
  final String? cloudInitMissing;
}

/// What creating a guest came to.
final class VirtCreated {
  const VirtCreated({required this.id, this.startError, this.diskKeptBytes});

  /// The new guest's [VirtGuest.id].
  final String id;

  /// Created, but it did not start: the host's words.
  final String? startError;

  /// A cloud image bigger than the disk asked for: the disk is the image's
  /// size, this. A disk is grown, never cut — cutting it would cut the
  /// system on it.
  final int? diskKeptBytes;
}

/// A guest's cloud-init as it stands — what the Settings view's cloud-init
/// group shows and edits. Never the password: PVE answers it masked, and
/// libvirt's seed holds only its hash, which stays with the backend.
final class VirtCloudInitState {
  const VirtCloudInitState({
    required this.user,
    this.sshKeys = const [],
    this.hostname,
    this.address,
    this.gateway,
    this.dns = const [],
    this.searchDomain,
    this.passwordSet = false,
    this.network = false,
    this.foreign = false,
    required this.revision,
  });

  final String user;
  final List<String> sshKeys;

  /// libvirt: the seed's hostname. Null on PVE, whose cloud-init uses the
  /// VM's name (the Settings view's General group).
  final String? hostname;

  /// IPv4 with its prefix; null for DHCP.
  final String? address;
  final String? gateway;
  final List<String> dns;
  final String? searchDomain;

  /// The account has a password.
  final bool passwordSet;

  /// The guest has the NIC the address settings apply to: PVE's `net0`,
  /// on libvirt the NIC the seed's network config names (or the first).
  final bool network;

  /// libvirt: the seed says more than the app writes (packages, commands,
  /// another account); saving writes a seed of the app's own instead.
  final bool foreign;

  /// What an edit is made from: PVE's `digest`, the seed's checksum. An
  /// edit made from an older read is refused (`VirtErrType.conflict`).
  final String revision;

  @override
  String toString() =>
      'VirtCloudInitState(user: $user, keys: ${sshKeys.length}, hostname: $hostname, '
      'address: ${address ?? 'dhcp'}, passwordSet: $passwordSet, foreign: $foreign)';
}

/// A change to a guest's cloud-init: [values] as they are to be. Its
/// `password` is a new one, or null to keep the one set — unless
/// [removePassword], which leaves the account keys only.
final class VirtCloudInitEdit {
  const VirtCloudInitEdit(this.values, {this.removePassword = false});

  final VirtCloudInit values;
  final bool removePassword;
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

  /// A cloud image not picked, or bigger than the disk asked for.
  image,
  imageSize,

  /// cloud-init: the account's name, its way in, the hostname, the address.
  ciUser,
  ciCredentials,
  ciHostname,
  ciAddress,
  ciGateway,
  ciDns,
  ciSearch,
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
  if (spec.kind == VirtGuestKind.qemu) {
    final image = spec.image;
    if (spec.cloudInit != null && image == null) return VirtCreateIssue.image;
    // A copy is grown, never cut.
    final bytes = image?.capacity;
    if (bytes != null && bytes > spec.diskGiB * (1 << 30)) {
      return VirtCreateIssue.imageSize;
    }
    if (spec.cloudInit case final ci?) {
      if (virtCloudInitIssue(ci, host: host) case final i?) return i;
    }
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

/// A Linux account name as `useradd` takes it by default.
final virtUserNamePattern = RegExp(r'^[a-z_][a-z0-9_-]{0,31}$');

final _ipv4 = RegExp(
  r'^((25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)\.){3}(25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)$',
);

bool _isIp(String s) => _ipv4.hasMatch(s) || (s.contains(':') && Uri.tryParse('http://[$s]/') != null);

/// Why [ci] cannot be sent; null when it can. Checked where a cloud image
/// is created ([virtCreateIssue]) and edited ([virtCloudInitEditIssue]);
/// the host checks it again. [keepsPassword]: the account has a password
/// already, which stays.
VirtCreateIssue? virtCloudInitIssue(
  VirtCloudInit ci, {
  required VirtHostKind host,
  bool keepsPassword = false,
}) {
  if (!virtUserNamePattern.hasMatch(ci.user)) return VirtCreateIssue.ciUser;
  final password = ci.password ?? '';
  if (password.isEmpty && !keepsPassword && ci.keys.isEmpty) {
    return VirtCreateIssue.ciCredentials;
  }
  if (!ci.keys.every(_sshKeyPattern.hasMatch)) return VirtCreateIssue.sshKeys;
  if (host == VirtHostKind.libvirt &&
      !virtPveNamePattern.hasMatch(ci.hostname ?? '')) {
    return VirtCreateIssue.ciHostname;
  }
  final address = ci.address;
  if (address != null) {
    final (ip, prefix) = switch (address.split('/')) {
      [final a, final p] => (a, int.tryParse(p)),
      _ => ('', null),
    };
    if (!_ipv4.hasMatch(ip) || prefix == null || prefix < 1 || prefix > 32) {
      return VirtCreateIssue.ciAddress;
    }
    final gw = ci.gateway;
    if (gw != null && !_ipv4.hasMatch(gw)) return VirtCreateIssue.ciGateway;
  }
  if (!ci.dns.every(_isIp)) return VirtCreateIssue.ciDns;
  final search = ci.searchDomain;
  if (search != null && !virtPveNamePattern.hasMatch(search)) {
    return VirtCreateIssue.ciSearch;
  }
  return null;
}

/// Why [edit] cannot be made to [state]; null when it can. An account needs
/// a way in: a password (a new one, or the one set, kept) or a key.
VirtCreateIssue? virtCloudInitEditIssue(
  VirtCloudInitState state,
  VirtCloudInitEdit edit, {
  required VirtHostKind host,
}) => virtCloudInitIssue(
  edit.values,
  host: host,
  keepsPassword: state.passwordSet && !edit.removePassword,
);

/// Where cloud images are found on [host] ([node] for PVE): a PVE storage
/// with `import` content (what `import-from` takes, PVE 8.2+); every active
/// libvirt pool.
List<VirtStoragePool> virtImageStorages(
  List<VirtStoragePool> pools, {
  required VirtHostKind host,
  String? node,
}) => [
  for (final p in pools)
    if (p.active &&
        switch (host) {
          VirtHostKind.pve =>
            p.node == node && p.enabled != false && p.content.contains('import'),
          VirtHostKind.libvirt => true,
        })
      p,
];

/// Whether [volume] is a disk image a new VM can be a copy of: PVE's
/// `import` content in a format QEMU reads (not an OVA, which carries a
/// machine of its own); on libvirt a qcow2 or raw volume no guest uses — a
/// disk in use would be copied mid-write — and not an ISO.
bool virtIsCloudImage(VirtVolume volume, VirtHostKind host) {
  final format = volume.format;
  return switch (host) {
    VirtHostKind.pve =>
      volume.content == 'import' &&
          (format == 'qcow2' || format == 'raw' || format == 'vmdk'),
    VirtHostKind.libvirt =>
      (format == 'qcow2' || format == 'raw') &&
          volume.users.isEmpty &&
          !volume.name.toLowerCase().endsWith('.iso'),
  };
}

/// Disk buses and NIC models a new VM can have, the default first. libvirt
/// narrows the buses to what the machine type has (q35: no IDE).
const virtCreateBuses = ['virtio', 'scsi', 'sata', 'ide'];
const virtPveCreateBuses = ['scsi', 'virtio', 'sata', 'ide'];
const virtCreateNicModels = ['virtio', 'e1000e', 'e1000', 'rtl8139'];

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

/// A copy of a guest (the Settings view's Clone group).
final class VirtCloneRequest {
  const VirtCloneRequest({
    required this.name,
    this.full = true,
    this.vmid,
  });

  /// A VM's name, a container's hostname: the same rules as a new guest's.
  final String name;

  /// PVE: a full clone, or a linked one sharing the template's disks
  /// (templates only). libvirt: each disk's contents copied, or an empty
  /// disk of the same size — the design's "copy disk contents".
  final bool full;

  /// PVE: the new guest's VMID (`/cluster/nextid` when null).
  final int? vmid;
}

/// Why [name] cannot be a clone's name on a host of [kind], or null. Taken
/// names are the caller's to check: it has the host's guests.
VirtCreateIssue? virtCloneNameIssue(String name, VirtHostKind? kind) {
  if (name.isEmpty) return VirtCreateIssue.nameEmpty;
  final pattern = kind == VirtHostKind.pve
      ? virtPveNamePattern
      : virtLibvirtNamePattern;
  return pattern.hasMatch(name) ? null : VirtCreateIssue.nameInvalid;
}
