import 'package:server_box/data/model/virt/virt.dart';
import 'package:server_box/data/model/virt/virt_resources.dart';

/// One change to a host's storage or networks (the Storage and Network
/// sections). Checked with [virtResourceIssue] before it is sent; made by
/// `VirtBackend.manage`.
///
/// libvirt: pools, volumes and networks through `virsh`
/// (`sbm_parser::virt_manage`). PVE: storages (`/storage`), volumes
/// (`/nodes/{node}/storage/{id}/content`) and Linux bridges
/// (`/nodes/{node}/network`), whose changes wait in
/// `/etc/network/interfaces.new` until applied ([VirtNetworkApply]).
sealed class VirtResourceChange {
  const VirtResourceChange();

  /// What the change is to, for "one change per thing at a time":
  /// `pool:<id>`, `net:<id>`, or the host's pools / networks as a whole.
  String get scope;
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
}

final class VirtNetworkSetActive extends VirtResourceChange {
  const VirtNetworkSetActive(this.network, {required this.active});

  final VirtNetwork network;
  final bool active;

  @override
  String get scope => 'net:${network.id}';
}

final class VirtNetworkSetAutostart extends VirtResourceChange {
  const VirtNetworkSetAutostart(this.network, {required this.on});

  final VirtNetwork network;
  final bool on;

  @override
  String get scope => 'net:${network.id}';
}

/// libvirt: stopped when active, undefined. PVE: the bridge removed from the
/// pending configuration, gone once applied.
final class VirtNetworkDelete extends VirtResourceChange {
  const VirtNetworkDelete(this.network);

  final VirtNetwork network;

  @override
  String get scope => 'net:${network.id}';
}

/// PVE: makes [node]'s pending network configuration the running one
/// (`PUT /nodes/{node}/network`, `ifreload -a`).
final class VirtNetworkApply extends VirtResourceChange {
  const VirtNetworkApply(this.node);

  final String node;

  @override
  String get scope => 'nets';
}

/// PVE: drops [node]'s pending network configuration.
final class VirtNetworkRevert extends VirtResourceChange {
  const VirtNetworkRevert(this.node);

  final String node;

  @override
  String get scope => 'nets';
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

/// Why a change cannot be sent. First wins; see [virtResourceIssue].
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
}

/// libvirt pool and network names: what `sbm_parser::virt_manage` takes.
final virtLibvirtResourceName = RegExp(r'^[A-Za-z0-9][A-Za-z0-9._-]{0,63}$');

/// PVE storage ids (`pve-storage-id`).
final virtPveStorageId = RegExp(r'^[a-z][a-z0-9_.-]*[a-z0-9]$');

/// PVE interface names (`pve-iface`), within Linux's 15 characters.
final virtPveBridgeName = RegExp(r'^[A-Za-z][A-Za-z0-9_]{1,14}$');

/// libvirt volume names: a file name in a directory pool.
final virtLibvirtVolumeName = RegExp(r'^[A-Za-z0-9][A-Za-z0-9._+-]{0,199}$');

/// PVE volume names: `vm-<vmid>-…` or `base-<vmid>-…`.
final virtPveVolumeName = RegExp(r'^(vm|base)-(\d+)-[A-Za-z0-9._-]+$');

/// A file name an upload may take: a volume name, and on PVE what its
/// upload accepts (letters, digits, `.`, `_`, `-`, `+`).
final virtUploadName = RegExp(r'^[A-Za-z0-9][A-Za-z0-9._+-]{0,199}$');

/// libvirt pool types that take a qcow2 file; the rest hold raw only.
const _qcow2Types = {'dir', 'fs', 'netfs', 'nfs', 'cifs', 'glusterfs', 'btrfs'};

/// The formats a new volume in [pool] can have, the first the default: qcow2
/// where the pool is a file system, raw where its volumes are block devices
/// or datasets.
List<String> virtVolumeFormats(VirtStoragePool pool) =>
    _qcow2Types.contains(pool.type) ? const ['qcow2', 'raw'] : const ['raw'];

/// PVE: the name a new volume is given, with the format as its extension on
/// a file-based storage (PVE refuses one without it there).
String virtVolumeFileName(VirtStoragePool pool, String name, String format) {
  if (!_qcow2Types.contains(pool.type)) return name;
  final ext = '.$format';
  return name.endsWith(ext) ? name : '$name$ext';
}

/// The VMID a PVE volume name belongs to; null when it is not one.
int? virtPveVolumeVmid(String name) {
  final m = virtPveVolumeName.firstMatch(name);
  return m == null ? null : int.tryParse(m[2]!);
}

/// `a.b.c.d/prefix` as the address and the prefix; null when it is not one
/// with a host address that can be used (not the network's own, not its
/// broadcast, prefix 8..30).
(int address, int prefix)? virtParseCidr(String cidr) {
  final parts = cidr.trim().split('/');
  if (parts.length != 2) return null;
  final address = virtParseIpv4(parts[0]);
  final prefix = int.tryParse(parts[1]);
  if (address == null || prefix == null || prefix < 8 || prefix > 30) {
    return null;
  }
  final mask = _mask(prefix);
  final net = address & mask;
  if (address == net || address == (net | (~mask & 0xFFFFFFFF))) return null;
  return (address, prefix);
}

