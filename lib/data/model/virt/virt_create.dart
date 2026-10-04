import 'dart:convert';

import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/data/model/virt/virt.dart';
import 'package:server_box/data/model/virt/virt_resources.dart';
import 'package:server_box/data/model/virt/virt_rust.dart';
import 'package:server_box/src/rust/api/create.dart' as ffi;
import 'package:server_box/src/rust/api/pve.dart' show PveError;

/// A volume, with the pool it is listed in: a PVE volid is the same on every
/// node that sees its storage, a libvirt volume name on every pool.
typedef VirtPoolVolume = ({VirtStoragePool pool, VirtVolume volume});

/// A guest to create. Checked with [virtCreateIssue] before it is sent, and
/// by `sbm_virt` again against what the host lists then.
///
/// [storage], [media], [image] and [network] are what the host listed
/// ([virtDiskStorages], [virtMediaStorages], [virtImageStorages],
/// [virtCreateNetworks]); they cross by id (`sbm_virt::create::CreateSpec`).
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
    this.secureBoot = false,
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
  final VirtPoolVolume? media;

  /// A cloud image the VM's disk is a copy of, grown to [diskGiB]: a disk
  /// with a system on it already, set up at its first boot by [cloudInit].
  /// Never with [media].
  final VirtPoolVolume? image;

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

  /// A VM booting from UEFI, with Secure Boot or without it, and with a
  /// TPM 2.0. Secure Boot is only offered where the host's firmware
  /// descriptors can back it ([VirtCreateOptions.secureBoot]).
  final bool uefi;
  final bool secureBoot;
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
    this.searchDomains = const [],
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

  /// The search domains, in order; empty for none. cloud-init takes a list
  /// and `resolv.conf` keeps the first few.
  final List<String> searchDomains;

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
    this.secureBoot = false,
    this.tpm = false,
    this.cloudImages = false,
    this.cloudInit = false,
    this.cloudInitMissing,
  });

  /// What [spec] asks for, as if offered: for a check made before the
  /// host's own options are read, which `sbm_virt` checks again.
  factory VirtCreateOptions.asked(VirtCreateSpec spec) => VirtCreateOptions(
    buses: [?spec.bus],
    nicModels: [?spec.nicModel],
    uefi: spec.uefi,
    secureBoot: spec.secureBoot,
    tpm: spec.tpm,
    cloudImages: true,
    cloudInit: true,
  );

  /// Disk buses, the default first.
  final List<String> buses;

  /// NIC models, the default first.
  final List<String> nicModels;

  /// UEFI firmware is installed (libvirt: OVMF), and a software TPM (swtpm).
  final bool uefi;
  final bool tpm;

  /// Secure Boot can be turned on: the host has a firmware that carries its
  /// enrolled keys. libvirt: a descriptor under `/usr/share/qemu/firmware`
  /// with both `secure-boot` and `enrolled-keys`
  /// (`<feature enabled='yes' name='enrolled-keys'/>` needs exactly that, or
  /// libvirt autoselection finds no firmware and refuses the definition).
  /// PVE: `efidisk0` with `pre-enrolled-keys=1`, which its own UEFI default
  /// writes.
  final bool secureBoot;

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
    this.searchDomains = const [],
    this.nics = 0,
    this.passwordSet = false,
    this.passwordExpires = false,
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

  /// The search domains, in order.
  final List<String> searchDomains;

  /// How many NICs the seed configures. More than one is read; the view
  /// edits the first and says how many there are.
  final int nics;

  /// The account has a password.
  final bool passwordSet;

  /// The password expires at the first login (cloud-init's `chpasswd:
  /// expire: true`). Always false on PVE, which writes `expire: false` and
  /// has no option for it.
  final bool passwordExpires;

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
  const VirtCloudInitEdit(
    this.values, {
    this.removePassword = false,
    this.passwordExpires = false,
  });

  final VirtCloudInit values;
  final bool removePassword;

  /// The account's password expires at the first login (cloud-init's
  /// `chpasswd: expire: true`). libvirt only: PVE has no such option.
  final bool passwordExpires;
}

/// Why a [VirtCreateSpec] cannot be sent, as `sbm_virt::create::Issue`
/// names it. First wins; see [virtCreateIssue].
enum VirtCreateIssue {
  nameEmpty,
  nameInvalid,
  nameTaken,
  vmidInvalid,
  vmidTaken,

  /// PVE: the node is not one of the host's online nodes.
  node,
  cores,
  memory,
  storage,
  diskSize,
  template,

