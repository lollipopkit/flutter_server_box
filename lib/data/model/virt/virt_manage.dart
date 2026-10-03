import 'dart:convert';

import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/data/model/virt/virt.dart';
import 'package:server_box/data/model/virt/virt_resources.dart';
import 'package:server_box/data/model/virt/virt_rust.dart';
import 'package:server_box/src/rust/api/pve.dart' show PveError;
import 'package:server_box/src/rust/api/resource.dart' as ffi;

/// One change to a host's storage or networks (the Storage and Network
/// sections). Checked with [virtResourceIssue] before it is sent; made by
/// `VirtBackend.manage`.
///
/// libvirt: pools, volumes and networks through `virsh`
/// (`sbm_virt::libvirt::manage`). PVE: storages (`/storage`), volumes
/// (`/nodes/{node}/storage/{id}/content`) and Linux bridges
/// (`/nodes/{node}/network`), whose changes wait in
/// `/etc/network/interfaces.new` until applied ([VirtNetworkApply]).
sealed class VirtResourceChange {
  const VirtResourceChange();

  /// What the change is to, for "one change per thing at a time":
  /// `pool:<id>`, `net:<id>`, or the host's pools / networks as a whole.
  String get scope;

  /// PVE: the node whose network configuration this changes, as
  /// [netNodeScope]; null otherwise. Every such change waits on the others
  /// on that node, besides [scope]: Apply and Revert take all of the node's
  /// pending configuration at once, so an edit made while one runs would be
  /// applied unchecked or thrown away.
  String? get nodeScope => null;

  /// [nodeScope] of a change to [node]'s networks.
  static String netNodeScope(String node) => 'netnode:$node';
}

/// A new pool (libvirt) or storage (PVE).
final class VirtPoolCreate extends VirtResourceChange {
  const VirtPoolCreate({
    required this.name,
    required this.type,
    required this.source,
    this.target,
    this.node,
    this.content = const [],
    this.autostart = true,
  });

  final String name;

  /// One of `VirtCapabilities.poolTypes`.
  final String type;

  /// What the type is made from: a directory (`dir`), `host:/export`
  /// (`netfs`, `nfs`), a volume group (`logical`), `vg/thinpool`
  /// (`lvmthin`), a ZFS pool or dataset (`zfspool`).
  final String source;

  /// libvirt `netfs`: where it is mounted.
  final String? target;

  /// PVE: the node it is made on and limited to. A storage is cluster-wide
  /// configuration; this keeps a local one where it is.
  final String? node;

  /// PVE: what it holds (`images`, `rootdir`, `iso`, `vztmpl`, `backup`).
  /// Empty for the type's own default.
  final List<String> content;

  /// libvirt: started with the host.
  final bool autostart;

  @override
  String get scope => 'pools';
}

/// libvirt: started (`pool-start`) or stopped (`pool-destroy`). PVE: enabled
/// or disabled in the storage configuration.
final class VirtPoolSetActive extends VirtResourceChange {
  const VirtPoolSetActive(this.pool, {required this.active});

  final VirtStoragePool pool;
  final bool active;

  @override
  String get scope => 'pool:${pool.id}';
}

final class VirtPoolSetAutostart extends VirtResourceChange {
  const VirtPoolSetAutostart(this.pool, {required this.on});

  final VirtStoragePool pool;
  final bool on;

  @override
  String get scope => 'pool:${pool.id}';
}

/// libvirt `pool-refresh`: files put in its directory by other means appear.
final class VirtPoolRefresh extends VirtResourceChange {
  const VirtPoolRefresh(this.pool);

  final VirtStoragePool pool;

  @override
  String get scope => 'pool:${pool.id}';
}

/// Removes the pool's definition; its volumes stay where they are. With
/// [deleteStorage] (libvirt, `VirtCapabilities.poolDeleteStorage`) what it is
/// on goes too: `pool-delete` removes an empty directory, never contents.
final class VirtPoolDelete extends VirtResourceChange {
  const VirtPoolDelete(this.pool, {this.deleteStorage = false});

  final VirtStoragePool pool;
  final bool deleteStorage;

  @override
  String get scope => 'pool:${pool.id}';
}

