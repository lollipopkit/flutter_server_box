/// `PveBackend` against a scripted PVE API: parsing, auth (ticket, TOTP,
/// token), session drop on 401 and not on 403, the generation guard, UPID
/// polling, and snapshots, storage, networks and hardware against payloads
/// captured from PVE 9.2.2 (`test/fixtures/pve/`).
///
/// TLS is `pve_tls_test.dart`, against a real TLS server.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/data/model/app/error.dart';
import 'package:server_box/data/model/server/pve_config.dart';
import 'package:server_box/data/model/server/server_exec.dart';
import 'package:server_box/data/model/virt/pve_resources.dart';
import 'package:server_box/data/model/virt/virt.dart';
import 'package:server_box/data/model/virt/virt_backup.dart';
import 'package:server_box/data/model/virt/virt_console.dart';
import 'package:server_box/data/model/virt/virt_create.dart';
import 'package:server_box/data/model/virt/virt_detail.dart';
import 'package:server_box/data/model/virt/virt_hardware.dart';
import 'package:server_box/data/model/virt/virt_manage.dart';
import 'package:server_box/data/model/virt/virt_resources.dart';
import 'package:server_box/data/provider/virt/pve_backend.dart';

import '../../helpers/pve_tunnel.dart';
import '../../helpers/rust_lib_helper.dart';

/// `/cluster/resources` from a one-node PVE 8 (the old `pve_test.dart`
/// fixture), plus a locked guest and a template.
final _resources = <Map<String, Object?>>[
  {
    'maxmem': 12884901888,
    'type': 'lxc',
    'cpu': 0.0544631947461575,
    'netin': 65412250538,
    'template': 0,
    'diskread': 324033204224,
    'maxcpu': 8,
    'disk': 29767077888,
    'diskwrite': 707866570752,
    'node': 'pve',
    'vmid': 100,
    'mem': 5389254656,
    'status': 'running',
    'netout': 66898114418,
    'uptime': 1204757,
    'id': 'lxc/100',
    'maxdisk': 134145380352,
    'name': 'Jellyfin',
    'tags': 'media;prod',
  },
  {
    'vmid': 101,
    'node': 'pve',
    'uptime': 0,
    'netout': 0,
    'status': 'stopped',
    'mem': 0,
    'id': 'qemu/101',
    'name': 'ubuntu',
    'maxdisk': 137438953472,
    'maxmem': 6442450944,
    'cpu': 0,
    'netin': 0,
    'type': 'qemu',
    'disk': 0,
    'diskread': 0,
    'template': 0,
    'maxcpu': 8,
    'diskwrite': 0,
  },
  {
    'maxcpu': 4,
    'template': 0,
    'diskread': 23287297536,
    'disk': 0,
    'diskwrite': 39555984896,
    'maxmem': 4294967296,
    'type': 'qemu',
    'netin': 2190678599,
    'cpu': 0.0516426831961466,
    'id': 'qemu/102',
    'maxdisk': 0,
    'name': 'win',
    'node': 'pve',
    'vmid': 102,
    'mem': 1791827968,
    'status': 'running',
    'netout': 213292068,
    'uptime': 1013075,
  },
  {
    'id': 'qemu/103',
    'type': 'qemu',
    'vmid': 103,
    'node': 'pve',
    'name': 'db',
    'status': 'running',
    'lock': 'backup',
    'maxcpu': 2,
    'maxmem': 2147483648,
    'cpu': 0.25,
    'mem': 1073741824,
  },
  {
    'id': 'qemu/9000',
    'type': 'qemu',
    'vmid': 9000,
    'node': 'pve',
    'name': 'tmpl',
    'status': 'stopped',
    'template': 1,
  },
  {
    'id': 'qemu/104',
    'type': 'qemu',
    'vmid': 104,
    'node': 'pve',
    'name': 'paused-vm',
    'status': 'paused',
  },
  {
    'maxcpu': 12,
    'id': 'node/pve',
    'disk': 358415503360,
    'maxdisk': 998011547648,
    'node': 'pve',
    'maxmem': 29287632896,
    'type': 'node',
    'status': 'online',
    'mem': 11522887680,
    'cpu': 0.0451634094268353,
    'uptime': 1204771,
  },
  {
    'id': 'storage/pve/local',
    'type': 'storage',
    'node': 'pve',
    'storage': 'local',
    'status': 'available',
  },
  {'id': 'sdn/pve/localnetwork', 'type': 'sdn', 'node': 'pve'},
];