  /// A VM's install media that is not on offer.
  media,
  credentials,
  password,
  sshKeys,

  /// A cloud image not picked, not one, or bigger than the disk asked for.
  image,
  imageSize,

  /// The network is not one a new NIC can be on.
  network,

  /// Secure Boot asked for without UEFI.
  secureBoot,

  /// A bus, a NIC model, UEFI, a TPM, a cloud image or cloud-init the host
  /// does not offer.
  notOffered,

  /// cloud-init: the account's name, its way in, the hostname, the address.
  ciUser,
  ciCredentials,
  ciHostname,
  ciAddress,
  ciGateway,
  ciDns,
  ciSearch,

  /// A clone: a linked one cannot name a storage or a node; a storage that
  /// is not there, holds no images, or is not shared while the copy moves to
  /// another node; a target node the host does not have.
  cloneLinkedTarget,
  cloneStorage,
  cloneStorageContent,
  cloneStorageShared,
  cloneNodeUnknown,

  /// Only a stopped guest is deleted, made a template, or (libvirt) copied.
  notStopped,
  isTemplate,
  notFound,
  unsupported;

  /// The issue `sbm_virt` names (`name_taken`).
  static VirtCreateIssue? ofRust(String? name) => switch (name) {
    null => null,
    _ => values.firstWhere(
      (i) => i.name == name.replaceAllMapped(RegExp('_([a-z])'), (m) => m[1]!.toUpperCase()),
      orElse: () => unsupported,
    ),
  };
}

/// What a [VirtCreateIssue] says where no field says it: a refusal's
/// message, a toast. [pve] picks the host's name rule.
String? virtCreateIssueText(VirtCreateIssue? issue, {bool pve = false}) => switch (issue) {
  null => null,
  VirtCreateIssue.nameEmpty => l10n.virtResNameEmpty,
  VirtCreateIssue.nameInvalid ||
  VirtCreateIssue.ciHostname ||
  VirtCreateIssue.ciSearch => pve ? l10n.virtCreateNameInvalidPve : l10n.virtCreateNameInvalidLibvirt,
  VirtCreateIssue.nameTaken => l10n.virtCreateNameTaken,
  VirtCreateIssue.vmidInvalid => l10n.virtCreateVmidInvalid,
  VirtCreateIssue.vmidTaken => l10n.virtCreateVmidTaken,
  VirtCreateIssue.node => l10n.virtCreateNodeOffline,
  VirtCreateIssue.cores => l10n.virtCreateCoresInvalid,
  VirtCreateIssue.memory => l10n.virtCreateMemoryInvalid,
  VirtCreateIssue.storage => l10n.virtCreateStorageMissing,
  VirtCreateIssue.diskSize => l10n.virtCreateDiskInvalid,
  VirtCreateIssue.template => l10n.virtCreateTemplateMissing,
  VirtCreateIssue.media => l10n.virtCreateMediaMissing,
  VirtCreateIssue.credentials => l10n.virtCreateCredentialsMissing,
  VirtCreateIssue.password => l10n.virtCreatePasswordShort(virtLxcPasswordMin),
  VirtCreateIssue.sshKeys => l10n.virtCreateSshKeysInvalid,
  VirtCreateIssue.image => l10n.virtCreateImageMissing,
  VirtCreateIssue.imageSize => l10n.virtCreateImageBigger,
  VirtCreateIssue.network => l10n.virtCreateNetworkMissing,
  VirtCreateIssue.secureBoot => l10n.virtCreateSecureBootNeedsUefi,
  VirtCreateIssue.notOffered => l10n.virtCreateNotOffered,
  VirtCreateIssue.ciUser => l10n.virtCiUserInvalid,
  VirtCreateIssue.ciCredentials => l10n.virtCiCredentialsMissing,
  VirtCreateIssue.ciAddress => l10n.virtCiAddressInvalid,
  VirtCreateIssue.ciGateway => l10n.virtCiGatewayInvalid,
  VirtCreateIssue.ciDns => l10n.virtCiDnsInvalid,
  VirtCreateIssue.cloneLinkedTarget => l10n.virtCloneLinkedTarget,
  VirtCreateIssue.cloneStorage => l10n.virtCloneStorageMissing,
  VirtCreateIssue.cloneStorageContent => l10n.virtCloneStorageContent,
  VirtCreateIssue.cloneStorageShared => l10n.virtCloneStorageShared,
  VirtCreateIssue.cloneNodeUnknown => l10n.virtCloneNodeUnknown,
  VirtCreateIssue.notStopped => l10n.virtGuestNotStopped,
  VirtCreateIssue.isTemplate => l10n.virtGuestIsTemplate,
  VirtCreateIssue.notFound => l10n.virtResNotFound,
  VirtCreateIssue.unsupported => l10n.virtResUnsupported,
};

