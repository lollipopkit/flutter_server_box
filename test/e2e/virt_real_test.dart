/// Opt-in end-to-end test of the Virtualization tab's backends against real
/// hosts, over the client the app uses (dartssh2) and the real
/// `LibvirtBackend` / `PveBackend` / console code — no fakes below the
/// backend.
///
/// Every group is skipped silently unless its variables are set, in the
/// environment or the workspace-root `.env` (never commit secrets there):
///
/// - `SBM_E2E_LIBVIRT_HOST` — SSH destination of a libvirt host (anything the
///   system `ssh` accepts; `ssh -G` supplies the address, user and keys), whose
///   account reaches `qemu:///system`. It must have three domains, named by
///   default as below and overridable:
///   - `SBM_E2E_LIBVIRT_RUNNING` (`cirros-run`): running, TCP VNC, a serial
///     console. **Destroyed and started again** by the power test.
///   - `SBM_E2E_LIBVIRT_PAUSED` (`cirros-paused`): paused. Resumed and paused
///     again.
///   - `SBM_E2E_LIBVIRT_STOPPED` (`it's-"odd"`): shut off. Started and
///     destroyed when the host allows it.
///
///   The running and the stopped domain get snapshots named `sbxe2e-*`
///   (their writable disks must be qcow2), reverted to and deleted again;
///   pools, networks and hardware are only listed.
/// - `SBM_E2E_PVE_HOST` — SSH destination of a Proxmox VE node. The API is
///   reached through an SSH channel to `https://localhost:8006`, and directly
///   at `SBM_E2E_PVE_ADDR` (default `https://<ssh hostname>:8006`).
/// - `SBM_E2E_PVE_TOKEN_ID`, `SBM_E2E_PVE_TOKEN_SECRET` — an API token
///   (`user@realm!name`) with `VM.Audit`, `VM.PowerMgmt`, `VM.Console` and
///   `Sys.Audit`. Read from the environment only by this file; never printed.
/// - `SBM_E2E_PVE_USB` (`vendor:product`) and `SBM_E2E_PVE_PCI` (an address,
///   `0000:01:00.0`), with `SBM_E2E_PVE_HOST` reached as root: real
///   passthrough of that host device to a temporary VM, through a temporary
///   resource mapping made over SSH and granted to the token
///   (`PVEMappingUser` on it) — how a token is allowed a device at all. The
///   VM is started with it and the device checked in its QEMU command line,
///   then stopped, the device taken off, the VM deleted, the mapping and the
///   grant removed. PCI needs the IOMMU on; nothing here changes the host.
///   **The device is the guest's while it runs.**
/// - `SBM_E2E_PVE_LXC` (default `200`): a running container. **Rebooted**, and
///   over SSH **snapshotted, rolled back (and started again) and the snapshot
///   deleted**, on a storage that supports snapshots. Its console is typed
///   into, at the login prompt only.
/// - `SBM_E2E_PVE_VM` (default `100`): a running VM with a `serialN` port and
///   a display. Only read: its serial console is connected to and closed
///   without input, its VNC console is authenticated and closed.
/// - `SBM_E2E_SSH_KEY_PASSPHRASE`: only for an encrypted key.
///
/// Creating and deleting, groups of their own that touch nothing existing
/// (`--plain-name 'create and delete'` runs only them): on the libvirt host a
/// VM `sbme2e-vm-*` with a 1 GiB disk in the first pool, the first ISO and
/// the `default` network; on the PVE node a VM and — where a template is
/// there — a container `sbme2e-*`. Each is started, refused a second time,
/// refused deletion while running, force-stopped and deleted with its disk.
/// The PVE token then needs `VM.Allocate`, `VM.Config.*`,
/// `Datastore.AllocateSpace` and `SDN.Use` as well.
///
/// A QEMU VM of the test's own, a group of its own (needs the three PVE
/// variables above, and the `SBM_E2E_PVE_HOST` login to be root for `qm`):
///
/// - `SBM_E2E_PVE_TEST_VM`: the VMID of a VM nothing else depends on, with a
///   `serialN` port that has a getty on it, `vga` other than `none`/`serialN`,
///   one `scsi0` disk of 8 GiB on `local-lvm`, a cloud-init drive on `ide2`,
///   one virtio NIC on `vmbr0` and `ostype: l26`; a guest that honours ACPI.
///   **Started, suspended, rebooted, shut down, force-stopped, locked with
///   `qm set --lock` and unlocked, over each transport; over SSH also
///   snapshotted without and with memory, rolled back to each and the
///   snapshots deleted; left stopped.**
/// - `SBM_E2E_PVE_TEST_VM_ROOT_PASSWORD` (optional): root's password on that
///   serial console; the test logs in and runs a command. Unset, it only
///   checks that getty answers a login name.
///
/// Password login, a group of its own (needs `SBM_E2E_PVE_HOST`, not the
/// token). The `SBM_E2E_PVE_HOST` login must be root: it disables and
/// re-enables the accounts below with `pveum` and reads `pvedaemon`'s journal.
/// Every secret is read from the environment only and never printed.
///
/// - `SBM_E2E_PVE_PWD_USER`, `SBM_E2E_PVE_PWD`: a Linux account on the node,
///   `<user>@pam` in PVE, with the privileges the token has, that password
///   for both, and no second factor. **Disabled and enabled again.**
/// - `SBM_E2E_PVE_USER_IDENTITY`: an unencrypted private key authorized for
///   both accounts, which SSH logs in with where the test says "by key".
/// - `SBM_E2E_PVE_TOTP_USER`, `SBM_E2E_PVE_TOTP_PWD`,
///   `SBM_E2E_PVE_TOTP_SECRET`: another such account with a TOTP factor; the
///   secret is its base32. **Disabled and enabled again**; about four codes
///   are used, so the group waits for new 30 s steps.
///
/// Run with `flutter test test/e2e/virt_real_test.dart`, after
/// `cargo build -p sbm_ffi`.
@Timeout(Duration(minutes: 10))
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:dartssh2/dartssh2.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pointycastle/export.dart'
    show DESedeEngine, HMac, KeyParameter, SHA1Digest;
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/core/utils/pve_termproxy.dart';
import 'package:server_box/core/utils/server_tcp.dart';
import 'package:server_box/core/utils/ssh_exec.dart';
import 'package:server_box/core/utils/websocket_tunnel.dart';
import 'package:server_box/data/model/app/error.dart';
import 'package:server_box/data/model/server/pve_config.dart';
import 'package:server_box/data/model/server/server_private_info.dart';
import 'package:server_box/data/model/server/shell_backend.dart';
import 'package:server_box/data/model/virt/virt.dart';
import 'package:server_box/data/model/virt/virt_console.dart';
import 'package:server_box/data/model/virt/virt_create.dart';
import 'package:server_box/data/model/virt/virt_detail.dart';
import 'package:server_box/data/model/virt/virt_hardware.dart';
import 'package:server_box/data/model/virt/virt_resources.dart';
import 'package:server_box/data/provider/virt/libvirt_backend.dart';
import 'package:server_box/data/provider/virt/pve_backend.dart';
import 'package:server_box/src/rust/api/virt.dart' as ffi;

import '../helpers/rust_lib_helper.dart';
import '../helpers/spi_fixture.dart';
import '../helpers/ssh_e2e.dart';
import '../helpers/tunnel_client.dart';

Future<void> main() async {
  // Standing alone: `--plain-name 'create and delete'` runs only these.
  await _libvirtCreate();
  await _pveCreate();
  await _pvePassthrough();
  await _libvirt();
  await _pve();
  await _pveTestVm();
  await _pvePassword();
}

// -----------------------------------------------------------------------------
// libvirt
// -----------------------------------------------------------------------------