final class VirtVolumeCreate extends VirtResourceChange {
  const VirtVolumeCreate(
    this.pool, {
    required this.name,
    required this.gib,
    required this.format,
  });

  final VirtStoragePool pool;

  /// As typed: PVE's own rule is `vm-<vmid>-…`, and a file-based storage's
  /// name gets the format as its extension ([virtVolumeFileName]).
  final String name;
  final int gib;

  /// One of [virtVolumeFormats].
  final String format;

  @override
  String get scope => 'pool:${pool.id}';
}

/// Deletes a volume and its contents. Refused before it is sent while a
/// guest uses it ([VirtResIssue.inUse]).
final class VirtVolumeDelete extends VirtResourceChange {
  const VirtVolumeDelete(this.pool, this.volume);

  final VirtStoragePool pool;
  final VirtVolume volume;

  @override
  String get scope => 'pool:${pool.id}';
}

/// Grows a volume that no running guest has open (libvirt `vol-resize`); a
/// guest's disk grows through its Hardware view instead.
final class VirtVolumeResize extends VirtResourceChange {
  const VirtVolumeResize(this.pool, this.volume, {required this.bytes});

  final VirtStoragePool pool;
  final VirtVolume volume;
  final int bytes;

  @override
  String get scope => 'pool:${pool.id}';
}

/// Copies a volume within its pool (libvirt `vol-clone`).
final class VirtVolumeClone extends VirtResourceChange {
  const VirtVolumeClone(this.pool, this.volume, {required this.name});

  final VirtStoragePool pool;
  final VirtVolume volume;
  final String name;

  @override
  String get scope => 'pool:${pool.id}';
}

/// A new network: a libvirt virtual network, or a PVE Linux bridge (pending
/// until applied).
final class VirtNetworkCreate extends VirtResourceChange {
  const VirtNetworkCreate({
    required this.name,
    required this.mode,
    this.node,
    this.bridge,
    this.cidr,
    this.dhcpStart,
    this.dhcpEnd,
    this.vlanAware = false,
    this.autostart = true,
  });

  final String name;

  /// One of `VirtCapabilities.networkModes`.
  final String mode;

  /// PVE: the node the bridge is made on.
  final String? node;

  /// libvirt `bridge` mode: the host bridge guests are handed to. PVE: the
  /// bridge's ports, space-separated; empty for a bridge of its own.
  final String? bridge;

  /// The host's address with its prefix, e.g. `192.168.150.1/24`. libvirt:
  /// required for NAT and routed, optional for isolated. PVE: optional.
  final String? cidr;

  /// libvirt: the DHCP range dnsmasq serves; both or neither.
  final String? dhcpStart;
  final String? dhcpEnd;

  /// PVE `bridge_vlan_aware`.
  final bool vlanAware;

  /// libvirt: started with the host. PVE: `auto` in the interfaces file.
  final bool autostart;

  @override
  String get scope => 'nets';

  @override
  String? get nodeScope => switch (node) {
    final node? => VirtResourceChange.netNodeScope(node),
    null => null,
  };
}

/// What an existing network is edited to (phase 10).
///
/// libvirt: mode, host bridge, IPv4 address and prefix, the DHCP range and
/// the static hosts, written into the definition by `net-define`. The
/// running network takes it at its next start unless [restart], which stops
/// and starts it — and cuts off every guest on it meanwhile.
final class VirtNetworkEdit extends VirtResourceChange {
  const VirtNetworkEdit(
    this.network, {
    required this.mode,
    this.bridge,
    this.address,
    this.prefix,
    this.dhcpStart,
    this.dhcpEnd,
    this.hosts = const [],
    this.restart = false,
  });

  final VirtNetwork network;

  /// One of `VirtCapabilities.networkModes`.
  final String mode;

  /// `bridge` mode: the host bridge guests are handed to.
  final String? bridge;

  /// The host's address on it, without its prefix; null for an isolated
  /// network without one.
  final String? address;
  final int? prefix;
  final String? dhcpStart;
  final String? dhcpEnd;

  /// The static DHCP entries the network ends up with.
  final List<VirtNetHost> hosts;

  /// Stop and start the network so the running one takes the change.
  final bool restart;

