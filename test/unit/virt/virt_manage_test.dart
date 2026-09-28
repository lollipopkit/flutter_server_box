/// Managing storage and networks: the rules a change is checked with before
/// it is sent (both backends), and `LibvirtBackend`'s side of it — the
/// `VirtResourceOp` JSON each change becomes, how the host's answers read,
/// and the streamed upload over a scripted byte channel: the sudo password
/// ahead of the file, the go line, a retry when sudo did not ask, a
/// cancelled or refused upload deleting its volume.
///
/// Scripts and parsers go through the real FFI: `cargo build -p sbm_ffi`
/// first.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/data/model/app/error.dart';
import 'package:server_box/data/model/server/server_exec.dart';
import 'package:server_box/data/model/virt/virt.dart';
import 'package:server_box/data/model/virt/virt_manage.dart';
import 'package:server_box/data/model/virt/virt_resources.dart';
import 'package:server_box/data/provider/virt/libvirt_backend.dart';
import 'package:server_box/src/rust/api/script.dart' as script;
import 'package:server_box/src/rust/api/virt.dart' as ffi;

import '../../helpers/rust_lib_helper.dart';

const _dir = VirtStoragePool(
  id: 'images',
  name: 'images',
  type: 'dir',
  path: '/var/lib/libvirt/images',
  available: 10 << 30,
);
const _lvm = VirtStoragePool(id: 'vg', name: 'vg', type: 'logical');
const _pveDir = VirtStoragePool(
  id: 'pve/local',
  name: 'local',
  node: 'pve',
  type: 'dir',
  content: ['iso', 'vztmpl', 'images'],
);

String _marker(String key) =>
    script.scriptSegmentMarker(key: key, custom: false);

String _section(String key, String body, [int rc = 0]) =>
    '${_marker(key)}\n$body\nSbVirtRc=$rc\n';