Future<void> _libvirt() async {
  final host = e2eEnv('SBM_E2E_LIBVIRT_HOST');
  if (host == null) {
    test('libvirt e2e', () {}, skip: 'SBM_E2E_LIBVIRT_HOST not set');
    return;
  }
  final ready = await prepareSshE2e(host);
  final target = ready.target;
  if (target == null) {
    final failure = ready.failure;
    if (failure != null) {
      test('libvirt e2e', () => fail(failure));
    } else {
      test('libvirt e2e', () {}, skip: ready.skip);
    }
    return;
  }
  final runningName = e2eEnv('SBM_E2E_LIBVIRT_RUNNING') ?? 'cirros-run';
  final pausedName = e2eEnv('SBM_E2E_LIBVIRT_PAUSED') ?? 'cirros-paused';
  final stoppedName = e2eEnv('SBM_E2E_LIBVIRT_STOPPED') ?? 'it\'s-"odd"';

  group('libvirt over SSH', () {
    SSHClient? client;
    late LibvirtBackend virt;

    Future<VirtGuest> guest(String name) async =>
        (await virt.load()).guests.firstWhere(
          (g) => g.name == name,
          orElse: () => fail('no domain named $name'),
        );

    /// Loads until [name] reads as [state]: libvirt reports a change a moment
    /// after `virsh` returns for some of them.
    Future<VirtGuest> settle(String name, VirtGuestState state) async {
      late VirtGuest g;
      for (var i = 0; i < 20; i++) {
        g = await guest(name);
        if (g.state == state) return g;
        await Future<void>.delayed(const Duration(milliseconds: 500));
      }
      fail('$name is ${g.state}, expected $state');
    }

    setUpAll(() async {
      await initRustLibForTest();
      final c = await connectSshE2e(target, ready.identities);
      client = c;
      virt = LibvirtBackend(
        serverId: 'e2e-libvirt',
        exec: () async => SshExec(c),
      );
    });

    tearDownAll(() async {
      final c = client;
      if (c == null) return;
      // Whatever a failed test left behind, back to the documented state.
      Future<void> virsh(String args) => execSshE2e(
        c,
        'LC_ALL=C virsh --connect qemu:///system -q $args </dev/null',
        null,
      );
      final q = _shQuote;
      for (final name in [runningName, stoppedName]) {
        for (final snap in ['sbxe2e-a', 'sbxe2e-b', 'sbxe2e-off']) {
          await virsh(
            'snapshot-delete --domain ${q(name)} --snapshotname $snap',
          );
        }
      }
      await virsh('start --domain ${q(runningName)}');
      await virsh('suspend --domain ${q(pausedName)}');
      await virsh('destroy --domain ${q(stoppedName)}');
      await virt.close();
      c.close();
    });

    test('load: states, vCPUs and memory', () async {
      final snap = await virt.load();
      expect(snap.host.kind, VirtHostKind.libvirt);
      expect(snap.host.version, isNotNull);
      expect(snap.host.hypervisor, startsWith('QEMU '));
      final byName = {for (final g in snap.guests) g.name: g};
      expect(byName.keys, containsAll([runningName, pausedName, stoppedName]));

      final run = byName[runningName]!;
      expect(run.state, VirtGuestState.running);
      expect(run.stateReason, 'booted');
      expect(run.vcpu, greaterThan(0));
      expect(run.memBytes, greaterThan(0));
      expect(run.autostart, isTrue);
      expect(run.id, matches(RegExp(r'^[0-9a-f-]{36}$')));

      final paused = byName[pausedName]!;
      expect(paused.state, VirtGuestState.paused);
      expect(paused.actions, {VirtPowerAction.resume, VirtPowerAction.forceStop});

      final stopped = byName[stoppedName]!;
      expect(stopped.state, VirtGuestState.stopped);
      expect(stopped.actions, {VirtPowerAction.start});
    });

    test('two samples give sane rates', () async {
      await virt.reset();
      final first = await virt.load();
      final id = first.guests.firstWhere((g) => g.name == runningName).id;
      expect(first.stats[id]?.cpu, isNull, reason: 'nothing to diff yet');
      await Future<void>.delayed(const Duration(seconds: 3));
      final second = await virt.load();
      final s = second.stats[id]!;
      expect(s.cpu, inInclusiveRange(0, 100));
      expect(s.memUsed, greaterThan(0));
      expect(s.memTotal, greaterThanOrEqualTo(s.memUsed!));
      expect(s.diskTotal, greaterThan(0));
      for (final rate in [s.diskRead, s.diskWrite, s.netIn, s.netOut]) {
        expect(rate, isNotNull);
        expect(rate, greaterThanOrEqualTo(0));
        // A cirros guest idling: well under 100 MB/s on anything.
        expect(rate, lessThan(100e6));
      }
    });

    test('detail: disks, NICs, and a VNC display on a real port', () async {
      final run = await guest(runningName);
      final detail = await virt.detail(run);
      expect(detail.disks, isNotEmpty);
      expect(detail.disks.first.source, isNotNull);
      expect(detail.nics, isNotEmpty);
      expect(detail.nics.first.mac, matches(RegExp(r'^([0-9a-f]{2}:){5}')));
      expect(detail.display?.protocol, 'vnc');
      expect(detail.display?.port, greaterThanOrEqualTo(5900));
      expect(detail.consoles, {VirtConsoleKind.text, VirtConsoleKind.vnc});

      final stopped = await virt.detail(await guest(stoppedName));
      expect(stopped.display, isNull);
      expect(stopped.consoles, {VirtConsoleKind.text});
    });

    test('hardware: both definitions of the running domain, one of the '
        'shut-off one', () async {
      final run = await virt.hardware(await guest(runningName));
      expect(run.running, isTrue);
      expect(run.cpu.total, greaterThan(0));
      expect(run.memory.mib, greaterThan(0));
      expect(run.disks.where((d) => d.kind == VirtHwDiskKind.disk), isNotEmpty);
      expect(run.disks.first.size, greaterThan(0));
      expect(run.nics, isNotEmpty);
      expect(run.boot, isNotEmpty);
      expect(run.autostart, isTrue);
      expect(run.limits.hostCpus, greaterThan(0));
      expect(run.revision, startsWith('<domain'));

      final stopped = await virt.hardware(await guest(stoppedName));
      expect(stopped.running, isFalse);
      expect(stopped.pending, isEmpty);
    });

    test('the VNC console speaks RFB through the SSH loopback tunnel', () async {
      final run = await guest(runningName);
      final console = await virt.console(run, VirtConsoleKind.vnc);
      expect(console, isA<LibvirtVncConsole>());
      console as LibvirtVncConsole;
      final dialer = ServerTcpDialer(
        spi: spiFixture(name: 'e2e', id: 'e2e', ip: target.hostname),
        ssh: () async => ServerTcpSsh.client(client!),
      );
      final tunnel = await dialer.loopback(console.host, console.port);
      final socket = await connectTunnel(tunnel);
      final rfb = _RfbReader(socket);
      try {
        expect(ascii.decode(await rfb.take(12)), startsWith('RFB 003.00'));
      } finally {
        await rfb.close();
        await tunnel.close();
        dialer.close();
      }
    });

    test('the serial console attaches in a shell and Ctrl+] leaves it', () async {
      final run = await guest(runningName);
      final console = await virt.console(run, VirtConsoleKind.text);
      expect(console, isA<LibvirtSerialConsole>());
      console as LibvirtSerialConsole;
      expect(
        console.command,
        "virsh --connect qemu:///system console --force --domain '${run.id}'",
      );
      expect(console.needsRoot, isFalse);

      // What the terminal page does with `SshPageArgs.initCmd`: a login shell
      // on a PTY, the command typed into it.
      final shell = await client!.shell(
        pty: const SSHPtyConfig(width: 80, height: 24),
      );
      final out = _Collector(shell.stdout);
      try {
        shell.write(utf8.encode('${console.command}\n'));
        await out.waitFor('Escape character is');
        expect(out.text, contains('Connected to domain'));
        out.clear();
        shell.write(Uint8List.fromList([0x1d]));
        // virsh exits and the shell prints its prompt again; input sent
        // before that would still go to the guest.
        await out.waitFor('\n');
        await Future<void>.delayed(const Duration(milliseconds: 500));
        // Back at the shell: something typed now runs there.
        final marker = 'sbm-e2e-${Random().nextInt(1 << 30)}';
        shell.write(utf8.encode('echo "$marker-' r'$((6*7))"' '\n'));
        await out.waitFor('$marker-42');
      } finally {
        shell.close();
      }
    });

    test('snapshots: with memory on the running domain; revert keeps it '
        'running', () async {
      var run = await guest(runningName);
      await virt.createSnapshot(run, name: 'sbxe2e-a', description: 'e2e');
      await virt.createSnapshot(run, name: 'sbxe2e-b');
      var list = await virt.snapshots(run);
      final a = list.firstWhere((s) => s.name == 'sbxe2e-a');
      final b = list.firstWhere((s) => s.name == 'sbxe2e-b');
      // Internal snapshots of an active domain always hold its memory.
      expect(a.withMemory, isTrue);
      expect(a.description, 'e2e');
      expect(b.parent, 'sbxe2e-a');
      expect(b.current, isTrue);
      expect(a.createdAt, isNotNull);

      // A name taken is libvirt's refusal, in its words.
      final taken = await _virtErr(virt.createSnapshot(run, name: 'sbxe2e-a'));
      expect(taken.type, VirtErrType.actionFailed);
      expect(taken.message, contains('already exists'));

      await virt.revertSnapshot(run, 'sbxe2e-a');
      run = await settle(runningName, VirtGuestState.running);
      list = await virt.snapshots(run);
      expect(list.firstWhere((s) => s.name == 'sbxe2e-a').current, isTrue);

      await virt.deleteSnapshot(run, 'sbxe2e-b');
      await virt.deleteSnapshot(run, 'sbxe2e-a');
      list = await virt.snapshots(run);
      expect(list.where((s) => s.name.startsWith('sbxe2e')), isEmpty);
    });

    test('snapshots: disks only while shut off, and a name that needs '
        'quoting', () async {
      final off = await guest(stoppedName);
      await virt.createSnapshot(off, name: 'sbxe2e-off');
      final snap = (await virt.snapshots(
        off,
      )).firstWhere((s) => s.name == 'sbxe2e-off');
      expect(snap.withMemory, isFalse);
      expect(snap.current, isTrue);
      await virt.revertSnapshot(off, 'sbxe2e-off');
      expect((await guest(stoppedName)).state, VirtGuestState.stopped);
      await virt.deleteSnapshot(off, 'sbxe2e-off');
      expect(
        (await virt.snapshots(off)).where((s) => s.name == 'sbxe2e-off'),
        isEmpty,
      );
    });

    test('storage: pools, and the running domain on its volumes', () async {
      final run = await guest(runningName);
      final pools = await virt.storagePools();
      expect(pools, isNotEmpty);
      final active = pools.where((p) => p.active).toList();
      expect(active, isNotEmpty);
      var found = false;
      for (final pool in active) {
        expect(pool.capacity, greaterThan(0), reason: pool.name);
        expect(pool.path, isNotNull, reason: pool.name);
        final vols = await virt.volumes(pool);
        expect(vols.length, pool.volumeCount, reason: pool.name);
        for (final v in vols) {
          expect(v.format, isNotNull, reason: v.name);
          expect(v.capacity, greaterThan(0), reason: v.name);
          if (v.users.any((u) => u.guestId == run.id)) found = true;
        }
      }
      expect(found, isTrue, reason: 'no volume names $runningName');
      for (final p in pools.where((p) => !p.active)) {
        expect(await virt.volumes(p), isEmpty);
      }
    });

    test('networks: the default NAT network with the running domain on it',
        () async {
      final run = await guest(runningName);
      final nets = await virt.networks();
      final def = nets.firstWhere(
        (n) => n.name == 'default',
        orElse: () => fail('no default network'),
      );
      expect(def.mode, 'nat');
      expect(def.bridge, isNotNull);
      expect(def.cidrs.single, matches(RegExp(r'^\d+\.\d+\.\d+\.\d+/\d+$')));
      expect(def.dhcpRanges, isNotEmpty);
      final nic = def.users.firstWhere(
        (u) => u.guestId == run.id,
        orElse: () => fail('$runningName is not on default'),
      );
      expect(nic.mac, matches(RegExp(r'^([0-9a-f]{2}:){5}[0-9a-f]{2}$')));
      expect(nic.device, startsWith('vnet'));
    });

    test('power: resume and suspend the paused domain', () async {
      var paused = await guest(pausedName);
      await virt.power(paused, VirtPowerAction.resume);
      final running = await settle(pausedName, VirtGuestState.running);
      expect(running.stateReason, 'unpaused');
      await virt.power(running, VirtPowerAction.suspend);
      paused = await settle(pausedName, VirtGuestState.paused);
      expect(paused.stateReason, 'user');
    });

    test('power: a refused action is actionFailed with virsh\'s words',
        () async {
      final paused = await guest(pausedName);
      // Offered for a paused domain, so the backend lets it through; libvirt
      // refuses a second suspend without an error, so ask for a destroy of a
      // domain that is already gone instead.
      final gone = paused.copyWith(
        id: '00000000-0000-4000-8000-00000000e2e0',
        name: 'missing',
      );
      final e = await _virtErr(virt.power(gone, VirtPowerAction.forceStop));
      expect(e.type, VirtErrType.actionFailed);
      expect(e.message, startsWith('failed to get domain'));
      expect(
        (e.cause as ffi.VirtFfiError).kind,
        ffi.VirtErrorKind.domainNotFound,
      );
    });

    test('power: the shut-off domain starts and is destroyed, or the host '
        'says why not', () async {
      final stopped = await guest(stoppedName);
      try {
        await virt.power(stopped, VirtPowerAction.start);
      } on VirtErr catch (e) {
        // An AppArmor host refuses a domain name with `"` in it
        // (`virt-aa-helper: bad name`): the user sees libvirt's reason.
        expect(e.type, VirtErrType.actionFailed);
        expect(e.message, startsWith('Failed to start domain'));
        expect(
          (e.cause as ffi.VirtFfiError).kind,
          ffi.VirtErrorKind.command,
        );
        // ignore: avoid_print
        print('$stoppedName cannot start on this host: ${e.message}');
        return;
      }
      final running = await settle(stoppedName, VirtGuestState.running);
      await virt.power(running, VirtPowerAction.forceStop);
      await settle(stoppedName, VirtGuestState.stopped);
    });

    test('power: destroy and start the running domain', () async {
      final run = await guest(runningName);
      await virt.power(run, VirtPowerAction.forceStop);
      final stopped = await settle(runningName, VirtGuestState.stopped);
      expect(stopped.stateReason, 'destroyed');

      // Destroying it again is refused as an invalid state.
      final again = await _virtErr(virt.power(run, VirtPowerAction.forceStop));
      expect(again.type, VirtErrType.actionFailed);
      expect(
        (again.cause as ffi.VirtFfiError).kind,
        ffi.VirtErrorKind.invalidState,
      );

      await virt.power(stopped, VirtPowerAction.start);
      await settle(runningName, VirtGuestState.running);
    });
  });
}

// -----------------------------------------------------------------------------
// Proxmox VE
// -----------------------------------------------------------------------------