void main() {
  setUpAll(initRustLibForTest);

  group('PveResources', () {
    test('config: disks, NICs, consoles', () {
      final qemu = PveResources.parseConfig({
        'scsi0': 'local-lvm:vm-100-disk-0,iothread=1,size=32G',
        'scsi10': 'local-lvm:vm-100-disk-2,size=512M',
        'scsi2': 'local-lvm:vm-100-disk-1,size=1T',
        'ide2': 'local:iso/debian.iso,media=cdrom,size=600M',
        'net0': 'virtio=BC:24:11:AA:BB:CC,bridge=vmbr0,firewall=1',
        'serial0': 'socket',
        'vga': 'qxl,memory=32',
        'ostype': 'l26',
      }, VirtGuestKind.qemu);
      expect(qemu.disks.map((d) => d.target), [
        'ide2',
        'scsi0',
        'scsi2',
        'scsi10',
      ]);
      expect(qemu.disks.first.device, 'cdrom');
      expect(qemu.disks[1].size, 32 << 30);
      expect(qemu.disks[1].source, 'local-lvm:vm-100-disk-0');
      expect(qemu.disks[3].size, 512 << 20);
      expect(qemu.nics.single.model, 'virtio');
      expect(qemu.nics.single.mac, 'BC:24:11:AA:BB:CC');
      expect(qemu.nics.single.source, 'vmbr0');
      expect(qemu.graphics.single.kind, 'qxl');
      expect(qemu.consoles, {VirtConsoleKind.vnc, VirtConsoleKind.text});
      expect(qemu.machine, 'l26');

      final serialOnly = PveResources.parseConfig({
        'vga': 'serial0',
        'serial0': 'socket',
      }, VirtGuestKind.qemu);
      expect(serialOnly.consoles, {VirtConsoleKind.text});

      final lxc = PveResources.parseConfig({
        'rootfs': 'local-lvm:vm-100-disk-0,size=8G',
        'mp0': '/srv/data,mp=/data,ro=1',
        'net0':
            'name=eth0,bridge=vmbr0,hwaddr=BC:24:11:00:00:01,ip=dhcp,type=veth',
      }, VirtGuestKind.lxc);
      expect(lxc.disks.map((d) => d.device), ['mp', 'rootfs']);
      expect(lxc.disks.first.readonly, isTrue);
      expect(lxc.nics.single.target, 'eth0');
      expect(lxc.nics.single.mac, 'BC:24:11:00:00:01');
      expect(lxc.consoles, {VirtConsoleKind.text});
    });
  });

  test('consoles: termproxy and vncproxy tickets', () async {
    final api = _Api()..resources = _resources;
    final pve = api.backend(const PveConfig(addr: 'https://pve.lan:8006'));
    final guests = (await pve.load()).guests;
    final term = await pve.console(guests.first, VirtConsoleKind.text);
    expect(term, isA<PveTermConsole>());
    expect(
      term.websocketPath,
      '/api2/json/nodes/pve/lxc/100/vncwebsocket?port=5900'
      '&vncticket=PVEVNC%3Aabc%2F%3D',
    );
    final vnc = await pve.console(guests[2], VirtConsoleKind.vnc);
    expect(vnc, isA<PveVncConsole>());
    expect(api.bodies.last, contains('websocket=1'));
    expect(
      (await _err(pve.console(guests.first, VirtConsoleKind.vnc))).type,
      VirtErrType.unsupported,
    );
  });

  group('create and delete', () {
    const token = PveConfig(
      addr: 'https://pve.lan:8006',
      auth: PveAuth.token,
      tokenId: 'root@pam!sb',
      tokenSecret: 's3cret',
    );
    const lvm = VirtStoragePool(
      id: 'pve/local-lvm',
      name: 'local-lvm',
      node: 'pve',
      type: 'lvmthin',
      content: ['images', 'rootdir'],
    );
    const bridge = VirtNetwork(
      id: 'pve/vmbr0',
      name: 'vmbr0',
      node: 'pve',
      mode: 'bridge',
    );
    Map<String, String> form(String body) => Uri.splitQueryString(body);

    test('nextid', () async {
      final api = _Api()..routes['GET /cluster/nextid'] = (_) => '105';
      expect(await api.backend(token).nextVmid(), 105);
    });

    test('a VM: its configuration, the task, then start on its own', () async {
      final api = _Api();
      api.routes['POST /nodes/pve/qemu'] = (_) => _Api.upid;
      api.routes['POST /nodes/pve/qemu/105/status/start'] = (_) => _Api.upid;
      final created = await api.backend(token).create(
        const VirtCreateSpec(
          kind: VirtGuestKind.qemu,
          name: 'web-02',
          node: 'pve',
          vmid: 105,
          cores: 2,
          memoryMiB: 2048,
          storage: lvm,
          diskGiB: 32,
          media: VirtVolume(
            id: 'local:iso/debian-13.iso',
            name: 'debian-13.iso',
            content: 'iso',
          ),
          network: bridge,
          start: true,
        ),
      );
      expect(created.id, 'qemu/105');
      expect(created.startError, isNull);
      final i = api.paths.indexOf('POST /nodes/pve/qemu');
      expect(form(api.bodies[i]), {
        'vmid': '105',
        'name': 'web-02',
        'cores': '2',
        'memory': '2048',
        'ostype': 'l26',
        'scsihw': 'virtio-scsi-single',
        'scsi0': 'local-lvm:32,iothread=1',
        'ide2': 'local:iso/debian-13.iso,media=cdrom',
        'net0': 'virtio,bridge=vmbr0',
        'serial0': 'socket',
        'boot': 'order=scsi0;ide2',
      });
      // Created (its task waited for) before it is started.
      final start = api.paths.indexOf('POST /nodes/pve/qemu/105/status/start');
      expect(
        api.paths.indexWhere((p) => p.contains('/tasks/')),
        allOf(greaterThan(i), lessThan(start)),
      );
    });

    test('a cloud image with cloud-init: import-from, PVE\'s drive, grown '
        'before the start', () async {
      final api = _Api();
      api.routes['POST /nodes/pve/qemu'] = (_) => _Api.upid;
      // Imported at the image's own size.
      api.routes['GET /nodes/pve/qemu/107/config'] =
          (_) => {'scsi0': 'local-lvm:vm-107-disk-1,iothread=1,size=3G'};
      api.routes['PUT /nodes/pve/qemu/107/resize'] = (_) => _Api.upid;
      api.routes['POST /nodes/pve/qemu/107/status/start'] = (_) => _Api.upid;
      const key = 'ssh-ed25519 AAAAC3NzaC1lZDI1NTE5 me@x';
      final created = await api.backend(token).create(
        const VirtCreateSpec(
          kind: VirtGuestKind.qemu,
          name: 'ci-01',
          node: 'pve',
          vmid: 107,
          cores: 1,
          memoryMiB: 1024,
          storage: lvm,
          diskGiB: 16,
          image: VirtVolume(
            id: 'local:import/debian-13.qcow2',
            name: 'debian-13.qcow2',
            content: 'import',
            format: 'qcow2',
            capacity: 3 << 30,
          ),
          network: bridge,
          nicModel: 'e1000e',
          uefi: true,
          tpm: true,
          cloudInit: VirtCloudInit(
            user: 'admin',
            password: 'p a&ss=word',
            sshKeys: '$key\n',
            address: '10.0.0.5/24',
            gateway: '10.0.0.1',
            dns: ['1.1.1.1', '9.9.9.9'],
            searchDomains: ['lab.example'],
          ),
          start: true,
        ),
      );
      expect(created.startError, isNull);
      expect(created.diskKeptBytes, isNull);
      final i = api.paths.indexOf('POST /nodes/pve/qemu');
      final body = form(api.bodies[i]);
      expect(body, {
        'vmid': '107',
        'name': 'ci-01',
        'cores': '1',
        'memory': '1024',
        'ostype': 'l26',
        'scsihw': 'virtio-scsi-single',
        'scsi0': 'local-lvm:0,import-from=local:import/debian-13.qcow2,iothread=1',
        // Where a cloud kernel reads it: not IDE.
        'scsi1': 'local-lvm:cloudinit',
        'net0': 'e1000e,bridge=vmbr0',
        'serial0': 'socket',
        'boot': 'order=scsi0',
        'bios': 'ovmf',
        'efidisk0': 'local-lvm:1,efitype=4m,pre-enrolled-keys=0',
        'tpmstate0': 'local-lvm:1,version=v2.0',
        'ciuser': 'admin',
        'cipassword': 'p a&ss=word',
        // Encoded once more inside the form, as PVE wants it.
        'sshkeys': Uri.encodeComponent('$key\n'),
        'ipconfig0': 'ip=10.0.0.5/24,gw=10.0.0.1',
        'nameserver': '1.1.1.1 9.9.9.9',
        'searchdomain': 'lab.example',
      });
      expect(body['sshkeys'], 'ssh-ed25519%20AAAAC3NzaC1lZDI1NTE5%20me%40x%0A');
      // Secure Boot is offered, and is the EFI disk with the keys enrolled.
      expect((await api.backend(token).createOptions()).secureBoot, isTrue);
      // Grown to the size asked for, then started.
      final resize = api.paths.indexOf('PUT /nodes/pve/qemu/107/resize');
      expect(form(api.bodies[resize]), {'disk': 'scsi0', 'size': '16G'});
      final start = api.paths.indexOf('POST /nodes/pve/qemu/107/status/start');
      expect(i < resize && resize < start, isTrue);
    });

    test('an image bigger than the disk asked for keeps its size, not grown '
        'and not failed', () async {
      final api = _Api();
      api.routes['POST /nodes/pve/qemu'] = (_) => _Api.upid;
      api.routes['GET /nodes/pve/qemu/109/config'] =
          (_) => {'scsi0': 'local-lvm:vm-109-disk-0,iothread=1,size=3584M'};
      api.routes['POST /nodes/pve/qemu/109/status/start'] = (_) => _Api.upid;
      final created = await api.backend(token).create(
        const VirtCreateSpec(
          kind: VirtGuestKind.qemu,
          name: 'ci-03',
          node: 'pve',
          vmid: 109,
          cores: 1,
          memoryMiB: 1024,
          storage: lvm,
          diskGiB: 2,
          // The listing's size was the file's: unknown.
          image: VirtVolume(id: 'local:import/noble.qcow2', name: 'noble.qcow2', content: 'import', format: 'qcow2'),
          cloudInit: VirtCloudInit(user: 'u', password: 'pw'),
          start: true,
        ),
      );
      expect(created.diskKeptBytes, 3584 << 20);
      expect(created.startError, isNull);
      expect(api.paths.where((p) => p.endsWith('/resize')), isEmpty);
      expect(api.paths, contains('POST /nodes/pve/qemu/109/status/start'));
    });

    test('a disk on SATA has no I/O thread; a failed growth is not started',
        () async {
      final api = _Api();
      api.routes['POST /nodes/pve/qemu'] = (_) => _Api.upid;
      api.routes['PUT /nodes/pve/qemu/108/resize'] = (_) =>
          _Api._status(500, message: 'resize failed');
      final created = await api.backend(token).create(
        const VirtCreateSpec(
          kind: VirtGuestKind.qemu,
          name: 'ci-02',
          node: 'pve',
          vmid: 108,
          cores: 1,
          memoryMiB: 1024,
          storage: lvm,
          diskGiB: 8,
          image: VirtVolume(id: 'local:import/x.raw', name: 'x.raw', format: 'raw'),
          bus: 'sata',
          cloudInit: VirtCloudInit(user: 'u', password: 'pw'),
          start: true,
        ),
      );
      final body = form(api.bodies[api.paths.indexOf('POST /nodes/pve/qemu')]);
      expect(body['sata0'], 'local-lvm:0,import-from=local:import/x.raw');
      expect(body['boot'], 'order=sata0');
      expect(body['sata1'], 'local-lvm:cloudinit');
      // No NIC: DHCP all the same (PVE writes it for none), no key.
      expect(body['ipconfig0'], 'ip=dhcp');
      expect(body.containsKey('sshkeys'), isFalse);
      expect(created.startError, contains('resize failed'));
      expect(api.paths.where((p) => p.contains('status/start')), isEmpty);
    });

    test('a container: template, rootfs, DHCP, and its login', () async {
      final api = _Api()..routes['POST /nodes/pve/lxc'] = (_) => _Api.upid;
      final created = await api.backend(token).create(
        const VirtCreateSpec(
          kind: VirtGuestKind.lxc,
          name: 'ct-01',
          node: 'pve',
          vmid: 201,
          cores: 1,
          memoryMiB: 512,
          storage: lvm,
          diskGiB: 8,
          media: VirtVolume(
            id: 'local:vztmpl/alpine-3.22.tar.xz',
            name: 'alpine-3.22.tar.xz',
            content: 'vztmpl',
          ),
          network: bridge,
          password: 'p4ss word&=',
          sshKeys: 'ssh-ed25519 AAAAC3Nza me@host\n',
        ),
      );
      expect(created.id, 'lxc/201');
      expect(api.paths, isNot(contains(startsWith('POST /nodes/pve/lxc/201/status'))));
      final body = form(api.bodies[api.paths.indexOf('POST /nodes/pve/lxc')]);
      expect(body, {
        'vmid': '201',
        'hostname': 'ct-01',
        'ostemplate': 'local:vztmpl/alpine-3.22.tar.xz',
        'cores': '1',
        'memory': '512',
        'rootfs': 'local-lvm:8',
        'unprivileged': '1',
        'net0': 'name=eth0,bridge=vmbr0,ip=dhcp',
        // In the body, encoded, as typed.
        'password': 'p4ss word&=',
        'ssh-public-keys': 'ssh-ed25519 AAAAC3Nza me@host',
      });
      // Nowhere else: not in a path, not in a query.
      expect(api.queries.join(), isNot(contains('p4ss')));
    });

    test('a VMID taken is exists; a bad parameter, the host\'s words', () async {
      final api = _Api()
        ..routes['POST /nodes/pve/qemu'] = ((_) => _Api._status(
          500,
          message: "unable to create VM 100 - VM 100 already exists on node 'pve'\n",
        ));
      const spec = VirtCreateSpec(
        kind: VirtGuestKind.qemu,
        name: 'x',
        node: 'pve',
        vmid: 100,
        cores: 1,
        memoryMiB: 512,
        storage: lvm,
        diskGiB: 1,
      );
      final pve = api.backend(token);
      final taken = await _err(pve.create(spec));
      expect(taken.type, VirtErrType.exists);
      expect(taken.message, contains('already exists'));

      api.routes['POST /nodes/pve/qemu'] = (_) => _Api._status(
        400,
        message: 'Parameter verification failed.\n',
        errors: {'memory': 'value must have a minimum value of 16\n'},
      );
      final bad = await _err(pve.create(spec));
      expect(bad.type, VirtErrType.actionFailed);
      expect(
        bad.message,
        'Parameter verification failed.\nmemory: value must have a minimum value of 16',
      );
    });

    test('created, then not started: a start error, not a failure', () async {
      final api = _Api()..actionStatus = 500;
      api.routes['POST /nodes/pve/qemu'] = (_) => _Api.upid;
      final created = await api.backend(token).create(
        const VirtCreateSpec(
          kind: VirtGuestKind.qemu,
          name: 'x',
          node: 'pve',
          vmid: 106,
          cores: 1,
          memoryMiB: 512,
          storage: lvm,
          diskGiB: 1,
          start: true,
        ),
      );
      expect(created.id, 'qemu/106');
      expect(created.startError, isNotNull);
    });

    test('delete: stopped only, purged, unreferenced disks too', () async {
      final api = _Api()..routes['DELETE /nodes/pve/qemu/101'] = (_) => _Api.upid;
      final pve = api.backend(token);
      const off = VirtGuest(
        id: 'qemu/101',
        name: 'off',
        kind: VirtGuestKind.qemu,
        state: VirtGuestState.stopped,
        vmid: 101,
        node: 'pve',
      );
      await pve.delete(off);
      final i = api.paths.indexOf('DELETE /nodes/pve/qemu/101');
      expect(
        Uri.splitQueryString(api.queries[i]),
        {'purge': '1', 'destroy-unreferenced-disks': '1'},
      );
      expect(api.paths.last, contains('/tasks/'));

      final running = off.copyWith(state: VirtGuestState.running);
      expect((await _err(pve.delete(running))).type, VirtErrType.unsupported);
    });
  });

  group('cloud images and cloud-init', () {
    const token = PveConfig(
      addr: 'https://pve.lan:8006',
      auth: PveAuth.token,
      tokenId: 'root@pam!sb',
      tokenSecret: 's3cret',
    );
    Map<String, String> form(String body) => Uri.splitQueryString(body);

    test('an import image\'s listing size is its file\'s: the virtual size '
        'is asked for', () async {
      final api = _Api();
      api.routes['GET /nodes/pve/storage/local/content'] = (_) => [
        {'volid': 'local:import/debian-13.qcow2', 'content': 'import', 'format': 'qcow2', 'size': 340983808},
        {'volid': 'local:import/alpine.raw', 'content': 'import', 'format': 'raw', 'size': 1 << 30},
        {'volid': 'local:iso/x.iso', 'content': 'iso', 'format': 'iso', 'size': 1000},
      ];
      api.routes['GET /nodes/pve/storage/local/content/${Uri.encodeComponent('local:import/debian-13.qcow2')}'] =
          (_) => {'size': 3221225472, 'used': 340983808, 'format': 'qcow2', 'path': '/var/lib/vz/import/debian-13.qcow2'};
      final vols = await api.backend(token).volumes(
        const VirtStoragePool(id: 'pve/local', name: 'local', type: 'dir', node: 'pve'),
      );
      final by = {for (final v in vols) v.name: v};
      expect(by['debian-13.qcow2']!.capacity, 3 << 30);
      expect(by['debian-13.qcow2']!.allocation, 340983808);
      // A raw image's file is its size; nothing asked for it or the ISO.
      expect(by['alpine.raw']!.capacity, 1 << 30);
      expect(by['x.iso']!.capacity, 1000);
      expect(api.paths.where((p) => p.contains('/content/')), hasLength(1));
    });

    test('an image PVE will not size stays unknown', () async {
      final api = _Api();
      api.routes['GET /nodes/pve/storage/local/content'] = (_) => [
        {'volid': 'local:import/a.qcow2', 'content': 'import', 'format': 'qcow2', 'size': 10},
      ];
      api.routes['GET /nodes/pve/storage/local/content/${Uri.encodeComponent('local:import/a.qcow2')}'] =
          (_) => _Api._status(403, message: 'Permission check failed');
      final vols = await api.backend(token).volumes(
        const VirtStoragePool(id: 'pve/local', name: 'local', type: 'dir', node: 'pve'),
      );
      expect(vols.single.capacity, isNull);
    });

    const vm = VirtGuest(
      id: 'qemu/950',
      name: 'ci',
      kind: VirtGuestKind.qemu,
      state: VirtGuestState.running,
      vmid: 950,
      node: 'pve',
    );
    Map<String, Object?> config() => {
      'ciuser': 'sbxe',
      'cipassword': '**********',
      'sshkeys': Uri.encodeComponent('ssh-ed25519 AAAA one\nssh-ed25519 BBBB two\n'),
      'ipconfig0': 'ip=10.0.0.5/24,gw=10.0.0.1,ip6=auto',
      'nameserver': '1.1.1.1 9.9.9.9',
      'searchdomain': 'lab.example',
      'net0': 'virtio=BC:24:11:00:00:01,bridge=vmbr0',
      'scsi1': 'local-lvm:vm-950-cloudinit,media=cdrom',
      'digest': 'd1',
    };

    test('read: ci options, the password only as set', () async {
      final api = _Api()..routes['GET /nodes/pve/qemu/950/config'] = (_) => config();
      final ci = await api.backend(token).cloudInit(vm);
      expect(ci.user, 'sbxe');
      expect(ci.sshKeys, ['ssh-ed25519 AAAA one', 'ssh-ed25519 BBBB two']);
      expect((ci.address, ci.gateway), ('10.0.0.5/24', '10.0.0.1'));
      expect(ci.dns, ['1.1.1.1', '9.9.9.9']);
      expect(ci.searchDomains, ['lab.example']);
      expect((ci.passwordSet, ci.network, ci.hostname), (true, true, null));
      expect(ci.revision, 'd1');
      expect('$ci', isNot(contains('**')));
      final dhcp = PveResources.parseCloudInit({'ipconfig0': 'ip=dhcp', 'digest': 'x'});
      expect((dhcp.address, dhcp.passwordSet, dhcp.network, dhcp.user), (null, false, false, ''));
    });

    test('write: the options with the digest, ip6 kept, emptied ones '
        'deleted, then the drive written again', () async {
      final api = _Api()
        ..routes['GET /nodes/pve/qemu/950/config'] = ((_) => config())
        ..routes['POST /nodes/pve/qemu/950/config'] = ((_) => _Api.upid)
        ..routes['PUT /nodes/pve/qemu/950/cloudinit'] = ((_) => null);
      final pve = api.backend(token);
      final base = await pve.cloudInit(vm);
      await pve.setCloudInit(
        vm,
        base,
        const VirtCloudInitEdit(
          VirtCloudInit(user: 'ops', sshKeys: 'ssh-ed25519 CCCC three'),
          removePassword: true,
        ),
      );
      final i = api.paths.indexOf('POST /nodes/pve/qemu/950/config');
      expect(form(api.bodies[i]), {
        'ciuser': 'ops',
        'sshkeys': Uri.encodeComponent('ssh-ed25519 CCCC three\n'),
        'ipconfig0': 'ip=dhcp,ip6=auto',
        'delete': 'cipassword,nameserver,searchdomain',
        'digest': 'd1',
      });
      expect(api.paths.indexOf('PUT /nodes/pve/qemu/950/cloudinit'), greaterThan(i));

      // A new password and a static address; the password is kept where
      // none is typed and it is not removed.
      await pve.setCloudInit(
        vm,
        base,
        const VirtCloudInitEdit(
          VirtCloudInit(user: 'ops', password: 'n e&w', address: '10.0.0.9/24', gateway: '10.0.0.254', dns: ['8.8.8.8']),
        ),
      );
      final j = api.paths.lastIndexOf('POST /nodes/pve/qemu/950/config');
      expect(form(api.bodies[j]), {
        'ciuser': 'ops',
        'cipassword': 'n e&w',
        'ipconfig0': 'ip=10.0.0.9/24,gw=10.0.0.254,ip6=auto',
        'nameserver': '8.8.8.8',
        'delete': 'sshkeys,searchdomain',
        'digest': 'd1',
      });
    });

    test('write from a stale read: a conflict', () async {
      final api = _Api()
        ..routes['GET /nodes/pve/qemu/950/config'] = ((_) => config())
        ..routes['POST /nodes/pve/qemu/950/config'] = ((_) => _Api._status(
          500,
          message: 'checksum mismatch (file change by other user?)',
        ));
      final pve = api.backend(token);
      final e = await _err(
        pve.setCloudInit(vm, await pve.cloudInit(vm), const VirtCloudInitEdit(VirtCloudInit(user: 'x', password: 'y'))),
      );
      expect(e.type, VirtErrType.conflict);
      expect(api.paths.where((p) => p.endsWith('/cloudinit')), isEmpty);
    });
  });

  group('clone and backups', () {
    Object? fixture(String name) =>
        jsonDecode(File('test/fixtures/pve/$name').readAsStringSync());
    Map<String, String> form(String body) => Uri.splitQueryString(body);
    const token = PveConfig(
      addr: 'https://pve.lan:8006',
      auth: PveAuth.token,
      tokenId: 'root@pam!sb',
      tokenSecret: 's3cret',
    );
    const vm = VirtGuest(
      id: 'qemu/9941',
      name: 'sbbk-src',
      kind: VirtGuestKind.qemu,
      state: VirtGuestState.stopped,
      vmid: 9941,
      node: 'pve',
    );
    const ct = VirtGuest(
      id: 'lxc/200',
      name: 'alpine',
      kind: VirtGuestKind.lxc,
      state: VirtGuestState.stopped,
      vmid: 200,
      node: 'pve',
    );

    test('backups and jobs, as PVE 9.2 lists them', () {
      final backups = PveResources.parseBackups(
        'pve',
        'local',
        fixture('backup_content.json')! as List,
      );
      final b = backups.single;
      expect(b.id, 'local:backup/vzdump-qemu-9941-2026_09_26-03_11_45.vma.zst');
      expect(b.fileName, 'vzdump-qemu-9941-2026_09_26-03_11_45.vma.zst');
      expect((b.storage, b.node, b.vmid), ('local', 'pve', 9941));
      expect((b.size, b.format, b.notes), (37103, 'vma.zst', 'sb e2e 9941'));
      expect(b.kind, VirtGuestKind.qemu);
      expect(b.createdAt, DateTime.fromMillisecondsSinceEpoch(1790363505000));
      expect(b.protected, isFalse);

      final raw = fixture('backup_jobs.json')! as List;
      final job = PveResources.parseBackupJobs(raw, vmid: 9941).single;
      expect(
        (job.id, job.schedule, job.storage, job.mode, job.compress, job.keep),
        ('sbbk-job', '02:00', 'local', 'snapshot', 'zstd', 'keep-last=7'),
      );
      expect(job.enabled, isFalse);
      expect(PveResources.parseBackupJobs(raw, vmid: 100), isEmpty);
      // Every guest, less the excluded ones.
      final all = [
        {'id': 'all', 'type': 'vzdump', 'all': 1, 'exclude': '101'},
      ];
      expect(PveResources.parseBackupJobs(all, vmid: 100), hasLength(1));
      expect(PveResources.parseBackupJobs(all, vmid: 101), isEmpty);
    });

    test('a guest\'s plan leaves out the jobs restricted to another node',
        () async {
      final api = _Api()
        ..routes['GET /cluster/backup'] = ((_) => [
          {'id': 'on-a', 'type': 'vzdump', 'all': 1, 'node': 'a'},
          {'id': 'on-b', 'type': 'vzdump', 'all': 1, 'node': 'pve'},
          {'id': 'any', 'type': 'vzdump', 'vmid': '9941'},
          {'id': 'listed-on-a', 'type': 'vzdump', 'vmid': '9941', 'node': 'a'},
        ]);
      final jobs = await api.backend(token).backupJobs(vm);
      expect(jobs.map((j) => j.id), ['on-b', 'any']);
      expect(
        PveResources.parseBackupJobs(
          [
            {'id': 'on-a', 'type': 'vzdump', 'all': 1, 'node': 'a'},
          ],
          vmid: 9941,
          node: 'pve',
        ),
        isEmpty,
      );
    });

    test('clone: full unless a template asks for linked; a VMID taken', () async {
      final api = _Api();
      api.routes['GET /cluster/nextid'] = (_) => '120';
      api.routes['POST /nodes/pve/qemu/9941/clone'] = (_) => _Api.upid;
      api.routes['POST /nodes/pve/lxc/200/clone'] = (_) => _Api.upid;
      final pve = api.backend(token);
      expect(
        await pve.clone(vm, const VirtCloneRequest(name: 'copy', full: false)),
        'qemu/120',
      );
      var i = api.paths.indexOf('POST /nodes/pve/qemu/9941/clone');
      expect(form(api.bodies[i]), {'newid': '120', 'name': 'copy', 'full': '1'});
      expect(api.paths.last, contains('/tasks/'), reason: 'waited for');

      final template = vm.copyWith(template: true);
      await pve.clone(template, const VirtCloneRequest(name: 'l', full: false, vmid: 121));
      i = api.paths.lastIndexOf('POST /nodes/pve/qemu/9941/clone');
      expect(form(api.bodies[i]), {'newid': '121', 'name': 'l', 'full': '0'});

      expect(
        await pve.clone(ct, const VirtCloneRequest(name: 'ct2', vmid: 202)),
        'lxc/202',
      );
      i = api.paths.indexOf('POST /nodes/pve/lxc/200/clone');
      expect(form(api.bodies[i]), {'newid': '202', 'hostname': 'ct2', 'full': '1'});

      api.routes['POST /nodes/pve/qemu/9941/clone'] = (_) => _Api._status(
        500,
        message: "unable to create VM 120 - VM 120 already exists on node 'pve'",
      );
      final taken = await _err(pve.clone(vm, const VirtCloneRequest(name: 'x', vmid: 120)));
      expect(taken.type, VirtErrType.exists);
    });

    test('a job keeps the one selection it has: pool, all or a list', () async {
      final api = _Api();
      api.routes['PUT /cluster/backup/j1'] = (_) => null;
      final pve = api.backend(token);
      VirtBackupJobEdit edit({String? pool, bool all = false, List<int> vmids = const [], List<int> exclude = const []}) =>
          VirtBackupJobEdit(
            id: 'j1',
            node: null,
            storage: 'local',
            schedule: 'sat 03:00',
            pool: pool,
            all: all,
            vmids: vmids,
            exclude: exclude,
          );
      Map<String, String> sent() =>
          form(api.bodies[api.paths.lastIndexOf('PUT /cluster/backup/j1')]);
      Set<String> deleted() => sent()['delete']!.split(',').toSet();

      // A pool job saved with only its schedule changed stays a pool job.
      await pve.editBackupJob(edit(pool: 'prod', all: true, vmids: [1]));
      expect(sent()['pool'], 'prod');
      expect(sent()['all'], '0');
      expect(sent().containsKey('vmid'), isFalse);
      expect(deleted(), containsAll(['vmid', 'exclude']));
      expect(deleted(), isNot(contains('pool')));

      await pve.editBackupJob(edit(all: true, exclude: [101, 102]));
      expect(sent()['all'], '1');
      expect(sent()['exclude'], '101,102');
      expect(deleted(), containsAll(['vmid', 'pool']));
      expect(deleted(), isNot(contains('exclude')));

      // A list is sent and not deleted in the same request.
      await pve.editBackupJob(edit(vmids: [100, 200]));
      expect(sent()['vmid'], '100,200');
      expect(sent()['all'], '0');
      expect(deleted(), containsAll(['exclude', 'pool']));
      expect(deleted(), isNot(contains('vmid')));
    });

    test("a template PVE refuses itself: the action refused, in PVE's words", () async {
      final api = _Api();
      api.resources = [
        {'id': 'node/pve', 'type': 'node', 'node': 'pve', 'status': 'online'},
        {'id': 'qemu/9', 'type': 'qemu', 'vmid': 9, 'node': 'pve', 'status': 'stopped', 'name': 'a'},
      ];
      // PVE 9.2.2, answered before any task.
      api.routes['POST /nodes/pve/qemu/9/template'] = (_) => _Api._status(
        500,
        message: 'unable to create template, because VM contains snapshots',
      );
      final pve = api.backend(token);
      final vm = (await pve.load()).guests.single;
      final e = await _err(pve.makeTemplate(vm));
      expect(e.type, VirtErrType.actionFailed);
      expect(e.message, 'unable to create template, because VM contains snapshots');
    });

    test("run now: the job's node, or every online node", () async {
      final api = _Api();
      api.resources = [
        {'id': 'node/pve', 'type': 'node', 'node': 'pve', 'status': 'online'},
        {'id': 'node/pve2', 'type': 'node', 'node': 'pve2', 'status': 'online'},
        {'id': 'node/pve3', 'type': 'node', 'node': 'pve3', 'status': 'offline'},
        {'id': 'qemu/9', 'type': 'qemu', 'vmid': 9, 'node': 'pve2', 'status': 'stopped'},
      ];
      for (final n in ['pve', 'pve2', 'pve3']) {
        api.routes['POST /nodes/$n/vzdump'] = (_) => _Api.upid;
      }
      final pve = api.backend(token);
      await pve.load();
      Iterable<String> runs() =>
          api.paths.where((p) => p.endsWith('/vzdump'));

      // No node: vzdump takes only the guests on the node it runs on, so
      // each online node is asked — the offline one is not.
      // The job as PVE has it, read again: what the model does not carry
      // (`bwlimit`, `performance`, ...) runs with it, as PVE's own "Run
      // now" sends it; what describes the schedule does not.
      var job = <String, Object?>{
        'id': 'j',
        'type': 'vzdump',
        'schedule': 'sat 03:00',
        'enabled': 0,
        'next-run': 1790967600,
        'comment': 'nightly',
        'storage': 'nfs',
        'all': 1,
        'exclude': '9',
        'bwlimit': 4096,
        'ionice': 5,
        'performance': {'max-workers': '2'},
        'prune-backups': {'keep-last': '2', 'keep-daily': '4'},
        'fleecing': {'enabled': 0},
      };
      api.routes['GET /cluster/backup/j'] = (_) => job;
      await pve.runBackupJob(const VirtBackupJob(id: 'j', all: true));
      expect(runs(), ['POST /nodes/pve/vzdump', 'POST /nodes/pve2/vzdump']);
      final body = form(api.bodies[api.paths.indexOf('POST /nodes/pve2/vzdump')]);
      expect(body, {
        'storage': 'nfs',
        'all': '1',
        'exclude': '9',
        'bwlimit': '4096',
        'ionice': '5',
        'performance': 'max-workers=2',
        'prune-backups': 'keep-last=2,keep-daily=4',
        'fleecing': 'enabled=0',
      });

      // A node of its own: there only, and refused when it is offline.
      api.paths.clear();
      api.bodies.clear();
      job = {'id': 'j', 'type': 'vzdump', 'storage': 'nfs', 'node': 'pve2', 'pool': 'prod'};
      await pve.runBackupJob(const VirtBackupJob(id: 'j'));
      expect(runs(), ['POST /nodes/pve2/vzdump']);
      expect(
        form(api.bodies[api.paths.lastIndexOf('POST /nodes/pve2/vzdump')]),
        containsPair('pool', 'prod'),
      );
      api.paths.clear();
      api.bodies.clear();
      job = {'id': 'j', 'type': 'vzdump', 'node': 'pve3', 'all': 1};
      final e = await _err(pve.runBackupJob(const VirtBackupJob(id: 'j')));
      expect(e.type, VirtErrType.unsupported);
      expect(runs(), isEmpty);
    });

    test('back up now, list, restore over and as new, delete', () async {
      final api = _Api();
      api.routes['GET /nodes/pve/storage'] = (_) => [
        {'storage': 'local', 'type': 'dir', 'active': 1, 'enabled': 1, 'content': 'iso,backup'},
        {'storage': 'nfs', 'type': 'nfs', 'active': 1, 'enabled': 1, 'content': 'backup'},
      ];
      api.routes['GET /nodes/pve/storage/local/content'] =
          (_) => fixture('backup_content.json');
      api.routes['GET /nodes/pve/storage/nfs/content'] = (_) => [
        {
          'volid': 'nfs:backup/vzdump-qemu-9941-2026_09_27-02_00_00.vma.zst',
          'content': 'backup',
          'ctime': 1790450000,
          'protected': 1,
          'verification': {'state': 'ok'},
          'subtype': 'qemu',
          'vmid': 9941,
        },
      ];
      api.routes['POST /nodes/pve/vzdump'] = (_) => _Api.upid;
      api.routes['POST /nodes/pve/qemu'] = (_) => _Api.upid;
      api.routes['POST /nodes/pve/lxc'] = (_) => _Api.upid;
      final pve = api.backend(token);

      final storages = await pve.backupStorages(vm);
      expect(storages.map((s) => s.name), ['local', 'nfs']);
      final i0 = api.paths.indexOf('GET /nodes/pve/storage');
      expect(Uri.splitQueryString(api.queries[i0]), {'content': 'backup', 'enabled': '1'});

      final backups = await pve.backups(vm);
      expect(backups.map((b) => b.storage), ['nfs', 'local'], reason: 'newest first');
      expect(backups.first.protected, isTrue);
      expect(backups.first.verification, 'ok');
      final ic = api.paths.indexOf('GET /nodes/pve/storage/local/content');
      expect(Uri.splitQueryString(api.queries[ic]), {'content': 'backup', 'vmid': '9941'});

      await pve.backup(
        vm,
        const VirtBackupRequest(storage: 'local', mode: 'stop', notes: ' n ', protected: true),
      );
      var i = api.paths.indexOf('POST /nodes/pve/vzdump');
      expect(form(api.bodies[i]), {
        'vmid': '9941',
        'storage': 'local',
        'mode': 'stop',
        'compress': 'zstd',
        'notes-template': 'n',
        'protected': '1',
      });
      expect(api.paths.last, contains('/tasks/'));

      final local = backups.last;
      await pve.restoreBackup(vm, local);
      i = api.paths.indexOf('POST /nodes/pve/qemu');
      expect(form(api.bodies[i]), {'vmid': '9941', 'archive': local.id, 'force': '1'});
      await pve.restoreBackup(vm, local, vmid: 130);
      i = api.paths.lastIndexOf('POST /nodes/pve/qemu');
      expect(form(api.bodies[i]), {'vmid': '130', 'archive': local.id});
      // Over a running guest: refused here, not forced.
      final running = vm.copyWith(state: VirtGuestState.running);
      expect(
        (await _err(pve.restoreBackup(running, local))).type,
        VirtErrType.unsupported,
      );
      // A container's archive is its template, restored.
      final ctBackup = local.copyWith(id: 'local:backup/vzdump-lxc-200-x.tar.zst', kind: VirtGuestKind.lxc);
      await pve.restoreBackup(ct, ctBackup);
      i = api.paths.indexOf('POST /nodes/pve/lxc');
      expect(form(api.bodies[i]), {
        'vmid': '200',
        'ostemplate': ctBackup.id,
        'restore': '1',
        'force': '1',
      });

      final del =
          'DELETE /nodes/pve/storage/local/content/${Uri.encodeComponent(local.id)}';
      api.routes[del] = (_) => _Api.upid;
      await pve.deleteBackup(vm, local);
      expect(api.paths, contains(del));
    });
  });

  group('hardware', () {
    Object? fixture(String name) =>
        jsonDecode(File('test/fixtures/pve/$name').readAsStringSync());
    Map<String, Object?> config(String name) =>
        (fixture(name)! as Map).cast<String, Object?>();

    const token = PveConfig(
      addr: 'https://pve.lan:8006',
      auth: PveAuth.token,
      tokenId: 'root@pam!sb',
      tokenSecret: 's',
    );
    const vm = VirtGuest(
      id: 'qemu/9901',
      name: 'sbhw-e2e-vm',
      kind: VirtGuestKind.qemu,
      state: VirtGuestState.running,
      vmid: 9901,
      node: 'pve',
    );
    const ct = VirtGuest(
      id: 'lxc/9902',
      name: 'sbhw-e2e-ct',
      kind: VirtGuestKind.lxc,
      state: VirtGuestState.running,
      vmid: 9902,
      node: 'pve',
    );

    /// Captured from PVE 9.2 with cores, memory and the boot order pending,
    /// a hot-plugged NIC disconnected behind the firewall, and a CPU model
    /// with a flag.
    VirtHardware vmHardware() => PveResources.parseHardware(
      config: config('hw_vm_config.json'),
      pending: fixture('hw_vm_pending.json')! as List,
      kind: VirtGuestKind.qemu,
      running: true,
      limits: const VirtHwLimits(hostCpus: 12, hostMemoryBytes: 16 << 30),
    );

    test('a VM: the next start\'s values, and what is pending', () {
      final hw = vmHardware();
      expect((hw.cpu.sockets, hw.cpu.cores, hw.cpu.type), (1, 2, 'host'));
      expect((hw.memory.mib, hw.memory.minMib, hw.memory.balloon), (768, 256, true));
      expect(hw.disk('scsi0')!.size, 1 << 30);
      expect(hw.disk('scsi0')!.storage, 'local-lvm');
      expect(hw.disk('ide2')!.kind, VirtHwDiskKind.cdrom);
      expect(hw.disk('ide2')!.source, isNull);
      final net1 = hw.nic('net1')!;
      expect((net1.linkUp, net1.firewall, net1.mac), (false, true, 'BC:24:11:DE:00:BF'));
      expect(hw.nic('net0')!.firewall, isFalse);
      expect(hw.boot, ['scsi0', 'ide2', 'net0']);
      expect(hw.autostart, isFalse);
      final pending = {for (final p in hw.pending) p.key: p};
      expect(pending['cores']?.current, '1');
      expect(pending['cores']?.pending, '2');
      expect(pending.keys, containsAll(['memory', 'boot']));
      // Not pending: applied at once (the NIC was hot-plugged).
      expect(pending.keys, isNot(contains('net1')));
      expect(pending.keys, isNot(contains('digest')));
      expect(hw.revision, '698abb29c27485d3497f5b7a8ca4b6b2789c1cd1');
      expect(hw.configText, contains('cpu: host,flags=+aes'));
      expect(hw.configText, isNot(contains('digest')));
    });

    test('a container: resources, mount points, a removal pending', () {
      var hw = PveResources.parseHardware(
        config: config('hw_ct_config.json'),
        pending: fixture('hw_ct_pending.json')! as List,
        kind: VirtGuestKind.lxc,
        running: true,
      );
      expect((hw.cpu.cores, hw.memory.mib, hw.memory.swapMib), (2, 384, 128));
      expect(hw.boot, isNull);
      expect(hw.disk('rootfs')!.kind, VirtHwDiskKind.rootfs);
      expect(hw.disk('mp0')!.mountPoint, '/mnt/e2e');
      expect(hw.nic('net0')!.name, 'eth0');
      expect(hw.pending, isEmpty);

      // `delete=mp0` on a running container: gone from what the next start
      // gets, pending until then.
      hw = PveResources.parseHardware(
        config: config('hw_ct_config_mp_delete.json'),
        pending: fixture('hw_ct_pending_mp_delete.json')! as List,
        kind: VirtGuestKind.lxc,
        running: true,
      );
      expect(hw.disk('mp0'), isNull);
      final p = hw.pending.single;
      expect((p.key, p.delete), ('mp0', true));
      expect(p.current, contains('vm-9902-disk-1'));
    });

    test('option strings: what is not set stays, in its place', () {
      const net = 'virtio=BC:24:11:DE:00:BF,bridge=vmbr0,firewall=1,link_down=1';
      expect(
        PveResources.withOptions(net, {'bridge': 'vmbr1', 'link_down': null}),
        'virtio=BC:24:11:DE:00:BF,bridge=vmbr1,firewall=1',
      );
      expect(
        PveResources.withOptions('virtio=AA,bridge=vmbr0', {'link_down': '1'}),
        'virtio=AA,bridge=vmbr0,link_down=1',
      );
      expect(PveResources.withCpuType('host,flags=+aes', 'x86-64-v3'), 'x86-64-v3,flags=+aes');
      expect(PveResources.withCpuType('cputype=kvm64,hidden=1', 'host'), 'host,hidden=1');
      expect(PveResources.withCpuType(null, 'host'), 'host');
      expect(PveResources.sizeArg(2 << 30), '2G');
      expect(PveResources.sizeArg((1 << 30) + 1), '1048577K');
    });

    /// An API answering the hardware reads with the captures.
    _Api hwApi() => _Api()
      ..routes['GET /nodes/pve/qemu/9901/config'] = ((_) => fixture('hw_vm_config.json'))
      ..routes['GET /nodes/pve/qemu/9901/pending'] = ((_) => fixture('hw_vm_pending.json'))
      ..routes['GET /nodes/pve/status'] = ((_) => {
        'cpuinfo': {'cpus': 12},
        'memory': {'total': 16627777536},
      })
      ..routes['GET /nodes/pve/capabilities/qemu/cpu'] = ((_) => [
        {'name': 'x86-64-v3', 'custom': 0},
        {'name': 'host', 'custom': 0},
      ])
      ..routes['POST /nodes/pve/qemu/9901/config'] = ((_) => _Api.upid)
      ..routes['PUT /nodes/pve/lxc/9902/config'] = ((_) => null)
      ..routes['PUT /nodes/pve/qemu/9901/resize'] = ((_) => _Api.upid);

    Map<String, String> sent(_Api api, String key) {
      final i = api.paths.lastIndexOf(key);
      expect(i, isNot(-1), reason: '$key not sent: ${api.paths}');
      return Uri.splitQueryString(api.bodies[i]);
    }

    test('read: the node\'s limits and CPU models, sorted', () async {
      final hw = await hwApi().backend(token).hardware(vm);
      expect(hw.limits.hostCpus, 12);
      expect(hw.limits.hostMemoryBytes, 16627777536);
      expect(hw.cpuTypes, ['host', 'x86-64-v3']);
    });

    test('read: a token without Sys.Audit on the node still reads the guest',
        () async {
      final api = hwApi()
        ..routes['GET /nodes/pve/status'] = ((_) => _Api._status(403))
        ..routes['GET /nodes/pve/capabilities/qemu/cpu'] = ((_) => _Api._status(403));
      final hw = await api.backend(token).hardware(vm);
      expect(hw.limits.hostCpus, isNull);
      expect(hw.cpuTypes, isEmpty);
      expect(hw.cpu.cores, 2);
    });

    test('every change carries the digest it was made from', () async {
      final api = hwApi();
      final pve = api.backend(token);
      final hw = await pve.hardware(vm);
      await pve.changeHardware(vm, hw, const VirtHwSetCpu(sockets: 2, cores: 2, type: 'x86-64-v3'));
      expect(sent(api, 'POST /nodes/pve/qemu/9901/config'), {
        'sockets': '2',
        'cores': '2',
        // The model changes, its flag stays.
        'cpu': 'x86-64-v3,flags=+aes',
        'digest': hw.revision,
      });
      await pve.changeHardware(vm, hw, const VirtHwSetMemory(mib: 1024));
      expect(sent(api, 'POST /nodes/pve/qemu/9901/config'), {
        'memory': '1024',
        // No floor any more: the default, the whole memory.
        'delete': 'balloon',
        'digest': hw.revision,
      });
      await pve.changeHardware(vm, hw, VirtHwUpdateNic(key: 'net1', linkUp: true, network: _bridge('vmbr1')));
      expect(
        sent(api, 'POST /nodes/pve/qemu/9901/config')['net1'],
        'virtio=BC:24:11:DE:00:BF,bridge=vmbr1,firewall=1',
      );
      await pve.changeHardware(vm, hw, const VirtHwSetBoot(['ide2', 'scsi0']));
      expect(sent(api, 'POST /nodes/pve/qemu/9901/config')['boot'], 'order=ide2;scsi0');
      await pve.changeHardware(vm, hw, const VirtHwRevert(['cores', 'memory']));
      expect(sent(api, 'POST /nodes/pve/qemu/9901/config')['revert'], 'cores,memory');
      await pve.changeHardware(vm, hw, const VirtHwGrowDisk(key: 'scsi0', bytes: 3 << 30));
      expect(sent(api, 'PUT /nodes/pve/qemu/9901/resize'), {
        'disk': 'scsi0',
        'size': '3G',
        'digest': hw.revision,
      });
      // A task each, waited for.
      expect(api.paths.last, contains('/tasks/'));
    });

    test('a new disk and NIC go in the first free slot', () async {
      final api = hwApi();
      final pve = api.backend(token);
      final hw = await pve.hardware(vm);
      await pve.changeHardware(
        vm,
        hw,
        VirtHwAddDisk(storage: _pool('local-lvm'), gib: 4),
      );
      expect(sent(api, 'POST /nodes/pve/qemu/9901/config')['scsi1'], 'local-lvm:4');
      await pve.changeHardware(vm, hw, VirtHwAddNic(network: _bridge('vmbr0')));
      expect(sent(api, 'POST /nodes/pve/qemu/9901/config')['net2'], 'virtio,bridge=vmbr0');
      await pve.changeHardware(
        vm,
        hw,
        VirtHwSetMedia(key: 'ide2', media: _iso('local:iso/a.iso')),
      );
      expect(sent(api, 'POST /nodes/pve/qemu/9901/config')['ide2'], 'local:iso/a.iso,media=cdrom');
      // A new drive: the first free IDE slot (ide2 is taken), empty or not.
      await pve.changeHardware(vm, hw, const VirtHwAddCdrom());
      expect(sent(api, 'POST /nodes/pve/qemu/9901/config')['ide0'], 'none,media=cdrom');
      await pve.changeHardware(vm, hw, VirtHwAddCdrom(media: _iso('local:iso/a.iso')));
      expect(sent(api, 'POST /nodes/pve/qemu/9901/config')['ide0'], 'local:iso/a.iso,media=cdrom');
    });

    test('a cloud-init drive is told apart from install media', () {
      final hw = PveResources.parseHardware(
        config: {
          ...config('hw_vm_config.json'),
          'ide2': 'local-lvm:vm-9901-cloudinit,media=cdrom',
          'ide0': 'local:9901/vm-9901-cloudinit.qcow2,media=cdrom',
          'ide3': 'local:iso/vm-1-cloudinit.iso,media=cdrom',
        },
        pending: const [],
        kind: VirtGuestKind.qemu,
        running: false,
      );
      expect(hw.disk('ide2')!.cloudInit, isTrue);
      expect(hw.disk('ide0')!.cloudInit, isTrue);
      // An ISO that happens to be named so is media.
      expect(hw.disk('ide3')!.cloudInit, isFalse);
    });

    test('a removed disk\'s volume: deleted as unused, or kept while in use',
        () async {
      final api = hwApi();
      final pve = api.backend(token);
      final hw = await pve.hardware(vm);
      // Detached: PVE lists the volume as unused, and deleting that deletes
      // it.
      final detached = Map.of(config('hw_vm_config.json'))
        ..remove('scsi0')
        ..['unused0'] = 'local-lvm:vm-9901-disk-0'
        ..['digest'] = 'after';
      var reads = 0;
      api.routes['GET /nodes/pve/qemu/9901/config'] = (_) =>
          reads++ == 0 ? config('hw_vm_config.json') : detached;
      var out = await pve.changeHardware(
        vm,
        hw,
        const VirtHwRemoveDisk(key: 'scsi0', deleteVolume: true),
      );
      expect(out.volumeKept, isFalse);
      final bodies = [
        for (final (i, p) in api.paths.indexed)
          if (p == 'POST /nodes/pve/qemu/9901/config')
            Uri.splitQueryString(api.bodies[i]),
      ];
      expect(bodies[0]['delete'], 'scsi0');
      expect(bodies[1], {'delete': 'unused0', 'digest': 'after'});

      // Still attached (pending until the guest stops): kept.
      reads = 0;
      api.routes['GET /nodes/pve/qemu/9901/config'] = (_) => config('hw_vm_config.json');
      out = await pve.changeHardware(
        vm,
        hw,
        const VirtHwRemoveDisk(key: 'scsi0', deleteVolume: true),
      );
      expect(out.volumeKept, isTrue);
    });

    test('a volume written as `file=`, and a TPM state, are deleted with the '
        'digest of the configuration they were found in', () async {
      final api = hwApi();
      final pve = api.backend(token);
      final hw = await pve.hardware(vm);
      final before = {
        ...config('hw_vm_config.json'),
        'scsi0': 'file=local-lvm:vm-9901-disk-0,size=1G',
        'tpmstate0': 'local-lvm:vm-9901-disk-7,size=4M,version=v2.0',
      };
      final detached = Map.of(before)
        ..remove('scsi0')
        ..remove('tpmstate0')
        ..['unused0'] = 'local-lvm:vm-9901-disk-0'
        ..['unused1'] = 'local-lvm:vm-9901-disk-7'
        ..['digest'] = 'after';
      var reads = 0;
      api.routes['GET /nodes/pve/qemu/9901/config'] = (_) =>
          (reads++).isEven ? before : detached;
      List<Map<String, String>> bodies() => [
        for (final (i, p) in api.paths.indexed)
          if (p == 'POST /nodes/pve/qemu/9901/config')
            Uri.splitQueryString(api.bodies[i]),
      ];

      final out = await pve.changeHardware(
        vm,
        hw,
        const VirtHwRemoveDisk(key: 'scsi0', deleteVolume: true),
      );
      expect(out.volumeKept, isFalse);
      expect(bodies().last, {'delete': 'unused0', 'digest': 'after'});

      await pve.changeHardware(
        vm,
        hw,
        const VirtHwRemoveDevice(key: 'tpmstate0'),
      );
      expect(bodies()[bodies().length - 2]['delete'], 'tpmstate0');
      expect(bodies().last, {'delete': 'unused1', 'digest': 'after'});
    });

    test('a container: PUT, a mount point and an interface named for it',
        () async {
      final api = hwApi()
        ..routes['GET /nodes/pve/lxc/9902/config'] = ((_) => fixture('hw_ct_config.json'))
        ..routes['GET /nodes/pve/lxc/9902/pending'] = ((_) => fixture('hw_ct_pending.json'));
      final pve = api.backend(token);
      final hw = await pve.hardware(ct);
      expect(api.paths, isNot(contains('GET /nodes/pve/capabilities/qemu/cpu')));
      await pve.changeHardware(ct, hw, const VirtHwSetMemory(mib: 512, swapMib: 0));
      expect(sent(api, 'PUT /nodes/pve/lxc/9902/config'), {
        'memory': '512',
        'swap': '0',
        'digest': hw.revision,
      });
      await pve.changeHardware(
        ct,
        hw,
        VirtHwAddDisk(storage: _pool('local-lvm'), gib: 2, mountPoint: '/srv'),
      );
      expect(sent(api, 'PUT /nodes/pve/lxc/9902/config')['mp1'], 'local-lvm:2,mp=/srv');
      await pve.changeHardware(ct, hw, VirtHwAddNic(network: _bridge('vmbr0')));
      expect(
        sent(api, 'PUT /nodes/pve/lxc/9902/config')['net1'],
        'name=eth1,bridge=vmbr0,ip=dhcp',
      );
    });

    test('settings: name, note (cleared by deleting it), protection',
        () async {
      final api = hwApi();
      final pve = api.backend(token);
      final hw = await pve.hardware(vm);
      await pve.changeHardware(vm, hw, const VirtHwSetName('web-03'));
      expect(sent(api, 'POST /nodes/pve/qemu/9901/config'), {
        'name': 'web-03',
        'digest': hw.revision,
      });
      await pve.changeHardware(vm, hw, const VirtHwSetDescription('a & b'));
      expect(sent(api, 'POST /nodes/pve/qemu/9901/config')['description'], 'a & b');
      await pve.changeHardware(vm, hw, const VirtHwSetDescription(''));
      expect(sent(api, 'POST /nodes/pve/qemu/9901/config'), {
        'delete': 'description',
        'digest': hw.revision,
      });
      await pve.changeHardware(vm, hw, const VirtHwSetProtection(true));
      expect(sent(api, 'POST /nodes/pve/qemu/9901/config')['protection'], '1');

      // A container's name is its hostname.
      final ctApi = hwApi()
        ..routes['GET /nodes/pve/lxc/9902/config'] = ((_) => config('hw_ct_config.json'))
        ..routes['GET /nodes/pve/lxc/9902/pending'] = ((_) => const <Object?>[]);
      final ctPve = ctApi.backend(token);
      final ctHw = await ctPve.hardware(ct);
      expect(ctHw.name, isNotNull);
      await ctPve.changeHardware(ct, ctHw, const VirtHwSetName('dns-02'));
      expect(sent(ctApi, 'PUT /nodes/pve/lxc/9902/config')['hostname'], 'dns-02');
    });

    test('a stale digest is a conflict; a bad value the host\'s words',
        () async {
      final api = hwApi();
      final pve = api.backend(token);
      final hw = await pve.hardware(vm);
      api.routes['POST /nodes/pve/qemu/9901/config'] = (_) => _Api._status(
        500,
        message: 'checksum mismatch (file change by other user?)\n',
      );
      final stale = await _err(pve.changeHardware(vm, hw, const VirtHwSetAutostart(true)));
      expect(stale.type, VirtErrType.conflict);
      api.routes['POST /nodes/pve/qemu/9901/config'] = (_) => _Api._status(
        400,
        message: 'Parameter verification failed.',
        errors: {'cores': 'value must have a minimum value of 1'},
      );
      final bad = await _err(pve.changeHardware(vm, hw, const VirtHwSetCpu(sockets: 1, cores: 1)));
      expect(bad.type, VirtErrType.actionFailed);
      expect(bad.message, contains('minimum value of 1'));
    });
  });

  group('snapshots, storage, networks', () {
    List<Object?> fixture(String name) =>
        jsonDecode(File('test/fixtures/pve/$name').readAsStringSync())
            as List<Object?>;

    const token = PveConfig(
      addr: 'https://pve.lan:8006',
      auth: PveAuth.token,
      tokenId: 'root@pam!sb',
      tokenSecret: 's3cret',
    );

    test('storage support: asked of the guest, refused before the task', () async {
      final api = _Api();
      api.routes['GET /nodes/pve/qemu/100/feature'] = (_) => {
        'hasFeature': 0,
        'nodes': ['pve'],
      };
      // Only the disks a snapshot takes name a storage: not a NIC's MAC, a
      // description with a colon, a CD-ROM or an unused volume.
      api.routes['GET /nodes/pve/qemu/100/config'] = (_) => {
        'scsi0': 'local-lvm:vm-100-disk-0,size=20G',
        'net0': 'virtio=BC:24:11:AA:BB:CC,bridge=vmbr0',
        'description': 'Note: prod',
        'ide2': 'local:iso/debian.iso,media=cdrom',
        'unused0': 'nfs:100/vm-100-disk-1.qcow2',
      };
      final backend = api.backend(token);
      const guest = VirtGuest(
        id: 'qemu/100',
        name: 'web-01',
        kind: VirtGuestKind.qemu,
        state: VirtGuestState.running,
        vmid: 100,
        node: 'pve',
      );
      expect(await backend.snapshotSupported(guest), isFalse);
      final refusal = await backend.snapshotRefusal(guest);
      expect(refusal, 'snapshot feature is not available: local-lvm');
      // The create is refused before any task is started, with the reason.
      final e = await _err(
        backend.createSnapshot(guest, name: 'pre-up'),
      );
      expect(e.type, VirtErrType.unsupported);
      expect(e.message, contains('snapshot feature is not available'));
      expect(api.paths, isNot(contains('POST /nodes/pve/qemu/100/snapshot')));

      // A guest whose storages do support it goes through.
      api.routes['GET /nodes/pve/qemu/100/feature'] = (_) => {'hasFeature': 1};
      api.routes['POST /nodes/pve/qemu/100/snapshot'] = (_) => _Api.upid;
      api.routes['GET /nodes/pve/qemu/100/status/current'] = (_) => {
        'status': 'running',
      };
      expect(await backend.snapshotSupported(guest), isTrue);
      expect(await backend.snapshotRefusal(guest), isNull);

      // A host that does not answer the question at all (an older PVE, or a
      // guest deleted since the last load) is "unknown", not "no".
      api.routes['GET /nodes/pve/qemu/100/feature'] = (_) => _Api._status(501);
      expect(await backend.snapshotSupported(guest), isNull);
      expect(await backend.snapshotRefusal(guest), isNull);
    });

    test('the config diff: the snapshot\'s own config against the guest\'s', () async {
      final api = _Api();
      api.routes['GET /nodes/pve/qemu/100/snapshot/sbx/config'] = (_) => {
        'cores': 1,
        'memory': '512',
        'scsi0': 'local-lvm:vm-100-disk-0,size=20G',
        'net0': 'virtio=BC:24:11:65:B0:B5,bridge=vmbr0',
        'description': 'before the bump',
        'snaptime': 1790415090,
        'digest': 'aa',
      };
      api.routes['GET /nodes/pve/qemu/100/config'] = (_) => {
        'cores': 2,
        'memory': '1024',
        'scsi0': 'local-lvm:vm-100-disk-0,size=20G',
        'net0': 'virtio=BC:24:11:65:B0:B5,bridge=vmbr1',
        'digest': 'bb',
        'parent': 'sbx',
      };
      final backend = api.backend(token);
      const guest = VirtGuest(
        id: 'qemu/100',
        name: 'web-01',
        kind: VirtGuestKind.qemu,
        state: VirtGuestState.running,
        vmid: 100,
        node: 'pve',
      );
      final diff = await backend.snapshotDiff(guest, 'sbx');
      // Grouped, and only what differs: the bookkeeping keys are left out.
      expect(
        diff.map((d) => (d.group, d.key, d.before, d.after)),
        [
          (VirtSnapDiffGroup.cpu, 'cores', '1', '2'),
          (VirtSnapDiffGroup.memory, 'memory', '512', '1024'),
          (
            VirtSnapDiffGroup.nics,
            'net0',
            'virtio=BC:24:11:65:B0:B5,bridge=vmbr0',
            'virtio=BC:24:11:65:B0:B5,bridge=vmbr1',
          ),
        ],
      );
      expect(diff.any((d) => d.key == 'digest'), isFalse);
      expect(diff.any((d) => d.key == 'description'), isFalse);
      // The disk is the same: no row for it.
      expect(diff.any((d) => d.key == 'scsi0'), isFalse);
    });

    test('the captured payloads: a real snapshot config against the current one', () {
      // `snapshot_config.json` / `snapshot_current_config.json` are PVE
      // 9.2.2's own answers for a VM whose memory was changed after the
      // snapshot was taken; `node_storage_p8.json` is the node's storage
      // list at the same moment.
      final snap = jsonDecode(
        File('test/fixtures/pve/snapshot_config.json').readAsStringSync(),
      ) as Map<String, Object?>;
      final cur = jsonDecode(
        File('test/fixtures/pve/snapshot_current_config.json').readAsStringSync(),
      ) as Map<String, Object?>;
      expect((snap['memory'], cur['memory']), ('512', '768'));
      // The storage list has no `snapshot` content kind: support follows the
      // storage's type, not its content.
      final storages = jsonDecode(
        File('test/fixtures/pve/node_storage_p8.json').readAsStringSync(),
      ) as List<Object?>;
      final parsed = PveResources.parseStorages('pve', storages);
      expect(parsed.map((p) => p.type), containsAll(['dir', 'lvmthin']));
      for (final p in parsed) {
        expect(p.content, isNot(contains('snapshot')));
      }
      expect(
        storages.whereType<Map>().map((e) => e['content']).join(),
        isNot(contains('snapshot')),
      );
    });

    test('a storage that does not support snapshots is a request PVE refuses', () {
      // What PVE answers for a raw disk on a directory storage, on the task:
      // the form's own check is what says so before it is started.
      expect(virtPveStorageMaySnapshot('dir'), isFalse);
      expect(virtPveStorageMaySnapshot('lvmthin'), isTrue);
      expect(virtPveStorageMaySnapshot('zfspool'), isTrue);
    });

    test('snapshot listing: the "current" entry marks, and is not one', () {
      final list = PveResources.parseSnapshots(fixture('snapshots_qemu.json'));
      expect(list.map((s) => s.name), ['sbx-disk', 'sbx-mem']);
      final disk = list.first;
      expect(disk.description, 'disk only');
      expect(disk.withMemory, isFalse);
      // After a rollback to it: `current`'s parent.
      expect(disk.current, isTrue);
      expect(
        disk.createdAt,
        DateTime.fromMillisecondsSinceEpoch(1790335982 * 1000),
      );
      final mem = list.last;
      expect(mem.withMemory, isTrue);
      expect(mem.parent, 'sbx-disk');
      expect(mem.current, isFalse);
      // An empty description is none.
      expect(mem.description, isNull);
      expect(PveResources.parseSnapshots(fixture('snapshots_none.json')), isEmpty);
    });

    test('storage: node figures with the cluster configuration', () {
      final pools = PveResources.parseStorages(
        'pve',
        fixture('node_storage.json'),
        config: fixture('storage_config.json'),
      );
      expect(pools.map((p) => p.id), ['pve/local', 'pve/local-lvm']);
      final local = pools.first;
      expect(local.type, 'dir');
      expect(local.path, '/var/lib/vz');
      expect(local.content, ['backup', 'import', 'iso', 'vztmpl']);
      expect(local.capacity, 105089261568);
      expect(local.shared, isFalse);
      final lvm = pools.last;
      expect(lvm.path, 'pve/data');
      expect(lvm.used, 4176431231);
      expect(lvm.available, 848156473217);
      expect(lvm.usedFraction, closeTo(0.0049, 0.0001));
      // Without the configuration (no Datastore.Audit on /storage): no path.
      final bare = PveResources.parseStorages('pve', fixture('node_storage.json'));
      expect(bare.first.path, isNull);
      // A network storage says where it comes from.
      final nfs = PveResources.parseStorages(
        'pve',
        [
          {'storage': 'nas', 'type': 'nfs', 'active': 0, 'content': 'backup'},
        ],
        config: [
          {
            'storage': 'nas',
            'type': 'nfs',
            'server': '10.0.0.5',
            'export': '/export/pve',
            'path': '/mnt/pve/nas',
          },
        ],
      ).single;
      expect(nfs.source, '10.0.0.5:/export/pve');
      expect(nfs.active, isFalse);
      expect(nfs.capacity, isNull);
    });

    test('content: names, kinds and owners', () {
      final vols = PveResources.parseContent(fixture('content_local_lvm.json'));
      expect(vols.map((v) => v.name), [
        'vm-100-cloudinit',
        'vm-100-disk-0',
        'vm-101-cloudinit',
        'vm-101-disk-0',
        'vm-101-state-sbx-mem',
        'vm-200-disk-0',
      ]);
      final disk = vols[1];
      expect(disk.id, 'local-lvm:vm-100-disk-0');
      expect(disk.capacity, 21474836480);
      expect(disk.users, [const VirtGuestRef(vmid: 100)]);
      // `ctime` arrives as a string for some storages.
      expect(disk.createdAt, isNotNull);
      final tmpl = PveResources.parseContent(fixture('content_local.json')).single;
      expect(tmpl.name, 'alpine-3.24-default_20260714_amd64.tar.xz');
      expect(tmpl.content, 'vztmpl');
      expect(tmpl.users, isEmpty);
    });

    test('network: bridges first, ports, and the guests on each', () {
      final nets = PveResources.parseNetworks(
        'pve',
        [
          ...fixture('network.json'),
          {
            'iface': 'bond0',
            'type': 'bond',
            'slaves': 'nic1 nic2',
            'bond_mode': '802.3ad',
            'active': 1,
          },
          {
            'iface': 'vmbr1',
            'type': 'bridge',
            'bridge_ports': 'bond0',
            'bridge_vlan_aware': 1,
            'comments': 'lab\n',
          },
          {
            'iface': 'vmbr1.10',
            'type': 'vlan',
            'vlan-id': '10',
            'vlan-raw-device': 'vmbr1',
            'cidr': '10.10.0.2/24',
          },
        ],
        users: {
          'vmbr0': [const VirtGuestRef(guestId: 'qemu/100', vmid: 100)],
        },
      );
      expect(nets.map((n) => n.name), [
        'vmbr0',
        'vmbr1',
        'bond0',
        'vmbr1.10',
        'nic0',
        'nic1',
        'wlp4s0',
      ]);
      final vmbr0 = nets.first;
      expect(vmbr0.id, 'pve/vmbr0');
      expect(vmbr0.cidrs, ['192.168.31.20/24']);
      expect(vmbr0.gateway, '192.168.31.1');
      expect(vmbr0.ports, ['nic0']);
      expect(vmbr0.active, isTrue);
      expect(vmbr0.autostart, isTrue);
      expect(vmbr0.vlanAware, isNull);
      expect(vmbr0.users.single.vmid, 100);
      expect(nets[1].vlanAware, isTrue);
      expect(nets[1].comment, 'lab');
      expect(nets[1].active, isFalse);
      expect(nets[2].ports, ['nic1', 'nic2']);
      expect(nets[2].bondMode, '802.3ad');
      expect(nets[3].vlanId, 10);
      expect(nets[3].vlanDevice, 'vmbr1');
    });

    test('bridge users from a guest configuration', () {
      final users = PveResources.bridgeUsers(
        const VirtGuest(
          id: 'lxc/200',
          name: 'ct',
          kind: VirtGuestKind.lxc,
          state: VirtGuestState.running,
          vmid: 200,
        ),
        {
          'net0':
              'name=eth0,bridge=vmbr0,hwaddr=BC:24:11:30:5B:A7,ip=dhcp,type=veth',
          'net1': 'name=eth1,bridge=vmbr1,hwaddr=BC:24:11:30:5B:A8',
          'rootfs': 'local-lvm:vm-200-disk-0,size=4G',
        },
      );
      expect(users.keys, unorderedEquals(['vmbr0', 'vmbr1']));
      expect(
        users['vmbr0'],
        [
          const VirtGuestRef(
            guestId: 'lxc/200',
            vmid: 200,
            device: 'net0',
            mac: 'bc:24:11:30:5b:a7',
          ),
        ],
      );
    });

    test('snapshot requests: create, rollback and delete wait for their task',
        () async {
      final api = _Api()..resources = _resources;
      api.routes['POST /nodes/pve/qemu/102/snapshot'] = (_) => _Api.upid;
      api.routes['POST /nodes/pve/lxc/100/snapshot'] = (_) => _Api.upid;
      api.routes['POST /nodes/pve/qemu/102/snapshot/pre-up/rollback'] =
          (_) => _Api.upid;
      api.routes['DELETE /nodes/pve/qemu/102/snapshot/pre-up'] =
          (_) => _Api.upid;
      api.current = {'status': 'stopped'};
      final pve = api.backend(token);
      final guests = (await pve.load()).guests;
      final vm = guests.firstWhere((g) => g.id == 'qemu/102');
      final ct = guests.firstWhere((g) => g.id == 'lxc/100');

      await pve.createSnapshot(
        vm,
        name: 'pre-up',
        description: ' before ',
        memory: true,
      );
      expect(api.bodies[api.paths.indexOf('POST /nodes/pve/qemu/102/snapshot')],
          'snapname=pre-up&description=before&vmstate=1');
      expect(api.paths.last, startsWith('GET /nodes/pve/tasks/'));

      // A container has no memory to save, whatever is asked.
      await pve.createSnapshot(ct, name: 'pre-up', memory: true);
      expect(
        api.bodies[api.paths.indexOf('POST /nodes/pve/lxc/100/snapshot')],
        'snapname=pre-up',
      );

      // The start is a task of its own, holding the guest's lock: waited for.
      api.routes['GET /nodes/pve/tasks'] = (_) => [
        {'type': 'vncproxy', 'upid': 'UPID:other'},
        {'type': 'qmstart', 'upid': 'UPID:pve:9:9:9:qmstart:102:root@pam:'},
      ];
      await pve.revertSnapshot(vm, 'pre-up', start: true);
      expect(
        api.bodies[api.paths.indexOf(
          'POST /nodes/pve/qemu/102/snapshot/pre-up/rollback',
        )],
        'start=1',
      );
      expect(
        api.paths,
        contains(
          'GET /nodes/pve/tasks/${Uri.encodeComponent('UPID:pve:9:9:9:qmstart:102:root@pam:')}/status',
        ),
      );
      // The state after it is read, as after a power action.
      expect(api.paths.last, 'GET /nodes/pve/qemu/102/status/current');

      await pve.deleteSnapshot(vm, 'pre-up');
      expect(api.paths, contains('DELETE /nodes/pve/qemu/102/snapshot/pre-up'));

      expect(
        (await _err(pve.createSnapshot(vm, name: '1bad'))).type,
        VirtErrType.unsupported,
      );
    });

    test('a snapshot task that fails is actionFailed with its exit', () async {
      final api = _Api()
        ..resources = _resources
        ..taskExit = "snapshot name 'pre-up' already used";
      api.routes['POST /nodes/pve/qemu/102/snapshot'] = (_) => _Api.upid;
      final pve = api.backend(token);
      final vm = (await pve.load()).guests.firstWhere((g) => g.id == 'qemu/102');
      final e = await _err(pve.createSnapshot(vm, name: 'pre-up'));
      expect(e.type, VirtErrType.actionFailed);
      expect(e.message, "snapshot name 'pre-up' already used");
    });

    test('storage without /storage access still lists, without paths',
        () async {
      final api = _Api()..resources = _resources;
      api.routes['GET /storage'] = (_) => _Api._status(403);
      api.routes['GET /nodes/pve/storage'] = (_) => fixture('node_storage.json');
      api.routes['GET /nodes/pve/storage/local-lvm/content'] =
          (_) => fixture('content_local_lvm.json');
      final pve = api.backend(token);
      await pve.load();
      final pools = await pve.storagePools();
      expect(pools.map((p) => p.name), ['local', 'local-lvm']);
      expect(pools.first.path, isNull);
      final vols = await pve.volumes(pools.last);
      expect(vols, hasLength(6));
    });

    test("networks: each guest's configuration says which bridge", () async {
      final api = _Api()..resources = _resources;
      api.routes['GET /nodes/pve/network'] = (_) => fixture('network.json');
      for (final g in ['lxc/100', 'qemu/101', 'qemu/102', 'qemu/103', 'qemu/9000', 'qemu/104']) {
        api.routes['GET /nodes/pve/$g/config'] = (_) => {
          'net0': g.startsWith('lxc')
              ? 'name=eth0,bridge=vmbr0,hwaddr=BC:24:11:00:00:01,type=veth'
              : 'virtio=BC:24:11:00:00:02,bridge=vmbr0',
        };
      }
      // One guest this account may not read: left out, not a failure.
      api.routes['GET /nodes/pve/qemu/104/config'] = (_) => _Api._status(403);
      final pve = api.backend(token);
      await pve.load();
      final nets = await pve.networks();
      final vmbr0 = nets.firstWhere((n) => n.name == 'vmbr0');
      expect(vmbr0.users.map((u) => u.vmid), [100, 101, 102, 103, 9000]);
      expect(nets.firstWhere((n) => n.name == 'nic0').users, isEmpty);
    });
  });

  group('hardware: devices, firmware, display', () {
    Object? fixture(String name) =>
        jsonDecode(File('test/fixtures/pve/$name').readAsStringSync());

    const token = PveConfig(
      addr: 'https://pve.lan:8006',
      auth: PveAuth.token,
      tokenId: 'root@pam!sb',
      tokenSecret: 's',
    );
    const vm = VirtGuest(
      id: 'qemu/9921',
      name: 'sbhwb-probe',
      kind: VirtGuestKind.qemu,
      state: VirtGuestState.stopped,
      vmid: 9921,
      node: 'pve',
    );

    /// Captured from PVE 9.2: UEFI with Secure Boot, a TPM, a USB device by
    /// mapping and one by id, a PCI device by mapping, a virtio card, and
    /// disks with cache modes.
    _Api devApi() => _Api()
      ..routes['GET /nodes/pve/qemu/9921/config'] = ((_) => fixture('hw_vm_devices_config.json'))
      ..routes['GET /nodes/pve/qemu/9921/pending'] = ((_) => const [])
      ..routes['GET /nodes/pve/status'] = ((_) => const {})
      ..routes['GET /nodes/pve/capabilities/qemu/cpu'] = ((_) => const [])
      ..routes['POST /nodes/pve/qemu/9921/config'] = ((_) => _Api.upid)
      ..routes['GET /nodes/pve/hardware/pci'] = ((_) => fixture('hardware_pci.json'))
      ..routes['GET /nodes/pve/hardware/usb'] = ((_) => fixture('hardware_usb.json'))
      ..routes['GET /cluster/mapping/usb'] = ((_) => fixture('mapping_usb.json'))
      ..routes['GET /cluster/mapping/pci'] = ((_) => fixture('mapping_pci.json'));

    Map<String, String> sent(_Api api) {
      final i = api.paths.lastIndexOf('POST /nodes/pve/qemu/9921/config');
      expect(i, isNot(-1), reason: '${api.paths}');
      return Uri.splitQueryString(api.bodies[i]);
    }

    test('read: devices, firmware, card and cache modes', () async {
      final hw = await devApi().backend(token).hardware(vm);
      expect(
        hw.devices.map((d) => (d.key, d.kind, d.detail, d.mapping)),
        [
          ('hostpci0', VirtHwDeviceKind.pci, 'sbhwb-xhci', true),
          ('tpmstate0', VirtHwDeviceKind.tpm, 'TPM v2.0', false),
          ('usb0', VirtHwDeviceKind.usb, 'sbhwb-bt', true),
          ('usb1', VirtHwDeviceKind.usb, '0bda:b023', false),
        ],
      );
      expect(hw.firmware, const VirtHwFirmware(uefi: true, secureBoot: true, varsStorage: 'local-lvm'));
      expect(hw.display?.gpu, 'virtio');
      expect({for (final d in hw.disks) d.key: d.cache}, {'scsi1': 'writethrough', 'virtio0': 'writeback'});
      // The EFI and TPM volumes are not disks to edit.
      expect(hw.disks.map((d) => d.key), isNot(contains('efidisk0')));
      expect(hw.support, PveResources.pveQemuSupport);
    });

    test('disk cache, and a bus change with the boot order kept', () async {
      final api = devApi();
      final pve = api.backend(token);
      final hw = await pve.hardware(vm);
      await pve.changeHardware(vm, hw, const VirtHwUpdateDisk(key: 'virtio0', cache: 'default'));
      expect(sent(api)['virtio0'], 'local-lvm:vm-9921-disk-0,size=1G');
      // The boot order names the disk: it moves with it, in its place.
      final booted = hw.copyWith(boot: ['scsi1', 'net0']);
      await pve.changeHardware(vm, booted, const VirtHwUpdateDisk(key: 'scsi1', bus: 'sata'));
      expect(sent(api), {
        'sata0': 'local-lvm:vm-9921-disk-4,cache=writethrough,size=1G',
        'boot': 'order=sata0;net0',
        'delete': 'scsi1',
        'digest': hw.revision!,
      });
    });

    test('a bus change drops what the new bus does not take', () async {
      // `virtio0` as `qemuCreateBody` makes it, with `iothread=1`, which
      // SATA and IDE refuse.
      final config = (fixture('hw_vm_devices_config.json')! as Map)
          .cast<String, Object?>();
      config['virtio0'] = 'local-lvm:vm-9921-disk-0,iothread=1,ro=1,size=1G';
      final api = devApi()
        ..routes['GET /nodes/pve/qemu/9921/config'] = ((_) => config);
      final pve = api.backend(token);
      final hw = await pve.hardware(vm);
      await pve.changeHardware(vm, hw, const VirtHwUpdateDisk(key: 'virtio0', bus: 'sata'));
      expect(sent(api)['sata0'], 'local-lvm:vm-9921-disk-0,size=1G');
      await pve.changeHardware(vm, hw, const VirtHwUpdateDisk(key: 'virtio0', bus: 'scsi'));
      expect(sent(api)['scsi0'], 'local-lvm:vm-9921-disk-0,iothread=1,ro=1,size=1G');
    });

    test('NIC model and MAC, devices, card', () async {
      final api = devApi();
      final pve = api.backend(token);
      final hw = await pve.hardware(vm);
      await pve.changeHardware(
        vm,
        hw,
        const VirtHwSetNicHardware(key: 'net0', model: 'virtio', mac: 'bc:24:11:00:00:09'),
      );
      expect(sent(api)['net0'], 'virtio=BC:24:11:00:00:09,bridge=vmbr0');
      await pve.changeHardware(
        vm,
        hw,
        const VirtHwAddDevice(
          kind: VirtHwDeviceKind.usb,
          host: VirtHostDevice(id: 'bt', label: 'bt', mapping: true),
        ),
      );
      expect(sent(api)['usb2'], 'mapping=bt');
      // A device by vendor and product (the default), or by where it sits.
      const dongle = VirtHostDevice(id: '0bda:b023', label: 'bt', usbBus: 1, usbPort: '1.2');
      await pve.changeHardware(vm, hw, const VirtHwAddDevice(kind: VirtHwDeviceKind.usb, host: dongle));
      expect(sent(api)['usb2'], 'host=0bda:b023');
      await pve.changeHardware(
        vm,
        hw,
        const VirtHwAddDevice(kind: VirtHwDeviceKind.usb, host: dongle, usbNaming: VirtUsbNaming.address),
      );
      expect(sent(api)['usb2'], 'host=1-1.2');
      // No port from the host: no address to give it by.
      final e = await _err(
        pve.changeHardware(
          vm,
          hw,
          const VirtHwAddDevice(
            kind: VirtHwDeviceKind.usb,
            host: VirtHostDevice(id: '0bda:b023', label: 'bt', usbBus: 1),
            usbNaming: VirtUsbNaming.address,
          ),
        ),
      );
      expect(e.type, VirtErrType.unsupported);
      await pve.changeHardware(
        vm,
        hw,
        const VirtHwAddDevice(
          kind: VirtHwDeviceKind.pci,
          host: VirtHostDevice(id: '0000:00:14.0', label: 'xHCI'),
        ),
      );
      expect(sent(api)['hostpci1'], '0000:00:14.0');
      await pve.changeHardware(vm, hw, const VirtHwAddDevice(kind: VirtHwDeviceKind.tpm, storage: 'local-lvm'));
      expect(sent(api)['tpmstate0'], 'local-lvm:1,version=v2.0');
      await pve.changeHardware(vm, hw, const VirtHwRemoveDevice(key: 'usb1'));
      expect(sent(api)['delete'], 'usb1');
      await pve.changeHardware(vm, hw, const VirtHwSetDisplay(gpu: 'qxl'));
      expect(sent(api)['vga'], 'qxl');
    });

    test('firmware: Secure Boot is a new variables disk, BIOS keeps it', () async {
      final api = devApi();
      final pve = api.backend(token);
      final hw = await pve.hardware(vm);
      await pve.changeHardware(vm, hw, const VirtHwSetFirmware(uefi: true, secureBoot: true));
      expect(sent(api), {'bios': 'ovmf', 'digest': hw.revision!});
      await pve.changeHardware(vm, hw, const VirtHwSetFirmware(uefi: true));
      final bodies = [
        for (final (i, p) in api.paths.indexed)
          if (p == 'POST /nodes/pve/qemu/9921/config') Uri.splitQueryString(api.bodies[i]),
      ];
      expect(bodies.reversed.take(2).toList().reversed, [
        {'delete': 'efidisk0', 'digest': hw.revision!},
        {'bios': 'ovmf', 'efidisk0': 'local-lvm:1,efitype=4m,pre-enrolled-keys=0'},
      ]);
      await pve.changeHardware(vm, hw, const VirtHwSetFirmware(uefi: false));
      expect(sent(api), {'bios': 'seabios', 'digest': hw.revision!});
    });

    test('host devices: a token gets mappings; root@pam the node\'s too', () async {
      final tokenDevs = await devApi().backend(token).hostDevices(vm);
      expect(tokenDevs.mappingsOnly, isTrue);
      expect(tokenDevs.usb.map((d) => (d.id, d.mapping)), [('sbhwb-bt', true)]);
      expect(tokenDevs.pci.map((d) => (d.id, d.mapping)), [('sbhwb-xhci', true)]);
      // No IOMMU group on any device: the host has none on.
      expect(tokenDevs.iommu, isFalse);

      final api = devApi();
      const password = PveConfig(addr: 'https://pve.lan:8006', auth: PveAuth.password);
      final root = await api.backend(password, user: 'root').hostDevices(vm);
      expect(root.mappingsOnly, isFalse);
      // Hubs left out; the Bluetooth radio offered by id.
      expect(root.usb.map((d) => d.id), ['sbhwb-bt', '0bda:b023']);
      expect(root.pci.length, 1 + (fixture('hardware_pci.json')! as List).length);
      expect(root.pci.last.iommuGroup, isNull);
    });
  });

  group('storage and network management', () {
    const token = PveConfig(
      addr: 'https://pve.lan:8006',
      auth: PveAuth.token,
      tokenId: 'root@pam!sb',
      tokenSecret: 's3cret',
    );
    const local = VirtStoragePool(
      id: 'pve/local',
      name: 'local',
      node: 'pve',
      type: 'dir',
      content: ['iso', 'vztmpl', 'images'],
    );
    const lvm = VirtStoragePool(
      id: 'pve/local-lvm',
      name: 'local-lvm',
      node: 'pve',
      type: 'lvmthin',
      content: ['images', 'rootdir'],
    );
    Map<String, String> form(String body) => Uri.splitQueryString(body);
    _Api api0() => _Api()
      ..routes['GET /nodes'] = ((_) => [
        {'node': 'pve', 'status': 'online'},
      ]);

    test('a storage: its type\'s fields, its node, the design\'s content', () async {
      final api = api0()..routes['POST /storage'] = (_) => {'storage': 'x'};
      final pve = api.backend(token);
      await pve.manage(
        const VirtPoolCreate(name: 'data', type: 'dir', source: '/srv/data', node: 'pve'),
      );
      await pve.manage(
        const VirtPoolCreate(name: 'nas', type: 'nfs', source: '10.0.0.5:/export/pve', node: 'pve'),
      );
      await pve.manage(
        const VirtPoolCreate(name: 'thin', type: 'lvmthin', source: 'pve/data', node: 'pve'),
      );
      final sent = [
        for (final (i, p) in api.paths.indexed)
          if (p == 'POST /storage') form(api.bodies[i]),
      ];
      expect(sent[0], {
        'storage': 'data',
        'type': 'dir',
        'path': '/srv/data',
        'content': 'images,rootdir',
        'nodes': 'pve',
      });
      expect(sent[1], containsPair('server', '10.0.0.5'));
      expect(sent[1], containsPair('export', '/export/pve'));
      expect(sent[1], containsPair('content', 'backup,iso'));
      expect(sent[2], containsPair('vgname', 'pve'));
      expect(sent[2], containsPair('thinpool', 'data'));
    });

    test('disabled and enabled; removed', () async {
      final api = api0()
        ..routes['PUT /storage/local'] = ((_) => null)
        ..routes['DELETE /storage/local'] = ((_) => null);
      final pve = api.backend(token);
      await pve.manage(const VirtPoolSetActive(local, active: false));
      await pve.manage(const VirtPoolSetActive(local, active: true));
      await pve.manage(const VirtPoolDelete(local));
      final puts = [
        for (final (i, p) in api.paths.indexed)
          if (p == 'PUT /storage/local') form(api.bodies[i])['disable'],
      ];
      expect(puts, ['1', '0']);
      expect(api.paths, contains('DELETE /storage/local'));
      // What PVE has no call for is refused before anything is sent.
      final e = await _err(pve.manage(const VirtPoolSetAutostart(local, on: true)));
      expect(e.type, VirtErrType.unsupported);
    });

    test('a volume: for its VMID, with the extension a directory wants; deleted with its task', () async {
      final api = api0()
        ..routes['POST /nodes/pve/storage/local/content'] = ((_) => 'local:105/vm-105-disk-0.qcow2')
        ..routes['POST /nodes/pve/storage/local-lvm/content'] = ((_) => 'local-lvm:vm-105-disk-1')
        ..routes['DELETE /nodes/pve/storage/local/content/${Uri.encodeComponent('local:105/vm-105-disk-0.qcow2')}'] =
            (_) => _Api.upid;
      final pve = api.backend(token);
      await pve.manage(
        const VirtVolumeCreate(local, name: 'vm-105-disk-0', gib: 4, format: 'qcow2'),
      );
      await pve.manage(
        const VirtVolumeCreate(lvm, name: 'vm-105-disk-1', gib: 8, format: 'raw'),
      );
      final bodies = [
        for (final (i, p) in api.paths.indexed)
          if (p.endsWith('/content')) form(api.bodies[i]),
      ];
      expect(bodies[0], {
        'vmid': '105',
        'filename': 'vm-105-disk-0.qcow2',
        'size': '4G',
        'format': 'qcow2',
      });
      expect(bodies[1], containsPair('filename', 'vm-105-disk-1'));
      await pve.manage(
        const VirtVolumeDelete(
          local,
          VirtVolume(id: 'local:105/vm-105-disk-0.qcow2', name: 'vm-105-disk-0.qcow2'),
        ),
      );
      expect(api.paths.last, startsWith('GET /nodes/pve/tasks/'));
    });

    test('a privilege missing: which, where, and the command that grants it', () async {
      final api = api0()
        ..routes['POST /storage'] = ((_) => _Api._status(
          403,
          message: 'Permission check failed (/storage, Datastore.Allocate)\n',
        ))
        ..routes['POST /nodes/pve/network'] = ((_) => _Api._status(
          403,
          message: 'Permission check failed (/nodes/pve, Sys.Modify)\n',
        ));
      final pve = api.backend(token);
      final e = await _err(
        pve.manage(const VirtPoolCreate(name: 'd', type: 'dir', source: '/d', node: 'pve')),
      );
      expect(e.type, VirtErrType.permissionDenied);
      expect(e.message, contains('Datastore.Allocate'));
      expect(
        e.message,
        contains("pveum acl modify /storage --tokens 'root@pam!sb' --roles PVEDatastoreAdmin"),
      );
      expect(e.message, isNot(contains('s3cret')));
      final n = await _err(
        pve.manage(const VirtNetworkCreate(name: 'vmbr9', mode: 'bridge', node: 'pve')),
      );
      expect(n.type, VirtErrType.permissionDenied);
      // Only Administrator holds Sys.Modify among the built-in roles: a
      // role of its own.
      expect(n.message, contains('pveum role add ServerBox-SysModify --privs Sys.Modify'));
      expect(n.message, contains('/nodes/pve'));
    });

    test('a name taken is exists', () async {
      final api = api0()
        ..routes['POST /storage'] = ((_) => _Api._status(
          500,
          message: "create storage failed: storage ID 'local' already defined\n",
        ));
      final e = await _err(
        api.backend(token).manage(
          const VirtPoolCreate(name: 'local', type: 'dir', source: '/d', node: 'pve'),
        ),
      );
      expect(e.type, VirtErrType.exists);
    });

    test('a bridge: pending; its changes read, applied with a task, reverted', () async {
      final api = api0()
        ..routes['POST /nodes/pve/network'] = ((_) => null)
        ..routes['PUT /nodes/pve/network'] = ((_) => _Api.upid)
        ..routes['DELETE /nodes/pve/network'] = ((_) => null)
        ..routes['DELETE /nodes/pve/network/vmbr9'] = ((_) => null)
        ..routes['GET /nodes/pve/network'] = ((_) => ResponseBody.fromString(
          jsonEncode({
            'data': [
              {'iface': 'vmbr9', 'type': 'bridge', 'autostart': 1},
            ],
            'changes': '--- a\n+++ b\n+auto vmbr9\n+iface vmbr9 inet manual\n',
          }),
          200,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType],
          },
        ));
      final pve = api.backend(token);
      await pve.manage(
        const VirtNetworkCreate(
          name: 'vmbr9',
          mode: 'bridge',
          node: 'pve',
          cidr: '10.20.0.1/24',
          vlanAware: true,
        ),
      );
      expect(form(api.bodies[api.paths.indexOf('POST /nodes/pve/network')]), {
        'iface': 'vmbr9',
        'type': 'bridge',
        'autostart': '1',
        'cidr': '10.20.0.1/24',
        'bridge_vlan_aware': '1',
      });
      final changes = await pve.networkChanges();
      expect(changes.single.node, 'pve');
      expect(changes.single.diff, contains('+iface vmbr9'));
      await pve.manage(const VirtNetworkApply('pve'));
      expect(api.paths.last, startsWith('GET /nodes/pve/tasks/'));
      await pve.manage(const VirtNetworkRevert('pve'));
      await pve.manage(
        const VirtNetworkDelete(
          VirtNetwork(id: 'pve/vmbr9', name: 'vmbr9', node: 'pve', mode: 'bridge'),
        ),
      );
      expect(api.paths, containsAll(['DELETE /nodes/pve/network', 'DELETE /nodes/pve/network/vmbr9']));
    });

    test('an apply touching the management interface is refused', () async {
      Map<String, Object?> listing(String changes) => {
        'data': [
          {
            'iface': 'vmbr0',
            'type': 'bridge',
            'cidr': '192.168.31.20/24',
            'gateway': '192.168.31.1',
            'bridge_ports': 'nic0',
          },
          {'iface': 'vmbr9', 'type': 'bridge'},
        ],
        'changes': changes,
      };
      var changes = '--- a\n+++ b\n@@ -1,3 +1,4 @@\n iface vmbr0 inet static\n+\tbridge-vlan-aware yes\n';
      final api = api0()
        ..routes['PUT /nodes/pve/network'] = ((_) => _Api.upid)
        ..routes['GET /nodes/pve/network'] = ((_) => ResponseBody.fromString(
          jsonEncode(listing(changes)),
          200,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType],
          },
        ));
      final pve = api.backend(token);
      final e = await _err(pve.manage(const VirtNetworkApply('pve')));
      expect(e.type, VirtErrType.unsupported);
      expect(e.message, contains('vmbr0'));
      expect(api.paths, isNot(contains('PUT /nodes/pve/network')));
      // A change to its port is one to it too.
      changes = '--- a\n+++ b\n@@ -1,3 +1,3 @@\n iface nic0 inet manual\n-\tmtu 1500\n+\tmtu 9000\n';
      expect((await _err(pve.manage(const VirtNetworkApply('pve')))).message, contains('nic0'));
      // A hunk that does not say whose lines it changes.
      changes = '--- a\n+++ b\n@@ -3,2 +3,2 @@\n-\tmtu 1500\n+\tmtu 9000\n';
      expect((await _err(pve.manage(const VirtNetworkApply('pve')))).type, VirtErrType.unsupported);
      // A comment on it is a change to it too (PVE writes `comments` as
      // `#` lines in its stanza).
      changes = '--- a\n+++ b\n@@ -1,3 +1,4 @@\n iface vmbr0 inet static\n \tbridge-fd 0\n+#note\n';
      expect((await _err(pve.manage(const VirtNetworkApply('pve')))).message, contains('vmbr0'));
      // Another bridge's change goes through.
      changes = '--- a\n+++ b\n+auto vmbr9\n+iface vmbr9 inet manual\n';
      await pve.manage(const VirtNetworkApply('pve'));
      expect(api.paths, contains('PUT /nodes/pve/network'));
    });

    test('a pending change stripping the management address is refused '
        'without the node\'s own word on what it uses', () async {
      // The listing is the pending configuration: vmbr0 has neither its
      // address nor its gateway there any more.
      final api = api0()
        ..routes['PUT /nodes/pve/network'] = ((_) => _Api.upid)
        ..routes['GET /nodes/pve/network'] = ((_) => ResponseBody.fromString(
          jsonEncode({
            'data': [
              {'iface': 'vmbr0', 'type': 'bridge', 'bridge_ports': 'nic0'},
              {'iface': 'vmbr9', 'type': 'bridge'},
            ],
            'changes': '--- a\n+++ b\n@@ -1,5 +1,3 @@\n'
                '-iface vmbr0 inet static\n'
                '-\taddress 192.168.31.20/24\n'
                '-\tgateway 192.168.31.1\n'
                '+iface vmbr0 inet manual\n'
                ' \tbridge-ports nic0\n',
          }),
          200,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType],
          },
        ));
      final e = await _err(api.backend(token).manage(const VirtNetworkApply('pve')));
      expect(e.type, VirtErrType.unsupported);
      expect(e.message, contains('vmbr0'));
      expect(api.paths, isNot(contains('PUT /nodes/pve/network')));
    });

    test('a node\'s network changes run one at a time', () async {
      final saved = Completer<void>();
      final api = api0()
        ..routes['GET /nodes/pve/network'] = ((_) => [
          {'iface': 'vmbr7', 'type': 'bridge'},
        ])
        ..routes['GET /nodes/pve/network/vmbr7'] = ((_) => {'iface': 'vmbr7', 'type': 'bridge'})
        ..routes['PUT /nodes/pve/network/vmbr7'] = ((_) => saved.future.then((_) => null))
        ..routes['DELETE /nodes/pve/network'] = ((_) => null);
      final pve = api.backend(token);
      const net = VirtNetwork(id: 'pve/vmbr7', name: 'vmbr7', node: 'pve', mode: 'bridge');
      final edit = pve.manage(const VirtNetworkEditBridge(net, ports: 'nic1'));
      while (!api.paths.contains('PUT /nodes/pve/network/vmbr7')) {
        await Future<void>.delayed(const Duration(milliseconds: 1));
      }
      final revert = pve.manage(const VirtNetworkRevert('pve'));
      await Future<void>.delayed(const Duration(milliseconds: 30));
      expect(
        api.paths,
        isNot(contains('DELETE /nodes/pve/network')),
        reason: 'the revert would drop the edit being saved',
      );
      saved.complete();
      await Future.wait([edit, revert]);
      expect(api.paths.last, 'DELETE /nodes/pve/network');
      // A failed change does not hold the next one up.
      api.routes['PUT /nodes/pve/network/vmbr7'] = (_) => _Api._status(500);
      await _err(pve.manage(const VirtNetworkEditBridge(net, ports: 'nic1')));
      await pve.manage(const VirtNetworkRevert('pve'));
    });

    test('a bridge edit sends the addresses it has back', () async {
      final api = api0()
        ..routes['GET /nodes/pve/network'] = ((_) => [
          {'iface': 'vmbr0', 'type': 'bridge', 'cidr': '192.168.31.20/24', 'gateway': '192.168.31.1'},
          {'iface': 'vmbr7', 'type': 'bridge', 'cidr': '10.7.0.1/24', 'cidr6': 'fd07::1/64'},
        ])
        ..routes['GET /nodes/pve/network/vmbr7'] = ((_) => {
          'iface': 'vmbr7',
          'type': 'bridge',
          'cidr': '10.7.0.1/24',
          'cidr6': 'fd07::1/64',
        })
        ..routes['PUT /nodes/pve/network/vmbr7'] = ((_) => null);
      // The node says it is reached through vmbr0; vmbr7 carries nothing
      // of its own traffic.
      final pve = api.backend(
        token,
        liveNet: '@host pve\n@addr\n4: vmbr0    inet 192.168.31.20/24 scope global vmbr0\n'
            '5: vmbr7    inet 10.7.0.1/24 scope global vmbr7\n'
            '@route\ndefault via 192.168.31.1 dev vmbr0\n'
            '@conn\n0 0 192.168.31.20:22 192.168.31.183:62036\n@lower\n@end\n',
      );
      const net = VirtNetwork(id: 'pve/vmbr7', name: 'vmbr7', node: 'pve', mode: 'bridge');
      // Only the ports: PVE would drop both addresses from a request
      // without them (`update_network` sets `method` from the request).
      await pve.manage(const VirtNetworkEditBridge(net, ports: 'nic1'));
      expect(form(api.bodies[api.paths.lastIndexOf('PUT /nodes/pve/network/vmbr7')]), {
        'type': 'bridge',
        'bridge_ports': 'nic1',
        'cidr': '10.7.0.1/24',
        'cidr6': 'fd07::1/64',
      });
      // A new IPv4 address: that one, and the IPv6 one still.
      await pve.manage(const VirtNetworkEditBridge(net, cidr: '10.7.1.1/24'));
      final sent = form(api.bodies[api.paths.lastIndexOf('PUT /nodes/pve/network/vmbr7')]);
      expect(sent['cidr'], '10.7.1.1/24');
      expect(sent['cidr6'], 'fd07::1/64');
      // Cleared: deleted, not sent.
      await pve.manage(const VirtNetworkEditBridge(net, cidr: ''));
      final cleared = form(api.bodies[api.paths.lastIndexOf('PUT /nodes/pve/network/vmbr7')]);
      expect(cleared.containsKey('cidr'), isFalse);
      expect(cleared['delete'], contains('cidr'));
      // The management bridge is refused before anything is sent.
      final e = await _err(
        pve.manage(
          const VirtNetworkEditBridge(
            VirtNetwork(id: 'pve/vmbr0', name: 'vmbr0', node: 'pve', mode: 'bridge'),
            ports: 'nic1',
          ),
        ),
      );
      expect(e.type, VirtErrType.unsupported);
      expect(api.paths, isNot(contains('PUT /nodes/pve/network/vmbr0')));
    });

    test('upload: multipart as pveproxy reads it, the file last; progress; its task', () async {
      final api = api0()
        ..routes['POST /nodes/pve/storage/local/upload'] = ((_) => _Api.upid);
      final pve = api.backend(token);
      final sent = <int>[];
      final data = utf8.encode('iso bytes ' * 100);
      expect(
        await pve.upload(
          VirtUpload(
            pool: local,
            name: 'debian.iso',
            size: data.length,
            open: () => Stream.value(data),
          ),
          onProgress: sent.add,
        ),
        isTrue,
      );
      final body = api.bodies[api.paths.indexOf('POST /nodes/pve/storage/local/upload')];
      // pveproxy's pattern is case-sensitive.
      expect(body, contains('Content-Disposition: form-data; name="content"'));
      expect(
        body.indexOf('name="content"'),
        lessThan(body.indexOf('name="filename"; filename="debian.iso"')),
      );
      expect(body, contains('iso bytes iso bytes'));
      expect(sent, isNotEmpty);
      expect(api.paths.last, startsWith('GET /nodes/pve/tasks/'));
    });
  });
}