int? virtParseIpv4(String s) {
  final octets = s.trim().split('.');
  if (octets.length != 4) return null;
  var out = 0;
  for (final o in octets) {
    if (o.isEmpty || o.length > 3 || !RegExp(r'^\d+$').hasMatch(o)) {
      return null;
    }
    final n = int.parse(o);
    if (n > 255) return null;
    out = (out << 8) | n;
  }
  return out;
}

String virtFormatIpv4(int a) =>
    [24, 16, 8, 0].map((s) => (a >> s) & 0xFF).join('.');

int _mask(int prefix) => (0xFFFFFFFF << (32 - prefix)) & 0xFFFFFFFF;

/// The DHCP range the form offers for [cidr]: .100 to .200 of a /24, and
/// the same share of any other size — the design's default.
(String, String)? virtDefaultDhcpRange(String cidr) {
  final parsed = virtParseCidr(cidr);
  if (parsed == null) return null;
  final (address, prefix) = parsed;
  final mask = _mask(prefix);
  final net = address & mask;
  final size = (~mask & 0xFFFFFFFF) + 1;
  var start = net + (size * 100 ~/ 256).clamp(1, size - 2);
  var end = net + (size * 200 ~/ 256).clamp(1, size - 2);
  // Clear of the host's own address.
  if (address >= start && address <= end) {
    if (address - net < size ~/ 2) {
      start = address + 1;
    } else {
      end = address - 1;
    }
  }
  if (start > end) return null;
  return (virtFormatIpv4(start), virtFormatIpv4(end));
}

/// Whether two `a.b.c.d/prefix` subnets overlap.
bool _overlaps(String a, String b) {
  (int, int)? parse(String c) {
    final parts = c.trim().split('/');
    if (parts.length != 2) return null;
    final ip = virtParseIpv4(parts[0]);
    final p = int.tryParse(parts[1]);
    if (ip == null || p == null || p < 0 || p > 32) return null;
    return (ip, p);
  }

  final x = parse(a);
  final y = parse(b);
  if (x == null || y == null) return false;
  final prefix = x.$2 < y.$2 ? x.$2 : y.$2;
  final mask = prefix == 0 ? 0 : _mask(prefix);
  return (x.$1 & mask) == (y.$1 & mask);
}