Future<void> _pve() async {
  final host = e2eEnv('SBM_E2E_PVE_HOST');
  final tokenId = e2eEnv('SBM_E2E_PVE_TOKEN_ID');
  final tokenSecret = e2eEnv('SBM_E2E_PVE_TOKEN_SECRET');
  if (host == null || tokenId == null || tokenSecret == null) {
    test(
      'pve e2e',
      () {},
      skip:
          'SBM_E2E_PVE_HOST, SBM_E2E_PVE_TOKEN_ID and SBM_E2E_PVE_TOKEN_SECRET '
          'are not all set',
    );
    return;
  }
  final ready = await prepareSshE2e(host);
  final target = ready.target;
  if (target == null) {
    final failure = ready.failure;
    if (failure != null) {
      test('pve e2e', () => fail(failure));
    } else {
      test('pve e2e', () {}, skip: ready.skip);
    }
    return;
  }
  final lxcId = int.parse(e2eEnv('SBM_E2E_PVE_LXC') ?? '200');
  final vmId = int.parse(e2eEnv('SBM_E2E_PVE_VM') ?? '100');
  final directAddr =
      e2eEnv('SBM_E2E_PVE_ADDR') ?? 'https://${target.hostname}:8006';

  PveConfig config(String addr, {String? pin}) => PveConfig(
    addr: addr,
    auth: PveAuth.token,
    tokenId: tokenId,
    tokenSecret: tokenSecret,
    certSha256: pin,
  );

  SSHClient? client;
  setUpAll(() async {
    await initRustLibForTest();
    client = await connectSshE2e(target, ready.identities);
  });
  tearDownAll(() => client?.close());

  final paths = _pvePaths(target, () => client!, directAddr);

  for (final MapEntry(key: path, value: (:addr, :dialer)) in paths.entries) {
    group('PVE $path', () {
      String? pin;
      PveBackend backend({String? pinned}) {
        final d = dialer();
        return PveBackend(
          serverId: 'e2e-pve',
          config: config(addr, pin: pinned),
          connect: d.startConnect,
          onClose: d.close,
          taskPoll: const Duration(milliseconds: 500),
          taskTimeout: const Duration(minutes: 3),
        );
      }

      late PveBackend pve;
      setUpAll(() => pve = backend());
      tearDownAll(() => pve.close());

      VirtGuest guestOf(VirtSnapshot snap, VirtGuestKind kind, int vmid) =>
          snap.guests.firstWhere(
            (g) => g.kind == kind && g.vmid == vmid,
            orElse: () => fail('no ${kind.name} $vmid'),
          );

      test('certificate: unpinned is shown, confirmed, then trusted', () async {
        final e = await _virtErr(pve.load());
        expect(e.type, VirtErrType.certUnconfirmed);
        final fingerprint = e.cert!.fingerprint;
        expect(fingerprint.toLowerCase(), matches(RegExp(r'^[0-9a-f]{64}$')));
        await pve.confirmCert(fingerprint);
        expect(pve.config.certSha256, fingerprint.toLowerCase());
        pin = pve.config.certSha256;

        final snap = await pve.load();
        expect(snap.host.kind, VirtHostKind.pve);
        expect(snap.host.version, matches(RegExp(r'^\d+\.\d+')));
        expect(snap.host.nodes, isNotEmpty);
        expect(snap.capabilities.lxc, isTrue);
        final vm = guestOf(snap, VirtGuestKind.qemu, vmId);
        expect(vm.state, VirtGuestState.running);
        expect(vm.node, isNotNull);
        expect(vm.memBytes, greaterThan(0));
        final ct = guestOf(snap, VirtGuestKind.lxc, lxcId);
        expect(ct.state, VirtGuestState.running);
      });

      test('certificate: a different pin is certChanged, with both', () async {
        const wrong =
            '0000000000000000000000000000000000000000000000000000000000000000';
        final other = backend(pinned: wrong);
        try {
          final e = await _virtErr(other.load());
          expect(e.type, VirtErrType.certChanged);
          expect(e.previousFingerprint, wrong);
          expect(e.cert!.fingerprint.toLowerCase(), pin);
        } finally {
          await other.close();
        }
      });

      test('a pinned backend connects straight away; rates on the second '
          'load', () async {
        final pinned = backend(pinned: pin);
        try {
          final first = await pinned.load();
          final id = guestOf(first, VirtGuestKind.qemu, vmId).id;
          // CPU is PVE's own percentage, there at once.
          expect(first.stats[id]!.cpu, inInclusiveRange(0, 100));
          // Byte rates need two different samples, and pvestatd refreshes
          // /cluster/resources every ~10 s.
          VirtStats? s;
          for (var i = 0; i < 15 && s?.netIn == null; i++) {
            await Future<void>.delayed(const Duration(seconds: 2));
            s = (await pinned.load()).stats[id];
          }
          expect(s?.netIn, isNotNull, reason: 'no rate after 30 s');
          for (final rate in [s!.netIn, s.netOut, s.diskRead, s.diskWrite]) {
            expect(rate, greaterThanOrEqualTo(0));
          }
        } finally {
          await pinned.close();
        }
      });

      test('storage: pools with their figures, volumes with their owners',
          () async {
        final snap = await pve.load();
        final pools = await pve.storagePools();
        expect(pools, isNotEmpty);
        for (final p in pools.where((p) => p.active)) {
          expect(p.node, isNotNull);
          expect(p.capacity, greaterThan(0), reason: p.name);
          expect(p.content, isNotEmpty, reason: p.name);
        }
        final vm = guestOf(snap, VirtGuestKind.qemu, vmId);
        final images = pools.where(
          (p) => p.active && p.content.contains('images'),
        );
        var owned = false;
        for (final p in images) {
          final vols = await pve.volumes(p);
          if (vols.any((v) => v.users.any((u) => u.vmid == vm.vmid))) {
            owned = true;
          }
        }
        expect(owned, isTrue, reason: 'no volume of VM $vmId');
      });

      test('hardware: the VM and the container, as the next start has them',
          () async {
        final snap = await pve.load();
        final vm = await pve.hardware(guestOf(snap, VirtGuestKind.qemu, vmId));
        expect(vm.cpu.total, greaterThan(0));
        expect(vm.memory.mib, greaterThan(0));
        expect(vm.disks, isNotEmpty);
        expect(vm.boot, isNotNull);
        expect(vm.revision, matches(RegExp(r'^[0-9a-f]{40}$')));
        expect(vm.configText, contains('memory'));

        final ct = await pve.hardware(guestOf(snap, VirtGuestKind.lxc, lxcId));
        expect(ct.disk('rootfs')?.kind, VirtHwDiskKind.rootfs);
        expect(ct.memory.swapMib, isNotNull);
        expect(ct.boot, isNull);
      });

      test('network: bridges with the guests on them', () async {
        await pve.load();
        final nets = await pve.networks();
        final bridges = nets.where((n) => n.mode == 'bridge').toList();
        expect(bridges, isNotEmpty);
        final users = {
          for (final b in bridges) ...b.users.map((u) => u.vmid),
        };
        expect(users, containsAll([vmId, lxcId]));
        final withCidr = bridges.where((b) => b.cidrs.isNotEmpty);
        expect(withCidr, isNotEmpty);
        expect(bridges.first.ports, isNotEmpty);
      });

      if (path == 'over SSH') {
        test('snapshots: the running container, rolled back and started '
            'again, then deleted', () async {
          var ct = guestOf(await pve.load(), VirtGuestKind.lxc, lxcId);
          // A container never has memory to save, whatever is asked.
          await pve.createSnapshot(
            ct,
            name: 'sbxe2e-ct',
            description: 'e2e',
            memory: true,
          );
          try {
            final snap = (await pve.snapshots(
              ct,
            )).firstWhere((s) => s.name == 'sbxe2e-ct');
            expect(snap.withMemory, isFalse);
            expect(snap.current, isTrue);
            expect(snap.description, 'e2e');
            final taken = await _virtErr(
              pve.createSnapshot(ct, name: 'sbxe2e-ct'),
            );
            expect(taken.type, VirtErrType.actionFailed);
            expect(taken.message, contains('already used'));

            await pve.revertSnapshot(ct, 'sbxe2e-ct', start: true);
            ct = guestOf(await pve.load(), VirtGuestKind.lxc, lxcId);
            expect(ct.state, VirtGuestState.running);
          } finally {
            await _whileLocked(() => pve.deleteSnapshot(ct, 'sbxe2e-ct'));
          }
          expect(
            (await pve.snapshots(ct)).where((s) => s.name == 'sbxe2e-ct'),
            isEmpty,
          );
        });
      }

      if (path == 'over SSH') {
        test('power: reboot the container and wait for its task', () async {
          final ct = guestOf(await pve.load(), VirtGuestKind.lxc, lxcId);
          final before = ct.uptime;
          await pve.power(ct, VirtPowerAction.reboot);
          // The task has stopped, so the container is back — and reads so
          // at once, although /cluster/resources is still the one from
          // before the reboot.
          final after = guestOf(await pve.load(), VirtGuestKind.lxc, lxcId);
          expect(after.state, VirtGuestState.running);
          // Null only in the container's first second: `status/current`
          // answers 0 then.
          final up = after.uptime;
          if (before != null && up != null) expect(up, lessThan(before));
        });
      }

      test('termproxy on the container: OK, binary input, resize, keepalive',
          () async {
        final ct = guestOf(await pve.load(), VirtGuestKind.lxc, lxcId);
        final console = await pve.console(ct, VirtConsoleKind.text);
        expect(console, isA<PveTermConsole>());
        // Token sessions: the ticket is issued to the token itself.
        expect(console.user, tokenId);
        final socket = await pve.openConsoleSocket(console);
        expect(socket.protocol, 'binary');
        final term = await PveTermShellBackend.start(
          socket,
          user: console.user,
          ticket: console.ticket,
          keepAlive: const Duration(seconds: 1),
        );
        final shell = await term.openShell(width: 80, height: 24);
        final out = _Collector(shell.stdout!);
        try {
          // A container console is its getty. Enter brings up the prompt.
          shell.write(utf8.encode('\r'));
          await out.waitFor('login:');
          shell.resizeTerminal(100, 30);
          // Keep-alives go out every second; the session outlives several.
          await Future<void>.delayed(const Duration(seconds: 4));
          expect(term.isClosed, isFalse);
          final marker = 'sbm-e2e-${Random().nextInt(1 << 30)}';
          // Typed as a login name: getty echoes it and asks for a password,
          // which only happens if the line arrived.
          out.clear();
          shell.write(utf8.encode('$marker\r'));
          await out.waitFor('Password');
          expect(out.text, contains(marker));
          // Leave getty as it was.
          shell.write(utf8.encode('\r'));
        } finally {
          shell.close();
        }
        await shell.done.timeout(const Duration(seconds: 5));
      });

      test('termproxy refuses a wrong ticket in the handshake', () async {
        final ct = guestOf(await pve.load(), VirtGuestKind.lxc, lxcId);
        final console = await pve.console(ct, VirtConsoleKind.text);
        final socket = await pve.openConsoleSocket(console);
        final e = await _virtErr(
          PveTermShellBackend.start(
            socket,
            user: console.user,
            ticket: 'PVEVNC:00000000::bogus',
          ),
        );
        expect(e.type, anyOf(VirtErrType.authFailed, VirtErrType.unreachable));
      });

      test('termproxy on the VM serial port connects (no input)', () async {
        final vm = guestOf(await pve.load(), VirtGuestKind.qemu, vmId);
        final detail = await pve.detail(vm);
        expect(detail.consoles, contains(VirtConsoleKind.text));
        final console = await pve.console(vm, VirtConsoleKind.text);
        final socket = await pve.openConsoleSocket(console);
        final term = await PveTermShellBackend.start(
          socket,
          user: console.user,
          ticket: console.ticket,
        );
        expect(term.isClosed, isFalse);
        term.close();
      });

      test('vncproxy: RFB over the websocket tunnel, VNC auth with the '
          'generated password', () async {
        final vm = guestOf(await pve.load(), VirtGuestKind.qemu, vmId);

        Future<({int result, List<int> types})> handshake(
          String Function(PveVncConsole c) password,
        ) => _pveVncHandshake(pve, vm, password);

        final ok = await handshake((c) => c.rfbPassword);
        expect(ok.types, contains(2), reason: 'VNC authentication offered');
        expect(ok.result, 0, reason: 'SecurityResult OK');

        // The check is real: a wrong password is refused.
        final wrong = await handshake((c) => 'wrong!!!');
        expect(wrong.result, isNot(0));
      });
    });
  }
}