Future<VirtErr> _err(Future<Object?> future) async {
  try {
    await future;
  } on VirtErr catch (e) {
    return e;
  }
  fail('expected a VirtErr');
}

/// A scripted PVE API behind a Dio adapter. One instance per test; every Dio
/// the backend makes gets its own adapter over this shared state.
class _Api {
  static const upid = 'UPID:pve:0001:0002:0003:qmstart:101:root@pam:';

  List<Map<String, Object?>> resources = const [];
  int resourcesStatus = 200;
  int versionStatus = 200;
  String version = '8.2.4';
  int actionStatus = 200;
  int consoleStatus = 200;
  int ticketStatus = 200;

  /// Status for answers to a TFA challenge, and for renewals (the ticket sent
  /// as the password).
  int tfaStatus = 200;
  int renewStatus = 200;

  /// How many `/cluster/resources` requests answer 401 before the rest
  /// answer [resourcesStatus] — an expired ticket.
  int resources401 = 0;
  bool needTfa = false;
  /// Answers by `METHOD path`, checked before everything else: a value to
  /// send as `data`, or a [ResponseBody] as it is.
  final routes = <String, Object? Function(String body)>{};
  List<String> taskStates = const ['stopped'];
  String taskExit = 'OK';

  /// `GET .../status/current`; null answers 404.
  Map<String, Object?>? current;