  @override
  String get scope => 'net:${network.id}';

  @override
  String? get nodeScope => switch (network.node) {
    final node? => VirtResourceChange.netNodeScope(node),
    null => null,
  };
}

/// PVE: writes [bridge]'s configuration (`PUT /nodes/{node}/network/{iface}`)
/// into the node's pending one; applied with [VirtNetworkApply].
///
/// Only a bridge PVE made and the app may edit: a physical interface, and
/// any interface carrying the address the app is connected to, is refused
/// before this is built ([virtPveManagedIface]).
final class VirtNetworkEditBridge extends VirtResourceChange {
  const VirtNetworkEditBridge(
    this.network, {
    this.ports,
    this.cidr,
    this.gateway,
    this.vlanAware,
    this.autostart,
  });

  final VirtNetwork network;

  /// Space-separated ports; null keeps them, empty clears them.
  final String? ports;

  /// `a.b.c.d/prefix`; null keeps the address, empty clears it.
  final String? cidr;
  final String? gateway;
  final bool? vlanAware;
  final bool? autostart;

  @override
  String get scope => 'net:${network.id}';

  @override
  String? get nodeScope => switch (network.node) {
    final node? => VirtResourceChange.netNodeScope(node),
    null => null,
  };
}

/// libvirt: stops (`net-destroy`) and starts (`net-start`) the network, so
/// its definition applies to the running one. Asked for, never automatic:
/// the guests on it lose their link meanwhile.
final class VirtNetworkRestart extends VirtResourceChange {
  const VirtNetworkRestart(this.network);

  final VirtNetwork network;

  @override
  String get scope => 'net:${network.id}';

  @override
  String? get nodeScope => switch (network.node) {
    final node? => VirtResourceChange.netNodeScope(node),
    null => null,
  };
}

final class VirtNetworkSetActive extends VirtResourceChange {
  const VirtNetworkSetActive(this.network, {required this.active});

  final VirtNetwork network;
  final bool active;

  @override
  String get scope => 'net:${network.id}';

  @override
  String? get nodeScope => switch (network.node) {
    final node? => VirtResourceChange.netNodeScope(node),
    null => null,
  };
}

final class VirtNetworkSetAutostart extends VirtResourceChange {
  const VirtNetworkSetAutostart(this.network, {required this.on});

  final VirtNetwork network;
  final bool on;

  @override
  String get scope => 'net:${network.id}';

  @override
  String? get nodeScope => switch (network.node) {
    final node? => VirtResourceChange.netNodeScope(node),
    null => null,
  };
}

/// libvirt: stopped when active, undefined. PVE: the bridge removed from the
/// pending configuration, gone once applied.
final class VirtNetworkDelete extends VirtResourceChange {
  const VirtNetworkDelete(this.network);

  final VirtNetwork network;

  @override
  String get scope => 'net:${network.id}';

  @override
  String? get nodeScope => switch (network.node) {
    final node? => VirtResourceChange.netNodeScope(node),
    null => null,
  };
}

/// PVE: makes [node]'s pending network configuration the running one
/// (`PUT /nodes/{node}/network`, `ifreload -a`).
final class VirtNetworkApply extends VirtResourceChange {
  const VirtNetworkApply(this.node);

  final String node;

  @override
  String get scope => 'nets';

  @override
  String get nodeScope => VirtResourceChange.netNodeScope(node);
}

/// PVE: drops [node]'s pending network configuration.
final class VirtNetworkRevert extends VirtResourceChange {
  const VirtNetworkRevert(this.node);

  final String node;

  @override
  String get scope => 'nets';

  @override
  String get nodeScope => VirtResourceChange.netNodeScope(node);
}

/// A file from this device going into [pool] as [name].
final class VirtUpload {
  const VirtUpload({
    required this.pool,
    required this.name,
    required this.size,
    required this.open,
    this.content = 'iso',
  });

  final VirtStoragePool pool;
  final String name;

  /// Bytes: the volume is made this size, and progress counts against it.
  final int size;

  /// The file's bytes, from the start. Called once per attempt.
  final Stream<List<int>> Function() open;

  /// PVE: `iso` or `vztmpl`.
  final String content;
}

