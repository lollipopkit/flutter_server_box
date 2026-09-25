/// `PveBackend` against a scripted PVE API: parsing, auth (ticket, TOTP,
/// token), session drop on 401 and not on 403, the generation guard, UPID
/// polling, and snapshots, storage and networks against payloads captured
/// from PVE 9.2.2 (`test/fixtures/pve/`).
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
import 'package:server_box/data/model/virt/virt_console.dart';
import 'package:server_box/data/model/virt/virt_detail.dart';
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
      return _json({'version': '8.2.4', 'release': '8.2'});
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

  static ResponseBody _status(int code, {String? message}) =>
      ResponseBody.fromString(
        jsonEncode({'data': null, 'message': ?message}),
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