  /// Answered by `GET .../status/current` before [current], one per request.
  final currentFirst = <Map<String, Object?>>[];
  Future<void>? ticketGate;

  final paths = <String>[];
  final hosts = <String>[];
  final queries = <String>[];
  final bodies = <String>[];
  final headers = <Map<String, Object?>>[];
  final ticketRequested = Completer<void>();
  int closed = 0;
  int _tickets = 0;
  int _ticketsInFlight = 0;
  int maxConcurrentTickets = 0;
  int _taskPolls = 0;

  /// A backend whose session is the real one (`sbm_virt::pve` over FFI),
  /// reaching this fake through an authenticated loopback tunnel and TLS, as
  /// it reaches PVE. The fake's certificate is pinned unless [config] pins
  /// something else.
  PveBackend backend(
    PveConfig config, {
    String? user = 'root',
    String? sshKeyId,
    String sshPassword = 'sshpw',
    String? liveNet,
    Duration taskTimeout = const Duration(minutes: 10),
  }) {
    addTearDown(close);
    return PveBackend(
      serverId: 'srv',
      config: config.certSha256 == null
          ? config.copyWith(certSha256: _leafFingerprint())
          : config,
      user: user,
      sshKeyId: sshKeyId,
      sshPassword: sshPassword,
      exec: liveNet == null ? null : () async => _Probe(liveNet),
      tunnel: (_, _) async => loopbackTo(await _serve()),
      // A console's or an upload's own connection, to the same fake.
      connect: (_, _) => ConnectionTask.fromSocket(
        _serve().then((port) => Socket.connect(InternetAddress.loopbackIPv4, port)),
        () {},
      ),
      taskPoll: const Duration(milliseconds: 1),
      taskTimeout: taskTimeout,
    );
  }