void main() {
  setUpAll(initRustLibForTest);

  group('rules', () {
    test('addresses: a usable host address, and a default DHCP range', () {
      expect(virtParseCidr('192.168.150.1/24'), isNotNull);
      for (final bad in [
        '192.168.150.0/24',
        '192.168.150.255/24',
        '192.168.150.1',
        '192.168.150.1/31',
        '192.168.150.1/7',
        '300.1.1.1/24',
        '1.2.3/24',
        '01.2.3.4.5/24',
      ]) {
        expect(virtParseCidr(bad), isNull, reason: bad);
      }
      expect(virtDefaultDhcpRange('192.168.150.1/24'), (
        '192.168.150.100',
        '192.168.150.200',
      ));
      // The host's own address is left out of it.
      expect(virtDefaultDhcpRange('10.0.0.150/24'), ('10.0.0.100', '10.0.0.149'));
      expect(virtDefaultDhcpRange('10.8.0.1/16'), ('10.8.100.0', '10.8.200.0'));
      expect(virtDefaultDhcpRange('bad'), isNull);
    });

    test('networks: names, modes, subnets taken, DHCP ranges', () {
      const existing = [
        VirtNetwork(
          id: 'default',
          name: 'default',
          mode: 'nat',
          cidrs: ['192.168.122.1/24'],
        ),
      ];
      VirtResIssue? issue(VirtResourceChange c) => virtResourceIssue(
        c,
        host: VirtHostKind.libvirt,
        networks: existing,
      );
      expect(
        issue(
          const VirtNetworkCreate(
            name: 'lab',
            mode: 'nat',
            cidr: '192.168.150.1/24',
            dhcpStart: '192.168.150.100',
            dhcpEnd: '192.168.150.200',
          ),
        ),
        isNull,
      );
      expect(issue(const VirtNetworkCreate(name: '', mode: 'nat')), VirtResIssue.nameEmpty);
      expect(
        issue(const VirtNetworkCreate(name: 'a b', mode: 'isolated')),
        VirtResIssue.nameInvalid,
      );
      expect(
        issue(const VirtNetworkCreate(name: 'default', mode: 'isolated')),
        VirtResIssue.nameTaken,
      );
      // NAT and routed need an address; isolated does not.
      expect(issue(const VirtNetworkCreate(name: 'n', mode: 'nat')), VirtResIssue.cidrInvalid);
      expect(issue(const VirtNetworkCreate(name: 'n', mode: 'isolated')), isNull);
      // ... but a DHCP range needs a subnet to be served on, on a new
      // network and an edited one alike.
      expect(
        issue(
          const VirtNetworkCreate(
            name: 'n',
            mode: 'isolated',
            dhcpStart: '10.0.0.2',
            dhcpEnd: '10.0.0.9',
          ),
        ),
        VirtResIssue.dhcpInvalid,
      );
      expect(
        issue(
          const VirtNetworkEdit(
            VirtNetwork(id: 'iso', name: 'iso', mode: 'isolated'),
            mode: 'isolated',
            dhcpStart: '10.0.0.2',
            dhcpEnd: '10.0.0.9',
          ),
        ),
        VirtResIssue.dhcpInvalid,
      );
      expect(
        issue(
          const VirtNetworkEdit(
            VirtNetwork(id: 'iso', name: 'iso', mode: 'isolated'),
            mode: 'isolated',
          ),
        ),
        isNull,
      );
      expect(
        issue(const VirtNetworkCreate(name: 'n', mode: 'route', cidr: '192.168.122.9/25')),
        VirtResIssue.subnetTaken,
      );
      expect(
        issue(
          const VirtNetworkCreate(
            name: 'n',
            mode: 'nat',
            cidr: '192.168.150.1/24',
            dhcpStart: '192.168.150.1',
            dhcpEnd: '192.168.150.9',
          ),
        ),
        VirtResIssue.dhcpInvalid,
      );
      expect(
        issue(
          const VirtNetworkCreate(
            name: 'n',
            mode: 'nat',
            cidr: '192.168.150.1/24',
            dhcpStart: '192.168.151.2',
            dhcpEnd: '192.168.151.9',
          ),
        ),
        VirtResIssue.dhcpInvalid,
      );
      // Bridge mode names a host bridge and takes no address.
      expect(issue(const VirtNetworkCreate(name: 'n', mode: 'bridge', bridge: 'br0')), isNull);
      expect(
        issue(const VirtNetworkCreate(name: 'n', mode: 'bridge', bridge: 'br0; id')),
        VirtResIssue.bridgeInvalid,
      );
      // PVE: a Linux bridge name, ports that are interfaces, per node.
      VirtResIssue? pve(VirtNetworkCreate c) => virtResourceIssue(
        c,
        host: VirtHostKind.pve,
        networks: const [
          VirtNetwork(id: 'pve/vmbr0', name: 'vmbr0', node: 'pve', mode: 'bridge'),
        ],
      );
      expect(pve(const VirtNetworkCreate(name: 'vmbr1', mode: 'bridge', node: 'pve')), isNull);
      expect(
        pve(const VirtNetworkCreate(name: 'vmbr0', mode: 'bridge', node: 'pve')),
        VirtResIssue.nameTaken,
      );
      expect(
        pve(const VirtNetworkCreate(name: 'vmbr0', mode: 'bridge', node: 'pve2')),
        isNull,
      );
      expect(
        pve(const VirtNetworkCreate(name: 'vm-br', mode: 'bridge', node: 'pve')),
        VirtResIssue.nameInvalid,
      );
      expect(
        pve(
          const VirtNetworkCreate(
            name: 'vmbr1',
            mode: 'bridge',
            node: 'pve',
            bridge: 'eno1 eno2',
          ),
        ),
        isNull,
      );
      expect(
        pve(
          const VirtNetworkCreate(
            name: 'vmbr1',
            mode: 'bridge',
            node: 'pve',
            bridge: r'eno1 $(id)',
          ),
        ),
        VirtResIssue.bridgeInvalid,
      );
    });

    test('pools: names per host, sources per type', () {
      VirtResIssue? lv(VirtPoolCreate c) => virtResourceIssue(
        c,
        host: VirtHostKind.libvirt,
        pools: const [_dir],
      );
      expect(lv(const VirtPoolCreate(name: 'p', type: 'dir', source: '/srv/p')), isNull);
      expect(
        lv(const VirtPoolCreate(name: 'images', type: 'dir', source: '/srv/p')),
        VirtResIssue.nameTaken,
      );
      expect(
        lv(const VirtPoolCreate(name: 'p', type: 'dir', source: 'srv/p')),
        VirtResIssue.sourceInvalid,
      );
      expect(
        lv(const VirtPoolCreate(name: 'p', type: 'dir', source: '/srv/../etc')),
        VirtResIssue.sourceInvalid,
      );
      expect(
        lv(
          const VirtPoolCreate(
            name: 'p',
            type: 'netfs',
            source: 'nas.lan:/export/vm',
            target: '/mnt/p',
          ),
        ),
        isNull,
      );
      expect(
        lv(const VirtPoolCreate(name: 'p', type: 'netfs', source: 'nas.lan:/export/vm')),
        VirtResIssue.targetInvalid,
      );
      expect(
        lv(const VirtPoolCreate(name: 'p', type: 'netfs', source: 'nas.lan/export')),
        VirtResIssue.sourceInvalid,
      );
      expect(lv(const VirtPoolCreate(name: 'p', type: 'logical', source: 'vg_data')), isNull);
      // PVE storage ids: lowercase, no trailing dash.
      VirtResIssue? pve(VirtPoolCreate c) =>
          virtResourceIssue(c, host: VirtHostKind.pve);
      expect(pve(const VirtPoolCreate(name: 'nfs-2', type: 'nfs', source: '10.0.0.5:/e')), isNull);
      expect(
        pve(const VirtPoolCreate(name: 'Nfs', type: 'nfs', source: '10.0.0.5:/e')),
        VirtResIssue.nameInvalid,
      );
      expect(pve(const VirtPoolCreate(name: 'thin', type: 'lvmthin', source: 'pve/data')), isNull);
      expect(
        pve(const VirtPoolCreate(name: 'thin', type: 'lvmthin', source: 'pve')),
        VirtResIssue.sourceInvalid,
      );
      expect(pve(const VirtPoolCreate(name: 'zp', type: 'zfspool', source: 'rpool/data')), isNull);
      expect(
        pve(const VirtPoolCreate(name: 'z', type: 'zfspool', source: 'rpool/data')),
        VirtResIssue.nameInvalid,
      );
    });

    test('volumes: names, formats, space, and what a guest uses', () {
      VirtResIssue? lv(VirtResourceChange c, {List<VirtVolume> volumes = const []}) =>
          virtResourceIssue(c, host: VirtHostKind.libvirt, volumes: volumes);
      expect(
        lv(const VirtVolumeCreate(_dir, name: 'data.qcow2', gib: 20, format: 'qcow2')),
        isNull,
      );
      expect(
        lv(const VirtVolumeCreate(_lvm, name: 'data', gib: 20, format: 'qcow2')),
        VirtResIssue.format,
      );
      // A raw volume takes its size now; qcow2 grows into it.
      expect(
        lv(const VirtVolumeCreate(_dir, name: 'big.img', gib: 20, format: 'raw')),
        VirtResIssue.space,
      );
      // So does anything in an LVM thin pool, raw as it is.
      const thin = VirtStoragePool(
        id: 'pve/local-lvm',
        name: 'local-lvm',
        node: 'pve',
        type: 'lvmthin',
        available: 10 << 30,
      );
      expect(
        virtResourceIssue(
          const VirtVolumeCreate(thin, name: 'vm-100-disk-5', gib: 20, format: 'raw'),
          host: VirtHostKind.pve,
        ),
        isNull,
      );
      expect(
        lv(
          const VirtVolumeCreate(_dir, name: 'a.qcow2', gib: 1, format: 'qcow2'),
          volumes: const [VirtVolume(id: 'a.qcow2', name: 'a.qcow2')],
        ),
        VirtResIssue.nameTaken,
      );
      expect(
        lv(const VirtVolumeCreate(_dir, name: '../x', gib: 1, format: 'qcow2')),
        VirtResIssue.nameInvalid,
      );
      const used = VirtVolume(
        id: 'a',
        name: 'a',
        capacity: 1 << 30,
        users: [VirtGuestRef(guestId: 'u', device: 'vda')],
      );
      expect(lv(const VirtVolumeDelete(_dir, used)), VirtResIssue.inUse);
      expect(lv(const VirtVolumeResize(_dir, used, bytes: 2 << 30)), VirtResIssue.inUse);
      const free = VirtVolume(id: 'b', name: 'b', capacity: 1 << 30);
      expect(lv(const VirtVolumeResize(_dir, free, bytes: 1 << 30)), VirtResIssue.shrink);
      expect(lv(const VirtVolumeResize(_dir, free, bytes: 2 << 30)), isNull);
      expect(lv(const VirtPoolDelete(_dir), volumes: const [used]), VirtResIssue.inUse);
      expect(lv(const VirtPoolSetActive(_dir, active: false), volumes: const [used]), VirtResIssue.inUse);
      expect(lv(const VirtPoolSetActive(_dir, active: true), volumes: const [used]), isNull);

      // PVE: vm-<VMID>-…, with the format as the extension on a directory.
      VirtResIssue? pve(VirtResourceChange c) =>
          virtResourceIssue(c, host: VirtHostKind.pve);
      expect(
        pve(const VirtVolumeCreate(_pveDir, name: 'vm-105-disk-0', gib: 4, format: 'qcow2')),
        isNull,
      );
      expect(
        pve(const VirtVolumeCreate(_pveDir, name: 'data', gib: 4, format: 'qcow2')),
        VirtResIssue.nameInvalid,
      );
      expect(virtVolumeFileName(_pveDir, 'vm-105-disk-0', 'qcow2'), 'vm-105-disk-0.qcow2');
      expect(virtVolumeFileName(_pveDir, 'vm-105-disk-0.raw', 'raw'), 'vm-105-disk-0.raw');
      expect(
        virtVolumeFileName(
          const VirtStoragePool(id: 'pve/l', name: 'l', node: 'pve', type: 'lvmthin'),
          'vm-105-disk-0',
          'raw',
        ),
        'vm-105-disk-0',
      );
      expect(virtPveVolumeVmid('vm-105-disk-0.qcow2'), 105);
      expect(virtPveVolumeVmid('debian.iso'), isNull);
    });

    test('uploads: a file name, room for it, and pools that take one', () {
      expect(virtUploadIssue(_dir, 'debian-13.1.0-amd64-netinst.iso', 1 << 20), isNull);
      expect(virtUploadIssue(_dir, 'a b.iso', 1), VirtResIssue.nameInvalid);
      expect(virtUploadIssue(_dir, '.hidden.iso', 1), VirtResIssue.nameInvalid);
      expect(virtUploadIssue(_dir, 'x.iso', 20 << 30), VirtResIssue.space);
      expect(
        virtUploadIssue(
          _dir,
          'x.iso',
          1,
          volumes: const [VirtVolume(id: 'x.iso', name: 'x.iso')],
        ),
        VirtResIssue.nameTaken,
      );
      expect(virtPoolTakesMedia(_dir), isTrue);
      expect(virtPoolTakesMedia(_lvm), isTrue);
      expect(
        virtPoolTakesMedia(const VirtStoragePool(id: 'd', name: 'd', type: 'disk')),
        isFalse,
      );
      expect(virtPoolTakesMedia(_pveDir), isTrue);
      expect(
        virtPoolTakesMedia(
          const VirtStoragePool(
            id: 'pve/lvm',
            name: 'lvm',
            node: 'pve',
            type: 'lvmthin',
            content: ['images'],
          ),
        ),
        isFalse,
      );
    });
  });

  group('a PVE interface', () {
    // The listing of the real PVE 9.2.2 host this was written against.
    const nets = [
      VirtNetwork(id: 'pve/nic0', name: 'nic0', node: 'pve', mode: 'eth', active: true),
      VirtNetwork(id: 'pve/wlp5s0', name: 'wlp5s0', node: 'pve', mode: 'eth'),
      VirtNetwork(
        id: 'pve/sbxe2e0',
        name: 'sbxe2e0',
        node: 'pve',
        mode: 'bridge',
        cidrs: ['10.77.0.1/24'],
      ),
      VirtNetwork(
        id: 'pve/vmbr0',
        name: 'vmbr0',
        node: 'pve',
        mode: 'bridge',
        cidrs: ['192.168.31.20/24'],
        gateway: '192.168.31.1',
        active: true,
        ports: ['nic0'],
      ),
    ];

    // What the node itself printed (captured on PVE 9.2.2, 2026-09-27),
    // with a second connection over a VPN bridge and a VLAN on vmbr0.
    const probe = '''
@host pve
@addr
1: lo    inet 127.0.0.1/8 scope host lo\\       valid_lft forever preferred_lft forever
4: vmbr0    inet 192.168.31.20/24 scope global vmbr0\\       valid_lft forever preferred_lft forever
4: vmbr0    inet6 fe80::8286:f2ff:fec9:5882/64 scope link proto kernel_ll \\       valid_lft forever preferred_lft forever
7: sbxe2e0    inet 10.77.0.1/24 scope global sbxe2e0\\       valid_lft forever preferred_lft forever
9: vmbr1    inet 10.8.0.5/24 scope global vmbr1\\       valid_lft forever preferred_lft forever
@route
default via 192.168.31.1 dev vmbr0 proto kernel onlink 
@conn
0      0      192.168.31.20:22 192.168.31.183:62036
0      0      [::ffff:10.8.0.5]:22 [::ffff:10.8.0.9]:50110
0      0      127.0.0.1:8006 127.0.0.1:41234
@lower
vmbr0 nic0
vmbr0 tap100i0
@end
''';

    test('the live probe: routes, connections and what sits under them', () {
      final live = virtPveParseLiveNet(probe)!;
      expect(live.host, 'pve');
      expect(live.routed, {'vmbr0'});
      // The loopback relay the app's API calls come through is not one.
      expect(live.connected, {'vmbr0', 'vmbr1'});
      expect(live.lower['vmbr0'], {'nic0', 'tap100i0'});
      // Cut short: nothing is concluded from it.
      expect(virtPveParseLiveNet(probe.replaceFirst('@end', '')), isNull);
      // `@end` is the last line or nothing: one inside the interfaces file
      // is not the probe's.
      expect(
        virtPveParseLiveNet('@host pve\n@route\n@file\n@end\niface x inet manual\n'),
        isNull,
      );
    });

    test('the live probe says nothing when a command it needs failed',
        () async {
      // The script as the node runs it, with the commands it calls stubbed.
      final dir = await Directory.systemTemp.createTemp('sbm-livenet');
      addTearDown(() => dir.delete(recursive: true));
      Future<String> run({bool ssFails = false, bool ip6Fails = false}) async {
        final stubs = {
          'hostname': 'echo pve',
          'cat': 'echo "iface vmbr0 inet static"',
          'ss': ssFails ? 'exit 1' : 'echo "0 0 10.0.0.2:22 10.0.0.9:5000"',
          'ip': '''
case "\$*" in
  *-6*) ${ip6Fails ? 'exit 1' : 'exit 0'} ;;
  *addr*) echo "4: vmbr0 inet 10.0.0.2/24 scope global vmbr0" ;;
  *) echo "default via 10.0.0.1 dev vmbr0" ;;
esac''',
        };
        for (final MapEntry(:key, :value) in stubs.entries) {
          final f = File('${dir.path}/$key')..writeAsStringSync('#!/bin/sh\n$value\n');
          await Process.run('chmod', ['+x', f.path]);
        }
        final r = await Process.run(
          'sh',
          ['-c', virtPveLiveNetScript],
          environment: {'PATH': '${dir.path}:/usr/bin:/bin'},
        );
        return r.stdout as String;
      }

      final ok = virtPveParseLiveNet(await run())!;
      expect(ok.connected, {'vmbr0'});
      expect(ok.routed, {'vmbr0'});
      // A kernel without IPv6 is not a failure.
      expect(virtPveParseLiveNet(await run(ip6Fails: true)), isNotNull);
      // No connection list: not "no connections".
      expect(virtPveParseLiveNet(await run(ssFails: true)), isNull);
    }, skip: Platform.isWindows);

    test('pending diffs: every interface a stanza line names, file-wide '
        'directives, and what the old side carried', () {
      // `auto vmbr9 vmbr0` removed touches both.
      final both = virtPveDiffIfaces(
        '@@ -1,2 +1,1 @@\n-auto vmbr9 vmbr0\n+auto vmbr9\n',
      );
      expect(both.ifaces, {'vmbr9', 'vmbr0'});
      expect(both.unknown, isFalse);
      // A `source` line is no interface's, even under one's stanza.
      final source = virtPveDiffIfaces(
        '@@ -1,3 +1,4 @@\n iface vmbr9 inet manual\n \tbridge-ports none\n+source /etc/network/more\n',
      );
      expect(source.unknown, isTrue);
      final afterSource = virtPveDiffIfaces(
        '@@ -1,3 +1,4 @@\n iface vmbr9 inet manual\n source /etc/x\n+\tmtu 9000\n',
      );
      expect(afterSource.unknown, isTrue);
      // The old side: the address and gateway the pending file drops.
      final stripped = virtPveDiffIfaces(
        '@@ -1,4 +1,2 @@\n'
        '-iface vmbr0 inet static\n'
        '-\taddress 192.168.31.20/24\n'
        '-\tgateway 192.168.31.1\n'
        '+iface vmbr0 inet manual\n'
        ' \tbridge-ports nic0\n'
        '@@ -9,2 +7,1 @@\n'
        ' iface vmbr1 inet dhcp\n'
        '-\tmtu 9000\n',
      );
      expect(stripped.ifaces, {'vmbr0', 'vmbr1'});
      expect(stripped.oldAddressed, {'vmbr0'});
      expect(stripped.oldGateways, {'vmbr0'});
      final dhcp = virtPveDiffIfaces('@@ -1,1 +1,1 @@\n-iface vmbr1 inet dhcp\n+iface vmbr1 inet manual\n');
      expect(dhcp.oldAddressed, {'vmbr1'});
    });

    test('the one carrying the host address is not editable', () {
      final live = virtPveParseLiveNet(probe)!;
      final withVpn = [
        ...nets,
        const VirtNetwork(
          id: 'pve/vmbr1',
          name: 'vmbr1',
          node: 'pve',
          mode: 'bridge',
          cidrs: ['10.8.0.5/24'],
        ),
      ];
      final m = virtPveManagementIfaces(withVpn, live: live);
      // The default route's, and the VPN bridge this app may be connected
      // through (it has no gateway), with the port under vmbr0.
      expect(m, containsAll(['vmbr0', 'vmbr1', 'nic0']));
      expect(m, isNot(contains('sbxe2e0')));
      // A bridge of the app's own is editable; a physical interface never is.
      for (final n in withVpn) {
        expect(
          virtPveManagedIface(n, management: m),
          n.name == 'sbxe2e0',
          reason: n.name,
        );
      }
      // The node did not answer: every interface with an address is kept.
      expect(
        virtPveManagementIfaces(withVpn),
        containsAll(['vmbr0', 'vmbr1', 'sbxe2e0']),
      );
      // A VLAN interface carrying the address protects the bridge it is on:
      // turning VLAN awareness off there would cut it.
      const vlan = [
        VirtNetwork(
          id: 'pve/vmbr0',
          name: 'vmbr0',
          node: 'pve',
          mode: 'bridge',
          vlanAware: true,
          ports: ['nic0'],
        ),
        VirtNetwork(
          id: 'pve/vmbr0.10',
          name: 'vmbr0.10',
          node: 'pve',
          mode: 'vlan',
          cidrs: ['10.10.0.2/24'],
          gateway: '10.10.0.1',
        ),
      ];
      expect(virtPveManagementIfaces(vlan), containsAll(['vmbr0.10', 'vmbr0', 'nic0']));
      // An IPv6-only node: its `gateway6` counts.
      expect(
        virtPveManagementIfaces(const [
          VirtNetwork(id: 'pve/vmbr2', name: 'vmbr2', node: 'pve', mode: 'bridge'),
        ], live: live, gateways6: {'vmbr2'}),
        contains('vmbr2'),
      );
    });

    test('which interfaces a pending diff touches', () {
      const diff = '''
--- /etc/network/interfaces\t2026-09-27
+++ /etc/network/interfaces.new\t2026-09-27
@@ -10,6 +10,7 @@
 auto vmbr0
 iface vmbr0 inet static
 \taddress 192.168.31.20/24
+\tbridge-vlan-aware yes
 \tgateway 192.168.31.1
@@ -20,3 +21,8 @@
+
+auto vmbr9
+iface vmbr9 inet manual
+\tbridge-ports none
''';
      final t = virtPveDiffIfaces(diff);
      expect(t.ifaces, {'vmbr0', 'vmbr9'});
      expect(t.unknown, isFalse);
      // A hunk whose change comes before any stanza line: not known.
      const midDiff = '@@ -5,3 +5,4 @@\n \tbridge-ports nic0\n \tbridge-stp off\n \tbridge-fd 0\n+\tbridge-vlan-aware yes\n';
      final mid = virtPveDiffIfaces(midDiff);
      expect(mid.unknown, isTrue);
      // ... unless the file as it is says which stanza line 5 is under.
      const file = 'auto lo\niface lo inet loopback\n\niface vmbr0 inet static\n\tbridge-ports nic0\n'
          '\tbridge-stp off\n\tbridge-fd 0\n';
      final placed = virtPveDiffIfaces(midDiff, interfaces: file);
      expect(placed.ifaces, {'vmbr0'});
      expect(placed.unknown, isFalse);
      // Placed after `lo`'s stanza, a hunk starting on line 3 is still lo's.
      final early = virtPveDiffIfaces('@@ -3,1 +3,2 @@\n \n+# note\n+\tmtu 9000\n', interfaces: file);
      expect(early.ifaces, {'lo'});
      // A comment is its stanza's: PVE writes `comments` there.
      final comment = virtPveDiffIfaces(
        '@@ -5,3 +5,4 @@\n \tbridge-ports nic0\n \tbridge-stp off\n \tbridge-fd 0\n+#note\n',
        interfaces: file,
      );
      expect(comment.ifaces, {'vmbr0'});
      // The probe carries the file.
      expect(
        virtPveParseLiveNet('@host pve\n@route\n@file\n$file@end\n')!.interfaces,
        contains('iface vmbr0 inet static'),
      );
    });
  });

  group('libvirt', () {
    test('each change as the parser takes it', () {
      Map<String, Object?> op(VirtResourceChange c) => LibvirtBackend.opJson(c);
      expect(
        op(const VirtPoolCreate(name: 'p', type: 'dir', source: '/srv/p')),
        {
          'op': 'pool_create',
          'name': 'p',
          'pool_type': 'dir',
          'target': '/srv/p',
          'source': null,
          'autostart': true,
        },
      );
      expect(
        op(
          const VirtPoolCreate(
            name: 'n',
            type: 'netfs',
            source: 'nas:/e',
            target: '/mnt/n',
          ),
        ),
        containsPair('source', 'nas:/e'),
      );
      expect(
        op(const VirtVolumeCreate(_dir, name: 'a.qcow2', gib: 2, format: 'qcow2')),
        containsPair('bytes', 2 << 30),
      );
      expect(
        op(
          const VirtNetworkCreate(
            name: 'lab',
            mode: 'nat',
            cidr: '192.168.150.1/24',
            dhcpStart: '192.168.150.100',
            dhcpEnd: '192.168.150.200',
          ),
        )['ipv4'],
        {
          'address': '192.168.150.1',
          'prefix': 24,
          'dhcp_start': '192.168.150.100',
          'dhcp_end': '192.168.150.200',
        },
      );
      expect(
        op(const VirtNetworkCreate(name: 'b', mode: 'bridge', bridge: 'br0', cidr: '1.2.3.4/24')),
        allOf(containsPair('bridge', 'br0'), containsPair('ipv4', null)),
      );
      const net = VirtNetwork(id: 'lab', name: 'lab', mode: 'nat', active: false);
      expect(op(const VirtNetworkDelete(net)), {'op': 'net_delete', 'name': 'lab'});
      expect(
        op(const VirtPoolDelete(_dir, deleteStorage: true)),
        {'op': 'pool_delete', 'name': 'images', 'active': true, 'delete_storage': true},
      );
      // Every op JSON is one the parser writes a script for.
      for (final c in <VirtResourceChange>[
        const VirtPoolCreate(name: 'p', type: 'dir', source: '/srv/p'),
        const VirtPoolSetActive(_dir, active: false),
        const VirtPoolSetAutostart(_dir, on: true),
        const VirtPoolRefresh(_dir),
        const VirtPoolDelete(_dir),
        const VirtVolumeCreate(_dir, name: 'a.qcow2', gib: 2, format: 'qcow2'),
        const VirtVolumeResize(_dir, VirtVolume(id: 'a', name: 'a'), bytes: 1 << 30),
        const VirtVolumeClone(_dir, VirtVolume(id: 'a', name: 'a'), name: 'b'),
        const VirtNetworkCreate(name: 'i', mode: 'isolated'),
        const VirtNetworkSetActive(net, active: true),
        const VirtNetworkSetAutostart(net, on: false),
      ]) {
        expect(
          ffi.virtResourceScript(opJson: jsonEncode(op(c))),
          contains('virsh'),
          reason: '$c',
        );
      }
      expect(() => op(const VirtNetworkApply('pve')), throwsA(isA<VirtErr>()));
    });

    test('an existing network\'s edit as the parser takes it', () async {
      const net = VirtNetwork(
        id: 'lab',
        name: 'lab',
        mode: 'nat',
        active: true,
        cidrs: ['192.168.150.1/24'],
        dhcpRanges: ['192.168.150.100-192.168.150.200'],
        bridge: 'virbr1',
        xml: '<network>\n'
            '  <name>lab</name>\n'
            "  <forward mode='nat'/>\n"
            "  <bridge name='virbr1'/>\n"
            "  <ip address='192.168.150.1' prefix='24'>\n"
            '    <dhcp>\n'
            "      <range start='192.168.150.100' end='192.168.150.200'/>\n"
            '    </dhcp>\n'
            '  </ip>\n'
            '</network>\n',
      );
      final edit = VirtNetworkEdit(
        net,
        mode: 'nat',
        address: '192.168.151.1',
        prefix: 24,
        dhcpStart: '192.168.151.100',
        dhcpEnd: '192.168.151.200',
        hosts: const [
          VirtNetHost(mac: '52:54:00:AA:BB:01', ip: '192.168.151.10', name: 'h1'),
        ],
      );
      final json = LibvirtBackend.opJson(edit);
      expect(json['op'], 'edit');
      expect(json['name'], 'lab');
      expect(json['active'], isTrue);
      expect(json['restart'], isFalse);
      expect(json['base_xml'], contains('<name>lab</name>'));
      expect(json['edit'], {
        'mode': 'nat',
        'bridge': null,
        'address': '192.168.151.1',
        'prefix': 24,
        'dhcp_start': '192.168.151.100',
        'dhcp_end': '192.168.151.200',
        'hosts': [
          {'mac': '52:54:00:aa:bb:01', 'ip': '192.168.151.10', 'name': 'h1'},
        ],
      });
      // The script is the network module's, not the resource one.
      final script = ffi.virtNetChangeScript(opJson: jsonEncode(json));
      expect(script, contains('net-define'));
      // The address moves, so the static hosts go into the definition with
      // it: `net-update` would check them against the old subnet.
      expect(script, isNot(contains('net-update')));
      // A static host alone takes the live path.
      final hostsOnly = LibvirtBackend.opJson(
        VirtNetworkEdit(
          net,
          mode: 'nat',
          address: '192.168.150.1',
          prefix: 24,
          dhcpStart: '192.168.150.100',
          dhcpEnd: '192.168.150.200',
          hosts: const [
            VirtNetHost(mac: '52:54:00:aa:bb:01', ip: '192.168.150.10'),
          ],
        ),
      );
      final live = ffi.virtNetChangeScript(opJson: jsonEncode(hostsOnly));
      expect(live, contains('net-update'));
      expect(live, isNot(contains('net-define')));
      await expectLater(
        ffi.parseVirtNetChange(raw: _section('virt.net.step', '')),
        completes,
      );
      // A restart is its own op: `net-destroy` and `net-start`, no
      // definition written either way.
      final restart = LibvirtBackend.opJson(const VirtNetworkRestart(net));
      expect(restart['op'], 'restart');
      expect(restart['name'], 'lab');
      expect(restart['base_xml'], contains('<name>lab</name>'));
      final restarted = ffi.virtNetChangeScript(opJson: jsonEncode(restart));
      expect(restarted, contains('net-destroy'));
      expect(restarted, contains('net-start'));
      expect(restarted, isNot(contains('net-define')));
      expect(
        () => LibvirtBackend.opJson(
          const VirtNetworkEditBridge(net, cidr: '10.0.0.1/24'),
        ),
        throwsA(isA<VirtErr>()),
      );
    });

    test('a network change the host refuses reaches the caller', () async {
      // The start refused, and the network started again as it ran: an
      // error, never a success.
      final exec = _Exec(
        (_) => _ok(
          [
            _section('virt.net.step', ''),
            _section(
              'virt.net.step',
              'error: Failed to start network lab\nerror: internal error: Network is already in use by interface eth0',
              1,
            ),
            '${_marker('virt.net.rollback')}\n${_marker('virt.net.restored')}\n',
          ].join(),
        ),
      );
      final virt = LibvirtBackend(serverId: 's', exec: () async => exec);
      const net = VirtNetwork(
        id: 'lab',
        name: 'lab',
        mode: 'nat',
        active: true,
        xml: '<network>\n  <name>lab</name>\n</network>\n',
      );
      final e = await _err(virt.manage(const VirtNetworkRestart(net)));
      expect(e.message, contains('started again as it ran before'));
    });

    test('a name taken is exists; a refusal is the host\'s words', () async {
      final exec = _Exec(
        (_) => _ok(
          _section('virt.res.step', "error: operation failed: pool 'p' already exists with uuid 1", 1),
        ),
      );
      final virt = LibvirtBackend(serverId: 's', exec: () async => exec);
      final e = await _err(
        virt.manage(const VirtPoolCreate(name: 'p', type: 'dir', source: '/srv/p')),
      );
      expect(e.type, VirtErrType.exists);
      expect(exec.calls.single.entry, 'sh');
      expect(exec.calls.single.script, contains('pool-define'));

      final refused = LibvirtBackend(
        serverId: 's',
        exec: () async => _Exec(
          (_) => _ok(
            _section('virt.res.step', 'error: Requested operation is not valid: storage pool is not empty', 1),
          ),
        ),
      );
      final e2 = await _err(refused.manage(const VirtPoolDelete(_dir, deleteStorage: true)));
      expect(e2.type, VirtErrType.actionFailed);
      expect(e2.message, contains('not empty'));
    });

    test('upload: the go line, then the file; progress; done', () async {
      final exec = _Exec((_) => _ok(_section('virt.res.step', '')));
      final bytes = _Bytes();
      final remote = _Remote();
      final virt = _backend(exec, remote);
      final sent = <int>[];
      expect(
        await virt.upload(
          VirtUpload(pool: _dir, name: 'x.iso', size: bytes.size, open: bytes.open),
          onProgress: sent.add,
        ),
        isTrue,
      );
      expect(remote.sessions.single.command, startsWith("sh -c 'eval"));
      expect(remote.sessions.single.file, bytes.all);
      expect(sent.last, bytes.size);
      // The volume first, raw and the file's size; nothing deleted after.
      expect(exec.calls.first.script, contains('vol-create-as'));
      expect(exec.calls.first.script, contains('--capacity ${bytes.size}B --format raw'));
      expect(exec.calls.map((c) => c.script).join(), isNot(contains('vol-delete')));
    });

    test('upload through sudo: the password is sudo\'s, never the volume\'s', () async {
      // Refused as this account, so sudo — with the password it was given.
      final exec = _Exec(
        (call) => call.entry == 'sh'
            ? _ok(_section('virt.res.step', 'error: authentication unavailable: polkit', 1))
            : _ok(_section('virt.res.step', '')),
      );
      final remote = _Remote(sudoAsks: true, password: 'pw');
      final virt = _backend(exec, remote)..provideSudoPassword('pw');
      final bytes = _Bytes();
      expect(
        await virt.upload(
          VirtUpload(pool: _dir, name: 'x.iso', size: bytes.size, open: bytes.open),
        ),
        isTrue,
      );
      expect(remote.sessions.single.command, startsWith("sudo -S -p '' sh -c"));
      expect(remote.sessions.single.file, bytes.all);

      // sudo did not ask (cached, NOPASSWD): the script found the password
      // where the go line belongs and stopped; once more without it.
      final remote2 = _Remote(sudoAsks: false);
      final virt2 = _backend(exec, remote2)..provideSudoPassword('pw');
      expect(
        await virt2.upload(
          VirtUpload(pool: _dir, name: 'x.iso', size: bytes.size, open: bytes.open),
        ),
        isTrue,
      );
      expect(remote2.sessions, hasLength(2));
      expect(remote2.sessions.first.file, isEmpty);
      expect(remote2.sessions.last.command, startsWith('sudo -n sh -c'));
      expect(remote2.sessions.last.file, bytes.all);
      expect(utf8.decode(remote2.sessions.last.file, allowMalformed: true), isNot(contains('pw\n')));
    });

    test('upload: a rejected password, a refusal and a cancel delete the volume', () async {
      final exec = _Exec(
        (call) => call.entry == 'sh'
            ? _ok(_section('virt.res.step', 'error: authentication unavailable: polkit', 1))
            : _ok(_section('virt.res.step', '')),
      );
      final bytes = _Bytes();
      final wrong = _backend(exec, _Remote(sudoAsks: true, password: 'right'))
        ..provideSudoPassword('wrong');
      final e = await _err(
        wrong.upload(VirtUpload(pool: _dir, name: 'x.iso', size: bytes.size, open: bytes.open)),
      );
      expect(e.type, VirtErrType.sudoPasswordRejected);
      expect(exec.calls.last.script, contains('vol-delete'));

      final full = _backend(
        _Exec((_) => _ok(_section('virt.res.step', ''))),
        _Remote(refuse: 'error: cannot upload to volume x.iso: No space left on device'),
      );
      final e2 = await _err(
        full.upload(VirtUpload(pool: _dir, name: 'x.iso', size: bytes.size, open: bytes.open)),
      );
      expect(e2.type, VirtErrType.actionFailed);
      expect(e2.message, contains('No space left'));

      final exec3 = _Exec((_) => _ok(_section('virt.res.step', '')));
      final remote3 = _Remote();
      final cancel = Completer<void>();
      final virt3 = _backend(exec3, remote3);
      final stopped = await virt3.upload(
        VirtUpload(pool: _dir, name: 'x.iso', size: bytes.size, open: bytes.open),
        cancel: cancel.future,
        onProgress: (n) {
          if (!cancel.isCompleted) cancel.complete();
        },
      );
      expect(stopped, isFalse);
      expect(remote3.sessions.single.killed, isTrue);
      expect(remote3.sessions.single.file.length, lessThan(bytes.size));
      expect(exec3.calls.last.script, contains('vol-delete'));
    });

    test('no byte channel: no upload offered, none made', () async {
      final virt = LibvirtBackend(
        serverId: 's',
        exec: () async => _Exec((_) => _ok('')),
        canStream: () => false,
        byteExec: () async => throw StateError('not called'),
      );
      final e = await _err(
        virt.upload(VirtUpload(pool: _dir, name: 'x.iso', size: 1, open: () => const Stream.empty())),
      );
      expect(e.type, VirtErrType.unsupported);
    });
  });
}

