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
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/data/model/app/error.dart';
import 'package:server_box/data/model/server/pve_config.dart';
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
  group('PveResources', () {
    test('parses nodes and guests, skipping storage and SDN', () {
      final r = PveResources.parse(_resources, at: DateTime(2026));
      expect(r.nodes.map((n) => n.name), ['pve']);
      expect(r.nodes.single.memTotal, 29287632896);
      expect(r.guests.map((g) => g.id), [
        'lxc/100',
        'qemu/101',
        'qemu/102',
        'qemu/103',
        'qemu/9000',
        'qemu/104',
      ]);
      final lxc = r.guests.first;
      expect(lxc.kind, VirtGuestKind.lxc);
      expect(lxc.state, VirtGuestState.running);
      expect(lxc.tags, ['media', 'prod']);
      expect(lxc.uptime, const Duration(seconds: 1204757));
      // No suspend for a container.
      expect(lxc.actions, {
        VirtPowerAction.shutdown,
        VirtPowerAction.reboot,
        VirtPowerAction.forceStop,
      });
      expect(r.guests[1].actions, {VirtPowerAction.start});
      expect(r.guests[2].actions, contains(VirtPowerAction.suspend));

      final locked = r.guests[3];
      expect(locked.state, VirtGuestState.backup);
      expect(locked.stateReason, 'backup');
      // PVE lets a VM under backup be paused, and nothing else.
      expect(locked.actions, {VirtPowerAction.suspend});
      // Still running: the lock does not hide its counters.
      expect(r.samples['qemu/103']!.cpuPercent, closeTo(25, 0.001));
      expect(r.samples['qemu/103']!.memUsed, 1073741824);

      final template = r.guests[4];
      expect(template.template, isTrue);
      expect(template.actions, isEmpty);

      final paused = r.guests[5];
      expect(paused.state, VirtGuestState.paused);
      expect(paused.actions, {
        VirtPowerAction.resume,
        VirtPowerAction.forceStop,
      });

      // CPU is a fraction of the guest's own CPUs; a stopped guest has none.
      expect(r.samples['lxc/100']!.cpuPercent, closeTo(5.446, 0.001));
      expect(r.samples['qemu/101']!.cpuPercent, isNull);
      // QEMU without the guest agent reports disk 0: not measured.
      expect(r.samples['qemu/102']!.diskUsed, isNull);
    });

    test('a lock leaves only what PVE allows under it', () {
      Set<VirtPowerAction> of(
        String status,
        String? lock, [
        VirtGuestKind kind = VirtGuestKind.qemu,
      ]) => PveResources.actionsOf(
        status,
        lock,
        kind,
        PveResources.stateOf(status, lock),
      );
      // `vm_suspend` / `vm_resume` skip the lock check for a backup only.
      expect(of('running', 'backup'), {VirtPowerAction.suspend});
      expect(of('paused', 'backup'), {VirtPowerAction.resume});
      expect(of('stopped', 'backup'), isEmpty);
      expect(of('running', 'backup', VirtGuestKind.lxc), isEmpty);
      for (final lock in ['snapshot', 'clone', 'rollback', 'migrate']) {
        expect(of('running', lock), isEmpty, reason: lock);
        expect(of('paused', lock), isEmpty, reason: lock);
      }
      // A hibernated VM: `start` resumes it.
      expect(of('stopped', 'suspended'), {VirtPowerAction.start});
      expect(of('paused', null), {
        VirtPowerAction.resume,
        VirtPowerAction.forceStop,
      });
    });

    test('status and lock map to one state', () {
      VirtGuestState of(String? status, [String? lock]) =>
          PveResources.stateOf(status, lock);
      expect(of('running', 'migrate'), VirtGuestState.migrating);
      expect(of('stopped', 'suspended'), VirtGuestState.stopped);
      expect(of('running', 'suspending'), VirtGuestState.stopping);
      expect(of('prelaunch'), VirtGuestState.starting);
      expect(of('io-error'), VirtGuestState.paused);
      expect(of('guest-panicked'), VirtGuestState.unknown);
      expect(PveResources.stateOf(null, null), VirtGuestState.unknown);
    });

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

    test('rrddata is already rates, sorted oldest first', () {
      final points = PveResources.parseRrd([
        {'time': 1700000060, 'cpu': 0.5, 'netin': 10.5, 'maxmem': 1024.0},
        {'time': 1700000000, 'cpu': 0.25, 'diskread': 3.0},
        {'cpu': 1},
      ]);
      expect(points, hasLength(2));
      expect(points.first.cpu, 25);
      expect(points.first.diskRead, 3);
      expect(points.last.netIn, 10.5);
      expect(points.last.memTotal, 1024);
    });
  });

  group('auth', () {
    test('an API token goes in every request, with no login', () async {
      final api = _Api()..resources = _resources;
      final pve = api.backend(
        const PveConfig(
          addr: 'https://pve.lan:8006',
          auth: PveAuth.token,
          tokenId: 'root@pam!sb',
          tokenSecret: 's3cret',
        ),
      );
      final snap = await pve.load();
      expect(snap.guests, hasLength(6));
      expect(snap.host.version, '8.2.4');
      expect(api.paths, ['GET /version', 'GET /cluster/resources']);
      for (final headers in api.headers) {
        expect(headers['Authorization'], 'PVEAPIToken=root@pam!sb=s3cret');
        expect(headers.containsKey('Cookie'), isFalse);
        expect(headers.containsKey('CSRFPreventionToken'), isFalse);
      }
    });

    test('a token that may see nothing says so, with the ACL to grant', () async {
      // Privilege separation on and no ACL of its own: PVE answers with the
      // node's bare name and nothing else, not a refusal (PVE 9.2).
      final api = _Api()
        ..resources = [
          {
            'id': 'node/pve',
            'node': 'pve',
            'type': 'node',
            'status': 'online',
            'level': '',
            'cgroup-mode': 2,
          },
        ]
        ..routes['GET /access/permissions'] = ((_) => {});
      const token = PveConfig(
        addr: 'https://pve.lan:8006',
        auth: PveAuth.token,
        tokenId: 'root@pam!sb',
        tokenSecret: 's3cret',
      );
      final e = await _err(api.backend(token).load());
      expect(e.type, VirtErrType.permissionDenied);
      expect(
        e.message,
        contains("pveum acl modify / --tokens 'root@pam!sb' "
            '--roles PVEAuditor,PVEVMAdmin'),
      );
      expect(e.message, isNot(contains('s3cret')));

      // An empty host that may be audited is only empty.
      final empty = _Api()
        ..routes['GET /access/permissions'] = ((_) => {
          '/': {'Sys.Audit': 1, 'VM.Audit': 1},
        });
      expect((await empty.backend(token).load()).guests, isEmpty);
    });

    test('a refused token is authFailed naming the id, not the secret', () async {
      final api = _Api()..versionStatus = 401;
      final pve = api.backend(
        const PveConfig(
          addr: 'https://pve.lan:8006',
          auth: PveAuth.token,
          tokenId: 'root@pam!sb',
          tokenSecret: 's3cret',
        ),
      );
      final err = await _err(pve.load());
      expect(err.type, VirtErrType.authFailed);
      expect(err.message, contains('root@pam!sb'));
      expect(err.message, isNot(contains('s3cret')));
    });

    test('a password login carries its ticket and CSRF token', () async {
      final api = _Api()..resources = _resources;
      final pve = api.backend(const PveConfig(addr: 'https://pve.lan:8006'));
      await pve.load();
      expect(api.paths.first, 'POST /access/ticket');
      expect(api.bodies.first, contains('username=root'));
      expect(api.bodies.first, contains('realm=pam'));
      expect(api.bodies.first, contains('password=sshpw'));
      final last = api.headers.last;
      expect(last['Cookie'], 'PVEAuthCookie=T1');
      expect(last['CSRFPreventionToken'], 'C1');
    });

    test('TOTP: needTfa, then the code logs in', () async {
      final api = _Api()
        ..resources = _resources
        ..needTfa = true;
      final pve = api.backend(
        const PveConfig(addr: 'https://pve.lan:8006', pwd: 'pvepw'),
        sshKeyId: 'key',
      );
      final err = await _err(pve.load());
      expect(err.type, VirtErrType.needTfa);
      expect(api.bodies.first, contains('password=pvepw'));

      await pve.submitTfa('123456');
      final answer = api.bodies.lastWhere((b) => b.contains('tfa-challenge'));
      expect(answer, contains('tfa-challenge=CHALLENGE1'));
      expect(answer, contains('password=totp%3A123456'));
      final snap = await pve.load();
      expect(snap.guests, isNotEmpty);
      expect(api.headers.last['Cookie'], 'PVEAuthCookie=T2');
    });

    group('which password a password login sends', () {
      // Every earlier build's rule: the PVE password when SSH logs in with a
      // key (there is no SSH password to lend), the SSH password otherwise.
      test('SSH with a key: the PVE password', () async {
        final api = _Api()..resources = _resources;
        final pve = api.backend(
          const PveConfig(addr: 'https://pve.lan:8006', pwd: 'pvepw'),
          sshKeyId: 'key',
        );
        await pve.load();
        expect(api.bodies.first, contains('password=pvepw'));
      });

      test('SSH with a password: that one, whatever PVE has stored', () async {
        final api = _Api()..resources = _resources;
        final pve = api.backend(
          const PveConfig(addr: 'https://pve.lan:8006', pwd: 'stale'),
        );
        await pve.load();
        expect(api.bodies.first, contains('password=sshpw'));
        expect(api.bodies.first, isNot(contains('stale')));
      });

      test('SSH with a key and no PVE password: notConfigured', () async {
        final api = _Api();
        final pve = api.backend(
          const PveConfig(addr: 'https://pve.lan:8006'),
          sshKeyId: 'key',
        );
        expect((await _err(pve.load())).type, VirtErrType.notConfigured);
        expect(api.paths, isEmpty);
      });

      test('a password is sent as stored, spaces included', () async {
        final api = _Api()..resources = _resources;
        final pve = api.backend(
          const PveConfig(addr: 'https://pve.lan:8006'),
          sshPassword: ' pw ',
        );
        await pve.load();
        expect(api.bodies.first, contains('password=+pw+&'));
      });

      test('the helper itself', () {
        const cfg = PveConfig(addr: 'https://h', pwd: 'pve');
        expect(cfg.loginPassword(sshKeyId: 'k', sshPassword: 'ssh'), 'pve');
        expect(cfg.loginPassword(sshKeyId: null, sshPassword: 'ssh'), 'ssh');
      });
    });

    test('a refused login without PVE text carries no made-up sentence', () {
      // The UI titles authFailed in the user's language; a fallback written
      // here would be English whatever the language.
      final api = _Api()..ticketStatus = 401;
      final pve = api.backend(const PveConfig(addr: 'https://pve.lan:8006'));
      return _err(pve.load()).then((err) {
        expect(err.type, VirtErrType.authFailed);
        expect(err.message, isNull);
      });
    });

    test('no user and no token is notConfigured', () async {
      final api = _Api();
      final pve = api.backend(
        const PveConfig(addr: 'https://pve.lan:8006'),
        user: null,
      );
      expect((await _err(pve.load())).type, VirtErrType.notConfigured);
      expect(api.paths, isEmpty);
    });
  });

  group('expired sessions', () {
    test('a refused ticket: one new login and the request repeated', () async {
      // What an expired ticket looks like: PVE answers the listing 401, and a
      // login with the stored password works.
      final api = _Api()..resources = _resources;
      final pve = api.backend(const PveConfig(addr: 'https://pve.lan:8006'));
      await pve.load();
      api.resources401 = 1;
      final snap = await pve.load();
      expect(snap.guests, hasLength(6));
      expect(api.closed, 1, reason: 'the refused session is dropped');
      expect(api.paths.where((p) => p == 'POST /access/ticket'), hasLength(2));
      expect(api.headers.last['Cookie'], 'PVEAuthCookie=T2');
    });

    test('a 401 a new login does not fix is authFailed, and drops the '
        'session', () async {
      final api = _Api()..resources = _resources;
      final pve = api.backend(const PveConfig(addr: 'https://pve.lan:8006'));
      await pve.load();
      api.resourcesStatus = 401;
      final err = await _err(pve.load());
      expect(err.type, VirtErrType.authFailed);
      expect(
        api.paths.where((p) => p == 'GET /cluster/resources'),
        hasLength(3),
        reason: 'the first load, the refused one, and one repeat',
      );
      expect(api.closed, 2, reason: 'both sessions are dropped');

      api.resourcesStatus = 200;
      await pve.load();
      expect(
        api.paths.where((p) => p == 'POST /access/ticket'),
        hasLength(3),
        reason: 'the next call logs in again',
      );
    });

    test('a 401 in the session the call logged in is not repeated', () async {
      final api = _Api()
        ..resources = _resources
        ..resourcesStatus = 401;
      final pve = api.backend(const PveConfig(addr: 'https://pve.lan:8006'));
      expect((await _err(pve.load())).type, VirtErrType.authFailed);
      expect(api.paths.where((p) => p == 'POST /access/ticket'), hasLength(1));
    });

    test('a refused token is not retried', () async {
      final api = _Api()..resources = _resources;
      final pve = api.backend(
        const PveConfig(
          addr: 'https://pve.lan:8006',
          auth: PveAuth.token,
          tokenId: 'root@pam!sb',
          tokenSecret: 's3cret',
        ),
      );
      await pve.load();
      api.resources401 = 1;
      expect((await _err(pve.load())).type, VirtErrType.authFailed);
      expect(api.paths.where((p) => p == 'GET /cluster/resources'), hasLength(2));
    });

    // PVE answers 403 only from its permission check, after it has accepted
    // the ticket or token: the session is good, the account lacks a privilege
    // on that path. This test once asserted the session was dropped, which
    // threw away a valid ticket and made a TOTP account type a code again to
    // be refused the same way. Only a 401 says the session itself is bad.
    test('a refused action keeps the session and says why', () async {
      final api = _Api()..resources = _resources;
      final pve = api.backend(const PveConfig(addr: 'https://pve.lan:8006'));
      final guest = (await pve.load()).guests[1];
      api.actionStatus = 403;
      final err = await _err(pve.power(guest, VirtPowerAction.start));
      expect(err.type, VirtErrType.actionFailed);
      expect(err.message, contains('Permission check failed'));
      expect(api.closed, 0, reason: 'the session is kept');

      api.actionStatus = 200;
      await pve.load();
      expect(
        api.paths.where((p) => p == 'POST /access/ticket'),
        hasLength(1),
        reason: 'no second login',
      );
    });

    test('a refused console ticket keeps the session', () async {
      final api = _Api()..resources = _resources;
      final pve = api.backend(const PveConfig(addr: 'https://pve.lan:8006'));
      final lxc = (await pve.load()).guests.first;
      api.consoleStatus = 403;
      final err = await _err(pve.console(lxc, VirtConsoleKind.text));
      expect(err.type, VirtErrType.actionFailed);
      expect(err.message, contains('VM.Console'));
      expect(api.closed, 0);
    });

    test('a 403 on a listing is authFailed and keeps the session', () async {
      final api = _Api()..resources = _resources;
      final pve = api.backend(const PveConfig(addr: 'https://pve.lan:8006'));
      await pve.load();
      api.resourcesStatus = 403;
      expect((await _err(pve.load())).type, VirtErrType.authFailed);
      expect(api.closed, 0);
    });

    test('a 401 on an action drops the session; the action is sent again '
        'once, after a new login', () async {
      final api = _Api()..resources = _resources;
      final pve = api.backend(const PveConfig(addr: 'https://pve.lan:8006'));
      final guest = (await pve.load()).guests[1];
      api.actionStatus = 401;
      final err = await _err(pve.power(guest, VirtPowerAction.start));
      expect(err.type, VirtErrType.authFailed);
      expect(
        api.paths.where((p) => p == 'POST /nodes/pve/qemu/101/status/start'),
        hasLength(2),
      );
      expect(api.closed, 2);
    });

    test('a reset during a login waits for it, and the stale one never '
        'becomes the session', () async {
      final api = _Api()..resources = _resources;
      final release = Completer<void>();
      api.ticketGate = release.future;
      final pve = api.backend(const PveConfig(addr: 'https://pve.lan:8006'));

      final first = pve.load();
      await api.ticketRequested.future.timeout(const Duration(seconds: 2));
      await pve.reset();
      final second = pve.load();
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(
        api.paths.where((p) => p == 'POST /access/ticket'),
        hasLength(1),
        reason: 'the new login must not overlap the stale one',
      );

      api.ticketGate = null;
      release.complete();
      await Future.wait([first, second]);
      expect(api.paths.where((p) => p == 'POST /access/ticket'), hasLength(2));
      expect(api.maxConcurrentTickets, 1);
      // The stale login's client was closed, and its ticket is not in use.
      expect(api.closed, greaterThanOrEqualTo(1));
      expect(api.headers.last['Cookie'], 'PVEAuthCookie=T2');
    });
  });

  group('ticket lifetime', () {
    const tfaCfg = PveConfig(addr: 'https://pve.lan:8006', pwd: 'pvepw');

    Future<PveBackend> loggedIn(_Api api, DateTime Function() now) async {
      final pve = api.backend(tfaCfg, sshKeyId: 'key', now: now);
      expect((await _err(pve.load())).type, VirtErrType.needTfa);
      await pve.submitTfa('123456');
      await pve.load();
      return pve;
    }

    int logins(_Api api) =>
        api.bodies.where((b) => b.contains('password=pvepw')).length;

    test('an hour on, the ticket is renewed with itself, no code asked',
        () async {
      var now = DateTime(2026, 1, 1);
      final api = _Api()
        ..resources = _resources
        ..needTfa = true;
      final pve = await loggedIn(api, () => now);
      expect(api.headers.last['Cookie'], 'PVEAuthCookie=T2');

      now = now.add(const Duration(minutes: 59));
      await pve.load();
      expect(api.paths.where((p) => p == 'POST /access/ticket'), hasLength(2));

      now = now.add(const Duration(minutes: 2));
      final snap = await pve.load();
      expect(snap.guests, isNotEmpty);
      final renewal = api.bodies.lastWhere((b) => b.contains('password=T'));
      expect(renewal, contains('password=T2'));
      expect(renewal, isNot(contains('tfa-challenge')));
      expect(api.headers.last['Cookie'], 'PVEAuthCookie=T3');
      expect(logins(api), 1, reason: 'no new login');

      // Renewed: the clock starts again.
      now = now.add(const Duration(minutes: 30));
      await pve.load();
      expect(api.headers.last['Cookie'], 'PVEAuthCookie=T3');
    });

    test('renewals running together are one request', () async {
      var now = DateTime(2026, 1, 1);
      final api = _Api()..resources = _resources;
      final pve = api.backend(
        const PveConfig(addr: 'https://pve.lan:8006'),
        now: () => now,
      );
      await pve.load();
      now = now.add(const Duration(minutes: 61));
      await Future.wait([pve.load(), pve.load(), pve.load()]);
      expect(api.paths.where((p) => p == 'POST /access/ticket'), hasLength(2));
    });

    test('a refused renewal logs in again, which asks for a code', () async {
      var now = DateTime(2026, 1, 1);
      final api = _Api()
        ..resources = _resources
        ..needTfa = true;
      final pve = await loggedIn(api, () => now);
      api.renewStatus = 401;
      now = now.add(const Duration(minutes: 61));
      expect((await _err(pve.load())).type, VirtErrType.needTfa);
      expect(logins(api), 2);
    });

    test('past the lifetime nothing is renewed: a new login', () async {
      var now = DateTime(2026, 1, 1);
      final api = _Api()
        ..resources = _resources
        ..needTfa = true;
      final pve = await loggedIn(api, () => now);
      now = now.add(PveBackend.ticketLifetime);
      expect((await _err(pve.load())).type, VirtErrType.needTfa);
      expect(api.bodies.where((b) => b.contains('password=T')), isEmpty);
      expect(logins(api), 2);
    });

    test('a failed renewal that is not a refusal keeps the ticket', () async {
      var now = DateTime(2026, 1, 1);
      final api = _Api()..resources = _resources;
      final pve = api.backend(
        const PveConfig(addr: 'https://pve.lan:8006'),
        now: () => now,
      );
      await pve.load();
      api.renewStatus = 500;
      now = now.add(const Duration(minutes: 61));
      await pve.load();
      expect(api.headers.last['Cookie'], 'PVEAuthCookie=T1');
      expect(api.closed, 0);
    });
  });

  group('TOTP challenges', () {
    const cfg = PveConfig(addr: 'https://pve.lan:8006', pwd: 'pvepw');

    test('a wrong code keeps the challenge for the next one', () async {
      final api = _Api()
        ..resources = _resources
        ..needTfa = true
        ..tfaStatus = 401;
      final pve = api.backend(cfg, sshKeyId: 'key');
      await _err(pve.load());
      final wrong = await _err(pve.submitTfa('000000'));
      expect(wrong.type, VirtErrType.needTfa);
      api.tfaStatus = 200;
      await pve.submitTfa('123456');
      final answers = api.bodies.where((b) => b.contains('tfa-challenge'));
      expect(answers, everyElement(contains('tfa-challenge=CHALLENGE1')));
      expect(api.bodies.where((b) => b.contains('password=pvepw')), hasLength(1));
    });

    test('a challenge past its lifetime is replaced before the code answers',
        () async {
      // PVE answers an expired challenge as it answers a wrong code, so
      // answering it would read as a wrong code however often it was typed.
      var now = DateTime(2026, 1, 1);
      final api = _Api()
        ..resources = _resources
        ..needTfa = true;
      final pve = api.backend(cfg, sshKeyId: 'key', now: () => now);
      await _err(pve.load());
      now = now.add(PveBackend.ticketLifetime);
      await pve.submitTfa('123456');
      final answer = api.bodies.lastWhere((b) => b.contains('tfa-challenge'));
      expect(answer, contains('tfa-challenge=CHALLENGE2'));
      expect(answer, contains('password=totp%3A123456'));
      expect((await pve.load()).guests, isNotEmpty);
    });

    test('a challenge dropped by a reset is replaced, not reported', () async {
      final api = _Api()
        ..resources = _resources
        ..needTfa = true;
      final pve = api.backend(cfg, sshKeyId: 'key');
      await _err(pve.load());
      await pve.reset();
      await pve.submitTfa('123456');
      final answer = api.bodies.lastWhere((b) => b.contains('tfa-challenge'));
      expect(answer, contains('tfa-challenge=CHALLENGE2'));
      expect((await pve.load()).guests, isNotEmpty);
    });

    test('an empty code asks nothing of PVE', () async {
      final api = _Api()
        ..resources = _resources
        ..needTfa = true;
      final pve = api.backend(cfg, sshKeyId: 'key');
      await _err(pve.load());
      final before = api.paths.length;
      expect((await _err(pve.submitTfa('  '))).type, VirtErrType.needTfa);
      expect(api.paths, hasLength(before));
    });
  });

  group('power', () {
    test('waits for the UPID task to stop', () async {
      final api = _Api()
        ..resources = _resources
        ..taskStates = ['running', 'running', 'stopped'];
      final pve = api.backend(const PveConfig(addr: 'https://pve.lan:8006'));
      final guest = (await pve.load()).guests[2];
      await pve.power(guest, VirtPowerAction.suspend);
      expect(api.paths, contains('POST /nodes/pve/qemu/102/status/suspend'));
      final polls = api.paths.where((p) => p.contains('/tasks/')).toList();
      expect(polls, hasLength(3));
      expect(polls.first, contains(Uri.encodeComponent(_Api.upid)));
    });

    test('a task ending in an error is actionFailed with its text', () async {
      final api = _Api()
        ..resources = _resources
        ..taskStates = ['stopped']
        ..taskExit = "can't lock file '/var/lock/qemu-server/lock-101.conf'";
      final pve = api.backend(const PveConfig(addr: 'https://pve.lan:8006'));
      final guest = (await pve.load()).guests[1];
      final err = await _err(pve.power(guest, VirtPowerAction.start));
      expect(err.type, VirtErrType.actionFailed);
      expect(err.message, contains("can't lock file"));
    });

    test('the state after an action shows before /cluster/resources catches '
        'up', () async {
      var now = DateTime(2026, 1, 1);
      final api = _Api()
        ..resources = _resources
        // What PVE 9.2 answered: status/current already `stopped` while the
        // listing still said `running`.
        ..current = {'status': 'stopped', 'qmpstatus': 'stopped'};
      final pve = api.backend(
        const PveConfig(addr: 'https://pve.lan:8006'),
        now: () => now,
      );
      VirtGuest vm(VirtSnapshot s) =>
          s.guests.firstWhere((g) => g.id == 'qemu/102');
      final running = vm(await pve.load());
      expect(running.state, VirtGuestState.running);
      await pve.power(running, VirtPowerAction.forceStop);
      expect(api.paths.last, 'GET /nodes/pve/qemu/102/status/current');

      now = now.add(const Duration(seconds: 2));
      final snap = await pve.load();
      expect(vm(snap).state, VirtGuestState.stopped);
      expect(vm(snap).actions, {VirtPowerAction.start});
      expect(snap.stats['qemu/102']!.cpu, isNull, reason: 'not running');

      // The listing still lags past the window: it is believed again.
      now = now.add(PveBackend.freshStatusFor);
      expect(vm(await pve.load()).state, VirtGuestState.running);
    });

    test('force stop overrules a pending shutdown, where PVE knows how', () async {
      Future<String> stopBody(String version) async {
        final api = _Api()
          ..resources = _resources
          ..version = version
          ..current = {'status': 'stopped', 'qmpstatus': 'stopped'};
        final pve = api.backend(const PveConfig(addr: 'https://pve.lan:8006'));
        final vm = (await pve.load()).guests.firstWhere(
          (g) => g.id == 'qemu/102',
        );
        await pve.power(vm, VirtPowerAction.forceStop);
        final at = api.paths.indexOf('POST /nodes/pve/qemu/102/status/stop');
        expect(at, isNonNegative);
        return api.bodies[at];
      }

      expect(await stopBody('9.2.2'), contains('overrule-shutdown=1'));
      expect(await stopBody('8.1.3'), contains('overrule-shutdown=1'));
      // Older releases refuse a parameter they do not know.
      expect(await stopBody('8.0.4'), isNot(contains('overrule-shutdown')));
      expect(await stopBody('7.4-3'), isNot(contains('overrule-shutdown')));
    });

    test('the listing agreeing ends the overlay', () async {
      final api = _Api()
        ..resources = _resources
        ..current = {'status': 'running', 'qmpstatus': 'paused'};
      final pve = api.backend(const PveConfig(addr: 'https://pve.lan:8006'));
      final running = (await pve.load()).guests.firstWhere(
        (g) => g.id == 'qemu/102',
      );
      await pve.power(running, VirtPowerAction.suspend);
      // The QEMU run state wins over `status`, as pvestatd reports it.
      VirtGuest vm(VirtSnapshot s) =>
          s.guests.firstWhere((g) => g.id == 'qemu/102');
      expect(vm(await pve.load()).state, VirtGuestState.paused);
      api.resources = [
        for (final r in _resources)
          r['id'] == 'qemu/102' ? {...r, 'status': 'paused'} : r,
      ];
      expect(vm(await pve.load()).state, VirtGuestState.paused);
      // Caught up, so a later change in the listing is taken as it is.
      api.resources = _resources;
      expect(vm(await pve.load()).state, VirtGuestState.running);
    });

    test('after a reboot the old uptime is not believed', () async {
      var now = DateTime(2026, 1, 1);
      final api = _Api()
        ..resources = _resources
        ..current = {'status': 'running', 'uptime': 3};
      final pve = api.backend(
        const PveConfig(addr: 'https://pve.lan:8006'),
        now: () => now,
      );
      VirtGuest vm(VirtSnapshot s) =>
          s.guests.firstWhere((g) => g.id == 'qemu/102');
      final before = vm(await pve.load());
      expect(before.uptime, greaterThan(const Duration(minutes: 1)));
      await pve.power(before, VirtPowerAction.reboot);
      now = now.add(const Duration(seconds: 4));
      expect(vm(await pve.load()).uptime, const Duration(seconds: 7));
      // pvestatd has caught up.
      api.resources = [
        for (final r in _resources)
          r['id'] == 'qemu/102' ? {...r, 'uptime': 12} : r,
      ];
      now = now.add(const Duration(seconds: 6));
      expect(vm(await pve.load()).uptime, const Duration(seconds: 12));
    });

    test('an uptime of 0 read right after a reboot counts up', () async {
      var now = DateTime(2026, 1, 1);
      final api = _Api()
        ..resources = _resources
        ..current = {'status': 'running', 'uptime': 0};
      final pve = api.backend(
        const PveConfig(addr: 'https://pve.lan:8006'),
        now: () => now,
      );
      VirtGuest vm(VirtSnapshot s) =>
          s.guests.firstWhere((g) => g.id == 'qemu/102');
      await pve.power(vm(await pve.load()), VirtPowerAction.reboot);
      now = now.add(const Duration(seconds: 5));
      final after = vm(await pve.load());
      expect(after.state, VirtGuestState.running);
      expect(after.uptime, const Duration(seconds: 5));
    });

    test('a VM read as stopped right after its reboot task is asked again '
        'until it runs', () async {
      final api = _Api()
        ..resources = _resources
        // PVE 9.2: `qmreboot` ends once the guest is down, and `qmeventd`
        // starts it again a moment later.
        ..currentFirst.addAll([
          {'status': 'stopped', 'qmpstatus': 'stopped'},
          {'status': 'stopped', 'qmpstatus': 'stopped'},
        ])
        ..current = {'status': 'running', 'qmpstatus': 'running', 'uptime': 1};
      final pve = api.backend(const PveConfig(addr: 'https://pve.lan:8006'));
      VirtGuest vm(VirtSnapshot s) =>
          s.guests.firstWhere((g) => g.id == 'qemu/102');
      await pve.power(vm(await pve.load()), VirtPowerAction.reboot);
      expect(
        api.paths.where((p) => p.endsWith('/status/current')),
        hasLength(3),
      );
      final after = vm(await pve.load());
      expect(after.state, VirtGuestState.running);
      expect(after.actions, contains(VirtPowerAction.reboot));
    });

    test('a guest that stays down after a reboot is believed in the end',
        () async {
      var now = DateTime(2026, 1, 1);
      final api = _Api()
        ..resources = _resources
        ..current = {'status': 'stopped', 'qmpstatus': 'stopped'};
      final pve = api.backend(
        const PveConfig(addr: 'https://pve.lan:8006'),
        now: () => now = now.add(const Duration(seconds: 1)),
      );
      VirtGuest vm(VirtSnapshot s) =>
          s.guests.firstWhere((g) => g.id == 'qemu/102');
      await pve.power(vm(await pve.load()), VirtPowerAction.reboot);
      final reads = api.paths.where((p) => p.endsWith('/status/current'));
      expect(reads.length, greaterThan(1));
      expect(reads.length, lessThan(40));
      expect(vm(await pve.load()).state, VirtGuestState.stopped);
    });

    test('other actions read the state once', () async {
      final api = _Api()
        ..resources = _resources
        ..current = {'status': 'stopped', 'qmpstatus': 'stopped'};
      final pve = api.backend(const PveConfig(addr: 'https://pve.lan:8006'));
      final running = (await pve.load()).guests.firstWhere(
        (g) => g.id == 'qemu/102',
      );
      await pve.power(running, VirtPowerAction.shutdown);
      expect(
        api.paths.where((p) => p.endsWith('/status/current')),
        hasLength(1),
      );
    });

    test('an action the guest does not offer is not sent', () async {
      final api = _Api()..resources = _resources;
      final pve = api.backend(const PveConfig(addr: 'https://pve.lan:8006'));
      final lxc = (await pve.load()).guests.first;
      final err = await _err(pve.power(lxc, VirtPowerAction.suspend));
      expect(err.type, VirtErrType.unsupported);
      expect(api.paths.where((p) => p.contains('/status/')), isEmpty);
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

  test('rates come from successive samples, held between PVE updates', () async {
    var now = DateTime(2026, 1, 1, 0, 0, 0);
    final api = _Api()..resources = _resources;
    final pve = api.backend(
      const PveConfig(addr: 'https://pve.lan:8006'),
      now: () => now,
    );
    var snap = await pve.load();
    expect(snap.stats['lxc/100']!.netIn, isNull, reason: 'nothing to diff');

    now = now.add(const Duration(seconds: 10));
    api.resources = [
      {..._resources.first, 'netin': 65412250538 + 10000},
      ..._resources.skip(1),
    ];
    snap = await pve.load();
    expect(snap.stats['lxc/100']!.netIn, 1000);
    expect(snap.stats['lxc/100']!.diskRead, 0);

    // pvestatd has not updated yet: the rate holds rather than dropping to 0.
    now = now.add(const Duration(seconds: 3));
    snap = await pve.load();
    expect(snap.stats['lxc/100']!.netIn, 1000);
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
            searchDomain: 'lab.example',
          ),
          start: true,
        ),
      );
      expect(created.startError, isNull);
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
      // Grown to the size asked for, then started.
      final resize = api.paths.indexOf('PUT /nodes/pve/qemu/107/resize');
      expect(form(api.bodies[resize]), {'disk': 'scsi0', 'size': '16G'});
      final start = api.paths.indexOf('POST /nodes/pve/qemu/107/status/start');
      expect(i < resize && resize < start, isTrue);
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
      // The session stays: a refusal is not a failed login.
      expect(api.closed, 0);
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
  final queries = <String>[];
  final bodies = <String>[];
  final headers = <Map<String, Object?>>[];
  final ticketRequested = Completer<void>();
  int closed = 0;
  int _tickets = 0;
  int _ticketsInFlight = 0;
  int maxConcurrentTickets = 0;
  int _taskPolls = 0;

  PveBackend backend(
    PveConfig config, {
    String? user = 'root',
    String? sshKeyId,
    String sshPassword = 'sshpw',
    DateTime Function()? now,
  }) => PveBackend(
    serverId: 'srv',
    config: config,
    user: user,
    sshKeyId: sshKeyId,
    sshPassword: sshPassword,
    connect: (_, _) => throw StateError('no network in this test'),
    adapter: () => _Adapter(this),
    taskPoll: const Duration(milliseconds: 1),
    now: now,
  );

  Future<ResponseBody> handle(RequestOptions o, String body) async {
    final path = o.uri.path.replaceFirst('/api2/json', '');
    final key = '${o.method} $path';
    paths.add(key);
    queries.add(o.uri.query);
    bodies.add(body);
    headers.add(Map.of(o.headers));
    if (routes[key] case final route?) {
      final answer = route(body);
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

class _Adapter implements HttpClientAdapter {
  _Adapter(this.api);

  final _Api api;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final bytes = <int>[];
    if (requestStream != null) {
      await for (final chunk in requestStream) {
        bytes.addAll(chunk);
      }
    }
    return api.handle(options, utf8.decode(bytes));
  }

  @override
  void close({bool force = false}) => api.closed++;
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
