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
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/data/model/app/error.dart';
import 'package:server_box/data/model/server/pve_config.dart';
import 'package:server_box/data/model/server/server_exec.dart';
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

    /// A node `pve` with VM 100, `local-lvm` and `vmbr0`.
    _Api host() => _Api()
      ..resources = [
        {'id': 'node/pve', 'type': 'node', 'node': 'pve', 'status': 'online', 'maxcpu': 8},
        {'id': 'qemu/100', 'type': 'qemu', 'vmid': 100, 'node': 'pve', 'status': 'running', 'name': 'web'},
        {'id': 'qemu/101', 'type': 'qemu', 'vmid': 101, 'node': 'pve', 'status': 'stopped', 'name': 'off'},
      ]
      ..routes['GET /nodes'] = ((_) => [
        {'node': 'pve', 'status': 'online'},
      ])
      ..routes['GET /storage'] = ((_) => const [])
      ..routes['GET /nodes/pve/storage'] = ((_) => [
        {'storage': 'local-lvm', 'type': 'lvmthin', 'active': 1, 'enabled': 1, 'content': 'images,rootdir'},
      ])
      ..routes['GET /nodes/pve/network'] = ((_) => [
        {'iface': 'vmbr0', 'type': 'bridge', 'active': 1},
      ]);

    VirtCreateSpec vm(String name, {int vmid = 105}) => VirtCreateSpec(
      kind: VirtGuestKind.qemu,
      name: name,
      node: 'pve',
      vmid: vmid,
      cores: 2,
      memoryMiB: 2048,
      storage: lvm,
      diskGiB: 32,
      network: bridge,
    );

    // What the session sends is `sbm_virt`'s (crates/sbm_virt/tests/
    // pve_create.rs); this is how the app reaches it and says it.
    test('nextid, options', () async {
      final api = host()..routes['GET /cluster/nextid'] = (_) => '105';
      final pve = api.backend(token);
      expect(await pve.nextVmid(), 105);
      final o = await pve.createOptions();
      expect(o.buses.first, 'scsi');
      expect((o.uefi, o.secureBoot, o.tpm, o.cloudInit), (true, true, true, true));
    });

    test('a VM: the spec crosses by id, the id comes back', () async {
      final api = host()..routes['POST /nodes/pve/qemu'] = (_) => _Api.upid;
      final created = await api.backend(token).create(vm('web-02'));
      expect(created.id, 'qemu/105');
      expect(created.startError, isNull);
      final body = form(api.bodies[api.paths.indexOf('POST /nodes/pve/qemu')]);
      expect(body['scsi0'], 'local-lvm:32,iothread=1');
      expect(body['net0'], 'virtio,bridge=vmbr0');
    });

    test('a refusal before anything is sent: a name taken is exists, said', () async {
      final api = host();
      final e = await _err(api.backend(token).create(vm('web')));
      expect(e.type, VirtErrType.exists);
      expect(e.message, l10n.virtCreateNameTaken);
      final v = await _err(api.backend(token).create(vm('x', vmid: 100)));
      expect(v.message, l10n.virtCreateVmidTaken);
      expect(api.paths, isNot(contains('POST /nodes/pve/qemu')));
    });

    test("a VMID taken by then: exists, in the host's words", () async {
      final api = host()
        ..routes['POST /nodes/pve/qemu'] = ((_) => _Api._status(
          500,
          message: "unable to create VM 105 - VM 105 already exists on node 'pve'\n",
        ));
      final e = await _err(api.backend(token).create(vm('x')));
      expect(e.type, VirtErrType.exists);
      expect(e.message, contains('already exists'));
    });

    test('delete: as the host has it now, purged', () async {
      final api = host()..routes['DELETE /nodes/pve/qemu/101'] = (_) => _Api.upid;
      final pve = api.backend(token);
      final guests = (await pve.load()).guests;
      await pve.delete(guests.firstWhere((g) => g.id == 'qemu/101'));
      final i = api.paths.indexOf('DELETE /nodes/pve/qemu/101');
      expect(Uri.splitQueryString(api.queries[i]), {'purge': '1', 'destroy-unreferenced-disks': '1'});
      final running = await _err(pve.delete(guests.firstWhere((g) => g.id == 'qemu/100')));
      expect(running.type, VirtErrType.unsupported);
      expect(running.message, l10n.virtGuestNotStopped);
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
    test('clone: the request crosses, the copy\'s id comes back', () async {
      final api = _Api()
        ..resources = [
          {'id': 'node/pve', 'type': 'node', 'node': 'pve', 'status': 'online'},
          {'id': 'qemu/9941', 'type': 'qemu', 'vmid': 9941, 'node': 'pve', 'status': 'stopped', 'name': 'sbbk-src', 'template': 1},
          {'id': 'lxc/200', 'type': 'lxc', 'vmid': 200, 'node': 'pve', 'status': 'stopped', 'name': 'alpine'},
        ]
        ..routes['GET /nodes'] = ((_) => [
          {'node': 'pve', 'status': 'online'},
        ])
        ..routes['GET /storage'] = ((_) => const [])
        ..routes['GET /nodes/pve/storage'] = ((_) => const [])
        ..routes['GET /cluster/nextid'] = ((_) => '120')
        ..routes['POST /nodes/pve/qemu/9941/clone'] = ((_) => _Api.upid)
        ..routes['POST /nodes/pve/lxc/200/clone'] = ((_) => _Api.upid);
      final pve = api.backend(token);
      final guests = (await pve.load()).guests;
      final template = guests.firstWhere((g) => g.id == 'qemu/9941');
      expect(
        await pve.clone(template, const VirtCloneRequest(name: 'l', full: false)),
        'qemu/120',
      );
      var i = api.paths.indexOf('POST /nodes/pve/qemu/9941/clone');
      expect(form(api.bodies[i]), {'newid': '120', 'name': 'l', 'full': '0'});
      final ct = guests.firstWhere((g) => g.id == 'lxc/200');
      expect(await pve.clone(ct, const VirtCloneRequest(name: 'ct2', vmid: 202)), 'lxc/202');
      i = api.paths.indexOf('POST /nodes/pve/lxc/200/clone');
      expect(form(api.bodies[i]), {'newid': '202', 'hostname': 'ct2', 'full': '1'});
      // A name the host has: refused before the request, said.
      final taken = await _err(pve.clone(ct, const VirtCloneRequest(name: 'alpine')));
      expect(taken.type, VirtErrType.exists);
      expect(taken.message, l10n.virtCreateNameTaken);
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

    // What each request carries is `sbm_virt`'s
    // (crates/sbm_virt/tests/pve_backup.rs); here, that each call reaches
    // the host through the session and a refusal crosses said.
    _Api backupHost({String vmState = 'stopped'}) => _Api()
      ..resources = [
        {'id': 'node/pve', 'type': 'node', 'node': 'pve', 'status': 'online'},
        {'id': 'node/pve2', 'type': 'node', 'node': 'pve2', 'status': 'online'},
        {'id': 'qemu/9941', 'type': 'qemu', 'vmid': 9941, 'node': 'pve', 'status': vmState, 'name': 'sbbk-src'},
      ]
      ..routes['GET /nodes'] = ((_) => [
        {'node': 'pve', 'status': 'online'},
        {'node': 'pve2', 'status': 'online'},
      ])
      ..routes['GET /nodes/pve/storage'] = ((_) => [
        {'storage': 'local', 'type': 'dir', 'active': 1, 'enabled': 1, 'content': 'iso,backup'},
        {'storage': 'nfs', 'type': 'nfs', 'active': 1, 'enabled': 1, 'content': 'backup', 'shared': 1},
      ])
      ..routes['GET /nodes/pve2/storage'] = ((_) => [
        {'storage': 'nfs', 'type': 'nfs', 'active': 1, 'enabled': 1, 'content': 'backup', 'shared': 1},
      ])
      ..routes['GET /nodes/pve/storage/local/content'] = ((_) => fixture('backup_content.json'))
      ..routes['GET /nodes/pve/storage/nfs/content'] = ((_) => [
        {
          'volid': 'nfs:backup/vzdump-qemu-9941-2026_09_27-02_00_00.vma.zst',
          'content': 'backup',
          'ctime': 1790450000,
          'protected': 1,
          'verification': {'state': 'ok'},
          'subtype': 'qemu',
          'vmid': 9941,
        },
      ])
      ..routes['GET /cluster/backup'] = ((_) => [
        {'id': 'on-a', 'type': 'vzdump', 'all': 1, 'node': 'a'},
        {'id': 'on-b', 'type': 'vzdump', 'all': 1, 'node': 'pve'},
        {'id': 'any', 'type': 'vzdump', 'vmid': '9941', 'prune-backups': {'keep-last': '7'}},
      ])
      ..routes['POST /nodes/pve/vzdump'] = ((_) => _Api.upid)
      ..routes['POST /nodes/pve2/vzdump'] = ((_) => _Api.upid)
      ..routes['POST /nodes/pve/qemu'] = ((_) => _Api.upid);

    test('backups, storages and plan through the session', () async {
      final api = backupHost();
      final pve = api.backend(token);
      expect((await pve.backupStorages(vm)).map((s) => s.name), ['local', 'nfs']);
      final i0 = api.paths.indexOf('GET /nodes/pve/storage');
      expect(Uri.splitQueryString(api.queries[i0]), {'content': 'backup', 'enabled': '1'});
      final backups = await pve.backups(vm);
      expect(backups.map((b) => b.storage), ['nfs', 'local'], reason: 'newest first');
      expect((backups.first.protected, backups.first.verification), (true, 'ok'));
      expect(backups.last.fileName, 'vzdump-qemu-9941-2026_09_26-03_11_45.vma.zst');
      expect(backups.last.createdAt, DateTime.fromMillisecondsSinceEpoch(1790363505000));
      // The jobs that take it: not one restricted to another node.
      final plan = await pve.backupJobs(vm);
      expect(plan.map((j) => j.id), ['on-b', 'any']);
      expect(plan.last.keep, 'keep-last=7');
      // The datacenter's: every job, every node's storages once.
      expect((await pve.allBackupJobs()).map((j) => j.id), ['on-a', 'on-b', 'any']);
      expect(
        [for (final p in await pve.allBackupStorages()) p.id],
        ['pve/local', 'pve/nfs', 'pve2/nfs'],
      );
    });

    test('back up, restore, edit and delete reach the host; refusals are said', () async {
      final api = backupHost();
      final pve = api.backend(token);
      await pve.backup(vm, const VirtBackupRequest(storage: 'local', mode: 'stop'));
      expect(form(api.bodies[api.paths.indexOf('POST /nodes/pve/vzdump')]), containsPair('mode', 'stop'));
      final notHere = await _err(pve.backup(vm, const VirtBackupRequest(storage: 'nas')));
      expect(notHere.type, VirtErrType.unsupported);
      expect(notHere.message, virtBackupIssueText('storage'));

      final local = (await pve.backups(vm)).last;
      await pve.restoreBackup(vm, local);
      expect(form(api.bodies[api.paths.indexOf('POST /nodes/pve/qemu')]), {
        'vmid': '9941',
        'archive': local.id,
        'force': '1',
      });
      final content = '/nodes/pve/storage/local/content/${Uri.encodeComponent(local.id)}';
      api.routes['PUT $content'] = (_) => null;
      await pve.editBackup(local, const VirtBackupEdit(notes: '', protected: true));
      expect(form(api.bodies[api.paths.indexOf('PUT $content')]), {'notes': '', 'protected': '1'});
      api.routes['DELETE $content'] = (_) => _Api.upid;
      await pve.deleteBackup(vm, local);
      expect(api.paths, contains('DELETE $content'));

      // Over a running guest: refused before any request.
      final running = backupHost(vmState: 'running');
      final e = await _err(running.backend(token).restoreBackup(vm, local));
      expect(e.message, virtBackupIssueText('not_stopped'));
      expect(running.paths, isNot(contains('POST /nodes/pve/qemu')));
    });

    test('jobs: edited, a schedule refused first, checked, run on its nodes', () async {
      final api = backupHost()
        ..routes['PUT /cluster/backup/any'] = ((_) => null)
        ..routes['GET /cluster/jobs/schedule-analyze'] = ((_) => [
          {'timestamp': 1790000000},
        ]);
      final pve = api.backend(token);
      VirtBackupJobEdit edit(String schedule) => VirtBackupJobEdit(
        id: 'any',
        node: null,
        storage: 'nfs',
        schedule: schedule,
        vmids: const [9941],
      );
      await pve.editBackupJob(edit('sat 03:00'));
      expect(form(api.bodies[api.paths.indexOf('PUT /cluster/backup/any')]), containsPair('schedule', 'sat 03:00'));
      final bad = await _err(pve.editBackupJob(edit('02:30 mon')));
      expect(bad.message, virtBackupIssueText('schedule_invalid'));
      expect(api.paths.where((p) => p == 'PUT /cluster/backup/any'), hasLength(1));

      final check = await pve.checkSchedule('02:00');
      expect(check.ok, isTrue);
      expect(check.next.single, DateTime.fromMillisecondsSinceEpoch(1790000000000, isUtc: true));
      // A value of the wrong shape is answered here, not asked.
      expect((await pve.checkSchedule('nope')).ok, isFalse);
      expect(api.paths.where((p) => p.contains('schedule-analyze')), hasLength(1));

      // No node of its own: every online node; one of its own that is not
      // online: refused.
      api.routes['GET /cluster/backup/j'] = (_) => {'id': 'j', 'type': 'vzdump', 'storage': 'nfs', 'all': 1};
      await pve.runBackupJob(const VirtBackupJob(id: 'j', all: true));
      expect(api.paths.where((p) => p.endsWith('/vzdump')), ['POST /nodes/pve/vzdump', 'POST /nodes/pve2/vzdump']);
      api.routes['GET /cluster/backup/j'] = (_) => {'id': 'j', 'type': 'vzdump', 'node': 'pve3', 'all': 1};
      final off = await _err(pve.runBackupJob(const VirtBackupJob(id: 'j')));
      expect(off.message, virtBackupIssueText('node_offline'));
    });
  });

  group('hardware through the session', () {
    Object? fixture(String name) =>
        jsonDecode(File('test/fixtures/pve/$name').readAsStringSync());

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

    /// The guest listed (each call reads it again), its configuration and
    /// pending list as captured from PVE 9.2, the node's figures, and the
    /// node's storage and bridge a change can name.
    _Api hwApi() => _Api()
      ..resources = [
        {'id': 'node/pve', 'type': 'node', 'node': 'pve', 'status': 'online', 'maxcpu': 12},
        {'id': 'qemu/9901', 'type': 'qemu', 'vmid': 9901, 'node': 'pve', 'status': 'running', 'name': 'sbhw-e2e-vm'},
      ]
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
      ..routes['GET /nodes'] = ((_) => [
        {'node': 'pve', 'status': 'online'},
      ])
      ..routes['GET /storage'] = ((_) => const [])
      ..routes['GET /nodes/pve/storage'] = ((_) => [
        {'storage': 'local-lvm', 'type': 'lvmthin', 'active': 1, 'enabled': 1, 'content': 'images,rootdir'},
      ])
      ..routes['GET /nodes/pve/network'] = ((_) => [
        {'iface': 'vmbr0', 'type': 'bridge', 'active': 1},
      ])
      ..routes['POST /nodes/pve/qemu/9901/config'] = ((_) => _Api.upid)
      ..routes['PUT /nodes/pve/qemu/9901/resize'] = ((_) => _Api.upid)
      ..routes['GET /nodes/pve/hardware/pci'] = ((_) => fixture('hardware_pci.json'))
      ..routes['GET /nodes/pve/hardware/usb'] = ((_) => fixture('hardware_usb.json'))
      ..routes['GET /cluster/mapping/usb'] = ((_) => fixture('mapping_usb.json'))
      ..routes['GET /cluster/mapping/pci'] = ((_) => fixture('mapping_pci.json'));

    Map<String, String> sent(_Api api, String key) {
      final i = api.paths.lastIndexOf(key);
      expect(i, isNot(-1), reason: '$key not sent: ${api.paths}');
      return Uri.splitQueryString(api.bodies[i]);
    }

    test('read: the guest, its pending changes, the node\'s limits and CPU models', () async {
      final hw = await hwApi().backend(token).hardware(vm);
      expect((hw.cpu.sockets, hw.cpu.cores, hw.cpu.type), (1, 2, 'host'));
      expect(hw.pending, isNotEmpty);
      expect(hw.revision, '698abb29c27485d3497f5b7a8ca4b6b2789c1cd1');
      expect(hw.limits.hostCpus, 12);
      expect(hw.cpuTypes, ['host', 'x86-64-v3']);
      // Without Sys.Audit on the node the guest still reads.
      final api = hwApi()
        ..routes['GET /nodes/pve/status'] = ((_) => _Api._status(403))
        ..routes['GET /nodes/pve/capabilities/qemu/cpu'] = ((_) => _Api._status(403));
      final bare = await api.backend(token).hardware(vm);
      expect(bare.limits.hostCpus, isNull);
      expect(bare.cpuTypes, isEmpty);
    });

    test('a change crosses, carrying the digest its read had', () async {
      final api = hwApi();
      final pve = api.backend(token);
      final hw = await pve.hardware(vm);
      await pve.changeHardware(vm, hw, const VirtHwSetCpu(sockets: 2, cores: 2, type: 'x86-64-v3'));
      expect(sent(api, 'POST /nodes/pve/qemu/9901/config'), {
        'sockets': '2',
        'cores': '2',
        'cpu': 'x86-64-v3,flags=+aes',
        'digest': hw.revision,
      });
      // What it names, by the node's own listing.
      await pve.changeHardware(vm, hw, VirtHwAddDisk(storage: _pool('local-lvm'), gib: 4));
      expect(sent(api, 'POST /nodes/pve/qemu/9901/config')['scsi1'], 'local-lvm:4');
      await pve.changeHardware(vm, hw, const VirtHwGrowDisk(key: 'scsi0', bytes: 3 << 30));
      expect(sent(api, 'PUT /nodes/pve/qemu/9901/resize'), {
        'disk': 'scsi0',
        'size': '3G',
        'digest': hw.revision,
      });
    });

    test('refused before anything is sent, in the rule\'s words', () async {
      final api = hwApi();
      final pve = api.backend(token);
      final hw = await pve.hardware(vm);
      final e = await _err(pve.changeHardware(vm, hw, const VirtHwGrowDisk(key: 'scsi0', bytes: 1)));
      expect(e.type, VirtErrType.unsupported);
      expect(e.message, virtHwIssueText(VirtHwIssue.diskShrink));
      expect(api.paths.where((p) => p.startsWith('POST') || p.startsWith('PUT')), isEmpty);
    });

    test('a stale digest is a conflict; a bad value the host\'s words', () async {
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

    test('host devices: a token gets mappings; root@pam the node\'s too', () async {
      final tokenDevs = await hwApi().backend(token).hostDevices(vm);
      expect(tokenDevs.mappingsOnly, isTrue);
      expect(tokenDevs.usb.map((d) => (d.id, d.mapping)), [('sbhwb-bt', true)]);
      expect(tokenDevs.pci.map((d) => (d.id, d.mapping)), [('sbhwb-xhci', true)]);
      expect(tokenDevs.iommu, isFalse);

      const password = PveConfig(addr: 'https://pve.lan:8006', auth: PveAuth.password);
      final root = await hwApi().backend(password, user: 'root').hostDevices(vm);
      expect(root.mappingsOnly, isFalse);
      // Hubs left out; the Bluetooth radio offered by id.
      expect(root.usb.map((d) => d.id), ['sbhwb-bt', '0bda:b023']);
      expect(root.pci.length, 1 + (fixture('hardware_pci.json')! as List).length);
    });
  });

  group('snapshots, storage, networks', () {

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
      expect(
        storages.whereType<Map>().map((e) => e['type']),
        containsAll(['dir', 'lvmthin']),
      );
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
      api.routes['GET /nodes'] = (_) => [
        {'node': 'pve', 'status': 'online'},
      ];
      api.routes['GET /storage'] = (_) => _Api._status(403);
      // `sbm_virt`'s captures, which its own tests read.
      Object? rust(String name) => jsonDecode(
        File('crates/sbm_virt/tests/fixtures/pve/$name').readAsStringSync(),
      );
      api.routes['GET /nodes/pve/storage'] = (_) => rust('node_storage.json');
      api.routes['GET /nodes/pve/storage/local-lvm/content'] =
          (_) => rust('content_local_lvm.json');
      final pve = api.backend(token);
      await pve.load();
      final pools = await pve.storagePools();
      expect(pools.map((p) => p.name), ['local', 'local-lvm']);
      expect(pools.first.path, isNull);
      final vols = await pve.volumes(pools.last);
      expect(vols, hasLength(6));
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
    _Api api0() => _Api()
      ..routes['GET /nodes'] = ((_) => [
        {'node': 'pve', 'status': 'online'},
      ]);

    // What the session decides is `sbm_virt`'s (crates/sbm_virt/tests/
    // pve_storage.rs); this is how the app says it.
    test('a privilege missing: which, where, and the command that grants it', () async {
      final api = api0()
        ..routes['GET /storage'] = ((_) => const [])
        ..routes['GET /nodes/pve/storage'] = ((_) => const [])
        ..routes['GET /nodes/pve/network'] = ((_) => const [])
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
        pve.manage(const VirtPoolCreate(name: 'data2', type: 'dir', source: '/d', node: 'pve')),
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

    test('a refusal before anything is sent says which rule', () async {
      final api = api0()
        ..routes['GET /nodes/pve/network'] = ((_) => [
          {'iface': 'vmbr0', 'type': 'bridge', 'cidr': '192.168.31.20/24', 'gateway': '192.168.31.1'},
        ]);
      final e = await _err(
        api.backend(token).manage(
          const VirtNetworkEditBridge(
            VirtNetwork(id: 'pve/vmbr0', name: 'vmbr0', node: 'pve', mode: 'bridge'),
            ports: 'nic1',
          ),
        ),
      );
      expect(e.type, VirtErrType.unsupported);
      expect(e.message, l10n.virtNetManagementIface);
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