LibvirtBackend _backend(_Exec exec, _Remote remote) => LibvirtBackend(
  serverId: 's',
  exec: () async => exec,
  byteExec: () async => remote,
  canStream: () => true,
);

Future<VirtErr> _err(Future<Object?> future) async {
  try {
    await future;
  } on VirtErr catch (e) {
    return e;
  }
  fail('expected a VirtErr');
}

ExecResult _ok(String stdout) =>
    ExecResult(exitCode: 0, stdout: stdout, stderr: '');

typedef _Call = ({String script, String? entry, String? stdin});

class _Exec implements ServerExec {
  _Exec(this.answer);

  final ExecResult Function(_Call call) answer;
  final calls = <_Call>[];

  @override
  Future<ExecResult> run(
    String script, {
    String? entry,
    Map<String, String>? env,
    String? stdin,
    OnExecOutput? onStdout,
    OnExecOutput? onStderr,
    Future<void>? cancel,
  }) async {
    final call = (script: script, entry: entry, stdin: stdin);
    calls.add(call);
    return answer(call);
  }
}

/// A file of a few chunks.
class _Bytes {
  static const chunk = 1000;
  static const chunks = 5;
  int get size => chunk * chunks;
  List<int> get all => [
    for (var i = 0; i < size; i++) i & 0xff,
  ];
  Stream<List<int>> open() async* {
    for (var c = 0; c < chunks; c++) {
      yield [for (var i = 0; i < chunk; i++) (c * chunk + i) & 0xff];
    }
  }
}