/// A node's network configuration waiting to be applied (PVE): the diff of
/// `/etc/network/interfaces` against `interfaces.new`, as PVE shows it.
final class VirtNetworkChanges {
  const VirtNetworkChanges({required this.node, required this.diff});

  final String node;
  final String diff;
}

/// Why a change cannot be sent (`sbm_virt::resource::Issue`). First wins;
/// see [virtResourceIssue].
enum VirtResIssue {
  nameEmpty,

  /// Not a name the host takes; the view says which characters are.
  nameInvalid,
  nameTaken,

  /// A path that is not absolute, `host:/export` that is not one, a volume
  /// group or ZFS pool name that is not one.
  sourceInvalid,

  /// A netfs mount point that is not an absolute path.
  targetInvalid,

  /// Not `a.b.c.d/prefix` with a usable host address.
  cidrInvalid,

  /// Outside the network, reversed, or covering the host's own address.
  dhcpInvalid,

  /// Another network of the host's is on an overlapping subnet.
  subnetTaken,

  /// libvirt bridge mode without a host bridge, or ports that are not
  /// interface names.
  bridgeInvalid,
  size,

  /// More than the pool has free.
  space,
  format,

  /// A guest uses it: the volume, the pool's volumes, the network.
  inUse,

  /// Only a new size larger than the volume's.
  shrink,

  /// A static DHCP entry with a MAC, an address or a name the host would
  /// refuse, or two entries for one MAC.
  hostInvalid,

  /// The interface carries the address this app is connected to, or the
  /// node's default route: editing it would cut the host off.
  managementIface,

  /// The pool, volume or network is no longer on the host.
  notFound,

  /// Not something this kind of host does.
  unsupported;

  /// The issue `sbm_virt` names (`in_use`).
  static VirtResIssue? ofRust(String? name) => switch (name) {
    null => null,
    _ => values.firstWhere(
      (i) => i.name == name.replaceAllMapped(RegExp('_([a-z])'), (m) => m[1]!.toUpperCase()),
      orElse: () => unsupported,
    ),
  };
}

/// What a [VirtResIssue] says, for a field's error line or a toast.
String? virtResIssueText(VirtResIssue? issue) => switch (issue) {
  null => null,
  VirtResIssue.nameEmpty => l10n.virtResNameEmpty,
  VirtResIssue.nameInvalid => l10n.virtResNameInvalid,
  VirtResIssue.nameTaken => l10n.virtCreateNameTaken,
  VirtResIssue.sourceInvalid => l10n.virtResSourceInvalid,
  VirtResIssue.targetInvalid => l10n.virtResTargetInvalid,
  VirtResIssue.cidrInvalid => l10n.virtResCidrInvalid,
  VirtResIssue.dhcpInvalid => l10n.virtResDhcpInvalid,
  VirtResIssue.subnetTaken => l10n.virtResSubnetTaken,
  VirtResIssue.bridgeInvalid => l10n.virtResBridgeInvalid,
  VirtResIssue.size => l10n.virtHwIssueDiskSize,
  VirtResIssue.space => l10n.virtHwIssueStorageSpace,
  VirtResIssue.format => l10n.virtResFormat,
  VirtResIssue.inUse => l10n.virtVolInUse,
  VirtResIssue.shrink => l10n.virtHwIssueDiskShrink,
  VirtResIssue.hostInvalid => l10n.virtNetHostInvalid,
  VirtResIssue.managementIface => l10n.virtNetManagementIface,
  VirtResIssue.notFound => l10n.virtResNotFound,
  VirtResIssue.unsupported => l10n.virtResUnsupported,
};

String _json(Object? value) => jsonEncode(value);

