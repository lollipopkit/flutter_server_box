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

  /// A static DHCP entry with a MAC, an address or a name the host would
  /// refuse, or two entries for one MAC.
  hostInvalid,

  /// The interface carries the address this app is connected to, or the
  /// node's default route: editing it would cut the host off.
  managementIface,
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

/// A dnsmasq host name: what libvirt writes into a static entry's `name`.
final _hostName = RegExp(r'^[A-Za-z0-9_][A-Za-z0-9_-]{0,62}$');

/// PVE: whether [network] may be edited and applied by this app at all.
///
/// A physical interface's own settings are the host's, not the app's: the
/// app manages bridges. And **no interface carrying the management address**
/// may be touched — the one the app is connected to, or the one the node's
/// default route goes through — because applying its configuration would cut
/// the host off, and there is nobody at the console to fix it.
bool virtPveManagedIface(VirtNetwork network, {Set<String> management = const {}}) {
  if (network.node == null) return false;
  if (network.mode != 'bridge') return false;
  return !management.contains(network.name);
}

/// The script [virtPveParseLiveNet] reads: what the node itself says of the
/// interfaces it is using right now — addresses, default routes, the local
/// address of every established TCP connection, and which device sits on
/// which (`/sys/class/net/*/lower_*`: a VLAN on its parent, a bridge on its
/// ports, a bond on its slaves), and the interfaces file as it is — what a
/// pending diff's line numbers count in. All of it readable without root.
///
/// `@end` only when every command that decides what is protected succeeded:
/// an empty `ss` or `ip` answer from a failed command would read as "no
/// connection, no route" and protect nothing. The IPv6 route is the one
/// allowed to fail (a kernel without IPv6).
const virtPveLiveNetScript = r'''
ok=1
echo "@host $(hostname)"
echo '@addr'; ip -o addr show 2>/dev/null || ok=
echo '@route'; ip -o route show default 2>/dev/null || ok=; ip -o -6 route show default 2>/dev/null
echo '@conn'; ss -Htn state established 2>/dev/null || ok=
echo '@lower'; for d in /sys/class/net/*; do n=${d##*/}; for l in "$d"/lower_*; do [ -e "$l" ] && printf '%s %s\n' "$n" "${l##*/lower_}"; done; done
echo '@file'; cat /etc/network/interfaces 2>/dev/null || ok=
[ -n "$ok" ] && echo '@end'
''';

/// What [virtPveLiveNetScript] printed.
final class VirtPveLiveNet {
  const VirtPveLiveNet({
    required this.host,
    required this.routed,
    required this.connected,
    required this.lower,
    this.interfaces = '',
  });

  /// The node it was read on (`hostname`, which is a PVE node's name): the
  /// only node this says anything about.
  final String host;

  /// The devices a default route (IPv4 or IPv6) goes through.
  final Set<String> routed;

  /// The devices carrying the local address of an established TCP
  /// connection — this app's among them, whatever it came through (SSH, the
  /// agent, a NAT in front of the node).
  final Set<String> connected;

  /// Each device's lower devices.
  final Map<String, Set<String>> lower;

  /// `/etc/network/interfaces` as it is now (not the pending `.new`).
  final String interfaces;
}

/// [virtPveLiveNetScript]'s output; null when it did not run to the end or
/// a command it needs failed — `@end` is then not its last line.
VirtPveLiveNet? virtPveParseLiveNet(String out) {
  final last = out.trimRight().split('\n').last.trim();
  if (last != '@end') return null;
  String? section;
  var host = '';
  final addrs = <String, String>{}; // address -> device
  final routed = <String>{};
  final local = <String>{};
  final lower = <String, Set<String>>{};
  final file = <String>[];
  String dev(String name) => name.split('@').first;
  String bare(String addr) {
    // `[::ffff:10.0.0.1]:22`, `10.0.0.1:22`, `[fe80::1%vmbr0]:22`
    var a = addr.trim();
    final port = a.lastIndexOf(':');
    if (port > 0) a = a.substring(0, port);
    a = a.replaceAll('[', '').replaceAll(']', '');
    final zone = a.indexOf('%');
    if (zone >= 0) a = a.substring(0, zone);
    if (a.startsWith('::ffff:') && a.contains('.')) a = a.substring(7);
    return a.toLowerCase();
  }

  for (final line in out.split('\n')) {
    final t = line.trim();
    if (section == '@file' && t != '@end') {
      file.add(line);
      continue;
    }
    if (t.startsWith('@host ')) {
      host = t.substring(6).trim();
      continue;
    }
    if (t.startsWith('@')) {
      section = t;
      continue;
    }
    if (t.isEmpty) continue;
    final w = t.split(RegExp(r'\s+'));
    switch (section) {
      case '@addr' when w.length >= 4 && (w[2] == 'inet' || w[2] == 'inet6'):
        addrs[w[3].split('/').first.toLowerCase()] = dev(w[1]);
      case '@route':
        final at = w.indexOf('dev');
        if (at >= 0 && at + 1 < w.length) routed.add(dev(w[at + 1]));
      case '@conn' when w.length >= 3:
        local.add(bare(w[2]));
      case '@lower' when w.length == 2:
        lower.putIfAbsent(w[0], () => {}).add(w[1]);
    }
  }
  final connected = {
    for (final a in local)
      if (addrs[a] case final d? when d != 'lo') d,
  };
  if (host.isEmpty) return null;
  return VirtPveLiveNet(
    host: host,
    routed: routed..remove('lo'),
    connected: connected,
    lower: lower,
    interfaces: file.join('\n'),
  );
}