  HttpServer? _server;
  Future<int>? _serving;

  Future<int> _serve() => _serving ??= () async {
    final ctx = SecurityContext()
      ..useCertificateChain('$_tlsDir/leaf.pem')
      ..usePrivateKey('$_tlsDir/leaf.key');
    final server = await HttpServer.bindSecure(InternetAddress.loopbackIPv4, 0, ctx);
    _server = server;
    server.listen((req) async {
      final body = await utf8.decodeStream(req);
      final o = RequestOptions(
        method: req.method,
        baseUrl: 'https://${req.headers.host ?? 'localhost'}',
        path: req.uri.toString(),
        headers: {
          for (final MapEntry(:key, :value) in _headersOf(req).entries) key: value,
        },
      );
      final answer = await handle(o, body);
      req.response.statusCode = answer.statusCode;
      answer.headers.forEach((k, v) => req.response.headers.set(k, v));
      await req.response.addStream(answer.stream);
      await req.response.close();
    });
    return server.port;
  }();

  /// The request's headers under the names a client sets them by.
  static Map<String, String> _headersOf(HttpRequest req) {
    String name(String lower) => switch (lower) {
      'authorization' => 'Authorization',
      'cookie' => 'Cookie',
      'csrfpreventiontoken' => 'CSRFPreventionToken',
      final n => n,
    };
    final out = <String, String>{};
    req.headers.forEach((k, v) => out[name(k)] = v.join(', '));
    return out;
  }