/// Why [change] cannot be made on a host of [host]
/// (`sbm_virt::resource::issue`); null when it can. [pools] and [networks]
/// are the host's, [volumes] the pool's the change is to; what the change
/// itself names is counted among them.
VirtResIssue? virtResourceIssue(
  VirtResourceChange change, {
  required VirtHostKind host,
  List<VirtStoragePool> pools = const [],
  List<VirtNetwork> networks = const [],
  List<VirtVolume> volumes = const [],
}) {
  final (pool, volume, network) = switch (change) {
    VirtPoolSetActive(:final pool) ||
    VirtPoolSetAutostart(:final pool) ||
    VirtPoolRefresh(:final pool) ||
    VirtPoolDelete(:final pool) ||
    VirtVolumeCreate(:final pool) => (pool, null, null),
    VirtVolumeDelete(:final pool, :final volume) ||
    VirtVolumeResize(:final pool, :final volume) ||
    VirtVolumeClone(:final pool, :final volume) => (pool, volume, null),
    VirtNetworkEdit(:final network) ||
    VirtNetworkEditBridge(:final network) ||
    VirtNetworkRestart(:final network) ||
    VirtNetworkSetActive(:final network) ||
    VirtNetworkSetAutostart(:final network) ||
    VirtNetworkDelete(:final network) => (null, null, network),
    _ => (null, null, null),
  };
  final allPools = [
    ...pools,
    if (pool != null && !pools.any((p) => p.id == pool.id)) pool,
  ];
  final allVolumes = [
    ...volumes,
    if (volume != null && !volumes.any((v) => v.id == volume.id)) volume,
  ];
  final allNetworks = [
    ...networks,
    if (network != null && !networks.any((n) => n.id == network.id)) network,
  ];
  try {
    return VirtResIssue.ofRust(
      ffi.virtResourceIssue(
        changeJson: _json(VirtRust.changeJson(change)),
        pve: host == VirtHostKind.pve,
        poolsJson: _json([for (final p in allPools) VirtRust.poolJson(p)]),
        networksJson: _json([for (final n in allNetworks) VirtRust.networkJson(n)]),
        volumesJson: _json([for (final v in allVolumes) VirtRust.volumeJson(v)]),
      ),
    );
  } on PveError {
    return VirtResIssue.unsupported;
  }
}

/// Why an upload of [name] into [pool] cannot start; null when it can.
VirtResIssue? virtUploadIssue(
  VirtStoragePool pool,
  String name,
  int size, {
  List<VirtVolume> volumes = const [],
}) => VirtResIssue.ofRust(
  ffi.virtUploadIssue(
    poolJson: _json(VirtRust.poolJson(pool)),
    name: name,
    size: BigInt.from(size < 0 ? 0 : size),
    volumesJson: _json([for (final v in volumes) VirtRust.volumeJson(v)]),
  ),
);

/// Whether [pool] takes uploads of install media.
bool virtPoolTakesMedia(VirtStoragePool pool) =>
    ffi.virtPoolTakesMedia(poolJson: _json(VirtRust.poolJson(pool)));

/// The formats a new volume in [pool] can have, the first the default.
List<String> virtVolumeFormats(VirtStoragePool pool) =>
    ffi.virtVolumeFormats(poolJson: _json(VirtRust.poolJson(pool)));

/// PVE: the name a new volume is given, with the format as its extension on
/// a file-based storage.
String virtVolumeFileName(VirtStoragePool pool, String name, String format) =>
    ffi.virtVolumeFileName(
      poolJson: _json(VirtRust.poolJson(pool)),
      name: name,
      format: format,
    );

/// The VMID a PVE volume name belongs to; null when it is not one.
int? virtPveVolumeVmid(String name) => ffi.virtPveVolumeVmid(name: name);

/// The DHCP range the form offers for [cidr]; null when it is not a usable
/// one.
(String, String)? virtDefaultDhcpRange(String cidr) =>
    switch (ffi.virtDefaultDhcpRange(cidr: cidr)) {
      [final a, final b] => (a, b),
      _ => null,
    };

/// An upload in flight: what it is and how far it has come.
final class VirtUploadProgress {
  const VirtUploadProgress({
    required this.name,
    required this.size,
    this.sent = 0,
  });

  final String name;
  final int size;
  final int sent;

  double get fraction => size <= 0 ? 0 : (sent / size).clamp(0, 1);

  VirtUploadProgress copyWith({int? sent}) =>
      VirtUploadProgress(name: name, size: size, sent: sent ?? this.sent);

  @override
  bool operator ==(Object other) =>
      other is VirtUploadProgress &&
      other.name == name &&
      other.size == size &&
      other.sent == sent;

  @override
  int get hashCode => Object.hash(name, size, sent);
}