/// PVE's own floor for a container's root password.
const virtLxcPasswordMin = 5;

/// VMIDs PVE accepts.
const virtVmidMin = 100;
const virtVmidMax = 999999999;

String _json(Object? v) => jsonEncode(v);

/// Why [spec] cannot be created on [host], whose guests are [guests]; null
/// when it can. [nodes], [pools] and [networks] are the host's; [options]
/// what it offers a new VM (null: everything, for a check that has not
/// read them). The volumes [spec] names are its own.
VirtCreateIssue? virtCreateIssue(
  VirtCreateSpec spec, {
  required VirtHostKind host,
  required List<VirtGuest> guests,
  List<VirtNode> nodes = const [],
  List<VirtStoragePool>? pools,
  List<VirtNetwork>? networks,
  VirtCreateOptions? options,
}) {
  try {
    return VirtCreateIssue.ofRust(
      ffi.virtCreateIssue(
        specJson: _json(VirtRust.specJson(spec)),
        pve: host == VirtHostKind.pve,
        guestsJson: _json([for (final g in guests) VirtRust.guestJson(g)]),
        nodesJson: _json([
          for (final n in nodes.isEmpty && spec.node != null ? [VirtNode(name: spec.node!)] : nodes)
            VirtRust.nodeJson(n),
        ]),
        poolsJson: _json([
          for (final p in pools ?? {spec.storage, ?spec.media?.pool, ?spec.image?.pool}) VirtRust.poolJson(p),
        ]),
        networksJson: _json([
          for (final n in networks ?? [?spec.network]) VirtRust.networkJson(n),
        ]),
        mediaJson: switch (spec.media) {
          final m? => _json(VirtRust.volumeJson(m.volume)),
          null => null,
        },
        imageJson: switch (spec.image) {
          final i? => _json(VirtRust.volumeJson(i.volume)),
          null => null,
        },
        optionsJson: _json(VirtRust.createOptionsJson(options ?? VirtCreateOptions.asked(spec))),
      ),
    );
  } on PveError {
    return VirtCreateIssue.unsupported;
  }
}

/// Why [ci] cannot be sent; null when it can. Checked where a cloud image
/// is created ([virtCreateIssue]) and edited ([virtCloudInitEditIssue]);
/// the host checks it again. [keepsPassword]: the account has a password
/// already, which stays.
VirtCreateIssue? virtCloudInitIssue(
  VirtCloudInit ci, {
  required VirtHostKind host,
  bool keepsPassword = false,
}) => VirtCreateIssue.ofRust(
  ffi.virtCloudInitIssue(
    ciJson: _json(VirtRust.cloudInitJson(ci)),
    pve: host == VirtHostKind.pve,
    keepsPassword: keepsPassword,
  ),
);

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

List<VirtStoragePool> _byIds(List<VirtStoragePool> pools, List<String> ids) => [
  for (final p in pools)
    if (ids.contains(p.id)) p,
];

String _poolsJson(List<VirtStoragePool> pools) => _json([for (final p in pools) VirtRust.poolJson(p)]);

/// Where cloud images are found on [host] ([node] for PVE): a PVE storage
/// with `import` content (what `import-from` takes, PVE 8.2+); every active
/// libvirt pool.
List<VirtStoragePool> virtImageStorages(
  List<VirtStoragePool> pools, {
  required VirtHostKind host,
  String? node,
}) => _byIds(
  pools,
  ffi.virtImageStorages(poolsJson: _poolsJson(pools), pve: host == VirtHostKind.pve, node: node),
);

/// Whether [volume] is a disk image a new VM can be a copy of.
bool virtIsCloudImage(VirtVolume volume, VirtHostKind host) => ffi.virtIsCloudImage(
  volumeJson: _json(VirtRust.volumeJson(volume)),
  pve: host == VirtHostKind.pve,
);

/// Where a new [kind] guest's disk can go on [host] ([node] for PVE).
List<VirtStoragePool> virtDiskStorages(
  List<VirtStoragePool> pools, {
  required VirtHostKind host,
  required VirtGuestKind kind,
  String? node,
}) => _byIds(
  pools,
  ffi.virtDiskStorages(
    poolsJson: _poolsJson(pools),
    pve: host == VirtHostKind.pve,
    lxc: kind == VirtGuestKind.lxc,
    node: node,
  ),
);