// -----------------------------------------------------------------------------
// Proxmox VE, a QEMU VM of the test's own
// -----------------------------------------------------------------------------

/// Everything `PveBackend` does to a QEMU guest, on a VM that exists for it
/// (`SBM_E2E_PVE_TEST_VM`), over SSH and directly. Each transport runs the
/// whole power cycle and leaves the VM stopped.
Future<void> _pveTestVm() async {
  final host = e2eEnv('SBM_E2E_PVE_HOST');
  final tokenId = e2eEnv('SBM_E2E_PVE_TOKEN_ID');
  final tokenSecret = e2eEnv('SBM_E2E_PVE_TOKEN_SECRET');
  final vmRaw = e2eEnv('SBM_E2E_PVE_TEST_VM');
  if (host == null ||
      tokenId == null ||
      tokenSecret == null ||
      vmRaw == null) {
    test(
      'pve test VM e2e',
      () {},
      skip:
          'SBM_E2E_PVE_HOST, SBM_E2E_PVE_TOKEN_ID, SBM_E2E_PVE_TOKEN_SECRET '
          'and SBM_E2E_PVE_TEST_VM are not all set',
    );
    return;
  }
  final ready = await prepareSshE2e(host);
  final target = ready.target;
  if (target == null) {
    final failure = ready.failure;
    if (failure != null) {
      test('pve test VM e2e', () => fail(failure));
    } else {
      test('pve test VM e2e', () {}, skip: ready.skip);
    }
    return;
  }
  final vmid = int.parse(vmRaw);
  final rootPassword = e2eEnv('SBM_E2E_PVE_TEST_VM_ROOT_PASSWORD');
  final directAddr =
      e2eEnv('SBM_E2E_PVE_ADDR') ?? 'https://${target.hostname}:8006';

  SSHClient? client;
  setUpAll(() async {
    await initRustLibForTest();
    client = await connectSshE2e(target, ready.identities);
  });
  tearDownAll(() => client?.close());

  final paths = _pvePaths(target, () => client!, directAddr);
  for (final MapEntry(key: path, value: (:addr, :dialer)) in paths.entries) {
    group('PVE test VM $vmid $path', () {
      String? pin;
      PveBackend backend() {
        final d = dialer();
        return PveBackend(
          serverId: 'e2e-pve',
          config: PveConfig(
            addr: addr,
            auth: PveAuth.token,
            tokenId: tokenId,
            tokenSecret: tokenSecret,
            certSha256: pin,
          ),
          connect: d.startConnect,
          onClose: d.close,
          taskPoll: const Duration(milliseconds: 500),
          taskTimeout: const Duration(minutes: 3),
        );
      }

      late PveBackend pve;
      setUpAll(() async {
        pve = backend();
        final e = await _virtErr(pve.load());
        expect(e.type, VirtErrType.certUnconfirmed);
        await pve.confirmCert(e.cert!.fingerprint);
        pin = pve.config.certSha256;
      });
      tearDownAll(() async {
        // Stopped and without the test's snapshots, whatever a failed test
        // left behind.
        try {
          var g = await _pveVm(pve, vmid);
          if (g.actions.contains(VirtPowerAction.forceStop)) {
            final running = g;
            await _whileLocked(
              () => pve.power(running, VirtPowerAction.forceStop),
            );
            await _afterStop();
            g = await _pveVm(pve, vmid);
          }
          for (final s in await pve.snapshots(g)) {
            if (s.name.startsWith('sbxe2e')) {
              await _whileLocked(() => pve.deleteSnapshot(g, s.name));
            }
          }
        } finally {
          await pve.close();
        }
      });

      Future<VirtGuest> vm() => _pveVm(pve, vmid);

      test('start: running once the task ends, with the running actions',
          () async {
        var g = await vm();
        if (g.state == VirtGuestState.paused) {
          await pve.power(g, VirtPowerAction.resume);
          g = await vm();
        }
        if (g.state == VirtGuestState.running) {
          await pve.power(g, VirtPowerAction.forceStop);
          g = await vm();
        }
        expect(g.state, VirtGuestState.stopped);
        await _afterStop();
        expect(g.actions, {VirtPowerAction.start});
        final watch = Stopwatch()..start();
        await pve.power(g, VirtPowerAction.start);
        // ignore: avoid_print
        print('$path: start task ${watch.elapsed}');
        g = await vm();
        expect(g.state, VirtGuestState.running);
        expect(g.stateReason, isNull);
        expect(g.actions, _qemuRunning);
      });

      test('an action the state does not offer is refused before PVE is '
          'asked', () async {
        final g = await vm();
        final e = await _virtErr(pve.power(g, VirtPowerAction.start));
        expect(e.type, VirtErrType.unsupported);
        final paused = await _virtErr(pve.power(g, VirtPowerAction.resume));
        expect(paused.type, VirtErrType.unsupported);
      });

      test('detail: disks, NIC, display and both consoles', () async {
        final d = await pve.detail(await vm());
        final disk = d.disks.firstWhere(
          (x) => x.target == 'scsi0',
          orElse: () => fail('no scsi0 in ${d.disks}'),
        );
        expect(disk.device, 'disk');
        expect(disk.bus, 'scsi');
        expect(disk.source, startsWith('local-lvm:'));
        expect(disk.size, 8 << 30);
        expect(disk.readonly, isFalse);
        final ci = d.disks.firstWhere(
          (x) => x.target == 'ide2',
          orElse: () => fail('no cloud-init drive in ${d.disks}'),
        );
        expect(ci.device, 'cdrom');
        expect(ci.source, contains('cloudinit'));
        expect(ci.readonly, isTrue);
        expect(d.nics, hasLength(1));
        final nic = d.nics.single;
        expect(nic.kind, 'net0');
        expect(nic.model, 'virtio');
        expect(nic.source, 'vmbr0');
        expect(nic.mac, matches(RegExp(r'^([0-9A-F]{2}:){5}[0-9A-F]{2}$')));
        expect(d.graphics.map((g) => g.kind), ['std']);
        expect(d.consoles, {VirtConsoleKind.vnc, VirtConsoleKind.text});
        expect(d.machine, 'l26');
      });

      test('serial console: getty on ttyS0, typed into', () async {
        final console = await pve.console(await vm(), VirtConsoleKind.text);
        expect(console, isA<PveTermConsole>());
        expect(console.user, tokenId);
        final term = await PveTermShellBackend.start(
          await pve.openConsoleSocket(console),
          user: console.user,
          ticket: console.ticket,
        );
        final shell = await term.openShell(width: 80, height: 24);
        final out = _Collector(shell.stdout!);
        try {
          await _serialLogin(shell, out, rootPassword);
        } finally {
          shell.close();
          await out.cancel();
        }
        await shell.done.timeout(const Duration(seconds: 5));
      });

      test('vncproxy: RFB and VNC auth', () async {
        final ok = await _pveVncHandshake(pve, await vm(), (c) => c.rfbPassword);
        expect(ok.types, contains(2));
        expect(ok.result, 0, reason: 'SecurityResult OK');
      });

      test('suspend: paused at once, and in the listing itself; resume',
          () async {
        await pve.power(await vm(), VirtPowerAction.suspend);
        var g = await vm();
        expect(g.state, VirtGuestState.paused);
        expect(g.stateReason, isNull);
        expect(g.actions, {VirtPowerAction.resume, VirtPowerAction.forceStop});
        expect(g.actions, isNot(contains(VirtPowerAction.suspend)));

        // A backend without this one's overlay reads /cluster/resources
        // alone: it has to say `paused` too, within pvestatd's cycle.
        final fresh = backend();
        try {
          final listed = await _settle(
            fresh,
            vmid,
            (g) => g.state == VirtGuestState.paused,
          );
          expect(listed.actions, {
            VirtPowerAction.resume,
            VirtPowerAction.forceStop,
          });
          // The overlay is gone and the listing agrees.
          expect((await vm()).state, VirtGuestState.paused);
        } finally {
          await fresh.close();
        }

        await pve.power(await vm(), VirtPowerAction.resume);
        g = await vm();
        expect(g.state, VirtGuestState.running);
        expect(g.actions, _qemuRunning);
      });

      if (path == 'over SSH') {
        test('a PVE lock blocks every action', () async {
          final c = client!;
          Future<void> qm(String args) async {
            final r = await execSshE2e(c, 'qm $args', null);
            expect(r.exitCode, 0, reason: r.stderr);
          }

          /// PVE's own refusal of [action], asked for as if it were offered.
          Future<VirtErr> refused(VirtGuest g, VirtPowerAction action) async {
            final e = await _virtErr(
              pve.power(g.copyWith(actions: {action}), action),
            );
            // ignore: avoid_print
            print('$path: ${action.name} under lock ${g.stateReason}: '
                '${e.type} ${e.message}');
            return e;
          }

          try {
            // A backup: the VM reads as one, and pausing is all it offers —
            // PVE skips the lock check for suspend and resume, nothing else.
            await qm('set $vmid --lock backup');
            var g = await _settle(pve, vmid, (g) => g.stateReason == 'backup');
            expect(g.state, VirtGuestState.backup);
            expect(g.actions, {VirtPowerAction.suspend});
            expect(
              (await _virtErr(pve.power(g, VirtPowerAction.shutdown))).type,
              VirtErrType.unsupported,
            );
            final stop = await refused(g, VirtPowerAction.forceStop);
            expect(stop.type, VirtErrType.actionFailed);
            expect(stop.message, contains('locked'));
            await pve.power(g, VirtPowerAction.suspend);
            g = await vm();
            expect(g.state, VirtGuestState.backup);
            expect(g.actions, {VirtPowerAction.resume});
            await pve.power(g, VirtPowerAction.resume);
            g = await vm();
            expect(g.actions, {VirtPowerAction.suspend});
            await qm('unlock $vmid');

            // Any other lock: nothing, and PVE says why.
            await qm('set $vmid --lock snapshot');
            g = await _settle(pve, vmid, (g) => g.stateReason == 'snapshot');
            expect(g.state, VirtGuestState.running);
            expect(g.actions, isEmpty);
            final pause = await refused(g, VirtPowerAction.suspend);
            expect(pause.type, VirtErrType.actionFailed);
            expect(pause.message, contains('locked'));
            await qm('unlock $vmid');
          } finally {
            await execSshE2e(c, 'qm unlock $vmid', null);
          }
          final g = await _settle(pve, vmid, (g) => g.stateReason == null);
          expect(g.state, VirtGuestState.running);
          expect(g.actions, _qemuRunning);
        });
      }

      test('reboot: running again with the uptime reset', () async {
        var g = await vm();
        // The listing's uptime lags by up to pvestatd's cycle; wait for one.
        g = await _settle(pve, vmid, (g) => (g.uptime?.inSeconds ?? 0) > 5);
        final before = g.uptime!;
        final watch = Stopwatch()..start();
        await pve.power(g, VirtPowerAction.reboot);
        // ignore: avoid_print
        print('$path: reboot task ${watch.elapsed} (uptime was $before)');
        g = await vm();
        expect(g.state, VirtGuestState.running);
        final up = g.uptime;
        if (up != null) expect(up, lessThan(before));
        expect(g.actions, _qemuRunning);
      });

      test('shutdown (ACPI): stopped once the task ends', () async {
        // An ACPI request sent while the guest is still booting is lost: PVE
        // 9.2 waited 60 s and failed the task with "VM quit/powerdown failed
        // - got timeout", the VM still running. The reboot above was just
        // now, so wait for the guest to be up (its getty came ~15 s in).
        final up = await _settle(
          pve,
          vmid,
          (g) => (g.uptime?.inSeconds ?? 0) >= 30,
          timeout: const Duration(seconds: 60),
        );
        final watch = Stopwatch()..start();
        await pve.power(up, VirtPowerAction.shutdown);
        // ignore: avoid_print
        print('$path: ACPI shutdown task ${watch.elapsed}');
        final g = await vm();
        expect(g.state, VirtGuestState.stopped);
        expect(g.uptime, isNull);
        expect(g.actions, {VirtPowerAction.start});
      });

      test('start, then force stop: stopped', () async {
        await _afterStop();
        await pve.power(await vm(), VirtPowerAction.start);
        expect((await vm()).state, VirtGuestState.running);
        await pve.power(await vm(), VirtPowerAction.forceStop);
        final g = await vm();
        expect(g.state, VirtGuestState.stopped);
        expect(g.actions, {VirtPowerAction.start});
      });

      if (path == 'over SSH') {
        test('snapshots: disks only while stopped, memory while running; '
            'rollback to each, then deleted', () async {
          var g = await vm();
          expect(g.state, VirtGuestState.stopped);
          // Straight after the force stop above: qmeventd's cleanup may
          // still hold the config lock.
          await _whileLocked(
            () => pve.createSnapshot(g, name: 'sbxe2e-disk', memory: true),
          );
          var list = await pve.snapshots(g);
          final disk = list.firstWhere((s) => s.name == 'sbxe2e-disk');
          // Stopped: nothing to save, whatever was asked.
          expect(disk.withMemory, isFalse);
          expect(disk.current, isTrue);

          await pve.power(g, VirtPowerAction.start);
          g = await vm();
          expect(g.state, VirtGuestState.running);
          await pve.createSnapshot(g, name: 'sbxe2e-mem', memory: true);
          list = await pve.snapshots(g);
          final mem = list.firstWhere((s) => s.name == 'sbxe2e-mem');
          expect(mem.withMemory, isTrue);
          expect(mem.parent, 'sbxe2e-disk');

          // Disks only: the running VM is stopped by it.
          await pve.revertSnapshot(g, 'sbxe2e-disk');
          g = await vm();
          expect(g.state, VirtGuestState.stopped);
          // With memory: running again, where it was.
          await pve.revertSnapshot(g, 'sbxe2e-mem');
          g = await vm();
          expect(g.state, VirtGuestState.running);
          list = await pve.snapshots(g);
          expect(list.firstWhere((s) => s.name == 'sbxe2e-mem').current, isTrue);

          // Straight after a rollback with memory the lock can still be
          // held: a stop there failed twice on it (PVE 9.2).
          final running = g;
          await _whileLocked(
            () => pve.power(running, VirtPowerAction.forceStop),
          );
          g = await vm();
          await _whileLocked(() => pve.deleteSnapshot(g, 'sbxe2e-mem'));
          await _whileLocked(() => pve.deleteSnapshot(g, 'sbxe2e-disk'));
          expect(
            (await pve.snapshots(g)).where((s) => s.name.startsWith('sbxe2e')),
            isEmpty,
          );
        });
      }
    });
  }
}