/// Why [change] cannot be made on a host of [host]; null when it can.
/// [pools] and [networks] are the host's, for names and subnets taken.
VirtResIssue? virtResourceIssue(
  VirtResourceChange change, {
  required VirtHostKind host,
  List<VirtStoragePool> pools = const [],
  List<VirtNetwork> networks = const [],
  List<VirtVolume> volumes = const [],
}) {
  final pve = host == VirtHostKind.pve;
  bool absolute(String p) =>
      p.startsWith('/') &&
      p.length > 1 &&
      !p.split('/').contains('..') &&
      !p.runes.any((r) => r < 0x20);
  switch (change) {
    case VirtPoolCreate(:final name, :final type, :final source, :final target):
      if (name.isEmpty) return VirtResIssue.nameEmpty;
      if (!(pve ? virtPveStorageId : virtLibvirtResourceName).hasMatch(name)) {
        return VirtResIssue.nameInvalid;
      }
      // PVE storage ids are the cluster's; libvirt names are the host's.
      if (pools.any((p) => p.name == name)) return VirtResIssue.nameTaken;
      final token = RegExp(r'^[A-Za-z0-9][A-Za-z0-9+_.-]*$');
      final ok = switch (type) {
        'dir' => absolute(source),
        'netfs' || 'nfs' => RegExp(
          r'^[A-Za-z0-9.:\[\]-]+:/',
        ).hasMatch(source) && absolute(source.substring(source.indexOf(':/') + 1)),
        'logical' => token.hasMatch(source),
        'lvmthin' =>
          source.split('/').length == 2 && source.split('/').every(token.hasMatch),
        'zfspool' =>
          source.split('/').every(token.hasMatch) && !source.endsWith('/'),
        _ => false,
      };
      if (!ok) return VirtResIssue.sourceInvalid;
      if (type == 'netfs' && !absolute(target ?? '')) {
        return VirtResIssue.targetInvalid;
      }
    case VirtVolumeCreate(:final pool, :final name, :final gib, :final format):
      if (name.isEmpty) return VirtResIssue.nameEmpty;
      if (!(pve ? virtPveVolumeName : virtLibvirtVolumeName).hasMatch(name)) {
        return VirtResIssue.nameInvalid;
      }
      final file = pve ? virtVolumeFileName(pool, name, format) : name;
      if (volumes.any((v) => v.name == file || v.name == name)) {
        return VirtResIssue.nameTaken;
      }
      if (!virtVolumeFormats(pool).contains(format)) return VirtResIssue.format;
      if (gib < 1 || gib > 65536) return VirtResIssue.size;
      final free = pool.available;
      // A thin volume takes nothing yet; a raw file or LV takes it all.
      if (format == 'raw' && free != null && gib * (1 << 30) > free) {
        return VirtResIssue.space;
      }
    case VirtVolumeDelete(:final volume):
      if (volume.users.isNotEmpty) return VirtResIssue.inUse;
    case VirtVolumeResize(:final volume, :final bytes):
      if (volume.users.isNotEmpty) return VirtResIssue.inUse;
      if (bytes <= (volume.capacity ?? 0)) return VirtResIssue.shrink;
      if (bytes > 1 << 50) return VirtResIssue.size;
    case VirtVolumeClone(:final name):
      if (name.isEmpty) return VirtResIssue.nameEmpty;
      if (!virtLibvirtVolumeName.hasMatch(name)) return VirtResIssue.nameInvalid;
      if (volumes.any((v) => v.name == name)) return VirtResIssue.nameTaken;
    case VirtPoolSetActive(:final active) when !active:
      if (volumes.any((v) => v.users.isNotEmpty)) return VirtResIssue.inUse;
    case VirtPoolDelete():
      if (volumes.any((v) => v.users.isNotEmpty)) return VirtResIssue.inUse;
    case VirtNetworkCreate(
      :final name,
      :final mode,
      :final node,
      :final bridge,
      :final cidr,
      :final dhcpStart,
      :final dhcpEnd,
    ):
      if (name.isEmpty) return VirtResIssue.nameEmpty;
      if (!(pve ? virtPveBridgeName : virtLibvirtResourceName).hasMatch(name)) {
        return VirtResIssue.nameInvalid;
      }
      if (networks.any((n) => n.name == name && (!pve || n.node == node))) {
        return VirtResIssue.nameTaken;
      }
      final ifname = RegExp(r'^[A-Za-z0-9][A-Za-z0-9_.-]{0,14}$');
      final ports = (bridge ?? '').trim();
      if (!pve && mode == 'bridge') {
        return ifname.hasMatch(ports) ? null : VirtResIssue.bridgeInvalid;
      }
      if (pve && ports.isNotEmpty && !ports.split(RegExp(r'\s+')).every(ifname.hasMatch)) {
        return VirtResIssue.bridgeInvalid;
      }
      final c = cidr?.trim() ?? '';
      final needsIp = !pve && (mode == 'nat' || mode == 'route');
      if (c.isEmpty) return needsIp ? VirtResIssue.cidrInvalid : null;
      final parsed = virtParseCidr(c);
      if (parsed == null) return VirtResIssue.cidrInvalid;
      for (final n in networks) {
        if (pve && n.node != node) continue;
        if (n.cidrs.any((other) => _overlaps(other, c))) {
          return VirtResIssue.subnetTaken;
        }
      }
      if (pve || (dhcpStart == null && dhcpEnd == null)) return null;
      final (address, prefix) = parsed;
      final mask = _mask(prefix);
      final net = address & mask;
      final broadcast = net | (~mask & 0xFFFFFFFF);
      final s = virtParseIpv4(dhcpStart ?? '');
      final e = virtParseIpv4(dhcpEnd ?? '');
      if (s == null ||
          e == null ||
          s > e ||
          s & mask != net ||
          e & mask != net ||
          s == net ||
          e == broadcast ||
          (address >= s && address <= e)) {
        return VirtResIssue.dhcpInvalid;
      }
    case VirtNetworkDelete(:final network) ||
        VirtNetworkSetActive(:final network, active: false):
      if (network.users.isNotEmpty) return VirtResIssue.inUse;
    case VirtPoolSetActive() ||
        VirtPoolSetAutostart() ||
        VirtPoolRefresh() ||
        VirtNetworkSetActive() ||
        VirtNetworkSetAutostart() ||
        VirtNetworkApply() ||
        VirtNetworkRevert():
      break;
  }
  return null;
}

/// Why an upload of [name] into [pool] cannot start; null when it can.
VirtResIssue? virtUploadIssue(
  VirtStoragePool pool,
  String name,
  int size, {
  List<VirtVolume> volumes = const [],
}) {
  if (name.isEmpty) return VirtResIssue.nameEmpty;
  if (!virtUploadName.hasMatch(name)) return VirtResIssue.nameInvalid;
  if (volumes.any((v) => v.name == name)) return VirtResIssue.nameTaken;
  if (size <= 0) return VirtResIssue.size;
  final free = pool.available;
  if (free != null && size > free) return VirtResIssue.space;
  return null;
}

/// Whether [pool] takes uploads of install media: PVE by its content kinds
/// (`iso`, `vztmpl`); libvirt pools hold any file, and every active pool
/// whose volumes are files takes one.
bool virtPoolTakesMedia(VirtStoragePool pool) {
  if (!pool.active) return false;
  if (pool.node != null) {
    return pool.content.contains('iso') || pool.content.contains('vztmpl');
  }
  return !_libvirtDevicePools.contains(pool.type);
}

/// libvirt pools of whole devices or LUNs: nothing is created in them.
const _libvirtDevicePools = {'disk', 'iscsi', 'iscsi-direct', 'scsi', 'mpath'};

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