  Future<void> close() async {
    await _server?.close(force: true);
  }

  Future<ResponseBody> handle(RequestOptions o, String body) async {
    final path = o.uri.path.replaceFirst('/api2/json', '');
    final key = '${o.method} $path';
    paths.add(key);
    hosts.add(o.uri.host);
    queries.add(o.uri.query);
    bodies.add(body);
    headers.add(Map.of(o.headers));
    if (routes[key] case final route?) {
      var answer = route(body);
      // A route may hold its answer back (a request still in flight).
      if (answer is Future) answer = await answer;
      return answer is ResponseBody ? answer : _json(answer);
    }

    if (key == 'POST /access/ticket') {
      _ticketsInFlight++;
      if (_ticketsInFlight > maxConcurrentTickets) {
        maxConcurrentTickets = _ticketsInFlight;
      }
      if (!ticketRequested.isCompleted) ticketRequested.complete();
      try {
        final gate = ticketGate;
        if (gate != null) await gate;
        if (ticketStatus != 200) return _status(ticketStatus);
        if (body.contains('tfa-challenge')) {
          if (tfaStatus != 200) return _status(tfaStatus);
          return _json({'ticket': 'T${++_tickets}', 'CSRFPreventionToken': 'C'});
        }
        // A renewal: a full ticket as the password, which asks no second
        // factor (PVE 9.2).
        if (RegExp(r'(^|&)password=T\d+(&|$)').hasMatch(body)) {
          if (renewStatus != 200) return _status(renewStatus);
          final n = ++_tickets;
          return _json({'ticket': 'T$n', 'CSRFPreventionToken': 'C$n'});
        }
        if (needTfa) {
          final n = ++_tickets;
          return _json({'ticket': 'CHALLENGE$n', 'NeedTFA': 1});
        }
        final n = ++_tickets;
        return _json({'ticket': 'T$n', 'CSRFPreventionToken': 'C$n'});
      } finally {
        _ticketsInFlight--;
      }
    }
    if (key == 'GET /version') {
      if (versionStatus != 200) return _status(versionStatus);
      return _json({'version': version, 'release': version});
    }
    if (key == 'GET /cluster/resources') {
      if (resources401 > 0) {
        resources401--;
        return _status(401);
      }
      if (resourcesStatus != 200) return _status(resourcesStatus);
      return _json(resources);
    }
    if (o.method == 'GET' && path.endsWith('/status/current')) {
      if (currentFirst.isNotEmpty) return _json(currentFirst.removeAt(0));
      final c = current;
      return c == null ? _status(404) : _json(c);
    }
    if (path.contains('/status/')) {
      if (actionStatus != 200) {
        return _status(
          actionStatus,
          message: 'Permission check failed (/vms/101, VM.PowerMgmt)\n',
        );
      }
      return _json(upid);
    }
    if (path.contains('/tasks/')) {
      final i = _taskPolls++;
      final status = taskStates[i.clamp(0, taskStates.length - 1)];
      return _json({
        'status': status,
        if (status == 'stopped') 'exitstatus': taskExit,
      });
    }
    if (path.endsWith('/termproxy') || path.endsWith('/vncproxy')) {
      if (consoleStatus != 200) {
        return _status(
          consoleStatus,
          message: 'Permission check failed (/vms/100, VM.Console)\n',
        );
      }
      return _json({
        'port': '5900',
        'ticket': 'PVEVNC:abc/=',
        'user': 'root@pam',
        'upid': upid,
      });
    }
    return _status(404);
  }