const _qemuRunning = {
  VirtPowerAction.shutdown,
  VirtPowerAction.reboot,
  VirtPowerAction.forceStop,
  VirtPowerAction.suspend,
};

Future<VirtGuest> _pveVm(PveBackend pve, int vmid) async =>
    (await pve.load()).guests.firstWhere(
      (g) => g.kind == VirtGuestKind.qemu && g.vmid == vmid,
      orElse: () => fail('no qemu $vmid'),
    );

/// A start straight after a stop leaves `qmeventd`'s cleanup of the old
/// QEMU process holding the VM's config lock for 30 s, and every action in
/// that window fails on it after 10 s (PVE 9.2, see virt.md). The cleanup
/// takes well under a second when nothing has started yet.
Future<void> _afterStop() => Future<void>.delayed(const Duration(seconds: 5));

/// Runs [op] again while PVE refuses it on the guest's config lock
/// (`can't lock file ... got timeout`), for up to a minute: a stop leaves
/// `qmeventd`'s cleanup holding it for as long as 30 s (see [_afterStop]),
/// and a rollback that starts the guest again holds it past its own task.
Future<void> _whileLocked(Future<void> Function() op) async {
  final deadline = DateTime.now().add(const Duration(minutes: 1));
  while (true) {
    try {
      return await op();
    } on VirtErr catch (e) {
      final message = e.message ?? '';
      final locked =
          message.contains("can't lock file") ||
          message.contains('Failed to obtain guest migration lock');
      if (!locked || DateTime.now().isAfter(deadline)) rethrow;
      // ignore: avoid_print
      print('config lock held, again: ${e.message}');
      await Future<void>.delayed(const Duration(seconds: 3));
    }
  }
}