/// PVE: the interfaces that carry a node's management traffic, and every
/// device they sit on — the ones an edit or an apply must not touch.
///
/// Where the node answered [live]: the devices its default routes go
/// through, and the ones carrying the local address of an established TCP
/// connection — this app's connection among them, whatever it came through
/// (SSH, the agent, a NAT or a VPN in front of the node), which a match on
/// the address the app dialled cannot see. Without it: every interface with
/// an address. Either way, every interface the listing gives a gateway
/// (`gateway`, and `gateway6` in [gateways6]) — the pending configuration's
/// default route.
///
/// Then down to what each sits on: a VLAN's parent (`vmbr0` under
/// `vmbr0.10`, where turning VLAN awareness off would cut it), a bridge's
/// ports, a bond's slaves — from the node's own `lower_*` links and from the
/// listing (`bridge_ports`, `vlan-raw-device`, a `name.N` VLAN).
///
/// [also]: interfaces known to carry it some other way — what the old side
/// of a pending diff gave an address or a gateway ([virtPveDiffIfaces]),
/// which the listing, being the pending configuration, no longer says.
Set<String> virtPveManagementIfaces(
  Iterable<VirtNetwork> networks, {
  VirtPveLiveNet? live,
  Set<String> gateways6 = const {},
  Set<String> also = const {},
}) {
  final seeds = <String>{
    ...gateways6,
    ...also,
    for (final n in networks)
      if (n.gateway?.isNotEmpty ?? false) n.name,
    if (live != null) ...live.routed,
    if (live != null) ...live.connected,
    if (live == null)
      for (final n in networks)
        if (n.cidrs.isNotEmpty) n.name,
  };
  final lower = <String, Set<String>>{
    for (final e in (live?.lower ?? const <String, Set<String>>{}).entries)
      e.key: {...e.value},
  };
  for (final n in networks) {
    final under = lower.putIfAbsent(n.name, () => {});
    under.addAll(n.ports);
    if (n.vlanDevice case final d? when d.isNotEmpty) under.add(d);
    final dot = n.name.lastIndexOf('.');
    if (dot > 0 && int.tryParse(n.name.substring(dot + 1)) != null) {
      under.add(n.name.substring(0, dot));
    }
  }
  final out = <String>{};
  final todo = [...seeds];
  while (todo.isNotEmpty) {
    final n = todo.removeLast();
    if (!out.add(n)) continue;
    todo.addAll(lower[n] ?? const {});
  }
  return out;
}