  static ResponseBody _json(Object? data) => ResponseBody.fromString(
    jsonEncode({'data': data}),
    200,
    headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    },
  );

  static ResponseBody _status(
    int code, {
    String? message,
    Map<String, String>? errors,
  }) => ResponseBody.fromString(
        jsonEncode({'data': null, 'message': ?message, 'errors': ?errors}),
        code,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );
}

const _tlsDir = 'test/fixtures/virt_tls';

/// SHA-256 of the fake's leaf, which every backend here pins.
String _leafFingerprint() {
  final pem = File('$_tlsDir/leaf.pem').readAsStringSync();
  final body = pem
      .split('\n')
      .where((l) => !l.startsWith('-----') && l.trim().isNotEmpty)
      .join();
  return sha256.convert(base64.decode(body)).toString();
}

VirtStoragePool _pool(String name) => VirtStoragePool(
  id: 'pve/$name',
  name: name,
  node: 'pve',
  type: 'lvmthin',
  content: const ['images', 'rootdir'],
);

VirtNetwork _bridge(String name) =>
    VirtNetwork(id: 'pve/$name', name: name, node: 'pve', mode: 'bridge');

VirtVolume _iso(String id) =>
    VirtVolume(id: id, name: id.split('/').last, content: 'iso');

/// What the node's live network probe printed.
class _Probe implements ServerExec {
  _Probe(this.out);

  final String out;

  @override
  Future<ExecResult> run(
    String script, {
    String? entry,
    Map<String, String>? env,
    String? stdin,
    OnExecOutput? onStdout,
    OnExecOutput? onStderr,
    Future<void>? cancel,
  }) async => ExecResult(exitCode: 0, stdout: out, stderr: '');
}