/// Loads until the VM satisfies [test]: `/cluster/resources` catches up
/// within pvestatd's ~10 s cycle.
Future<VirtGuest> _settle(
  PveBackend pve,
  int vmid,
  bool Function(VirtGuest g) test, {
  Duration timeout = const Duration(seconds: 40),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (true) {
    final g = await _pveVm(pve, vmid);
    if (test(g)) return g;
    if (DateTime.now().isAfter(deadline)) {
      fail('qemu $vmid never settled; last: ${g.state} (${g.stateReason})');
    }
    await Future<void>.delayed(const Duration(seconds: 1));
  }
}

/// At the guest's serial getty: Enter until `login:` (the VM may still be
/// booting), then either a root login with [password] and a command whose
/// output could only come from a shell, or — without one — a marker typed as
/// the login name, which getty answers with a password prompt.
Future<void> _serialLogin(
  ShellSession shell,
  _Collector out,
  String? password,
) async {
  for (var i = 0; i < 90 && !out.text.contains('login:'); i++) {
    shell.write(utf8.encode('\r'));
    await Future<void>.delayed(const Duration(seconds: 1));
  }
  await out.waitFor('login:');
  final marker = 'sbm-e2e-${Random().nextInt(1 << 30)}';
  out.clear();
  if (password == null) {
    shell.write(utf8.encode('$marker\r'));
    await out.waitFor('Password');
    expect(out.text, contains(marker));
    shell.write(utf8.encode('\r'));
    return;
  }
  shell.write(utf8.encode('root\r'));
  await out.waitFor('Password');
  out.clear();
  shell.write(utf8.encode('$password\r'));
  await out.waitFor('#', timeout: const Duration(seconds: 30));
  out.clear();
  // `$((6*7))` is expanded by the shell: the echo of the typed line has the
  // expression, only the output has 42.
  shell.write(utf8.encode('echo $marker-\$((6*7))\r'));
  await out.waitFor('$marker-42');
  out.clear();
  shell.write(utf8.encode('exit\r'));
  await out.waitFor('login:', timeout: const Duration(seconds: 30));
}

/// The two ways the app reaches the PVE API: an SSH channel from the node
/// itself (`localhost` resolves there), and a direct socket from this device,
/// which is what a local server's dialer does.
Map<String, ({String addr, ServerTcpDialer Function() dialer})> _pvePaths(
  SshE2eTarget target,
  SSHClient Function() client,
  String directAddr,
) => {
  'over SSH': (
    addr: 'https://localhost:8006',
    dialer: () => ServerTcpDialer(
      spi: spiFixture(name: 'e2e-pve', id: 'e2e-pve', ip: target.hostname),
      ssh: () async => ServerTcpSsh.client(client()),
    ),
  ),
  'direct': (
    addr: directAddr,
    dialer: () => ServerTcpDialer(
      spi: Spi(name: 'e2e-pve-local', id: 'e2e-pve-local', local: true),
      ssh: () => throw StateError('a local server has no SSH'),
    ),
  ),
};

// -----------------------------------------------------------------------------
// Creating and deleting, over SSH
// -----------------------------------------------------------------------------

/// A name for a new guest no earlier run left behind.
String _e2eName(String kind) =>
    'sbme2e-$kind-${DateTime.now().millisecondsSinceEpoch % 100000}';

/// A VM of the test's own on the libvirt host, over the backend the app uses
/// on SSH: created with a disk in a pool, the first ISO and the `default`
/// network, started, refused a second time and refused deletion while
/// running, then force-stopped and deleted with its disk. The existing
/// domains are not touched.
Future<void> _libvirtCreate() async {
  final host = e2eEnv('SBM_E2E_LIBVIRT_HOST');
  if (host == null) return;
  final ready = await prepareSshE2e(host);
  final target = ready.target;
  if (target == null) return;

  group('create and delete: libvirt over SSH', () {
    SSHClient? client;
    late LibvirtBackend virt;
    final name = _e2eName('vm');

    Future<VirtGuest?> find() async =>
        (await virt.load()).guests.where((g) => g.name == name).firstOrNull;

    Future<VirtGuest> settle(bool Function(VirtGuest g) test) async {
      for (var i = 0; i < 40; i++) {
        final g = await find();
        if (g != null && test(g)) return g;
        await Future<void>.delayed(const Duration(milliseconds: 500));
      }
      fail('$name never settled');
    }

    setUpAll(() async {
      await initRustLibForTest();
      final c = await connectSshE2e(target, ready.identities);
      client = c;
      virt = LibvirtBackend(
        serverId: 'e2e-libvirt-create',
        exec: () async => SshExec(c),
      );
    });
    tearDownAll(() async {
      // Whatever a failed test left.
      try {
        final g = await find();
        if (g != null) {
          if (g.state != VirtGuestState.stopped) {
            await virt.power(g, VirtPowerAction.forceStop);
          }
          await virt.delete((await find())!);
        }
      } catch (_) {}
      await virt.close();
      client?.close();
    });

    test('a VM: disk in a pool, ISO, NIC, started; then deleted with it',
        () async {
      final snap = await virt.load();
      expect(snap.capabilities.create, isTrue);
      final pools = await virt.storagePools();
      final pool = virtDiskStorages(
        pools,
        host: VirtHostKind.libvirt,
        kind: VirtGuestKind.qemu,
      ).first;
      final media = <VirtVolume>[];
      for (final p in virtMediaStorages(
        pools,
        host: VirtHostKind.libvirt,
        kind: VirtGuestKind.qemu,
      )) {
        media.addAll(
          (await virt.volumes(p)).where(
            (v) => virtIsMedia(v, VirtGuestKind.qemu),
          ),
        );
      }
      final nets = virtCreateNetworks(
        await virt.networks(),
        host: VirtHostKind.libvirt,
      );
      final spec = VirtCreateSpec(
        kind: VirtGuestKind.qemu,
        name: name,
        cores: 1,
        memoryMiB: 256,
        storage: pool,
        diskGiB: 1,
        media: media.firstOrNull,
        network: nets.where((n) => n.name == 'default').firstOrNull,
        start: true,
      );
      expect(
        virtCreateIssue(spec, host: VirtHostKind.libvirt, guests: snap.guests),
        isNull,
      );

      final created = await virt.create(spec);
      expect(created.startError, isNull);
      final g = await settle((g) => g.state == VirtGuestState.running);
      expect(g.id, created.id);
      final detail = await virt.detail(g);
      final disk = detail.disks.firstWhere((d) => d.device == 'disk');
      expect(disk.source, endsWith('/$name.qcow2'));
      expect(detail.consoles, containsAll(VirtConsoleKind.values));

      final taken = await _virtErr(virt.create(spec));
      expect(taken.type, VirtErrType.exists);

      final running = await _virtErr(virt.delete(g));
      expect(running.type, VirtErrType.unsupported);
      await virt.power(g, VirtPowerAction.forceStop);
      final stopped = await settle((g) => g.state == VirtGuestState.stopped);
      await virt.delete(stopped);
      expect(await find(), isNull);
      final vols = await virt.volumes(pool);
      expect(vols.where((v) => v.name == '$name.qcow2'), isEmpty);
    });
  });
}

/// Real USB and PCI passthrough on the PVE node, through a resource mapping:
/// see the file's header, `SBM_E2E_PVE_USB` and `SBM_E2E_PVE_PCI`.
Future<void> _pvePassthrough() async {
  final host = e2eEnv('SBM_E2E_PVE_HOST');
  final tokenId = e2eEnv('SBM_E2E_PVE_TOKEN_ID');
  final tokenSecret = e2eEnv('SBM_E2E_PVE_TOKEN_SECRET');
  final usb = e2eEnv('SBM_E2E_PVE_USB');
  final pci = e2eEnv('SBM_E2E_PVE_PCI');
  if (host == null || tokenId == null || tokenSecret == null) return;
  if (usb == null && pci == null) return;
  final ready = await prepareSshE2e(host);
  final target = ready.target;
  if (target == null) return;

  group('passthrough: PVE over SSH', () {
    SSHClient? client;
    late PveBackend pve;
    late VirtGuest vm;
    late VirtStoragePool storage;

    /// On the node, as the SSH user (root: the mapping needs it).
    Future<String> onNode(String command) async {
      final session = await client!.execute(command);
      final (out, err) = await (
        utf8.decodeStream(session.stdout),
        utf8.decodeStream(session.stderr),
      ).wait;
      await session.done;
      expect(session.exitCode, 0, reason: '$command\n$out$err');
      return out;
    }

    Future<VirtGuest> settle(bool Function(VirtGuest g) test) async {
      final deadline = DateTime.now().add(const Duration(seconds: 60));
      while (true) {
        final g = (await pve.load()).guests.where((g) => g.id == vm.id).firstOrNull;
        if (g != null && test(g)) return g;
        if (DateTime.now().isAfter(deadline)) fail('${vm.id} never settled');
        await Future<void>.delayed(const Duration(seconds: 1));
      }
    }

    Future<void> stop() async {
      final g = await settle((_) => true);
      if (g.state != VirtGuestState.stopped) {
        await pve.power(g, VirtPowerAction.forceStop);
      }
      vm = await settle((g) => g.state == VirtGuestState.stopped);
    }

    setUpAll(() async {
      await initRustLibForTest();
      final c = await connectSshE2e(target, ready.identities);
      client = c;
      expect((await onNode('id -u')).trim(), '0', reason: 'a mapping is made as root');
      final d = _pvePaths(target, () => c, '')['over SSH']!.dialer();
      pve = PveBackend(
        serverId: 'e2e-pve-passthrough',
        config: PveConfig(
          addr: 'https://localhost:8006',
          auth: PveAuth.token,
          tokenId: tokenId,
          tokenSecret: tokenSecret,
        ),
        connect: d.startConnect,
        onClose: d.close,
        taskPoll: const Duration(milliseconds: 500),
        taskTimeout: const Duration(minutes: 3),
      );
      final e = await _virtErr(pve.load());
      expect(e.type, VirtErrType.certUnconfirmed);
      await pve.confirmCert(e.cert!.fingerprint);
      final snap = await pve.load();
      final node = snap.host.nodes.first.name;
      storage = virtDiskStorages(
        await pve.storagePools(),
        host: VirtHostKind.pve,
        kind: VirtGuestKind.qemu,
        node: node,
      ).first;
      final created = await pve.create(
        VirtCreateSpec(
          kind: VirtGuestKind.qemu,
          name: _e2eName('pt'),
          node: node,
          vmid: (await pve.nextVmid())!,
          cores: 1,
          memoryMiB: 256,
          storage: storage,
          diskGiB: 1,
          network: virtCreateNetworks(
            await pve.networks(),
            host: VirtHostKind.pve,
            node: node,
          ).first,
        ),
      );
      vm = (await pve.load()).guests.firstWhere((g) => g.id == created.id);
    });
    tearDownAll(() async {
      try {
        await stop();
        await _whileLocked(() => pve.delete(vm));
      } catch (_) {}
      await pve.close();
      client?.close();
    });

    /// Maps [device], grants the token its use, gives it to the VM through
    /// the backend as the Hardware view does, starts the VM with it, checks
    /// QEMU was given it, and takes it off again. The mapping and the grant
    /// go whatever happens.
    Future<void> passthrough(String kind, String device) async {
      final id = 'sbe2e-$kind-${DateTime.now().millisecondsSinceEpoch % 100000}';
      final node = vm.node!;
      final String map;
      if (kind == 'usb') {
        map = 'node=$node,id=$device';
      } else {
        final ids = (await onNode("lspci -n -s '$device' | awk '{print \$3}'")).trim();
        final group = (await onNode(
          "basename \"\$(readlink /sys/bus/pci/devices/'$device'/iommu_group)\" 2>/dev/null || echo -1",
        )).trim();
        map = 'node=$node,path=$device,id=$ids,iommugroup=$group';
      }
      await onNode("pvesh create /cluster/mapping/$kind --id '$id' --map '$map'");
      try {
        await onNode("pveum acl modify '/mapping/$kind/$id' --tokens '$tokenId' --roles PVEMappingUser");
        final devs = await pve.hostDevices(vm);
        final mapped = (kind == 'usb' ? devs.usb : devs.pci).firstWhere((d) => d.id == id);
        expect(mapped.mapping, isTrue);
        var hw = await pve.hardware(vm);
        await pve.changeHardware(
          vm,
          hw,
          VirtHwAddDevice(
            kind: kind == 'usb' ? VirtHwDeviceKind.usb : VirtHwDeviceKind.pci,
            host: mapped,
          ),
        );
        hw = await pve.hardware(vm);
        final key = hw.devices.firstWhere((d) => d.detail == id).key;
        await pve.power(vm, VirtPowerAction.start);
        vm = await settle((g) => g.state == VirtGuestState.running);
        final cmd = await onNode('qm showcmd ${vm.vmid}');
        if (kind == 'usb') {
          final [vendor, product] = device.split(':');
          expect(cmd, allOf(contains('usb-host'), contains('0x$vendor'), contains('0x$product')));
        } else {
          expect(cmd, allOf(contains('vfio-pci'), contains(device)));
        }
        await stop();
        await pve.changeHardware(vm, await pve.hardware(vm), VirtHwRemoveDevice(key: key));
        expect((await pve.hardware(vm)).device(key), isNull);
      } finally {
        try {
          await stop();
        } catch (_) {}
        await onNode("pveum acl delete '/mapping/$kind/$id' --tokens '$tokenId' --roles PVEMappingUser || true");
        await onNode("pvesh delete '/cluster/mapping/$kind/$id'");
      }
    }

    test('USB passthrough through a resource mapping', () async {
      if (usb == null) {
        markTestSkipped('SBM_E2E_PVE_USB is not set');
        return;
      }
      await passthrough('usb', usb);
    });

    test('PCI passthrough through a resource mapping', () async {
      if (pci == null) {
        markTestSkipped('SBM_E2E_PVE_PCI is not set');
        return;
      }
      await passthrough('pci', pci);
    });
  });
}

/// A VM and, where a template is there, a container of the test's own on the
/// PVE node, through the API over an SSH channel: created, started, refused
/// a second time, refused deletion while running, then force-stopped and
/// deleted with their volumes. The token needs the create privileges too:
/// `VM.Allocate`, `VM.Config.*`, `Datastore.AllocateSpace`, `SDN.Use`.
Future<void> _pveCreate() async {
  final host = e2eEnv('SBM_E2E_PVE_HOST');
  final tokenId = e2eEnv('SBM_E2E_PVE_TOKEN_ID');
  final tokenSecret = e2eEnv('SBM_E2E_PVE_TOKEN_SECRET');
  if (host == null || tokenId == null || tokenSecret == null) return;
  final ready = await prepareSshE2e(host);
  final target = ready.target;
  if (target == null) return;

  group('create and delete: PVE over SSH', () {
    SSHClient? client;
    late PveBackend pve;
    final created = <VirtGuestKind, int>{};

    Future<VirtGuest?> find(VirtGuestKind kind, int vmid) async =>
        (await pve.load()).guests
            .where((g) => g.kind == kind && g.vmid == vmid)
            .firstOrNull;

    Future<VirtGuest> settle(
      VirtGuestKind kind,
      int vmid,
      bool Function(VirtGuest g) test,
    ) async {
      final deadline = DateTime.now().add(const Duration(seconds: 60));
      while (true) {
        final g = await find(kind, vmid);
        if (g != null && test(g)) return g;
        if (DateTime.now().isAfter(deadline)) fail('$kind $vmid never settled');
        await Future<void>.delayed(const Duration(seconds: 1));
      }
    }

    setUpAll(() async {
      await initRustLibForTest();
      final c = await connectSshE2e(target, ready.identities);
      client = c;
      final d = _pvePaths(target, () => c, '')['over SSH']!.dialer();
      pve = PveBackend(
        serverId: 'e2e-pve-create',
        config: PveConfig(
          addr: 'https://localhost:8006',
          auth: PveAuth.token,
          tokenId: tokenId,
          tokenSecret: tokenSecret,
        ),
        connect: d.startConnect,
        onClose: d.close,
        taskPoll: const Duration(milliseconds: 500),
        taskTimeout: const Duration(minutes: 3),
      );
      final e = await _virtErr(pve.load());
      expect(e.type, VirtErrType.certUnconfirmed);
      await pve.confirmCert(e.cert!.fingerprint);
    });
    tearDownAll(() async {
      for (final MapEntry(key: kind, value: vmid) in created.entries) {
        try {
          final g = await find(kind, vmid);
          if (g == null) continue;
          if (g.state != VirtGuestState.stopped) {
            await pve.power(g, VirtPowerAction.forceStop);
          }
          await _whileLocked(() async => pve.delete((await find(kind, vmid))!));
        } catch (_) {}
      }
      await pve.close();
      client?.close();
    });

    Future<void> stopAndDelete(VirtGuest g, VirtStoragePool storage) async {
      final running = await _virtErr(pve.delete(g));
      expect(running.type, VirtErrType.unsupported);
      await pve.power(g, VirtPowerAction.forceStop);
      final stopped = await settle(
        g.kind,
        g.vmid!,
        (x) => x.state == VirtGuestState.stopped,
      );
      await _afterStop();
      await _whileLocked(() => pve.delete(stopped));
      expect(await find(g.kind, g.vmid!), isNull);
      final vols = await pve.volumes(storage);
      expect(vols.where((v) => v.id.contains('-${g.vmid}-')), isEmpty);
      created.remove(g.kind);
    }

    for (final kind in VirtGuestKind.values) {
      test('a ${kind.name}: created, started, then deleted', () async {
        final snap = await pve.load();
        expect(snap.capabilities.create, isTrue);
        final node = snap.host.nodes.firstWhere((n) => n.online).name;
        final pools = await pve.storagePools();
        final storage = virtDiskStorages(
          pools,
          host: VirtHostKind.pve,
          kind: kind,
          node: node,
        ).first;
        final media = <VirtVolume>[];
        for (final p in virtMediaStorages(
          pools,
          host: VirtHostKind.pve,
          kind: kind,
          node: node,
        )) {
          media.addAll(
            (await pve.volumes(p)).where((v) => virtIsMedia(v, kind)),
          );
        }
        if (kind == VirtGuestKind.lxc && media.isEmpty) {
          markTestSkipped('no container template on $node');
          return;
        }
        final bridge = virtCreateNetworks(
          await pve.networks(),
          host: VirtHostKind.pve,
          node: node,
        ).first;
        final vmid = (await pve.nextVmid())!;
        final spec = VirtCreateSpec(
          kind: kind,
          name: _e2eName(kind == VirtGuestKind.lxc ? 'ct' : 'vm'),
          node: node,
          vmid: vmid,
          cores: 1,
          memoryMiB: kind == VirtGuestKind.lxc ? 256 : 512,
          storage: storage,
          diskGiB: 1,
          media: media.firstOrNull,
          network: bridge,
          password: kind == VirtGuestKind.lxc
              ? List.generate(
                  16,
                  (_) => 'abcdefghjkmnpqrstuvwxyz23456789'[Random.secure()
                      .nextInt(31)],
                ).join()
              : null,
          start: true,
        );
        expect(
          virtCreateIssue(spec, host: VirtHostKind.pve, guests: snap.guests),
          isNull,
        );
        final result = await pve.create(spec);
        created[kind] = vmid;
        expect(result.startError, isNull);
        final g = await settle(
          kind,
          vmid,
          (g) => g.state == VirtGuestState.running,
        );

        final taken = await _virtErr(pve.create(spec));
        expect(taken.type, VirtErrType.exists, reason: '${taken.message}');

        await stopAndDelete(g, storage);
      });
    }
  });
}

// -----------------------------------------------------------------------------
// Proxmox VE, password login
// -----------------------------------------------------------------------------

Future<void> _pvePassword() async {
  final host = e2eEnv('SBM_E2E_PVE_HOST');
  final pwdUser = e2eEnv('SBM_E2E_PVE_PWD_USER');
  final pwd = e2eEnv('SBM_E2E_PVE_PWD');
  final identity = e2eEnv('SBM_E2E_PVE_USER_IDENTITY');
  if (host == null || pwdUser == null || pwd == null || identity == null) {
    test(
      'pve password e2e',
      () {},
      skip:
          'SBM_E2E_PVE_HOST, SBM_E2E_PVE_PWD_USER, SBM_E2E_PVE_PWD and '
          'SBM_E2E_PVE_USER_IDENTITY are not all set',
    );
    return;
  }
  final ready = await prepareSshE2e(host);
  final target = ready.target;
  if (target == null) {
    final failure = ready.failure;
    if (failure != null) {
      test('pve password e2e', () => fail(failure));
    } else {
      test('pve password e2e', () {}, skip: ready.skip);
    }
    return;
  }
  final totpUser = e2eEnv('SBM_E2E_PVE_TOTP_USER');
  final totpPwd = e2eEnv('SBM_E2E_PVE_TOTP_PWD');
  final totpSecret = e2eEnv('SBM_E2E_PVE_TOTP_SECRET');
  final lxcId = int.parse(e2eEnv('SBM_E2E_PVE_LXC') ?? '200');
  final vmId = int.parse(e2eEnv('SBM_E2E_PVE_VM') ?? '100');
  const addr = 'https://localhost:8006';

  late SSHClient root;
  late List<SSHKeyPair> userKey;
  final clients = <SSHClient>[];
  String? pin;
  // Seconds since the epoch, on the node's clock, when the group started:
  // the journal is read from there.
  late int since;

  Future<SSHClient> connectAs(String user, {String? password}) async {
    final socket = await SSHSocket.connect(
      target.hostname,
      target.port,
      timeout: const Duration(seconds: 10),
    );
    final client = SSHClient(
      socket,
      username: user,
      identities: password == null ? userKey : null,
      onPasswordRequest: password == null ? null : () => password,
      disableHostkeyVerification: true,
    );
    await client.authenticated;
    clients.add(client);
    return client;
  }

  Future<String> asRoot(String command) async {
    final r = await execSshE2e(root, command, null);
    if (r.exitCode != 0) fail('`$command` exited ${r.exitCode}: ${r.stderr}');
    return r.stdout;
  }

  Future<void> enable(String user, bool on) =>
      asRoot('pveum user modify ${_shQuote('$user@pam')} --enable ${on ? 1 : 0}');

  /// What `pvedaemon` logged as `successful auth` for [user] since the group
  /// started: every password login, TFA answer and ticket renewal.
  Future<int> authCount(String user) async {
    final out = await asRoot(
      'journalctl -u pvedaemon --since @$since -o cat --no-pager',
    );
    return out
        .split('\n')
        .where((l) => l.contains("successful auth for user '$user@pam'"))
        .length;
  }

  /// [authCount] once the journal has caught up to [atLeast], or what it
  /// reads after a few seconds.
  Future<int> authCountAtLeast(String user, int atLeast) async {
    var n = 0;
    for (var i = 0; i < 10; i++) {
      n = await authCount(user);
      if (n >= atLeast) return n;
      await Future<void>.delayed(const Duration(milliseconds: 500));
    }
    return n;
  }

  /// [authCount] once two reads a moment apart agree: the journal has
  /// caught up with the logins made so far.
  Future<int> settledAuthCount(String user) async {
    var n = await authCount(user);
    while (true) {
      await Future<void>.delayed(const Duration(milliseconds: 500));
      final again = await authCount(user);
      if (again == n) return n;
      n = again;
    }
  }

  /// The backend as `PveBackend.of` makes it for [spi], over [client].
  PveBackend backend(
    Spi spi,
    SSHClient client, {
    String? pvePwd,
    DateTime Function()? now,
  }) {
    final d = ServerTcpDialer(
      spi: spi,
      ssh: () async => ServerTcpSsh.client(client),
    );
    return PveBackend(
      serverId: spi.id,
      config: PveConfig(addr: addr, pwd: pvePwd, certSha256: pin),
      connect: d.startConnect,
      onClose: d.close,
      user: spi.ssh?.user,
      sshKeyId: spi.ssh?.keyId,
      sshPassword: spi.ssh?.pwd,
      taskPoll: const Duration(milliseconds: 500),
      taskTimeout: const Duration(minutes: 3),
      now: now,
    );
  }

  Spi byKey(String user) => spiFixture(
    name: 'e2e-$user',
    id: 'e2e-$user',
    ip: target.hostname,
    user: user,
    keyId: 'e2e-key',
  );

  Spi byPassword(String user, String password) => spiFixture(
    name: 'e2e-$user-pw',
    id: 'e2e-$user-pw',
    ip: target.hostname,
    user: user,
    pwd: password,
  );

  VirtGuest guestOf(VirtSnapshot snap, VirtGuestKind kind, int vmid) =>
      snap.guests.firstWhere(
        (g) => g.kind == kind && g.vmid == vmid,
        orElse: () => fail('no ${kind.name} $vmid'),
      );

  group('PVE password', () {
    setUpAll(() async {
      await initRustLibForTest();
      root = await connectSshE2e(target, ready.identities);
      userKey = SSHKeyPair.fromPem(File(identity).readAsStringSync());
      since = int.parse((await asRoot('date +%s')).trim()) - 1;
    });

    tearDownAll(() async {
      // Whatever a failed test left behind.
      for (final user in [pwdUser, ?totpUser]) {
        await execSshE2e(
          root,
          'pveum user modify ${_shQuote('$user@pam')} --enable 1; '
          'pveum user tfa unlock ${_shQuote('$user@pam')}',
          null,
        );
      }
      for (final c in clients) {
        c.close();
      }
      root.close();
    });

    group('login', () {
      late SSHClient pwdKey;
      setUpAll(() async => pwdKey = await connectAs(pwdUser));

      test('the certificate is asked about before any password is sent',
          () async {
        final before = await settledAuthCount(pwdUser);
        final pve = backend(byKey(pwdUser), pwdKey, pvePwd: pwd);
        try {
          final e = await _virtErr(pve.load());
          expect(e.type, VirtErrType.certUnconfirmed);
          pin = e.cert!.fingerprint.toLowerCase();
          await pve.confirmCert(pin!);
          expect((await pve.load()).guests, isNotEmpty);
        } finally {
          await pve.close();
        }
        expect(await authCountAtLeast(pwdUser, before + 1), before + 1);
      });

      test('SSH by key, the PVE password: listing, a console as that user, and '
          'a reboot of the container', () async {
        final pve = backend(byKey(pwdUser), pwdKey, pvePwd: pwd);
        try {
          final snap = await pve.load();
          expect(snap.host.version, matches(RegExp(r'^\d+\.\d+')));
          expect(guestOf(snap, VirtGuestKind.qemu, vmId).state,
              VirtGuestState.running);
          final ct = guestOf(snap, VirtGuestKind.lxc, lxcId);
          expect(ct.state, VirtGuestState.running);

          // A ticket session's console: issued to the user, and the websocket
          // authenticated by the cookie rather than a token header.
          final console = await pve.console(ct, VirtConsoleKind.text);
          expect(console.user, '$pwdUser@pam');
          final socket = await pve.openConsoleSocket(console);
          final term = await PveTermShellBackend.start(
            socket,
            user: console.user,
            ticket: console.ticket,
          );
          expect(term.isClosed, isFalse);
          term.close();

          final before = ct.uptime;
          await pve.power(ct, VirtPowerAction.reboot);
          final after = guestOf(await pve.load(), VirtGuestKind.lxc, lxcId);
          expect(after.state, VirtGuestState.running);
          // Null only in the container's first second: `status/current`
          // answers 0 then.
          final up = after.uptime;
          if (before != null && up != null) expect(up, lessThan(before));
        } finally {
          await pve.close();
        }
      });

      test('SSH by password: that password logs in to PVE, a stored PVE '
          'password is not used', () async {
        final spi = byPassword(pwdUser, pwd);
        final client = await connectAs(pwdUser, password: pwd);
        final pve = backend(spi, client, pvePwd: 'stale-$pwd');
        try {
          final snap = await pve.load();
          expect(guestOf(snap, VirtGuestKind.lxc, lxcId).node, isNotNull);
        } finally {
          await pve.close();
        }
      });

      test('a wrong password is authFailed with PVE\'s own words', () async {
        final pve = backend(byKey(pwdUser), pwdKey, pvePwd: 'wrong-$pwd');
        try {
          final e = await _virtErr(pve.load());
          expect(e.type, VirtErrType.authFailed);
          // PVE 9.2 answers `401 authentication failure` with that message.
          expect(e.message, 'authentication failure');
          // Nothing stuck: asked again, it is refused again.
          expect((await _virtErr(pve.load())).type, VirtErrType.authFailed);
        } finally {
          await pve.close();
        }
      });

      test('a disabled account: the session is refused, and once enabled the '
          'next call logs in again', () async {
        final pve = backend(byKey(pwdUser), pwdKey, pvePwd: pwd);
        try {
          await pve.load();
          final logins = await settledAuthCount(pwdUser);
          await enable(pwdUser, false);
          try {
            // PVE answers the ticket 401 (`Authentication failed!`); the one
            // new login is refused too.
            final e = await _virtErr(pve.load());
            expect(e.type, VirtErrType.authFailed);
          } finally {
            await enable(pwdUser, true);
          }
          expect((await pve.load()).guests, isNotEmpty);
          expect(
            await authCountAtLeast(pwdUser, logins + 1),
            logins + 1,
            reason: 'one new login',
          );
        } finally {
          await pve.close();
        }
      });

      test('an hour on, the ticket is renewed with itself', () async {
        var offset = Duration.zero;
        final pve = backend(
          byKey(pwdUser),
          pwdKey,
          pvePwd: pwd,
          now: () => DateTime.now().add(offset),
        );
        try {
          await pve.load();
          final logins = await settledAuthCount(pwdUser);
          offset = PveBackend.renewAfter;
          expect((await pve.load()).guests, isNotEmpty);
          expect(await authCountAtLeast(pwdUser, logins + 1), logins + 1);
          // The renewed ticket is what the session uses now.
          final ct = guestOf(await pve.load(), VirtGuestKind.lxc, lxcId);
          expect((await pve.console(ct, VirtConsoleKind.text)).user,
              '$pwdUser@pam');
        } finally {
          await pve.close();
        }
      });
    });

    if (totpUser == null || totpPwd == null || totpSecret == null) {
      test(
        'pve TOTP e2e',
        () {},
        skip:
            'SBM_E2E_PVE_TOTP_USER, SBM_E2E_PVE_TOTP_PWD and '
            'SBM_E2E_PVE_TOTP_SECRET are not all set',
      );
      return;
    }

    group('with TOTP', () {
      late SSHClient totpKey;
      setUpAll(() async => totpKey = await connectAs(totpUser));

      // PVE refuses a TOTP value already used ("rejecting reused TOTP value")
      // and accepts the step after the current one, so a code for a step not
      // used yet is never more than a step's wait away.
      var lastStep = 0;
      int stepNow() => DateTime.now().millisecondsSinceEpoch ~/ 30000;
      Future<String> freshCode() async {
        while (lastStep >= stepNow() + 1) {
          await Future<void>.delayed(const Duration(seconds: 1));
        }
        lastStep = max(lastStep + 1, stepNow());
        return _totp(totpSecret, lastStep);
      }

      PveBackend totp({DateTime Function()? now}) =>
          backend(byKey(totpUser), totpKey, pvePwd: totpPwd, now: now);

      test('needTfa, a wrong code keeps the challenge, the right one logs in',
          () async {
        final pve = totp();
        try {
          final e = await _virtErr(pve.load());
          expect(e.type, VirtErrType.needTfa);
          expect(e.message, l10n.pveOtpRequired);

          // An hour ago's code is wrong now.
          final wrong = await _virtErr(
            pve.submitTfa(_totp(totpSecret, stepNow() - 120)),
          );
          expect(wrong.type, VirtErrType.needTfa);
          expect(wrong.message, l10n.pveOtpVerificationFailed);

          await pve.submitTfa(await freshCode());
          final snap = await pve.load();
          final ct = guestOf(snap, VirtGuestKind.lxc, lxcId);
          expect((await pve.console(ct, VirtConsoleKind.text)).user,
              '$totpUser@pam');
        } finally {
          await pve.close();
        }
      });

      test('a code already used is refused; a new one answers the same '
          'challenge', () async {
        final pve = totp();
        try {
          expect((await _virtErr(pve.load())).type, VirtErrType.needTfa);
          final used = _totp(totpSecret, lastStep);
          final replay = await _virtErr(pve.submitTfa(used));
          expect(replay.type, VirtErrType.needTfa);
          expect(replay.message, l10n.pveOtpVerificationFailed);
          await pve.submitTfa(await freshCode());
          expect((await pve.load()).guests, isNotEmpty);
        } finally {
          await pve.close();
        }
      });

      test('a challenge past its lifetime is replaced, and the code answers '
          'the new one', () async {
        var offset = Duration.zero;
        final pve = totp(now: () => DateTime.now().add(offset));
        try {
          expect((await _virtErr(pve.load())).type, VirtErrType.needTfa);
          final logins = await settledAuthCount(totpUser);
          offset = PveBackend.ticketLifetime;
          await pve.submitTfa(await freshCode());
          expect((await pve.load()).guests, isNotEmpty);
          // The new first-factor login and the answer.
          expect(await authCountAtLeast(totpUser, logins + 2), logins + 2);
        } finally {
          await pve.close();
        }
      });

      test('an hour on, the ticket is renewed without a code', () async {
        var offset = Duration.zero;
        final pve = totp(now: () => DateTime.now().add(offset));
        try {
          expect((await _virtErr(pve.load())).type, VirtErrType.needTfa);
          await pve.submitTfa(await freshCode());
          await pve.load();
          final logins = await settledAuthCount(totpUser);
          offset = PveBackend.renewAfter;
          expect((await pve.load()).guests, isNotEmpty);
          expect(await authCountAtLeast(totpUser, logins + 1), logins + 1);
        } finally {
          await pve.close();
        }
      });

      test('a refused session logs in again, and that asks for a code', () async {
        final pve = totp();
        try {
          expect((await _virtErr(pve.load())).type, VirtErrType.needTfa);
          await pve.submitTfa(await freshCode());
          await pve.load();
          await enable(totpUser, false);
          try {
            expect((await _virtErr(pve.load())).type, VirtErrType.authFailed);
          } finally {
            await enable(totpUser, true);
          }
          expect((await _virtErr(pve.load())).type, VirtErrType.needTfa);
          await pve.submitTfa(await freshCode());
          expect((await pve.load()).guests, isNotEmpty);
        } finally {
          await pve.close();
        }
      });
    });
  });
}

// -----------------------------------------------------------------------------
// Helpers
// -----------------------------------------------------------------------------

String _shQuote(String s) => "'${s.replaceAll("'", r"'\''")}'";

/// Opens [vm]'s VNC console through [pve]'s websocket tunnel and answers the
/// RFB handshake with [password]: the security types offered and the
/// SecurityResult (0 is OK; -1 when VNC authentication was not offered).
Future<({int result, List<int> types})> _pveVncHandshake(
  PveBackend pve,
  VirtGuest vm,
  String Function(PveVncConsole c) password,
) async {
  final console = await pve.console(vm, VirtConsoleKind.vnc);
  expect(console, isA<PveVncConsole>());
  console as PveVncConsole;
  // `generate-password`'s: 8 characters, not the ticket.
  expect(console.password, isNot(console.ticket));
  expect(console.password.length, 8);
  final socket = await pve.openConsoleSocket(console);
  final tunnel = await WebSocketTunnelChannel.loopbackOnce(
    WebSocketTunnelChannel(socket),
  );
  final rfb = _RfbReader(
    await connectTunnel(tunnel),
  );
  try {
    final version = ascii.decode(await rfb.take(12));
    expect(version, matches(RegExp(r'^RFB 003\.00\d\n$')));
    rfb.add(ascii.encode('RFB 003.008\n'));
    final count = (await rfb.take(1)).single;
    expect(count, greaterThan(0), reason: 'server refused: no types');
    final types = await rfb.take(count);
    if (!types.contains(2)) return (result: -1, types: types);
    rfb.add([2]);
    final challenge = await rfb.take(16);
    rfb.add(_vncResponse(password(console), challenge));
    final result = ByteData.sublistView(
      Uint8List.fromList(await rfb.take(4)),
    ).getUint32(0);
    return (result: result, types: types);
  } finally {
    await rfb.close();
    await tunnel.close();
  }
}

Future<VirtErr> _virtErr(Future<Object?> future) async {
  try {
    await future;
  } on VirtErr catch (e) {
    return e;
  }
  fail('expected a VirtErr');
}

/// Accumulates a byte stream as text, for "wait until this appears".
class _Collector {
  _Collector(Stream<Uint8List> stream) {
    _sub = stream.listen((b) {
      _buf.write(utf8.decode(b, allowMalformed: true));
      _changed.add(null);
    });
  }

  final _buf = StringBuffer();
  final _changed = StreamController<void>.broadcast();
  late final StreamSubscription<Uint8List> _sub;

  String get text => _buf.toString();

  void clear() => _buf.clear();

  Future<void> waitFor(
    String needle, {
    Duration timeout = const Duration(seconds: 20),
  }) async {
    final deadline = DateTime.now().add(timeout);
    while (!text.contains(needle)) {
      final left = deadline.difference(DateTime.now());
      if (left.isNegative) {
        fail('"$needle" never arrived; got: ${jsonEncode(text)}');
      }
      await _changed.stream.first.timeout(left, onTimeout: () {});
    }
  }

  Future<void> cancel() => _sub.cancel();
}

/// Reads exact byte counts off a socket.
class _RfbReader {
  _RfbReader(this._socket) {
    _sub = _socket.listen(
      (b) {
        _buf.addAll(b);
        _wake();
      },
      onDone: () {
        _done = true;
        _wake();
      },
    );
  }

  final Socket _socket;
  final _buf = <int>[];
  late final StreamSubscription<Uint8List> _sub;
  Completer<void>? _waiting;
  var _done = false;

  void _wake() {
    _waiting?.complete();
    _waiting = null;
  }

  void add(List<int> bytes) => _socket.add(bytes);

  Future<List<int>> take(int n) async {
    while (_buf.length < n) {
      if (_done) fail('connection closed after ${_buf.length}/$n bytes');
      _waiting = Completer<void>();
      await _waiting!.future.timeout(const Duration(seconds: 15));
    }
    final out = _buf.sublist(0, n);
    _buf.removeRange(0, n);
    return out;
  }

  Future<void> close() async {
    await _sub.cancel();
    _socket.destroy();
  }
}

/// RFB's VNC authentication: the 16-byte challenge DES-encrypted (ECB) with
/// the password — its first 8 bytes, zero-padded — as the key, each key byte
/// bit-reversed. Single DES is 3DES-EDE with three equal keys.
List<int> _vncResponse(String password, List<int> challenge) {
  final key = Uint8List(8);
  final pw = latin1.encode(password);
  for (var i = 0; i < 8 && i < pw.length; i++) {
    var b = pw[i], r = 0;
    for (var bit = 0; bit < 8; bit++) {
      r = (r << 1) | (b & 1);
      b >>= 1;
    }
    key[i] = r;
  }
  final des = DESedeEngine()
    ..init(true, KeyParameter(Uint8List.fromList([...key, ...key, ...key])));
  final input = Uint8List.fromList(challenge);
  final out = Uint8List(16);
  des.processBlock(input, 0, out, 0);
  des.processBlock(input, 8, out, 8);
  return out;
}

/// RFC 6238 TOTP, SHA-1, 6 digits, for the 30 s [step] — what PVE's `totp`
/// factor checks. [secret] is base32 (RFC 4648, padding optional).
String _totp(String secret, int step) {
  const alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567';
  final key = <int>[];
  var buffer = 0, bits = 0;
  for (final ch in secret.toUpperCase().replaceAll('=', '').split('')) {
    final v = alphabet.indexOf(ch);
    if (v < 0) throw FormatException('not base32', secret.length);
    buffer = (buffer << 5) | v;
    bits += 5;
    if (bits >= 8) {
      bits -= 8;
      key.add((buffer >> bits) & 0xff);
    }
  }
  final counter = ByteData(8)..setUint64(0, step);
  final mac = HMac(SHA1Digest(), 64)..init(KeyParameter(Uint8List.fromList(key)));
  final hash = mac.process(counter.buffer.asUint8List());
  final offset = hash.last & 0x0f;
  final code =
      ByteData.sublistView(hash, offset, offset + 4).getUint32(0) & 0x7fffffff;
  return (code % 1000000).toString().padLeft(6, '0');
}