/// The far side of the byte channel, as the upload command behaves there:
/// sudo reading its password line (when it asks), the script reading the go
/// line and saying it is ready, `vol-upload` taking the rest.
class _Remote implements ServerByteExec {
  _Remote({this.sudoAsks = false, this.password, this.refuse});

  final bool sudoAsks;
  final String? password;
  final String? refuse;
  final sessions = <_Session>[];

  @override
  Future<ExecSession> start(String command) async {
    final s = _Session(this, command);
    sessions.add(s);
    return s;
  }

  @override
  Future<ExecResult> run(
    String script, {
    String? entry,
    Map<String, String>? env,
    String? stdin,
    OnExecOutput? onStdout,
    OnExecOutput? onStderr,
    Future<void>? cancel,
  }) => throw UnimplementedError();
}

class _Session implements ExecSession {
  _Session(this.remote, this.command);

  final _Remote remote;
  final String command;
  final _out = StreamController<String>.broadcast();
  final _err = StreamController<String>.broadcast();
  final _done = Completer<int?>();
  final _input = <int>[];
  final file = <int>[];
  var _phase = 0;
  var killed = false;

  bool get _sudoPassword => command.startsWith('sudo -S');

  @override
  Stream<String> get stdout => _out.stream;

  @override
  Stream<String> get stderr => _err.stream;