/// Where install media ([kind] VM: ISOs) or templates (container) can be
/// found on [host] ([node] for PVE).
List<VirtStoragePool> virtMediaStorages(
  List<VirtStoragePool> pools, {
  required VirtHostKind host,
  required VirtGuestKind kind,
  String? node,
}) => _byIds(
  pools,
  ffi.virtMediaStorages(
    poolsJson: _poolsJson(pools),
    pve: host == VirtHostKind.pve,
    lxc: kind == VirtGuestKind.lxc,
    node: node,
  ),
);

/// Whether [volume] is install media ([kind] VM) or a template (container).
bool virtIsMedia(VirtVolume volume, VirtGuestKind kind) => ffi.virtIsMedia(
  volumeJson: _json(VirtRust.volumeJson(volume)),
  lxc: kind == VirtGuestKind.lxc,
);

/// The networks a new guest's NIC can be on: libvirt's active networks, a
/// PVE node's bridges.
List<VirtNetwork> virtCreateNetworks(
  List<VirtNetwork> networks, {
  required VirtHostKind host,
  String? node,
}) {
  final ids = ffi.virtCreateNetworks(
    networksJson: _json([for (final n in networks) VirtRust.networkJson(n)]),
    pve: host == VirtHostKind.pve,
    node: node,
  );
  return [
    for (final n in networks)
      if (ids.contains(n.id)) n,
  ];
}

/// The image format a libvirt pool of [type] takes: qcow2 (thin, snapshots)
/// where it can.
String virtLibvirtDiskFormat(String type) => ffi.virtLibvirtDiskFormat(poolType: type);

/// A copy of a guest (the Settings view's Clone group).
final class VirtCloneRequest {
  const VirtCloneRequest({
    required this.name,
    this.full = true,
    this.vmid,
    this.storage,
    this.targetNode,
    this.targetPool,
  });

  /// A VM's name, a container's hostname: the same rules as a new guest's.
  final String name;

  /// PVE: a full clone, or a linked one sharing the template's disks
  /// (templates only). libvirt: each disk's contents copied, or an empty
  /// disk of the same size — the design's "copy disk contents".
  final bool full;

  /// PVE: the new guest's VMID (`/cluster/nextid` when null).
  final int? vmid;

  /// PVE: where the copy's disks go (`storage`), null for the storages the
  /// source's are on. A linked clone cannot name one (PVE refuses it).
  final String? storage;

  /// PVE: the node the copy is made on (`target`), null for the source's.
  /// Needs a cluster and shared storage.
  final String? targetNode;

  /// libvirt: the pool the copy's disks go in, null for each disk's own.
  final String? targetPool;
}

/// Why a clone cannot go to [storage] on [targetNode], or null: the checks
/// PVE makes before it starts the clone task (`sbm_virt::create`).
/// [storages] are the source node's.
VirtCreateIssue? virtCloneStorageIssue({
  required Iterable<VirtStoragePool> storages,
  required String? storage,
  required bool full,
  VirtGuestKind kind = VirtGuestKind.qemu,
  String? targetNode,
}) => VirtCreateIssue.ofRust(
  ffi.virtCloneStorageIssue(
    storagesJson: _poolsJson(storages.toList()),
    storage: storage,
    full: full,
    lxc: kind == VirtGuestKind.lxc,
    targetNode: targetNode,
  ),
);

/// Why [targetNode] cannot be a clone's node, or null.
VirtCreateIssue? virtCloneNodeIssue({
  required Iterable<VirtNode> nodes,
  required String? targetNode,
  required String? sourceNode,
}) => VirtCreateIssue.ofRust(
  ffi.virtCloneNodeIssue(
    nodesJson: _json([for (final n in nodes) VirtRust.nodeJson(n)]),
    targetNode: targetNode,
    sourceNode: sourceNode,
  ),
);

/// Why [name] cannot be a clone's name on a host of [kind], or null. Taken
/// names are the caller's to check: it has the host's guests.
VirtCreateIssue? virtCloneNameIssue(String name, VirtHostKind? kind) {
  if (name.isEmpty) return VirtCreateIssue.nameEmpty;
  return ffi.virtGuestNameOk(name: name, pve: kind == VirtHostKind.pve)
      ? null
      : VirtCreateIssue.nameInvalid;
}