/// The interfaces a PVE pending-configuration diff (the network listing's
/// `changes`, a unified diff of `/etc/network/interfaces`) touches: the
/// stanza (`auto`/`iface`/`allow-*` line) each added or removed line is
/// under, and every interface an `auto`/`allow-*` line it adds or removes
/// names (`auto vmbr9 vmbr0` is both). A hunk that starts inside a stanza is
/// placed by its old line number in [interfaces] (the file as it is now);
/// without that, before any stanza, or under a file-wide directive
/// (`source`, `mapping`, ...) whose effect is no one interface's, [unknown]
/// says the diff does not tell whose lines they are.
///
/// The old side, for what the pending listing no longer says:
/// [oldAddressed] are the interfaces a removed line gave an address
/// (`address`, a `static`/`dhcp`/`auto` method), [oldGateways] the ones a
/// removed line gave a gateway — a management interface the pending
/// configuration strips is still one until it is applied.
({
  Set<String> ifaces,
  bool unknown,
  Set<String> oldAddressed,
  Set<String> oldGateways,
})
virtPveDiffIfaces(String diff, {String? interfaces}) {
  final hunk = RegExp(r'^@@ -(\d+)');
  final before = interfaces?.split('\n');
  final out = <String>{};
  final oldAddressed = <String>{};
  final oldGateways = <String>{};
  var unknown = false;
  String? current;
  for (final line in diff.split('\n')) {
    if (line.startsWith('---') || line.startsWith('+++')) continue;
    if (line.startsWith('@@')) {
      current = null;
      // The last stanza line above where the hunk starts in the old file.
      final from = int.tryParse(hunk.firstMatch(line)?[1] ?? '');
      if (before != null && from != null) {
        for (final l in before.take((from - 1).clamp(0, before.length))) {
          if (_ifupdownLine(l.trim()) case (final names, _)?) {
            current = names.length == 1 ? names.single : null;
          }
        }
      }
      continue;
    }
    if (line.isEmpty) continue;
    final mark = line[0];
    final body = line.substring(1).trim();
    final changed = mark == '+' || mark == '-';
    if (_ifupdownLine(body) case (final names, final iface)?) {
      // `auto a b` starts no stanza of its own: what follows is an
      // `iface` line's, or, before one, no one interface's.
      current = names.length == 1 ? names.single : null;
      if (changed) out.addAll(names);
      if (mark == '-' && iface && _addressedMethod.hasMatch(body)) {
        oldAddressed.addAll(names);
      }
      continue;
    }
    if (_globalDirective.hasMatch(body)) {
      // Not an interface's option: what it does, and to which, is not in
      // the diff.
      current = null;
      if (changed) unknown = true;
      continue;
    }
    if (!changed || body.isEmpty) continue;
    if (current != null) {
      // A `#` line is the stanza's too: PVE writes an interface's
      // `comments` as the lines after its own.
      out.add(current);
      if (mark == '-') {
        if (_addressOption.hasMatch(body)) oldAddressed.add(current);
        if (_gatewayOption.hasMatch(body)) oldGateways.add(current);
      }
    } else if (!body.startsWith('#')) {
      // A comment above every stanza is the file's header.
      unknown = true;
    }
  }
  return (
    ifaces: out,
    unknown: unknown,
    oldAddressed: oldAddressed,
    oldGateways: oldGateways,
  );
}

/// An `auto`/`allow-*` line's interfaces, or an `iface` line's one (and
/// whether it is that); null for any other line.
(List<String>, bool)? _ifupdownLine(String line) {
  final w = line.split(RegExp(r'\s+'));
  if (w.length < 2) return null;
  if (w[0] == 'iface') return ([w[1]], true);
  if (w[0] == 'auto' || w[0].startsWith('allow-')) return (w.sublist(1), false);
  return null;
}

/// ifupdown's file-wide directives: not an interface's options.
final _globalDirective = RegExp(
  r'^(?:source|source-directory|mapping|no-auto-down|no-scripts|rename)\b',
);