  @override
  Future<int?> get done => _done.future;

  String? _line() {
    final i = _input.indexOf(10);
    if (i < 0) return null;
    final line = utf8.decode(_input.sublist(0, i));
    _input.removeRange(0, i + 1);
    return line;
  }

  void _end(String out, int code) {
    if (_done.isCompleted) return;
    if (out.isNotEmpty) _out.add(out);
    scheduleMicrotask(() {
      _done.complete(code);
      unawaited(_out.close());
      unawaited(_err.close());
    });
  }

  @override
  Future<void> write(List<int> data) async {
    if (_done.isCompleted) throw StateError('closed');
    if (_phase == 2) {
      file.addAll(data);
      return;
    }
    _input.addAll(data);
    if (_phase == 0 && _sudoPassword && remote.sudoAsks) {
      final pw = _line();
      if (pw == null) return;
      if (pw != remote.password) {
        _err.add('Sorry, try again.\n');
        return;
      }
      _phase = 1;
    } else if (_phase == 0) {
      _phase = 1;
    }
    if (_phase == 1) {
      final go = _line();
      if (go == null) return;
      if (go != ffi.virtUploadGoLine()) {
        _end('${_marker('virt.upload.refused')}\n', 97);
        return;
      }
      _phase = 2;
      file.addAll(_input);
      _input.clear();
      _out.add('${ffi.virtUploadReadyMarker()}\n');
    }
  }

  @override
  Future<void> closeStdin() async {
    final refuse = remote.refuse;
    _end(
      refuse == null
          ? _section('virt.upload', '')
          : _section('virt.upload', refuse, 1),
      0,
    );
  }

  @override
  void kill() {
    if (_done.isCompleted) return;
    killed = true;
    _end('', 137);
  }
}