/// An `iface` line whose method gives the interface an address.
final _addressedMethod = RegExp(r'\binet6?\s+(?:static|dhcp|auto)\b');
final _addressOption = RegExp(r'^address6?\b');
final _gatewayOption = RegExp(r'^gateway6?\b');

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
      // A thin volume takes nothing yet — a qcow2 file, or anything in an
      // LVM thin pool, whose only format is raw; a raw file or a plain LV
      // takes it all.
      if (format == 'raw' &&
          pool.type != 'lvmthin' &&
          free != null &&
          gib * (1 << 30) > free) {
        return VirtResIssue.space;
      }
    case VirtVolumeDelete(:final volume):
      if (volume.inUse) return VirtResIssue.inUse;
    case VirtVolumeResize(:final volume, :final bytes):
      if (volume.users.isNotEmpty) return VirtResIssue.inUse;
      if (bytes <= (volume.capacity ?? 0)) return VirtResIssue.shrink;
      if (bytes > 1 << 50) return VirtResIssue.size;
    case VirtVolumeClone(:final name):
      if (name.isEmpty) return VirtResIssue.nameEmpty;
      if (!virtLibvirtVolumeName.hasMatch(name)) return VirtResIssue.nameInvalid;
      if (volumes.any((v) => v.name == name)) return VirtResIssue.nameTaken;
    case VirtPoolSetActive(:final active) when !active:
      if (volumes.any((v) => v.inUse)) return VirtResIssue.inUse;
    case VirtPoolDelete():
      if (volumes.any((v) => v.inUse)) return VirtResIssue.inUse;
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
      if (c.isEmpty) {
        if (needsIp) return VirtResIssue.cidrInvalid;
        // A DHCP range is served on the network's own subnet: with none,
        // the host refuses it.
        if (!pve && (dhcpStart != null || dhcpEnd != null)) {
          return VirtResIssue.dhcpInvalid;
        }
        return null;
      }
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
    case VirtNetworkEdit(
      :final network,
      :final mode,
      :final bridge,
      :final address,
      :final prefix,
      :final dhcpStart,
      :final dhcpEnd,
      :final hosts,
    ):
      final ifname = RegExp(r'^[A-Za-z0-9][A-Za-z0-9_.-]{0,14}$');
      if (!pve && mode == 'bridge') {
        if (!ifname.hasMatch(bridge?.trim() ?? '')) {
          return VirtResIssue.bridgeInvalid;
        }
      }
      // The address comes without its prefix (as the listing has it), the
      // prefix on its own: checked as the one CIDR they make.
      final bare = address?.trim() ?? '';
      final c = bare.isEmpty ? '' : '$bare/${prefix ?? ''}';
      (int, int)? subnet;
      if (!pve && mode != 'bridge') {
        if (c.isEmpty) {
          if (mode != 'isolated') return VirtResIssue.cidrInvalid;
          if (dhcpStart != null || dhcpEnd != null) {
            return VirtResIssue.dhcpInvalid;
          }
        } else {
          final parsed = virtParseCidr(c);
          if (parsed == null) return VirtResIssue.cidrInvalid;
          subnet = parsed;
          for (final n in networks) {
            // Its own subnet is not somebody else's.
            if (n.id == network.id) continue;
            if (n.cidrs.any((other) => _overlaps(other, c))) {
              return VirtResIssue.subnetTaken;
            }
          }
          if (dhcpStart != null || dhcpEnd != null) {
            final (addr, pfx) = parsed;
            final mask = _mask(pfx);
            final net = addr & mask;
            final broadcast = net | (~mask & 0xFFFFFFFF);
            final s2 = virtParseIpv4(dhcpStart ?? '');
            final e2 = virtParseIpv4(dhcpEnd ?? '');
            if (s2 == null ||
                e2 == null ||
                s2 > e2 ||
                s2 & mask != net ||
                e2 & mask != net ||
                s2 == net ||
                e2 == broadcast ||
                (addr >= s2 && addr <= e2)) {
              return VirtResIssue.dhcpInvalid;
            }
          }
        }
      }
      final macs = <String>{};
      final ips = <int>{};
      for (final h in hosts) {
        final ip = virtParseIpv4(h.ip);
        // Handed out on the network's own subnet, off its own addresses:
        // without one (or outside it) dnsmasq never serves it.
        final inSubnet = switch (subnet) {
          (final addr, final pfx) when ip != null =>
            ip & _mask(pfx) == addr & _mask(pfx) &&
                ip != addr &&
                ip != (addr & _mask(pfx)) &&
                ip != ((addr & _mask(pfx)) | (~_mask(pfx) & 0xFFFFFFFF)),
          _ => false,
        };
        if (!RegExp(r'^([0-9a-fA-F]{2}:){5}[0-9a-fA-F]{2}$').hasMatch(h.mac) ||
            ip == null ||
            (!pve && !inSubnet) ||
            !ips.add(ip) ||
            !macs.add(h.mac.toLowerCase()) ||
            switch (h.name) {
              final n? when n.isNotEmpty => !_hostName.hasMatch(n),
              _ => false,
            }) {
          return VirtResIssue.hostInvalid;
        }
      }
      if (hosts.isNotEmpty && !(pve || mode != 'bridge')) {
        // A bridge hands guests to the host's own network; it serves no
        // DHCP of its own.
        return VirtResIssue.hostInvalid;
      }
    case VirtNetworkEditBridge(:final cidr, :final gateway):
      final c = cidr?.trim();
      if (c != null && c.isNotEmpty && virtParseCidr(c) == null) {
        return VirtResIssue.cidrInvalid;
      }
      if (gateway != null && gateway.isNotEmpty && virtParseIpv4(gateway) == null) {
        return VirtResIssue.cidrInvalid;
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
        VirtNetworkRevert() ||
        VirtNetworkRestart():
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
