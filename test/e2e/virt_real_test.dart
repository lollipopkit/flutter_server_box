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
/// Storage and networks, groups of their own (`--plain-name 'storage and
/// networks'`) that touch nothing existing: on the libvirt host a pool in a
/// fresh `/var/lib/libvirt/sbxe2e-*` with volumes, uploads, a VM to attach
/// to, and `sbxe2e-net-*` networks on 10.231.78.0/24 and 10.231.79.0/24; on
/// the PVE node a directory storage in a fresh `/var/lib/sbxe2e-*`, a VM and
/// a bridge `sbxe2e*` on 10.231.77.0/24 with no ports, **applied** to the
/// node's network and removed again (it refuses to start while changes are
/// pending there already). The PVE token then needs `Datastore.Allocate`,
/// `Datastore.AllocateSpace`, `Datastore.AllocateTemplate` and `Sys.Modify`
/// on `/nodes/<node>`; the `SBM_E2E_PVE_HOST` login must be root.
///
/// - `SBM_E2E_LIBVIRT_SUDO_USER`, `SBM_E2E_LIBVIRT_SUDO_PASSWORD`: an account
///   on the libvirt host outside the `libvirt` group, with sudo, and its
///   password. The `SBM_E2E_LIBVIRT_HOST` login must be root: the upload runs
///   as that account through `su`, and so through sudo with the password.
///
/// Cloud images and cloud-init, groups of their own (`--plain-name 'cloud
/// images'`) that touch nothing existing. Each boots a VM `sbxe2e-ci-*` made
/// from a cloud image with cloud-init (an account with a password and a key
/// generated for the run), logs in to it over SSH through the host, checks
/// the hostname, the account, sudo, the password's hash and the grown disk,
/// adds and removes a CD-ROM drive, then deletes it — with its own disk and
/// seed; the image is left as it was.
///
/// - `SBM_E2E_LIBVIRT_CLOUD_IMAGE`: the path of a cloud image volume in a
///   pool of the libvirt host (Debian 13 genericcloud, say), which the
///   `SBM_E2E_LIBVIRT_HOST` login (root) can use; the host needs an ISO tool
///   (genisoimage, xorriso, …). The VM gets DHCP on `default`.
/// - `SBM_E2E_PVE_CLOUD_IMAGE`: the volid of such an image with `import`
///   content (`local:import/debian-13.qcow2`), with `SBM_E2E_PVE_HOST` as
///   root and the token; `SBM_E2E_PVE_CLOUD_ADDR` (`192.168.31.230/24`) and
///   `SBM_E2E_PVE_CLOUD_GW`: a free address on `vmbr0`'s network for the VM
///   (checked unanswered first) and its gateway. A VMID from 950 up that is
///   free is used. The token needs `VM.Config.Cloudinit` besides the create
///   set.
///
/// More cloud images, a group of its own (`--plain-name 'cloud images: each
/// image'`), everything named `sbxe2e-ci-*` and removed afterwards, the
/// images left as they were:
///
/// - `SBM_E2E_LIBVIRT_CLOUD_IMAGES`: cloud image paths on the libvirt host,
///   comma-separated (Debian, Ubuntu, Alpine's `nocloud` image, which boots
///   from BIOS only). Each is made a VM from (4 GiB, DHCP), logged in to,
///   its cloud-init read back from the seed and edited — a new hostname and
///   key, the password kept — then rebooted from inside: the new key lets
///   in, the hostname, the instance ID and the SSH host keys are new, the
///   old key still lets in. The biggest image is also made into a disk
///   asked smaller than it: kept at its size, and started.
/// - `SBM_E2E_LIBVIRT_DISK_POOL`: the pool the disks go to (another than
///   the images'); the image's own pool without it.
/// - `SBM_E2E_LIBVIRT_SEED_TOOLS`: ISO tools to make a seed with each
///   (`genisoimage,xorriso,mkisofs,cloud-localds`), the backend narrowed to
///   that one: booted from, read back, written anew.
/// - `SBM_E2E_LIBVIRT_TPM=1`: a UEFI VM with a TPM (the host needs swtpm):
///   swtpm runs for it, the system has `/dev/tpm0`, the state goes with it.
///
/// With `SBM_E2E_PVE_CLOUD_IMAGE` the PVE group also makes a VM from the
/// image with a disk asked smaller than it (kept at the image's size,
/// started), edits its cloud-init (a new key, another DNS server), and
/// reboots it from inside: the drive PVE wrote at once is what it reads.
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

import 'package:crypto/crypto.dart' show sha256;
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
import 'package:server_box/data/model/server/server_exec.dart';
import 'package:server_box/data/model/server/server_private_info.dart';
import 'package:server_box/data/model/server/shell_backend.dart';
import 'package:server_box/data/model/virt/virt.dart';
import 'package:server_box/data/model/virt/virt_console.dart';
import 'package:server_box/data/model/virt/virt_create.dart';
import 'package:server_box/data/model/virt/virt_detail.dart';
import 'package:server_box/data/model/virt/virt_hardware.dart';
import 'package:server_box/data/model/virt/virt_manage.dart';
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
  await _libvirtCloudInit();
  await _libvirtCloudImages();
  await _pveCloudInit();
  await _p8Snapshots();
  await _libvirtManage();
  await _libvirtBlockPools();
  await _pveManage();
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
  final ready = await prepareReachableSshE2e(host);
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
  final ready = await prepareReachableSshE2e(host);
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
          tunnel: d.loopback,
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
  final ready = await prepareReachableSshE2e(host);
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
          tunnel: d.loopback,
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
/// that window fails on it after 10 s (PVE 9.2, see docs/dev/virt.md). The cleanup
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
  final ready = await prepareReachableSshE2e(host);
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
      for (final n in [name, '$name-hw']) {
        try {
          final g = (await virt.load()).guests.where((g) => g.name == n).firstOrNull;
          if (g != null) {
            if (g.state != VirtGuestState.stopped) {
              await virt.power(g, VirtPowerAction.forceStop);
            }
            await virt.delete((await virt.load()).guests.firstWhere((g) => g.name == n));
          }
        } catch (_) {}
      }
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

    test('shut off: a topology with dies and clusters read and kept; a '
        'CD-ROM on SCSI; USB given by its address', () async {
      final hwName = '$name-hw';
      Future<String> sh(String command) async =>
          (await execSshE2e(client!, command, null)).stdout;
      Future<String> inactive(VirtGuest g) =>
          sh("virsh --connect qemu:///system dumpxml --inactive '${g.id}'");
      final pool = virtDiskStorages(
        await virt.storagePools(),
        host: VirtHostKind.libvirt,
        kind: VirtGuestKind.qemu,
      ).first;
      await virt.create(VirtCreateSpec(
        kind: VirtGuestKind.qemu,
        name: hwName,
        cores: 1,
        memoryMiB: 256,
        storage: pool,
        diskGiB: 1,
      ));
      var g = (await virt.load()).guests.firstWhere((g) => g.name == hwName);

      // A topology the form does not make: 1 socket, 2 dies, 2 clusters,
      // 1 core, 1 thread — 4 vCPUs. Written by hand, as virsh edit would.
      final xml = await inactive(g);
      final edited = xml
          .replaceFirst(RegExp(r'<vcpu[^>]*>\d+</vcpu>'), "<vcpu placement='static'>4</vcpu>")
          .replaceFirst(RegExp(r'<cpu\b[^>]*/>|<cpu\b[\s\S]*?</cpu>'), '')
          .replaceFirst('</features>', "</features><cpu mode='host-passthrough'><topology sockets='1' dies='2' clusters='2' cores='1' threads='1'/></cpu>");
      await execSshE2e(
        client!,
        r'f=$(mktemp) && cat > "$f" && virsh --connect qemu:///system -q define "$f" >/dev/null; r=$?; rm -f "$f"; exit $r',
        Uint8List.fromList(utf8.encode(edited)),
      );
      var hw = await virt.hardware(g);
      // Dies and clusters count as threads: 1 × 1 × 4.
      expect((hw.cpu.sockets, hw.cpu.cores, hw.cpu.threads), (1, 1, 4));
      // A memory change keeps the topology as it is.
      await virt.changeHardware(g, hw, VirtHwSetMemory(mib: 384));
      expect(await inactive(g), contains("dies='2' clusters='2'"));
      // Two sockets: the host takes the definition (libvirt checks the
      // vCPU count against the topology), dies and clusters kept.
      hw = await virt.hardware(g);
      await virt.changeHardware(g, hw, const VirtHwSetCpu(sockets: 2, cores: 1));
      final after = await inactive(g);
      final topo = RegExp(r'<topology[^>]*/>').firstMatch(after)![0]!;
      final vcpus = RegExp(r'<vcpu[^>]*>(\d+)</vcpu>').firstMatch(after)![1]!;
      int attr(String a) => int.parse(RegExp("$a='(\\d+)'").firstMatch(topo)![1]!);
      expect(attr('sockets'), 2, reason: topo);
      expect(int.parse(vcpus), attr('sockets') * attr('dies') * attr('clusters') * attr('cores') * attr('threads'), reason: after);
      hw = await virt.hardware(g);
      expect(hw.cpu.sockets * hw.cpu.cores * hw.cpu.threads, int.parse(vcpus));

      // A CD-ROM, moved to SCSI and back.
      await virt.changeHardware(g, hw, const VirtHwAddCdrom());
      hw = await virt.hardware(g);
      var cd = hw.disks.singleWhere((d) => d.kind == VirtHwDiskKind.cdrom);
      expect(cd.bus, 'sata');
      await virt.changeHardware(g, hw, VirtHwUpdateDisk(key: cd.key, bus: 'scsi'));
      hw = await virt.hardware(g);
      cd = hw.disks.singleWhere((d) => d.kind == VirtHwDiskKind.cdrom);
      expect(cd.bus, 'scsi');
      expect(cd.key, startsWith('sd'));
      expect(await inactive(g), contains("<controller type='scsi'"));
      await virt.changeHardware(g, hw, VirtHwRemoveDisk(key: cd.key));

      // USB by address. The host has no USB device, so the address is one
      // nothing sits at: the definition takes it (the device is looked for
      // at start), which is what is checked here.
      hw = await virt.hardware(g);
      const dev = VirtHostDevice(id: '1:7', label: 'sbxe2e', usbBus: 1, usbDevice: 7, usbPort: '3');
      await virt.changeHardware(g, hw, const VirtHwAddDevice(kind: VirtHwDeviceKind.usb, host: dev, usbNaming: VirtUsbNaming.address));
      final withUsb = await inactive(g);
      expect(withUsb, contains("<address bus='1' device='7'/>"), reason: withUsb);
      hw = await virt.hardware(g);
      final usb = hw.devices.singleWhere((d) => d.kind == VirtHwDeviceKind.usb);
      await virt.changeHardware(g, hw, VirtHwRemoveDevice(key: usb.key));
      expect(await inactive(g), isNot(contains('<hostdev')));

      g = (await virt.load()).guests.firstWhere((g) => g.name == hwName);
      await virt.delete(g);
      expect((await virt.load()).guests.where((g) => g.name == hwName), isEmpty);
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
  final ready = await prepareReachableSshE2e(host);
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
        tunnel: d.loopback,
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
        // PVE 9 checks a mapping against the device as it finds it at start,
        // the subsystem among it: a mapping without one refuses a device that
        // has one ("missing expected property 'subsystem-id'").
        final sub = (await onNode(
          "d=/sys/bus/pci/devices/'$device'; "
          "printf '%s:%s' \"\$(cut -c3- \$d/subsystem_vendor)\" \"\$(cut -c3- \$d/subsystem_device)\"",
        )).trim();
        map = 'node=$node,path=$device,id=$ids,subsystem-id=$sub,iommugroup=$group';
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
        // The guest as it is now, not as `setUpAll` saw it straight after
        // creating it — when PVE may still have held its create lock, and
        // offered no start.
        vm = await settle((g) => g.actions.contains(VirtPowerAction.start));
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
  final ready = await prepareReachableSshE2e(host);
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
        tunnel: d.loopback,
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
        // Recorded before the create, which may make the guest and fail
        // after — but not when the id turned out to be taken by another.
        created[kind] = vmid;
        final VirtCreated result;
        try {
          result = await pve.create(spec);
        } on VirtErr catch (e) {
          if (e.type == VirtErrType.exists) created.remove(kind);
          rethrow;
        }
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
  final ready = await prepareReachableSshE2e(host);
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
  }) {
    final d = ServerTcpDialer(
      spi: spi,
      ssh: () async => ServerTcpSsh.client(client),
    );
    return PveBackend(
      serverId: spi.id,
      config: PveConfig(addr: addr, pwd: pvePwd, certSha256: pin),
      tunnel: d.loopback,
      connect: d.startConnect,
      onClose: d.close,
      user: spi.ssh?.user,
      sshKeyId: spi.ssh?.keyId,
      sshPassword: spi.ssh?.pwd,
      taskPoll: const Duration(milliseconds: 500),
      taskTimeout: const Duration(minutes: 3),
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

      PveBackend totp() => backend(byKey(totpUser), totpKey, pvePwd: totpPwd);

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

// -----------------------------------------------------------------------------
// Storage and networks (phase 6)
// -----------------------------------------------------------------------------

/// Deterministic bytes of [size], in chunks, for an upload.
Stream<List<int>> _bytes(int size, {int chunk = 64 << 10}) async* {
  for (var at = 0; at < size; at += chunk) {
    final n = min(chunk, size - at);
    yield Uint8List.fromList(
      List<int>.generate(n, (i) => ((at + i) * 31 + (at + i) ~/ 7) & 0xff),
    );
  }
}

Future<String> _sha256(Stream<List<int>> data) async =>
    (await sha256.bind(data).first).toString();

/// Everything as [user], from a root login, through `su`: the account
/// outside the `libvirt` group that the sudo path is for.
class _AsUser implements ServerByteExec {
  _AsUser(this.inner, this.user);

  final SshExec inner;
  final String user;

  String _wrap(String command) =>
      "su -s /bin/sh $user -c '${command.replaceAll("'", r"'\''")}'";

  @override
  Future<ExecResult> run(
    String script, {
    String? entry,
    Map<String, String>? env,
    String? stdin,
    OnExecOutput? onStdout,
    OnExecOutput? onStderr,
    Future<void>? cancel,
  }) => inner.run(
    entry == null ? _wrap(script) : script,
    entry: entry == null ? null : _wrap(entry),
    env: env,
    stdin: stdin,
    onStdout: onStdout,
    onStderr: onStderr,
    cancel: cancel,
  );

  @override
  Future<ExecSession> start(String command) => inner.start(_wrap(command));
}

/// Pools that are not a directory on the libvirt host, each opt-in:
///
/// - `SBM_E2E_LIBVIRT_VG`: a volume group the test may make logical volumes
///   in (`sbxe2e-*`, all removed) — a pool of block devices: a pool made of
///   it, a VM from a cloud image with its disk and cloud-init seed on it
///   (with `SBM_E2E_LIBVIRT_CLOUD_IMAGE`), external snapshots refused there,
///   and a copy of a VM into it.
/// - `SBM_E2E_LIBVIRT_NFS`: an NFS export (`host:/path`) the host can mount,
///   for a `netfs` pool.
Future<void> _libvirtBlockPools() async {
  final host = e2eEnv('SBM_E2E_LIBVIRT_HOST');
  final vg = e2eEnv('SBM_E2E_LIBVIRT_VG');
  final nfs = e2eEnv('SBM_E2E_LIBVIRT_NFS');
  final imagePath = e2eEnv('SBM_E2E_LIBVIRT_CLOUD_IMAGE');
  if (host == null || (vg == null && nfs == null)) return;
  final ready = await prepareReachableSshE2e(host);
  final target = ready.target;
  if (target == null) return;

  group('block and network pools: libvirt over SSH', () {
    SSHClient? client;
    late LibvirtBackend virt;
    final run = DateTime.now().millisecondsSinceEpoch % 100000;
    final lvPool = 'sbxe2e-lv-$run';
    final nfsPool = 'sbxe2e-nfs-$run';
    final nfsDir = '/var/lib/libvirt/sbxe2e-nfs-$run';
    final made = <String>[];
    // What this run made, by exact name, and nothing else: teardown removes
    // these only. Each is claimed after checking it was not there before.
    final ownedLvs = <String>[];
    final ownedPools = <String>[];
    var ownsNfsDir = false;

    Future<String> sh(String command) async =>
        (await execSshE2e(client!, command, null)).stdout;
    Future<VirtStoragePool?> findPool(String name) async =>
        (await virt.storagePools()).where((p) => p.name == name).firstOrNull;
    Future<VirtGuest?> find(String name) async =>
        (await virt.load()).guests.where((g) => g.name == name).firstOrNull;
    Future<bool> lvExists(String name) async =>
        (await execSshE2e(client!, "lvs '$vg/$name' >/dev/null 2>&1", null)).exitCode == 0;
    /// [names] as this run's, refusing any that already exist.
    Future<void> claimLvs(List<String> names) async {
      for (final n in names) {
        expect(await lvExists(n), isFalse, reason: '$vg/$n exists already; not ours');
      }
      ownedLvs.addAll(names);
    }
    Future<VirtStoragePool?> lv() async {
      final p = await findPool(lvPool);
      if (p != null) {
        expect(ownedPools, contains(lvPool), reason: '$lvPool exists already; not ours');
        return p;
      }
      // Offered only where the daemon has the backend (`pool-capabilities`):
      // one started before LVM was installed has not.
      final types = (await virt.load()).capabilities.poolTypes;
      if (!types.contains('logical')) {
        markTestSkipped('the daemon has no logical backend: $types');
        return null;
      }
      await virt.manage(VirtPoolCreate(name: lvPool, type: 'logical', source: vg!));
      ownedPools.add(lvPool);
      return (await findPool(lvPool))!;
    }

    setUpAll(() async {
      await initRustLibForTest();
      final c = await connectSshE2e(target, ready.identities);
      client = c;
      virt = LibvirtBackend(serverId: 'e2e-libvirt-block', exec: () async => SshExec(c));
    });
    tearDownAll(() async {
      final c = client;
      if (c == null) return;
      Future<void> virsh(String args) =>
          execSshE2e(c, 'LC_ALL=C virsh --connect qemu:///system -q $args </dev/null', null);
      // The run's own domains, with the volumes they were made on (a failed
      // clone's source is in the directory pool).
      for (final n in made) {
        await virsh("destroy '$n'");
        await virsh("undefine '$n' --nvram --remove-all-storage");
      }
      for (final l in ownedLvs) {
        await execSshE2e(c, "lvs '$vg/$l' >/dev/null 2>&1 && lvremove -fy '$vg/$l'", null);
      }
      for (final p in ownedPools) {
        await virsh("pool-destroy '$p'");
        await virsh("pool-undefine '$p'");
      }
      if (ownsNfsDir) await execSshE2e(c, "rmdir '$nfsDir' 2>/dev/null", null);
      await virt.close();
      c.close();
    });

    test('a logical pool from a volume group: a raw volume made, its resize '
        'refused before the host is asked, deleted', () async {
      if (vg == null) return markTestSkipped('SBM_E2E_LIBVIRT_VG unset');
      final pool = await lv();
      if (pool == null) return;
      expect((await virt.load()).capabilities.poolTypes, contains('logical'));
      expect((pool.type, pool.active), ('logical', true));
      expect(virtPoolHoldsFiles(pool), isFalse);
      expect(virtVolumeFormats(pool), ['raw']);
      final vol = 'sbxe2e-v-$run';
      await claimLvs([vol]);
      await virt.manage(VirtVolumeCreate(pool, name: vol, gib: 1, format: 'raw'));
      final v = (await virt.volumes(pool)).singleWhere((v) => v.name == vol);
      expect(v.path, '/dev/$vg/$vol');
      expect(v.capacity, 1 << 30);
      // libvirt's logical backend has no resize ("storage pool does not
      // support changing of volume capacity"): not offered, and refused.
      expect(virtVolumeResizable(pool, VirtHostKind.libvirt), isFalse);
      final e = await _virtErr(virt.manage(VirtVolumeResize(pool, v, bytes: 2 << 30)));
      expect(e.type, VirtErrType.unsupported);
      expect(await sh("lvs --noheadings --units b -o lv_size '$vg/$vol'"), contains('${1 << 30}B'));
      await virt.manage(VirtVolumeDelete(pool, v));
      expect(await lvExists(vol), isFalse);
    });

    test('a VM from a cloud image on the logical pool: disk and seed are '
        'LVs; the seed edited and taken; external snapshots refused', () async {
      if (vg == null || imagePath == null) {
        return markTestSkipped('SBM_E2E_LIBVIRT_VG or SBM_E2E_LIBVIRT_CLOUD_IMAGE unset');
      }
      final pool = await lv();
      if (pool == null) return;
      VirtVolume? image;
      for (final p in await virt.storagePools()) {
        if (!p.active) continue;
        image ??= (await virt.volumes(p)).where((v) => v.path == imagePath).firstOrNull;
      }
      final login = await _guestLogin();
      final name = 'sbxe2e-lvci-$run';
      expect(await find(name), isNull, reason: '$name exists already; not ours');
      await claimLvs(['$name.img', '$name-cidata.iso']);
      made.add(name);
      final net = (await virt.networks()).firstWhere((n) => n.name == 'default');
      final created = await virt.create(VirtCreateSpec(
        kind: VirtGuestKind.qemu,
        name: name,
        cores: 1,
        memoryMiB: 1024,
        storage: pool,
        diskGiB: 4,
        image: image!,
        network: net,
        bus: 'virtio',
        uefi: true,
        cloudInit: VirtCloudInit(user: 'sbxe', password: login.password, sshKeys: login.publicKey, hostname: name),
        start: true,
      ));
      expect(created.startError, isNull);
      var g = (await find(name))!;
      final hw = await virt.hardware(g);
      final disk = hw.disks.singleWhere((d) => d.kind == VirtHwDiskKind.disk && !d.cloudInit);
      final seed = hw.disks.singleWhere((d) => d.cloudInit);
      expect(disk.source, '/dev/$vg/$name.img');
      expect(disk.format, 'raw');
      expect(seed.source, '/dev/$vg/$name-cidata.iso');
      expect(virtHwDiskGrowable(disk), isFalse);
      final xml = await sh("virsh --connect qemu:///system dumpxml '${g.id}'");
      expect(xml, contains("<disk type='block' device='disk'>"));
      expect(xml, contains("<disk type='block' device='cdrom'>"));

      Future<String> ip() async {
        final mac = (await virt.detail(g)).nics.first.mac!;
        final lease = RegExp('^\\s*(\\S+ \\S+)\\s+${RegExp.escape(mac)}\\s+ipv4\\s+([0-9.]+)/', multiLine: true);
        for (var i = 0; i < 80; i++) {
          final found = [for (final m in lease.allMatches(await sh('virsh --connect qemu:///system -q net-dhcp-leases default'))) (m[1]!, m[2]!)]
            ..sort((a, b) => a.$1.compareTo(b.$1));
          if (found.lastOrNull case (_, final ip)) return ip;
          await Future<void>.delayed(const Duration(seconds: 3));
        }
        fail('no DHCP lease for $mac');
      }

      var addr = await ip();
      final facts = await _guestFacts(client!, addr, 'sbxe', login.key, 'vda', login.password);
      expect((facts['host'], facts['disk']), (name, '${4 << 30}'));

      // The seed on a block device: read back, written anew (grown first
      // where the new one is bigger), taken at the next boot.
      final ci = await virt.cloudInit(g);
      expect((ci.user, ci.hostname, ci.foreign), ('sbxe', name, false));
      await virt.setCloudInit(
        g,
        ci,
        VirtCloudInitEdit(VirtCloudInit(
          user: 'sbxe',
          sshKeys: '${login.publicKey}\n${login.publicKey.replaceFirst('sbxe2e', 'sbxe2e-second-line-to-grow-the-seed')}',
          hostname: '$name-b',
          dns: const ['1.1.1.1'],
          searchDomains: const ['a.sbxe2e.test', 'b.sbxe2e.test'],
        )),
      );
      expect((await virt.cloudInit(g)).hostname, '$name-b');
      await _guestRun(client!, addr, 'sbxe', login.key, '(sleep 1; sudo -n reboot) >/dev/null 2>&1 &');
      await Future<void>.delayed(const Duration(seconds: 10));
      Map<String, String>? again;
      final deadline = DateTime.now().add(const Duration(minutes: 5));
      while (again?['host'] != '$name-b') {
        // Checked on every pass: a guest that answers with its old hostname
        // never throws, and would otherwise loop until the test's timeout.
        if (DateTime.now().isAfter(deadline)) {
          fail('the guest still answers as ${again?['host']}');
        }
        addr = await ip();
        try {
          again = await _guestFacts(client!, addr, 'sbxe', login.key, 'vda', login.password,
              within: const Duration(seconds: 20));
        } catch (_) {
          if (DateTime.now().isAfter(deadline)) rethrow;
        }
      }
      final resolv = await _guestRun(client!, addr, 'sbxe', login.key, 'cat /etc/resolv.conf; resolvectl domain 2>/dev/null');
      expect(resolv, allOf(contains('a.sbxe2e.test'), contains('b.sbxe2e.test')));

      // No overlay can go on a pool of block devices, and the disk is raw.
      final chain = await virt.snapshotChain(g);
      expect(chain.externalRefusal, isNotNull);
      final e = await _virtErr(virt.createSnapshot(g, name: 'sbxe2e-x', form: VirtSnapshotForm.external));
      expect(e.type, VirtErrType.unsupported, reason: e.message);
      expect(await virt.snapshots(g), isEmpty);

      await virt.power(g, VirtPowerAction.forceStop);
      g = (await find(name))!;
      await virt.delete(g);
      made.remove(name);
      expect(await sh("lvs --noheadings -o lv_name '$vg' | grep -c '$name' || true"), startsWith('0'));
    }, timeout: const Timeout(Duration(minutes: 15)));

    test('a VM copied into the logical pool: a raw LV, a block disk',
        () async {
      if (vg == null) return markTestSkipped('SBM_E2E_LIBVIRT_VG unset');
      final pool = await lv();
      if (pool == null) return;
      final source = virtDiskStorages(
        await virt.storagePools(),
        host: VirtHostKind.libvirt,
        kind: VirtGuestKind.qemu,
      ).firstWhere((p) => virtPoolHoldsFiles(p));
      final name = 'sbxe2e-cp-$run';
      for (final n in [name, '$name-lv']) {
        expect(await find(n), isNull, reason: '$n exists already; not ours');
      }
      await claimLvs(['$name-lv.img']);
      made.addAll([name, '$name-lv']);
      await virt.create(VirtCreateSpec(
        kind: VirtGuestKind.qemu,
        name: name,
        cores: 1,
        memoryMiB: 128,
        storage: source,
        diskGiB: 1,
      ));
      final src = (await find(name))!;
      final id = await virt.clone(src, VirtCloneRequest(name: '$name-lv', targetPool: pool.name));
      final copy = (await virt.load()).guests.firstWhere((g) => g.id == id);
      final disk = (await virt.detail(copy)).disks.firstWhere((d) => d.device == 'disk');
      // Raw on the LV, as libvirt converts it there, and said so: a block
      // disk with a raw driver (a qcow2 driver over raw data reads garbage).
      expect(disk.source, '/dev/$vg/$name-lv.img');
      expect(disk.format, 'raw');
      expect(await sh("qemu-img info --output=json '${disk.source}'"), contains('"format": "raw"'));
      expect(await sh("virsh --connect qemu:///system dumpxml --inactive '${copy.id}'"), contains("<disk type='block' device='disk'>"));
      for (final g in [copy, src]) {
        await virt.delete((await virt.load()).guests.firstWhere((x) => x.id == g.id));
        made.remove(g.name);
      }
      expect(await sh("lvs --noheadings -o lv_name '$vg' | grep -c '$name' || true"), startsWith('0'));
      // The pool is the run's own; deleting it leaves the group.
      await virt.manage(VirtPoolDelete((await findPool(lvPool))!));
      ownedPools.remove(lvPool);
      expect(await findPool(lvPool), isNull);
      expect(await sh("vgs --noheadings -o vg_name '$vg'"), contains(vg));
    });

    test('a netfs pool: mounted, a volume made in the export, unmounted when '
        'stopped, deleted', () async {
      if (nfs == null) return markTestSkipped('SBM_E2E_LIBVIRT_NFS unset');
      final change = VirtPoolCreate(name: nfsPool, type: 'netfs', source: nfs, target: nfsDir);
      expect(
        virtResourceIssue(change, host: VirtHostKind.libvirt, pools: await virt.storagePools()),
        isNull,
      );
      expect(await findPool(nfsPool), isNull, reason: '$nfsPool exists already; not ours');
      // `mkdir` without `-p`: an existing directory is someone else's.
      final mk = await execSshE2e(client!, "mkdir '$nfsDir'", null);
      expect(mk.exitCode, 0, reason: 'could not make $nfsDir: ${mk.stderr}');
      ownsNfsDir = true;
      await virt.manage(change);
      ownedPools.add(nfsPool);
      var pool = (await findPool(nfsPool))!;
      expect((pool.type, pool.active, virtPoolHoldsFiles(pool)), ('netfs', true, true));
      expect(await sh("findmnt -n -o SOURCE '$nfsDir'"), contains(nfs));
      final vol = 'sbxe2e-n-$run.qcow2';
      await virt.manage(VirtVolumeCreate(pool, name: vol, gib: 1, format: 'qcow2'));
      final v = (await virt.volumes(pool)).singleWhere((v) => v.name == vol);
      expect(v.format, 'qcow2');
      // The export as this host sees it: mounted at the pool's target. Its
      // path is one on the NFS server, not here.
      expect(await sh("ls -A '$nfsDir'"), contains(vol));
      await virt.manage(VirtVolumeDelete(pool, v));
      expect(await sh("ls -A '$nfsDir'"), isNot(contains(vol)));
      await virt.manage(VirtPoolSetActive(pool, active: false));
      pool = (await findPool(nfsPool))!;
      expect(pool.active, isFalse);
      expect(await sh("findmnt -n '$nfsDir' || true"), isEmpty);
      await virt.manage(VirtPoolDelete(pool));
      ownedPools.remove(nfsPool);
      expect(await findPool(nfsPool), isNull);
    });
  });
}

/// Pools, volumes, uploads and networks of the test's own on the libvirt
/// host (`sbxe2e-*`, a pool in a fresh `/var/lib/libvirt/sbxe2e-*`), over
/// the backend the app uses on SSH; with `SBM_E2E_LIBVIRT_SUDO_USER` and
/// `SBM_E2E_LIBVIRT_SUDO_PASSWORD` also as that account, through sudo.
/// Nothing that exists already is touched; everything is removed again.
Future<void> _libvirtManage() async {
  final host = e2eEnv('SBM_E2E_LIBVIRT_HOST');
  if (host == null) return;
  final ready = await prepareReachableSshE2e(host);
  final target = ready.target;
  if (target == null) return;
  final sudoUser = e2eEnv('SBM_E2E_LIBVIRT_SUDO_USER');
  final sudoPassword = e2eEnv('SBM_E2E_LIBVIRT_SUDO_PASSWORD');

  group('storage and networks: libvirt over SSH', () {
    SSHClient? client;
    late LibvirtBackend virt;
    final stamp = DateTime.now().millisecondsSinceEpoch % 100000;
    final poolName = 'sbxe2e-pool-$stamp';
    final poolDir = '/var/lib/libvirt/sbxe2e-$stamp';
    final net = 'sbxe2e-net-$stamp';
    final vm = 'sbxe2e-vm-$stamp';
    const iso = 'sbxe2e-upload.iso';

    Future<String> sh(String command) async =>
        (await execSshE2e(client!, command, null)).stdout;
    Future<VirtStoragePool?> findPool() async => (await virt.storagePools())
        .where((p) => p.name == poolName)
        .firstOrNull;
    Future<VirtStoragePool> pool() async =>
        (await findPool()) ?? fail('no pool $poolName');
    Future<List<VirtVolume>> vols() async => virt.volumes(await pool());
    Future<VirtNetwork?> findNet(String name) async =>
        (await virt.networks()).where((n) => n.name == name).firstOrNull;
    final nets = [net, '$net-iso', '$net-br', '$net-bad', '$net-ed'];
    // Set once setup has seen that none of the names below exist: before
    // that, whatever answers to them is someone else's, and teardown leaves
    // the host alone.
    var clean = false;

    setUpAll(() async {
      await initRustLibForTest();
      final c = await connectSshE2e(target, ready.identities);
      client = c;
      virt = LibvirtBackend(
        serverId: 'e2e-libvirt-manage',
        exec: () async => SshExec(c),
        byteExec: () async => SshExec(c),
        canStream: () => true,
      );
      // A fresh directory, names nothing on the host has, and addresses
      // nothing on the host routes.
      expect(await sh("test -e '$poolDir' && echo taken"), isEmpty);
      expect(await findPool(), isNull, reason: '$poolName exists already');
      final taken = (await virt.networks()).map((n) => n.name).toSet();
      expect(taken.intersection(nets.toSet()), isEmpty);
      expect(
        (await virt.load()).guests.where((g) => g.name == vm),
        isEmpty,
        reason: '$vm exists already',
      );
      final routes = await sh('ip -4 route');
      expect(routes, isNot(contains('10.231.78.')));
      expect(routes, isNot(contains('10.231.79.')));
      clean = true;
    });

    tearDownAll(() async {
      final c = client;
      if (c == null) return;
      if (!clean) {
        await virt.close();
        c.close();
        return;
      }
      Future<void> virsh(String args) => execSshE2e(
        c,
        'LC_ALL=C virsh --connect qemu:///system -q $args </dev/null',
        null,
      );
      // Only what this group made, by name: never storage deleted by a
      // domain's definition.
      await virsh("destroy '$vm'");
      await virsh("undefine '$vm' --nvram");
      final left = await sh(
        "virsh --connect qemu:///system -q vol-list --pool '$poolName' 2>/dev/null | awk '{print \$1}'",
      );
      for (final v in left.split('\n').where((l) => l.startsWith('sbxe2e'))) {
        await virsh("vol-delete --pool '$poolName' --vol '$v'");
      }
      await virsh("pool-destroy '$poolName'");
      await virsh("pool-undefine '$poolName'");
      await sh("rmdir '$poolDir' 2>/dev/null; true");
      for (final n in nets) {
        await virsh("net-destroy '$n'");
        await virsh("net-undefine '$n'");
      }
      await virt.close();
      c.close();
    });

    test('a dir pool: made, stopped, started, autostart off, refreshed', () async {
      final snap = await virt.load();
      expect(snap.capabilities.storageEdit, isTrue);
      expect(snap.capabilities.upload, isTrue);
      await virt.manage(
        VirtPoolCreate(name: poolName, type: 'dir', source: poolDir),
      );
      var p = await pool();
      expect(p.active, isTrue);
      expect(p.autostart, isTrue);
      expect(p.path, poolDir);
      expect(await sh("stat -c %U '$poolDir'"), contains('root'));

      final taken = await _virtErr(
        virt.manage(VirtPoolCreate(name: poolName, type: 'dir', source: poolDir)),
      );
      expect(taken.type, VirtErrType.exists);

      await virt.manage(VirtPoolSetActive(p, active: false));
      p = await pool();
      expect(p.active, isFalse);
      await virt.manage(VirtPoolSetActive(p, active: true));
      await virt.manage(VirtPoolSetAutostart(await pool(), on: false));
      p = await pool();
      expect(p.active, isTrue);
      expect(p.autostart, isFalse);
      // A file put there by other means appears after a refresh.
      await sh("head -c 1024 /dev/zero > '$poolDir/sbxe2e-byhand.img'");
      await virt.manage(VirtPoolRefresh(p));
      expect((await vols()).map((v) => v.name), contains('sbxe2e-byhand.img'));
      await virt.manage(
        VirtVolumeDelete(p, (await vols()).firstWhere((v) => v.name == 'sbxe2e-byhand.img')),
      );
    });

    test('volumes: made, grown, copied, deleted; a name taken is exists', () async {
      final p = await pool();
      await virt.manage(
        VirtVolumeCreate(p, name: 'sbxe2e-a.qcow2', gib: 1, format: 'qcow2'),
      );
      var v = (await vols()).firstWhere((v) => v.name == 'sbxe2e-a.qcow2');
      expect(v.format, 'qcow2');
      expect(v.capacity, 1 << 30);
      final taken = await _virtErr(
        virt.manage(
          VirtVolumeCreate(p, name: 'sbxe2e-a.qcow2', gib: 1, format: 'qcow2'),
        ),
      );
      expect(taken.type, VirtErrType.exists);

      await virt.manage(VirtVolumeResize(p, v, bytes: 2 << 30));
      v = (await vols()).firstWhere((v) => v.name == 'sbxe2e-a.qcow2');
      expect(v.capacity, 2 << 30);

      await virt.manage(VirtVolumeClone(p, v, name: 'sbxe2e-a-clone.qcow2'));
      final clone = (await vols()).firstWhere(
        (v) => v.name == 'sbxe2e-a-clone.qcow2',
      );
      expect(clone.capacity, 2 << 30);
      await virt.manage(VirtVolumeDelete(p, clone));
      expect(
        (await vols()).where((v) => v.name == 'sbxe2e-a-clone.qcow2'),
        isEmpty,
      );
    });

    test('upload: an ISO streamed in whole; a cancelled one leaves nothing', () async {
      final p = await pool();
      const size = 3 << 20;
      final sent = <int>[];
      final done = await virt.upload(
        VirtUpload(pool: p, name: iso, size: size, open: () => _bytes(size)),
        onProgress: sent.add,
      );
      expect(done, isTrue);
      expect(sent.last, size);
      final v = (await vols()).firstWhere((v) => v.name == iso);
      expect(v.capacity, size);
      expect(
        (await sh("sha256sum '$poolDir/$iso'")).split(' ').first,
        await _sha256(_bytes(size)),
      );

      // Stopped a few MiB in: the volume it went into is gone again.
      final cancel = Completer<void>();
      const big = 256 << 20;
      final cancelled = await virt.upload(
        VirtUpload(
          pool: p,
          name: 'sbxe2e-cancel.iso',
          size: big,
          open: () => _bytes(big),
        ),
        cancel: cancel.future,
        onProgress: (n) {
          if (n > 8 << 20 && !cancel.isCompleted) cancel.complete();
        },
      );
      expect(cancelled, isFalse);
      expect((await vols()).where((v) => v.name == 'sbxe2e-cancel.iso'), isEmpty);
      expect(await sh("ls '$poolDir'"), isNot(contains('sbxe2e-cancel')));

      // A name taken is refused before anything is sent.
      final taken = await _virtErr(
        virt.upload(
          VirtUpload(pool: p, name: iso, size: 10, open: () => _bytes(10)),
        ),
      );
      expect(taken.type, VirtErrType.exists);
      expect(await sh("sha256sum '$poolDir/$iso'"), contains(await _sha256(_bytes(size))));
    });

    test('a volume attached to a VM as a disk, the ISO put in its CD-ROM', () async {
      final p = await pool();
      final media = (await vols()).firstWhere((v) => v.name == iso);
      final spec = VirtCreateSpec(
        kind: VirtGuestKind.qemu,
        name: vm,
        cores: 1,
        memoryMiB: 256,
        storage: p,
        diskGiB: 1,
        media: media,
      );
      final created = await virt.create(spec);
      final g = (await virt.load()).guests.firstWhere((g) => g.id == created.id);
      final disk = (await vols()).firstWhere((v) => v.name == 'sbxe2e-a.qcow2');
      expect(disk.users, isEmpty);

      var hw = await virt.hardware(g);
      await virt.changeHardware(
        g,
        hw,
        VirtHwAttachVolume(storage: p, volume: disk),
      );
      hw = await virt.hardware(g);
      final attached = hw.disks.firstWhere((d) => d.source == disk.path);
      expect(attached.kind, VirtHwDiskKind.disk);
      expect(attached.format, 'qcow2');
      // Now used: the pool says by whom, and deleting it is refused before
      // the host is asked.
      await virt.storagePools();
      final used = (await vols()).firstWhere((v) => v.name == 'sbxe2e-a.qcow2');
      expect(used.users.single.guestId, g.id);
      expect(
        virtResourceIssue(VirtVolumeDelete(p, used), host: VirtHostKind.libvirt),
        VirtResIssue.inUse,
      );

      // The CD-ROM: ejected, and the uploaded ISO put back.
      final cd = hw.disks.firstWhere((d) => d.kind == VirtHwDiskKind.cdrom);
      await virt.changeHardware(g, hw, VirtHwSetMedia(key: cd.key));
      hw = await virt.hardware(g);
      expect(hw.disk(cd.key)?.source, isNull);
      await virt.changeHardware(g, hw, VirtHwSetMedia(key: cd.key, media: media));
      hw = await virt.hardware(g);
      expect(hw.disk(cd.key)?.source, media.path);

      // Detached, kept; then the VM deleted with its own disk only.
      await virt.changeHardware(
        g,
        hw,
        VirtHwRemoveDisk(key: attached.key, deleteVolume: false),
      );
      await virt.delete(g);
      final left = (await vols()).map((v) => v.name).toList();
      expect(left, containsAll(['sbxe2e-a.qcow2', iso]));
      expect(left, isNot(contains('$vm.qcow2')));
    });

    if (sudoUser != null && sudoPassword != null) {
      test('upload through sudo, as $sudoUser outside the libvirt group', () async {
        final c = client!;
        final asUser = LibvirtBackend(
          serverId: 'e2e-libvirt-sudo',
          exec: () async => _AsUser(SshExec(c), sudoUser),
          byteExec: () async => _AsUser(SshExec(c), sudoUser),
          canStream: () => true,
        );
        try {
          final refused = await _virtErr(asUser.storagePools());
          expect(refused.type, VirtErrType.sudoPasswordRequired);
          asUser.provideSudoPassword(sudoPassword);
          final p = (await asUser.storagePools()).firstWhere(
            (p) => p.name == poolName,
          );
          const size = 1 << 20;
          final done = await asUser.upload(
            VirtUpload(
              pool: p,
              name: 'sbxe2e-sudo.iso',
              size: size,
              open: () => _bytes(size),
            ),
          );
          expect(done, isTrue);
          // The bytes, and not the password, are what the volume holds.
          expect(
            (await sh("sha256sum '$poolDir/sbxe2e-sudo.iso'")).split(' ').first,
            await _sha256(_bytes(size)),
          );
          final v = (await asUser.volumes(p)).firstWhere(
            (v) => v.name == 'sbxe2e-sudo.iso',
          );
          await asUser.manage(VirtVolumeDelete(p, v));

          // A wrong password is refused, and nothing is left behind.
          final wrong = LibvirtBackend(
            serverId: 'e2e-libvirt-sudo-wrong',
            exec: () async => _AsUser(SshExec(c), sudoUser),
            byteExec: () async => _AsUser(SshExec(c), sudoUser),
            canStream: () => true,
          )..provideSudoPassword('${sudoPassword}x');
          final rejected = await _virtErr(
            wrong.upload(
              VirtUpload(
                pool: p,
                name: 'sbxe2e-wrong.iso',
                size: 10,
                open: () => _bytes(10),
              ),
            ),
          );
          expect(rejected.type, VirtErrType.sudoPasswordRejected);
          expect(await sh("ls '$poolDir'"), isNot(contains('sbxe2e-wrong')));
        } finally {
          await asUser.close();
        }
      });
    }

    test('a volume removed behind libvirt\'s back: the pool refreshed, and '
        'its count and its volumes agree', () async {
      await virt.manage(VirtVolumeCreate(await pool(), name: 'sbxe2e-gone.qcow2', gib: 1, format: 'qcow2'));
      await sh("rm '$poolDir/sbxe2e-gone.qcow2'");
      // libvirt still lists it from its cache.
      expect(await sh("virsh --connect qemu:///system -q vol-list '$poolName'"), contains('sbxe2e-gone.qcow2'));
      final listed = (await pool()).volumeCount!;
      final read = await vols();
      expect(read.map((v) => v.name), isNot(contains('sbxe2e-gone.qcow2')));
      expect(await sh("virsh --connect qemu:///system -q vol-list '$poolName'"), isNot(contains('sbxe2e-gone.qcow2')));
      expect((await pool()).volumeCount, read.length);
      expect(read.length, listed - 1);
    });

    test('the pool deleted with its directory', () async {
      final p = await pool();
      for (final v in await vols()) {
        await virt.manage(VirtVolumeDelete(p, v));
      }
      await virt.manage(VirtPoolDelete(await pool(), deleteStorage: true));
      expect(await findPool(), isNull);
      expect(await sh("test -e '$poolDir' || echo gone"), contains('gone'));
    });

    test('a network edited: a host live, the address with a restart, and every refusal undone', () async {
      final name = '$net-ed';
      await virt.manage(
        VirtNetworkCreate(
          name: name,
          mode: 'nat',
          cidr: '10.231.79.1/24',
          dhcpStart: '10.231.79.100',
          dhcpEnd: '10.231.79.200',
        ),
      );
      // Something the form does not edit, written by hand: it must survive
      // every edit below.
      await sh(
        "f=\$(mktemp); virsh --connect qemu:///system -q net-dumpxml --inactive '$name' | "
        "sed \"s|<range start='10.231.79.100' end='10.231.79.200'/>|&<range start='10.231.79.210' end='10.231.79.220'/>|\" > \$f && "
        r'virsh --connect qemu:///system -q net-define $f >/dev/null; rm -f $f',
      );
      var n = (await findNet(name))!;
      expect(n.xml, contains("start='10.231.79.210'"));

      // A static host: live, no restart.
      await virt.manage(
        VirtNetworkEdit(
          n,
          mode: 'nat',
          address: '10.231.79.1',
          prefix: 24,
          dhcpStart: '10.231.79.100',
          dhcpEnd: '10.231.79.200',
          hosts: const [VirtNetHost(mac: '52:54:00:aa:bb:e1', ip: '10.231.79.50', name: 'sbxe2e-h1')],
        ),
      );
      n = (await findNet(name))!;
      expect(n.hosts.single.ip, '10.231.79.50');
      expect(n.pendingRestart, isFalse);
      expect(await sh("virsh --connect qemu:///system -q net-dumpxml '$name'"), contains('sbxe2e-h1'));

      // The first range moved, with a restart: the running network takes it
      // and the second range is still there.
      await virt.manage(
        VirtNetworkEdit(
          n,
          mode: 'nat',
          address: '10.231.79.1',
          prefix: 24,
          dhcpStart: '10.231.79.110',
          dhcpEnd: '10.231.79.190',
          hosts: n.hosts,
          restart: true,
        ),
      );
      n = (await findNet(name))!;
      expect(n.pendingRestart, isFalse);
      final live = await sh("virsh --connect qemu:///system -q net-dumpxml '$name'");
      expect(live, contains("start='10.231.79.110'"));
      expect(live, contains("start='10.231.79.210'"));
      expect(live, contains('sbxe2e-h1'));

      // An address the host's own LAN is on. First with the hand-written
      // second range still there, which is outside the new subnet: the new
      // definition is refused while the network still runs, so nothing is
      // stopped and nothing changes.
      final lan = (await sh("ip -4 -o addr show scope global | awk '{print \$4}' | head -1")).trim();
      final lanNet = lan.split('/').first.split('.').take(3).join('.');
      VirtNetworkEdit toLan(VirtNetwork n) => VirtNetworkEdit(
        n,
        mode: 'nat',
        address: '$lanNet.1',
        prefix: 24,
        dhcpStart: '$lanNet.230',
        dhcpEnd: '$lanNet.240',
        restart: true,
      );
      final undefined = await _virtErr(virt.manage(toLan(n)));
      expect(undefined.message, contains('not entirely within'));
      n = (await findNet(name))!;
      expect((n.active, n.address, n.pendingRestart), (true, '10.231.79.1', false));

      // Without it: the definition is written, the start refused (the LAN
      // is in use), and the network started again as it ran, the old
      // definition back.
      await sh(
        "f=\$(mktemp); virsh --connect qemu:///system -q net-dumpxml --inactive '$name' | "
        "sed \"s|<range start='10.231.79.210' end='10.231.79.220'/>||\" > \$f && "
        r'virsh --connect qemu:///system -q net-define $f >/dev/null; rm -f $f',
      );
      n = (await findNet(name))!;
      final refused = await _virtErr(virt.manage(toLan(n)));
      expect(refused.message, contains('started again as it ran before'));
      n = (await findNet(name))!;
      expect(n.active, isTrue, reason: 'never left down');
      expect(n.address, '10.231.79.1');
      expect(await sh('ip -4 -br addr'), contains('10.231.79.1/24'));

      // To a host bridge (libvirt 11.3 starts a bridge-mode network whether
      // the bridge exists or not): the addressing, the <mac> and the ranges
      // go with the mode, which libvirt refuses there. Then back to NAT.
      await virt.manage(VirtNetworkEdit(n, mode: 'bridge', bridge: 'sbxnobr0', restart: true));
      n = (await findNet(name))!;
      expect((n.active, n.mode, n.bridge, n.pendingRestart), (true, 'bridge', 'sbxnobr0', false));
      expect(n.xml, isNot(contains('<ip')));
      expect(n.xml, isNot(contains('<mac')));
      await virt.manage(
        VirtNetworkEdit(
          n,
          mode: 'nat',
          address: '10.231.79.1',
          prefix: 24,
          dhcpStart: '10.231.79.100',
          dhcpEnd: '10.231.79.200',
          restart: true,
        ),
      );
      n = (await findNet(name))!;
      expect((n.active, n.mode, n.address), (true, 'nat', '10.231.79.1'));
      expect(await sh('ip -4 -br addr'), contains('10.231.79.1/24'));

      // A restart of its own onto a definition that cannot start: written
      // by hand, then restarted from the app — back as it ran.
      await sh(
        "f=\$(mktemp); virsh --connect qemu:///system -q net-dumpxml --inactive '$name' | "
        "sed 's/10.231.79/$lanNet/g' > \$f && virsh --connect qemu:///system -q net-define \$f >/dev/null; rm -f \$f",
      );
      n = (await findNet(name))!;
      expect(n.pendingRestart, isTrue);
      final restart = await _virtErr(virt.manage(VirtNetworkRestart(n)));
      expect(restart.message, contains('started again as it ran before'));
      n = (await findNet(name))!;
      expect(n.active, isTrue);
      expect(await sh('ip -4 -br addr'), contains('10.231.79.1/24'));

      await virt.manage(VirtNetworkSetActive(n, active: false));
      await virt.manage(VirtNetworkDelete((await findNet(name))!));
      expect(await findNet(name), isNull);
    });

    test('networks: NAT with DHCP, isolated, a host bridge; an address in use is rolled back', () async {
      await virt.manage(
        VirtNetworkCreate(
          name: net,
          mode: 'nat',
          cidr: '10.231.78.1/24',
          dhcpStart: '10.231.78.100',
          dhcpEnd: '10.231.78.200',
        ),
      );
      var n = (await findNet(net))!;
      expect(n.mode, 'nat');
      expect(n.active, isTrue);
      expect(n.autostart, isTrue);
      expect(n.cidrs, ['10.231.78.1/24']);
      expect(n.dhcpRanges, ['10.231.78.100-10.231.78.200']);
      expect(n.bridge, startsWith('virbr'));
      expect(await sh('ip -4 -br addr'), contains('10.231.78.1/24'));

      await virt.manage(VirtNetworkSetAutostart(n, on: false));
      await virt.manage(VirtNetworkSetActive((await findNet(net))!, active: false));
      n = (await findNet(net))!;
      expect(n.active, isFalse);
      expect(n.autostart, isFalse);
      expect(await sh('ip -4 -br addr'), isNot(contains('10.231.78.1/24')));
      await virt.manage(VirtNetworkSetActive(n, active: true));
      expect((await findNet(net))!.active, isTrue);

      await virt.manage(
        VirtNetworkCreate(name: '$net-iso', mode: 'isolated', cidr: '10.231.79.1/24'),
      );
      expect((await findNet('$net-iso'))!.mode, 'isolated');
      await virt.manage(
        VirtNetworkCreate(name: '$net-br', mode: 'bridge', bridge: 'sbxe2ebr0'),
      );
      final br = (await findNet('$net-br'))!;
      expect(br.mode, 'bridge');
      expect(br.bridge, 'sbxe2ebr0');

      // The first network's subnet: refused before the host is asked.
      final taken = await _virtErr(
        virt.manage(
          VirtNetworkCreate(name: '$net-bad', mode: 'nat', cidr: '10.231.78.1/24'),
        ),
      );
      expect(taken.type, VirtErrType.unsupported);
      expect(taken.message, l10n.virtResSubnetTaken);
      // The host's own subnet, which no libvirt network lists: refused by the
      // host at the start, and not left defined.
      final lan = (await sh(
        "ip -4 -o addr show scope global | awk '{print \$4}' | head -n1",
      )).trim();
      final hostAddr = lan.split('/').first.split('.');
      final inUse = '${hostAddr.take(3).join('.')}.${hostAddr.last == '250' ? '251' : '250'}/${lan.split('/').last}';
      final used = await _virtErr(
        virt.manage(VirtNetworkCreate(name: '$net-bad', mode: 'nat', cidr: inUse)),
      );
      expect(used.type, VirtErrType.actionFailed, reason: inUse);
      expect(await findNet('$net-bad'), isNull);
      // The form refuses it before the host is asked.
      expect(
        virtResourceIssue(
          VirtNetworkCreate(name: 'x', mode: 'nat', cidr: '10.231.78.9/24'),
          host: VirtHostKind.libvirt,
          networks: await virt.networks(),
        ),
        VirtResIssue.subnetTaken,
      );

      for (final name in [net, '$net-iso', '$net-br']) {
        await virt.manage(VirtNetworkDelete((await findNet(name))!));
        expect(await findNet(name), isNull);
      }
      expect(await sh('ip -4 -br addr'), isNot(contains('10.231.78.1/24')));
    });
  });
}

/// A storage, volumes, an upload and a Linux bridge of the test's own on the
/// PVE node (`sbxe2e*`, a directory storage in a fresh `/var/lib/sbxe2e-*`),
/// through the token over SSH, as the app makes them. The bridge has no
/// ports, and SSH is checked after every apply. Refuses to start while the
/// node has network changes pending — reverting would drop someone else's.
/// The privilege test puts `NoAccess` on `/storage` for the token and takes
/// it away again.
Future<void> _pveManage() async {
  final host = e2eEnv('SBM_E2E_PVE_HOST');
  final tokenId = e2eEnv('SBM_E2E_PVE_TOKEN_ID');
  final tokenSecret = e2eEnv('SBM_E2E_PVE_TOKEN_SECRET');
  if (host == null || tokenId == null || tokenSecret == null) return;
  final ready = await prepareReachableSshE2e(host);
  final target = ready.target;
  if (target == null) return;

  group('storage and networks: PVE over SSH', () {
    SSHClient? client;
    late PveBackend pve;
    late String node;
    final stamp = DateTime.now().millisecondsSinceEpoch % 100000;
    final store = 'sbxe2e-dir-$stamp';
    final dir = '/var/lib/sbxe2e-$stamp';
    final bridge = 'sbxe2e$stamp';
    int? vmid;
    var noAccess = false;
    // Set by setup once it has seen the storage, its directory and the bridge
    // absent and nothing pending on the node's network: before that, teardown
    // touches none of it — a refused preflight must not discard what it
    // refused over.
    var clean = false;
    var ownsStore = false;
    // Whether a test of this group got as far as staging network changes;
    // the node's pending configuration is only reverted then.
    var stagedNetwork = false;

    Future<String> sh(String command) async =>
        (await execSshE2e(client!, command, null)).stdout;
    Future<VirtStoragePool?> findStore() async => (await pve.storagePools())
        .where((p) => p.name == store && p.node == node)
        .firstOrNull;
    Future<VirtStoragePool> storage() async =>
        (await findStore()) ?? fail('no storage $store');
    Future<List<VirtVolume>> vols() async => pve.volumes(await storage());
    Future<VirtNetwork?> findBridge() async => (await pve.networks())
        .where((n) => n.name == bridge && n.node == node)
        .firstOrNull;
    Future<void> apply() async {
      await pve.manage(VirtNetworkApply(node));
      // The node is still there after its network reloaded.
      expect(await sh('echo ssh-ok'), contains('ssh-ok'));
      expect(await pve.networkChanges(), isEmpty);
    }

    setUpAll(() async {
      await initRustLibForTest();
      final c = await connectSshE2e(target, ready.identities);
      client = c;
      final d = _pvePaths(target, () => c, '')['over SSH']!.dialer();
      pve = PveBackend(
        serverId: 'e2e-pve-manage',
        config: PveConfig(
          addr: 'https://localhost:8006',
          auth: PveAuth.token,
          tokenId: tokenId,
          tokenSecret: tokenSecret,
        ),
        tunnel: d.loopback,
        connect: d.startConnect,
        // What the node says of its own interfaces, over the same SSH.
        exec: () async => SshExec(c),
        onClose: d.close,
        taskPoll: const Duration(milliseconds: 500),
        taskTimeout: const Duration(minutes: 3),
      );
      final e = await _virtErr(pve.load());
      expect(e.type, VirtErrType.certUnconfirmed);
      await pve.confirmCert(e.cert!.fingerprint);
      final snap = await pve.load();
      node = snap.host.nodes.first.name;
      expect(await sh("test -e '$dir' && echo taken"), isEmpty);
      expect(await findStore(), isNull, reason: '$store exists already');
      expect(await findBridge(), isNull, reason: '$bridge exists already');
      expect(
        await sh('ls /etc/network/interfaces.new 2>/dev/null'),
        isEmpty,
        reason: 'network changes are pending on the node already',
      );
      clean = true;
    });

    tearDownAll(() async {
      final c = client;
      if (c == null) return;
      if (noAccess) {
        await sh("pveum acl delete /storage --tokens '$tokenId' --roles NoAccess");
      }
      if (vmid != null) {
        // A disk on this group's storage, which may be gone already, keeps
        // `qm destroy` from running: taken off first.
        await sh(
          "for k in \$(qm config $vmid 2>/dev/null | grep '$store' | cut -d: -f1); do qm set $vmid --delete \$k; done; qm destroy $vmid --purge 2>/dev/null",
        );
      }
      if (clean && stagedNetwork) {
        // The bridge: out of the pending configuration, and out of the
        // running one if it got there. The pending file was empty when setup
        // looked, so what is pending now is this group's.
        if ((await sh('ls /etc/network/interfaces.new 2>/dev/null')).isNotEmpty) {
          await sh('pvesh delete /nodes/$node/network');
        }
        if ((await sh("grep -c 'iface $bridge ' /etc/network/interfaces")).trim() != '0') {
          await sh(
            'pvesh delete /nodes/$node/network/$bridge && pvesh set /nodes/$node/network',
          );
        }
      }
      if (ownsStore) {
        await sh(
          "for v in \$(pvesm list '$store' 2>/dev/null | awk 'NR>1{print \$1}'); do pvesm free \"\$v\"; done",
        );
        await sh("pvesm remove '$store' 2>/dev/null");
      }
      // Absent when setup looked, so whatever is there now this group made
      // (the storage creates it, and outlives its removal).
      if (clean) await sh("rm -rf -- '$dir'");
      await pve.close();
      c.close();
    });

    test('a dir storage: added, disabled, enabled', () async {
      final caps = (await pve.load()).capabilities;
      expect(caps.storageEdit, isTrue);
      expect(caps.networkApply, isTrue);
      await pve.manage(
        VirtPoolCreate(
          name: store,
          type: 'dir',
          source: dir,
          node: node,
          content: const ['images', 'iso'],
        ),
      );
      ownsStore = true;
      var s = await storage();
      expect(s.active, isTrue);
      expect(s.path, dir);
      expect(s.content, containsAll(['images', 'iso']));
      final taken = await _virtErr(
        pve.manage(VirtPoolCreate(name: store, type: 'dir', source: dir, node: node)),
      );
      expect(taken.type, VirtErrType.exists);

      await pve.manage(VirtPoolSetActive(s, active: false));
      s = await storage();
      expect(s.active, isFalse);
      expect(s.enabled, isFalse);
      await pve.manage(VirtPoolSetActive(s, active: true));
      expect((await storage()).active, isTrue);
    });

    test('volumes: allocated for a VMID, uploaded, deleted; a cancelled upload leaves nothing', () async {
      final s = await storage();
      final next = (await pve.nextVmid())!;
      final name = 'vm-$next-disk-0';
      await pve.manage(VirtVolumeCreate(s, name: name, gib: 1, format: 'qcow2'));
      final v = (await vols()).firstWhere((v) => v.name == '$name.qcow2');
      expect(v.capacity, 1 << 30);
      expect(v.format, 'qcow2');
      // Its VMID has no guest: not in use.
      expect(v.users, isEmpty);

      const size = 3 << 20;
      final sent = <int>[];
      expect(
        await pve.upload(
          VirtUpload(
            pool: s,
            name: 'sbxe2e-upload.iso',
            size: size,
            open: () => _bytes(size),
          ),
          onProgress: sent.add,
        ),
        isTrue,
      );
      expect(sent.last, greaterThanOrEqualTo(size));
      final iso = (await vols()).firstWhere((v) => v.name == 'sbxe2e-upload.iso');
      expect(iso.content, 'iso');
      expect(
        (await sh("sha256sum '$dir/template/iso/sbxe2e-upload.iso'")).split(' ').first,
        await _sha256(_bytes(size)),
      );

      final cancel = Completer<void>();
      const big = 256 << 20;
      expect(
        await pve.upload(
          VirtUpload(
            pool: s,
            name: 'sbxe2e-cancel.iso',
            size: big,
            open: () => _bytes(big),
          ),
          cancel: cancel.future,
          onProgress: (n) {
            if (n > 8 << 20 && !cancel.isCompleted) cancel.complete();
          },
        ),
        isFalse,
      );
      expect((await vols()).where((v) => v.name == 'sbxe2e-cancel.iso'), isEmpty);
      // The session outlived the cancel.
      await pve.load();

      await pve.manage(VirtVolumeDelete(s, iso));
      await pve.manage(VirtVolumeDelete(s, v));
      expect(await vols(), isEmpty);
    });

    test('a volume allocated for a VM, attached to it and deleted with it', () async {
      final s = await storage();
      final lvm = (await pve.storagePools()).firstWhere(
        (p) => p.node == node && p.active && p.content.contains('images') && p.name != store,
      );
      final id = (await pve.nextVmid())!;
      await pve.create(
        VirtCreateSpec(
          kind: VirtGuestKind.qemu,
          name: 'sbxe2e-attach',
          node: node,
          vmid: id,
          cores: 1,
          memoryMiB: 256,
          storage: lvm,
          diskGiB: 1,
        ),
      );
      // Only once PVE made it: an ID taken meanwhile is refused, and the
      // guest holding it is not this group's to destroy.
      vmid = id;
      await pve.manage(
        VirtVolumeCreate(s, name: 'vm-$id-disk-1', gib: 1, format: 'raw'),
      );
      final v = (await vols()).firstWhere((v) => v.name == 'vm-$id-disk-1.raw');
      // `/cluster/resources` names a new guest a moment after its task.
      late VirtGuest g;
      for (var i = 0; i < 30; i++) {
        final found = (await pve.load()).guests.where((g) => g.vmid == id);
        if (found.firstOrNull?.state == VirtGuestState.stopped) {
          g = found.first;
          break;
        }
        if (i == 29) fail('VM $id never read as stopped');
        await Future<void>.delayed(const Duration(seconds: 1));
      }
      var hw = await pve.hardware(g);
      await pve.changeHardware(g, hw, VirtHwAttachVolume(storage: s, volume: v));
      hw = await pve.hardware(g);
      expect(hw.disks.map((d) => d.source), contains(v.id));
      await _whileLocked(() => pve.delete(g));
      vmid = null;
      expect(await vols(), isEmpty);
    });

    test('a privilege missing is named, with the command that grants it', () async {
      await sh("pveum acl modify /storage --tokens '$tokenId' --roles NoAccess");
      noAccess = true;
      final e = await _virtErr(
        pve.manage(
          VirtPoolCreate(name: '$store-x', type: 'dir', source: '$dir-x', node: node),
        ),
      );
      await sh("pveum acl delete /storage --tokens '$tokenId' --roles NoAccess");
      noAccess = false;
      expect(e.type, VirtErrType.permissionDenied);
      expect(e.message, contains('Datastore.Allocate'));
      expect(e.message, contains("pveum acl modify /storage --tokens '$tokenId' --roles PVEDatastoreAdmin"));
      expect(await findStore(), isNotNull);
    });

    test('the storage removed; what was in it stays', () async {
      await sh("touch '$dir/sbxe2e-kept'");
      await pve.manage(VirtPoolDelete(await storage()));
      ownsStore = false;
      expect(await findStore(), isNull);
      expect(await sh("ls '$dir'"), contains('sbxe2e-kept'));
    });

    test('a Linux bridge: pending, reverted; made again, applied, deleted, applied', () async {
      stagedNetwork = true;
      await pve.manage(
        VirtNetworkCreate(name: bridge, mode: 'bridge', node: node, cidr: '10.231.77.1/24'),
      );
      var changes = await pve.networkChanges();
      expect(changes.single.node, node);
      expect(changes.single.diff, contains('iface $bridge'));
      var b = (await findBridge())!;
      expect(b.active, isFalse);
      expect(b.cidrs, ['10.231.77.1/24']);
      await pve.manage(VirtNetworkRevert(node));
      expect(await pve.networkChanges(), isEmpty);
      expect(await findBridge(), isNull);

      await pve.manage(
        VirtNetworkCreate(
          name: bridge,
          mode: 'bridge',
          node: node,
          cidr: '10.231.77.1/24',
          vlanAware: true,
        ),
      );
      await apply();
      b = (await findBridge())!;
      expect(b.active, isTrue);
      expect(b.vlanAware, isTrue);
      expect(await sh('ip -4 -br addr show $bridge'), contains('10.231.77.1/24'));

      await pve.manage(VirtNetworkDelete(b));
      changes = await pve.networkChanges();
      expect(changes.single.diff, contains('-iface $bridge'));
      await apply();
      expect(await findBridge(), isNull);
      expect(await sh('ip link show $bridge 2>&1'), contains('does not exist'));
    });

    test('an edit keeps the addresses; the management bridge and an apply touching it are refused', () async {
      // A dual-stack bridge of the run's own, applied.
      stagedNetwork = true;
      await pve.manage(
        VirtNetworkCreate(name: bridge, mode: 'bridge', node: node, cidr: '10.231.78.1/24'),
      );
      await sh(
        'pvesh set /nodes/$node/network/$bridge --type bridge '
        '--cidr 10.231.78.1/24 --cidr6 fd31:78::1/64',
      );
      await apply();
      expect(await sh('ip -br addr show $bridge'), allOf(contains('10.231.78.1/24'), contains('fd31:78::1/64')));

      // Only VLAN awareness edited: PVE would drop both addresses from a
      // request without them. Both are in the pending stanza, and applied.
      final b = (await findBridge())!;
      expect(b.managementEditable, isTrue, reason: 'no traffic of the node on it');
      await pve.manage(VirtNetworkEditBridge(b, vlanAware: true));
      final pending = await sh('cat /etc/network/interfaces.new');
      final stanza = pending.substring(pending.indexOf('iface $bridge inet'));
      expect(stanza, contains('10.231.78.1/24'));
      expect(pending, contains('iface $bridge inet6 static'));
      expect(pending, contains('fd31:78::1/64'));
      await apply();
      expect(await sh('ip -br addr show $bridge'), allOf(contains('10.231.78.1/24'), contains('fd31:78::1/64')));

      // The node's own bridge: the node says its default route and this SSH
      // session are on it, so it is not editable, and an edit is refused
      // before anything is written.
      final nets = await pve.networks();
      final mgmt = nets.firstWhere((n) => n.node == node && n.gateway != null);
      expect(mgmt.managementEditable, isFalse, reason: mgmt.name);
      final e = await _virtErr(pve.manage(VirtNetworkEditBridge(mgmt, vlanAware: true)));
      expect(e.type, VirtErrType.unsupported);
      expect(await pve.networkChanges(), isEmpty);

      // A pending change to it made elsewhere (here with pvesh, as PVE's web
      // UI would): the app refuses to apply it. The change itself is a
      // comment on the same addresses, harmless even if it went through.
      final cidr = mgmt.cidrs.firstWhere((c) => !c.contains(':'));
      await sh(
        'pvesh set /nodes/$node/network/${mgmt.name} --type bridge '
        '--cidr $cidr --gateway ${mgmt.gateway} '
        '${mgmt.ports.isEmpty ? '' : '--bridge_ports "${mgmt.ports.join(' ')}"'} '
        '--comments sbxe2e',
      );
      expect(await pve.networkChanges(), isNotEmpty);
      final refused = await _virtErr(pve.manage(VirtNetworkApply(node)));
      expect(refused.type, VirtErrType.unsupported);
      expect(refused.message, contains(mgmt.name));
      expect(await sh('ls /etc/network/interfaces.new 2>/dev/null'), isNotEmpty, reason: 'not applied');
      await pve.manage(VirtNetworkRevert(node));
      expect(await pve.networkChanges(), isEmpty);
      expect(await sh('echo ssh-ok'), contains('ssh-ok'));

      await pve.manage(VirtNetworkDelete((await findBridge())!));
      await apply();
      expect(await findBridge(), isNull);
    });
  });
}

// -----------------------------------------------------------------------------
// Cloud images and cloud-init
// -----------------------------------------------------------------------------

/// VM [vmid] as the listing has it once it has caught up with its creation:
/// PVE's resource list trails a new VM by a few seconds (a placeholder
/// `VM <id>` name, the default memory, no action while it still reads as
/// locked).
Future<VirtGuest> _pveStartable(PveBackend pve, int vmid, String name) async {
  for (var i = 0; i < 30; i++) {
    final g = (await pve.load()).guests.where((g) => g.vmid == vmid).firstOrNull;
    if (g != null && g.name == name && g.actions.contains(VirtPowerAction.start)) return g;
    await Future<void>.delayed(const Duration(seconds: 1));
  }
  fail('VM $vmid never listed as $name, startable');
}

/// A key pair and a password for a guest's cloud-init, made for this run.
/// The password is never printed.
Future<({SSHKeyPair key, String publicKey, String password})> _guestLogin() async {
  final dir = await Directory.systemTemp.createTemp('sbxe2e-key');
  addTearDown(() => dir.delete(recursive: true));
  final path = '${dir.path}/id';
  final r = await Process.run('ssh-keygen', ['-q', '-t', 'ed25519', '-N', '', '-C', 'sbxe2e', '-f', path]);
  expect(r.exitCode, 0, reason: '${r.stderr}');
  final rnd = Random.secure();
  final password = base64Url.encode([for (var i = 0; i < 18; i++) rnd.nextInt(256)]);
  return (
    key: SSHKeyPair.fromPem(await File(path).readAsString()).single,
    publicKey: (await File('$path.pub').readAsString()).trim(),
    password: password,
  );
}

/// What the guest [ip] says of itself, over SSH through [host] once its
/// sshd answers (cloud-init done) and lets [user] in with [key]: the
/// hostname, the account, sudo (`ok`, or `doas` where the system has that
/// instead), the account's password hash, whether [password] makes that
/// hash (`pw`: the guest's crypt(3) with the hash as its salt, the password
/// on stdin; only where perl is), the size of [disk], cloud-init's instance
/// ID, and the SSH host key it answered with (`hostkey`). Portable to a
/// busybox system: no bash, lsblk or getent.
Future<Map<String, String>> _guestFacts(
  SSHClient host,
  String ip,
  String user,
  SSHKeyPair key,
  String disk,
  String password, {
  Duration within = const Duration(minutes: 5),
}) async {
  final deadline = DateTime.now().add(within);
  while (true) {
    String? hostKey;
    try {
      final guest = SSHClient(
        await host.forwardLocal(ip, 22),
        username: user,
        identities: [key],
        onVerifyHostKey: (type, fingerprint) {
          hostKey = '$type ${base64.encode(fingerprint)}';
          return true;
        },
      );
      try {
        final out = (await execSshE2e(
          guest,
          'cloud-init status --wait >/dev/null 2>&1; echo "host=\$(hostname)"; echo "user=\$(id -un)"; '
          "if sudo -n true 2>/dev/null; then echo sudo=ok; s='sudo -n'; "
          "elif doas -n true 2>/dev/null; then echo sudo=doas; s='doas -n'; else s=; fi; "
          r'''h=$($s grep "^$(id -un):" /etc/shadow | cut -d: -f2); echo "hash=$h"; '''
          'echo "disk=\$((\$(cat /sys/block/$disk/size) * 512))"; '
          'echo "iid=\$(cat /var/lib/cloud/data/instance-id 2>/dev/null)"; '
          // The system's own crypt(3), as a login checks it: perl-base
          // is in every Debian image, `crypt` is gone from Python 3.13.
          r'''command -v perl >/dev/null && perl -e '$p = <STDIN>; chomp $p; print "pw=ok\n" if length $ARGV[0] && crypt($p, $ARGV[0]) eq $ARGV[0]' "$h"''',
          Uint8List.fromList(utf8.encode('$password\n')),
        )).stdout;
        // A session cut short — cloud-init's first boot restarts sshd with
        // its new host keys — printed nothing: not in yet, tried again.
        if (!out.contains('host=')) throw StateError('no answer from $ip yet');
        return {
          for (final l in const LineSplitter().convert(out))
            if (l.contains('=')) l.substring(0, l.indexOf('=')): l.substring(l.indexOf('=') + 1),
          'hostkey': ?hostKey,
        };
      } finally {
        guest.close();
      }
    } catch (e) {
      if (DateTime.now().isAfter(deadline)) rethrow;
      await Future<void>.delayed(const Duration(seconds: 5));
    }
  }
}

/// Runs [command] in the guest [ip] as [user], once it lets [key] in.
Future<String> _guestRun(
  SSHClient host,
  String ip,
  String user,
  SSHKeyPair key,
  String command,
) async {
  final guest = SSHClient(
    await host.forwardLocal(ip, 22),
    username: user,
    identities: [key],
    onVerifyHostKey: (_, _) => true,
  );
  try {
    return (await execSshE2e(guest, command, null)).stdout;
  } finally {
    guest.close();
  }
}

/// Whether the guest [ip] lets [user] in with [key] now.
Future<bool> _guestLetsIn(SSHClient host, String ip, String user, SSHKeyPair key) async {
  try {
    return (await _guestRun(host, ip, user, key, 'echo in')).trim() == 'in';
  } catch (_) {
    return false;
  }
}

/// The hash of [password] with the salt [hash] was made with equals it:
/// the app's own SHA-512 crypt, for a hash it made (libvirt's seed).
bool _sameCrypt(String hash, String password) {
  final salt = hash.split(r'$')[2];
  return ffi.virtHashPassword(password: password, salt: salt) == hash;
}

Future<void> _libvirtCloudInit() async {
  final host = e2eEnv('SBM_E2E_LIBVIRT_HOST');
  final imagePath = e2eEnv('SBM_E2E_LIBVIRT_CLOUD_IMAGE');
  if (host == null || imagePath == null) return;
  final ready = await prepareReachableSshE2e(host);
  final target = ready.target;
  if (target == null) return;

  group('cloud images: libvirt over SSH', () {
    SSHClient? client;
    late LibvirtBackend virt;
    final vm = 'sbxe2e-ci-${DateTime.now().millisecondsSinceEpoch % 100000}';
    String? poolName;

    Future<String> sh(String command) async =>
        (await execSshE2e(client!, command, null)).stdout;
    Future<VirtGuest?> find() async =>
        (await virt.load()).guests.where((g) => g.name == vm).firstOrNull;

    setUpAll(() async {
      await initRustLibForTest();
      final c = await connectSshE2e(target, ready.identities);
      client = c;
      virt = LibvirtBackend(serverId: 'e2e-libvirt-ci', exec: () async => SshExec(c));
    });
    tearDownAll(() async {
      final c = client;
      if (c == null) return;
      Future<void> virsh(String args) =>
          execSshE2e(c, 'LC_ALL=C virsh --connect qemu:///system -q $args </dev/null', null);
      // Only what this group made, by name.
      await virsh("destroy '$vm'");
      await virsh("undefine '$vm' --nvram");
      if (poolName case final p?) {
        await virsh("vol-delete --pool '$p' --vol '$vm.qcow2'");
        await virsh("vol-delete --pool '$p' --vol '$vm-cidata.iso'");
      }
      await virt.close();
      c.close();
    });

    test('a VM from a cloud image, set up by cloud-init, then deleted with '
        'its disk and seed', () async {
      final options = await virt.createOptions();
      expect((options.cloudImages, options.cloudInit, options.uefi), (true, true, true));
      expect(options.buses, isNot(contains('ide')));

      // The image, in whichever pool holds it.
      VirtStoragePool? pool;
      VirtVolume? image;
      for (final p in await virt.storagePools()) {
        if (!p.active) continue;
        final v = (await virt.volumes(p)).where((v) => v.path == imagePath).firstOrNull;
        if (v != null) {
          (pool, image) = (p, v);
          break;
        }
      }
      expect(image, isNotNull, reason: 'no volume at $imagePath');
      expect(virtIsCloudImage(image!, VirtHostKind.libvirt), isTrue);
      poolName = pool!.name;
      final baseSum = await sh("sha256sum '$imagePath' | cut -c1-64");
      final login = await _guestLogin();
      final net = (await virt.networks()).firstWhere((n) => n.name == 'default');
      final snap = await virt.load();
      final spec = VirtCreateSpec(
        kind: VirtGuestKind.qemu,
        name: vm,
        cores: 1,
        memoryMiB: 1024,
        storage: pool,
        diskGiB: 4,
        image: image,
        network: net,
        bus: 'virtio',
        nicModel: 'virtio',
        uefi: true,
        cloudInit: VirtCloudInit(
          user: 'sbxe',
          password: login.password,
          sshKeys: login.publicKey,
          hostname: vm,
        ),
        start: true,
      );
      expect(virtCreateIssue(spec, host: VirtHostKind.libvirt, guests: snap.guests), isNull);
      final created = await virt.create(spec);
      expect(created.startError, isNull);
      final g = (await find())!;

      // The seed is the domain's own, and not install media.
      final hw = await virt.hardware(g);
      final seed = hw.disks.singleWhere((d) => d.cloudInit);
      expect(seed.source, endsWith('/$vm-cidata.iso'));
      expect(hw.firmware?.uefi, isTrue);
      // Only the hash is on the host.
      expect(await sh("grep -c -F '${login.password}' '${seed.source}' || true"), contains('0'));

      final mac = (await virt.detail(g)).nics.single.mac!;
      String? ip;
      for (var i = 0; i < 60 && ip == null; i++) {
        final leases = await sh('virsh --connect qemu:///system -q net-dhcp-leases default');
        ip = RegExp('${RegExp.escape(mac)}\\s+ipv4\\s+([0-9.]+)/').firstMatch(leases)?[1];
        if (ip == null) await Future<void>.delayed(const Duration(seconds: 3));
      }
      expect(ip, isNotNull, reason: 'no DHCP lease for $mac');
      final facts = await _guestFacts(client!, ip!, 'sbxe', login.key, 'vda', login.password);
      expect(facts['host'], vm);
      expect(facts['user'], 'sbxe');
      expect(facts['sudo'], 'ok');
      // The hash the app made, and the password makes it on the guest too.
      expect(_sameCrypt(facts['hash']!, login.password), isTrue);
      expect(facts['pw'], 'ok');
      expect(facts['disk'], '${4 << 30}');

      // A CD-ROM drive beside the seed, stopped, and taken off again.
      await virt.power(g, VirtPowerAction.forceStop);
      final stopped = (await find())!;
      var hw2 = await virt.hardware(stopped);
      await virt.changeHardware(stopped, hw2, const VirtHwAddCdrom());
      hw2 = await virt.hardware(stopped);
      final drive = hw2.disks.singleWhere((d) => d.kind == VirtHwDiskKind.cdrom && !d.cloudInit);
      expect((drive.source, drive.bus), (null, 'sata'));
      await virt.changeHardware(stopped, hw2, VirtHwRemoveDisk(key: drive.key));
      expect((await virt.hardware(stopped)).disks.where((d) => d.kind == VirtHwDiskKind.cdrom), hasLength(1));

      await virt.delete(stopped);
      expect(await find(), isNull);
      final names = [for (final v in await virt.volumes(pool)) v.name];
      expect(names, isNot(contains('$vm.qcow2')));
      expect(names, isNot(contains('$vm-cidata.iso')));
      expect(names, contains(image.name));
      expect(await sh("sha256sum '$imagePath' | cut -c1-64"), baseSum);
    }, timeout: const Timeout(Duration(minutes: 10)));
  });
}

/// Cloud images besides the one above, the seed tools, a TPM and a disk
/// asked smaller than its image, and cloud-init edited after creation: see
/// the header (`SBM_E2E_LIBVIRT_CLOUD_IMAGES` and after).
Future<void> _libvirtCloudImages() async {
  final host = e2eEnv('SBM_E2E_LIBVIRT_HOST');
  List<String> list(String name) => [
    for (final s in (e2eEnv(name) ?? '').split(','))
      if (s.trim().isNotEmpty) s.trim(),
  ];
  final images = list('SBM_E2E_LIBVIRT_CLOUD_IMAGES');
  if (host == null || images.isEmpty) return;
  final diskPoolName = e2eEnv('SBM_E2E_LIBVIRT_DISK_POOL');
  final tools = list('SBM_E2E_LIBVIRT_SEED_TOOLS');
  final tpm = e2eEnv('SBM_E2E_LIBVIRT_TPM') == '1';
  final ready = await prepareReachableSshE2e(host);
  final target = ready.target;
  if (target == null) return;

  group('cloud images: each image, the seed tools, edited (libvirt over SSH)', () {
    SSHClient? client;
    late LibvirtBackend virt;
    final run = DateTime.now().millisecondsSinceEpoch % 100000;
    final made = <String>[];
    String? diskPool;
    // An isolated network of the run's own, for a second NIC.
    final net2 = 'sbxe2e-n2-$run';

    Future<String> sh(String command) async =>
        (await execSshE2e(client!, command, null)).stdout;
    Future<VirtGuest?> find(LibvirtBackend b, String name) async =>
        (await b.load()).guests.where((g) => g.name == name).firstOrNull;

    setUpAll(() async {
      await initRustLibForTest();
      final c = await connectSshE2e(target, ready.identities);
      client = c;
      virt = LibvirtBackend(serverId: 'e2e-libvirt-images', exec: () async => SshExec(c));
    });
    tearDownAll(() async {
      final c = client;
      if (c == null) return;
      Future<void> virsh(String args) =>
          execSshE2e(c, 'LC_ALL=C virsh --connect qemu:///system -q $args </dev/null', null);
      // Only what this group made, by name; never `--remove-all-storage`.
      await virsh("net-destroy '$net2'");
      await virsh("net-undefine '$net2'");
      for (final name in made) {
        await virsh("destroy '$name'");
        await virsh("undefine '$name' --nvram");
        if (diskPool case final p?) {
          await virsh("vol-delete --pool '$p' --vol '$name.qcow2'");
          await virsh("vol-delete --pool '$p' --vol '$name-cidata.iso'");
        }
      }
      await virt.close();
      c.close();
    });

    /// The image volume at [path], in whichever pool holds it.
    Future<VirtVolume> imageAt(String path) async {
      for (final p in await virt.storagePools()) {
        if (!p.active) continue;
        final v = (await virt.volumes(p)).where((v) => v.path == path).firstOrNull;
        if (v != null) return v;
      }
      fail('no volume at $path');
    }

    Future<VirtStoragePool> poolFor(String imagePath) async {
      final pools = await virt.storagePools();
      final VirtStoragePool pool;
      if (diskPoolName != null) {
        pool = pools.firstWhere((p) => p.name == diskPoolName);
      } else {
        pool = pools.firstWhere((p) => p.path != null && imagePath.startsWith('${p.path}/'));
      }
      diskPool = pool.name;
      return pool;
    }

    /// The address of [g]'s newest lease: a new instance may come back
    /// with a new DHCP client ID, and so another address, beside the old
    /// lease.
    Future<String> ipOf(VirtGuest g) async {
      final mac = (await virt.detail(g)).nics.first.mac!;
      final lease = RegExp(
        '^\\s*(\\S+ \\S+)\\s+${RegExp.escape(mac)}\\s+ipv4\\s+([0-9.]+)/',
        multiLine: true,
      );
      for (var i = 0; i < 80; i++) {
        final leases = await sh('virsh --connect qemu:///system -q net-dhcp-leases default');
        final found = [for (final m in lease.allMatches(leases)) (m[1]!, m[2]!)]
          ..sort((a, b) => a.$1.compareTo(b.$1));
        if (found.lastOrNull case (_, final ip)) return ip;
        await Future<void>.delayed(const Duration(seconds: 3));
      }
      fail('no DHCP lease for $mac');
    }

    /// A VM `sbxe2e-ci-<tag>-<run>` from [imagePath], with cloud-init for
    /// [login], made by [b] (the group's backend unless a narrowed one).
    Future<(VirtGuest, VirtCreated, VirtStoragePool)> make(
      String tag,
      String imagePath,
      ({SSHKeyPair key, String publicKey, String password}) login, {
      LibvirtBackend? b,
      int gib = 4,
      bool tpm = false,
      bool secureBoot = false,
    }) async {
      final backend = b ?? virt;
      final name = 'sbxe2e-ci-$tag-$run';
      made.add(name);
      final image = await imageAt(imagePath);
      expect(virtIsCloudImage(image, VirtHostKind.libvirt), isTrue);
      final pool = await poolFor(imagePath);
      final net = (await backend.networks()).firstWhere((n) => n.name == 'default');
      // Alpine's `bios` image boots from BIOS only.
      final bios = imagePath.contains('alpine');
      final created = await backend.create(
        VirtCreateSpec(
          kind: VirtGuestKind.qemu,
          name: name,
          cores: 1,
          memoryMiB: 1024,
          storage: pool,
          diskGiB: gib,
          image: image,
          network: net,
          bus: 'virtio',
          uefi: !bios,
          secureBoot: secureBoot,
          tpm: tpm,
          cloudInit: VirtCloudInit(
            user: 'sbxe',
            password: login.password,
            sshKeys: login.publicKey,
            hostname: name,
          ),
          start: true,
        ),
      );
      expect(created.startError, isNull);
      return ((await find(backend, name))!, created, pool);
    }

    Future<void> remove(VirtGuest g, VirtStoragePool pool) async {
      await virt.power(g, VirtPowerAction.forceStop);
      final off = (await find(virt, g.name))!;
      await virt.delete(off);
      expect(await find(virt, g.name), isNull);
      final names = [for (final v in await virt.volumes(pool)) v.name];
      expect(names, isNot(contains('${g.name}.qcow2')));
      expect(names, isNot(contains('${g.name}-cidata.iso')));
      made.remove(g.name);
    }

    for (final path in images) {
      final tag = path.split('/').last.split('.').first.replaceAll('sbxe2e-', '');
      test('$tag: set up by cloud-init; edited, and the edit taken at the next boot', () async {
        final baseSum = await sh("sha256sum '$path' | cut -c1-64");
        final login = await _guestLogin();
        final (g, created, pool) = await make(tag, path, login);
        expect(created.diskKeptBytes, isNull);
        var ip = await ipOf(g);
        final before = await _guestFacts(client!, ip, 'sbxe', login.key, 'vda', login.password);
        expect(before['host'], g.name);
        expect(before['user'], 'sbxe');
        expect(before['sudo'], anyOf('ok', 'doas'));
        expect(_sameCrypt(before['hash']!, login.password), isTrue);
        if (before.containsKey('pw')) expect(before['pw'], 'ok');
        expect(before['disk'], '${4 << 30}');
        // ignore: avoid_print
        print('$tag: sudo=${before['sudo']} iid=${before['iid']} hostkey=${before['hostkey']}');

        // Read back from the seed as it was written.
        final hw = await virt.hardware(g);
        expect(hw.disks.where((d) => d.cloudInit), hasLength(1));
        final ci = await virt.cloudInit(g);
        expect(ci.user, 'sbxe');
        expect(ci.hostname, g.name);
        expect(ci.sshKeys, [login.publicKey]);
        expect((ci.passwordSet, ci.network, ci.foreign, ci.address), (true, true, false, null));

        // A new hostname and a new key; the password kept.
        final next = await _guestLogin();
        final edit = VirtCloudInitEdit(
          VirtCloudInit(user: 'sbxe', sshKeys: next.publicKey, hostname: '${g.name}-b'),
        );
        expect(virtCloudInitEditIssue(ci, edit, host: VirtHostKind.libvirt), isNull);
        await virt.setCloudInit(g, ci, edit);
        final after = await virt.cloudInit(g);
        expect((after.hostname, after.passwordSet), ('${g.name}-b', true));
        expect(after.sshKeys, [next.publicKey]);
        expect(after.revision, isNot(ci.revision));
        // The same edit from the old read: refused.
        final stale = await _virtErr(virt.setCloudInit(g, ci, edit));
        expect(stale.type, VirtErrType.conflict);
        // Nothing yet in the running system: the new key is not let in.
        expect(await _guestLetsIn(client!, ip, 'sbxe', next.key), isFalse);

        // A reboot from inside: the same QEMU process reads the new seed.
        await _guestRun(client!, ip, 'sbxe', login.key, '(sleep 1; sudo -n reboot || doas -n reboot) >/dev/null 2>&1 &');
        await Future<void>.delayed(const Duration(seconds: 10));
        // Wherever its newest lease says, asked again until it lets the new
        // key in.
        Map<String, String>? rebooted;
        final deadline = DateTime.now().add(const Duration(minutes: 5));
        while (rebooted == null) {
          ip = await ipOf(g);
          try {
            rebooted = await _guestFacts(
              client!, ip, 'sbxe', next.key, 'vda', login.password,
              within: const Duration(seconds: 20),
            );
          } catch (_) {
            if (DateTime.now().isAfter(deadline)) rethrow;
          }
        }
        expect(rebooted['host'], '${g.name}-b');
        expect(rebooted['iid'], isNot(before['iid']));
        // A new instance makes new host keys.
        expect(rebooted['hostkey'], isNot(before['hostkey']));
        // The password as it was (the seed kept its hash).
        expect(rebooted['hash'], before['hash']);
        // A key taken out of the settings stays in the system.
        final oldKeyIn = await _guestLetsIn(client!, ip, 'sbxe', login.key);
        // ignore: avoid_print
        print('$tag after the edit: iid=${rebooted['iid']} hostkey=${rebooted['hostkey']} old key in: $oldKeyIn');
        expect(oldKeyIn, isTrue);

        await remove((await find(virt, g.name))!, pool);
        expect(await sh("sha256sum '$path' | cut -c1-64"), baseSum);
      }, timeout: const Timeout(Duration(minutes: 15)));
    }

    test('an image bigger than the disk asked for: kept at its size, started', () async {
      // The biggest image there is.
      final sizes = [for (final p in images) ((await imageAt(p)).capacity ?? 0, p)]..sort((a, b) => b.$1.compareTo(a.$1));
      final (bytes, path) = sizes.first;
      expect(bytes, greaterThan(1 << 30));
      // Strictly smaller than the image, a whole-GiB one (Debian 13's is
      // 3 GiB exactly) included.
      final gib = ((bytes - 1) >> 30).clamp(1, 1 << 20);
      expect(gib << 30, lessThan(bytes));
      final login = await _guestLogin();
      final (g, created, pool) = await make('kept', path, login, gib: gib);
      expect(created.diskKeptBytes, bytes);
      expect(await sh("LC_ALL=C virsh -q vol-info --bytes --pool '${pool.name}' --vol '${g.name}.qcow2' | grep Capacity"), contains('$bytes bytes'));
      expect(g.state, VirtGuestState.running);
      await remove(g, pool);
    }, timeout: const Timeout(Duration(minutes: 10)));

    for (final tool in tools) {
      test('a seed made by $tool: booted from, read back, written anew by it', () async {
        final path = images.firstWhere((p) => p.contains('alpine'), orElse: () => images.first);
        final c = client!;
        final narrowed = LibvirtBackend(serverId: 'e2e-libvirt-$tool', exec: () async => SshExec(c), seedTools: [tool]);
        addTearDown(narrowed.close);
        final login = await _guestLogin();
        final (g, _, pool) = await make(tool, path, login, b: narrowed);
        final ip = await ipOf(g);
        final facts = await _guestFacts(c, ip, 'sbxe', login.key, 'vda', login.password);
        expect(facts['host'], g.name);
        await narrowed.hardware(g);
        final ci = await narrowed.cloudInit(g);
        expect((ci.user, ci.hostname, ci.foreign), ('sbxe', g.name, false));
        await narrowed.setCloudInit(
          g,
          ci,
          VirtCloudInitEdit(VirtCloudInit(user: 'sbxe', sshKeys: login.publicKey, hostname: '$tool-x')),
        );
        expect((await narrowed.cloudInit(g)).hostname, '$tool-x');
        await remove(g, pool);
      }, timeout: const Timeout(Duration(minutes: 10)));
    }

    test('Secure Boot on; a second NIC from the seed, kept through a save; '
        'a password that expires at the first login', () async {
      final path = images.firstWhere((p) => !p.contains('alpine'), orElse: () => images.first);
      final options = await virt.createOptions();
      // ignore: avoid_print
      print('Secure Boot offered: ${options.secureBoot}');
      final login = await _guestLogin();
      final (g, _, pool) = await make('sb', path, login, secureBoot: options.secureBoot);
      if (options.secureBoot) {
        expect((await virt.hardware(g)).firmware, const VirtHwFirmware(uefi: true, secureBoot: true));
        final xml = await sh("virsh --connect qemu:///system dumpxml '${g.id}'");
        expect(xml, contains("<feature enabled='yes' name='secure-boot'/>"));
        expect(xml, contains("<feature enabled='yes' name='enrolled-keys'/>"));
        expect(xml, contains("<smm state='on'/>"));
      }
      var ip = await ipOf(g);
      await _guestFacts(client!, ip, 'sbxe', login.key, 'vda', login.password);
      if (options.secureBoot) {
        // The firmware's own variable: its last byte is 1 with Secure Boot on.
        final sb = await _guestRun(
          client!, ip, 'sbxe', login.key,
          'od -An -tu1 /sys/firmware/efi/efivars/SecureBoot-8be4df61-93ca-11d2-aa0d-00e098032b8c',
        );
        expect(sb.trim().split(RegExp(r'\s+')).last, '1', reason: sb);
      }

      // A second NIC, on a network of the run's own, while it runs.
      await virt.manage(VirtNetworkCreate(name: net2, mode: 'isolated', cidr: '10.231.79.1/24'));
      final n2 = (await virt.networks()).firstWhere((n) => n.name == net2);
      await virt.changeHardware(g, await virt.hardware(g), VirtHwAddNic(network: n2));
      final nics = (await virt.detail(g)).nics;
      expect(nics, hasLength(2));
      final (mac1, mac2) = (nics[0].mac!, nics[1].mac!);

      // A seed with both NICs, as one written elsewhere would have them: the
      // app's own script with an extra network the form does not edit.
      final hw = await virt.hardware(g);
      final seed = hw.disks.singleWhere((d) => d.cloudInit).source!;
      final one = await virt.cloudInit(g);
      expect(one.nics, 1);
      final json = LibvirtBackend.cloudInitJson(
        VirtCloudInit(user: 'sbxe', password: login.password, sshKeys: login.publicKey, hostname: g.name),
        name: g.name,
        mac: mac1,
        extraNetworks: [
          {
            'mac': mac2,
            'ipv4': {'address': '10.231.79.10/24', 'gateway': null},
            'dns': <String>[],
            'search': <String>[],
          },
        ],
      );
      final out = (await execSshE2e(
        client!,
        'sh -s',
        Uint8List.fromList(utf8.encode(ffi.virtSeedUpdateScript(
          seed: seed,
          revision: one.revision,
          cloudInitJson: jsonEncode(json),
        ))),
      )).stdout;
      ffi.parseVirtSeedUpdate(raw: out);

      // Read back: two NICs. A save from the form (a new hostname) keeps
      // the second.
      final two = await virt.cloudInit(g);
      expect((two.nics, two.foreign), (2, false));
      await virt.setCloudInit(
        g,
        two,
        VirtCloudInitEdit(VirtCloudInit(user: 'sbxe', sshKeys: login.publicKey, hostname: '${g.name}-b')),
      );
      final saved = await virt.cloudInit(g);
      expect((saved.nics, saved.hostname, saved.passwordExpires), (2, '${g.name}-b', false));

      Future<void> reboot() async {
        await _guestRun(client!, ip, 'sbxe', login.key, '(sleep 1; sudo -n reboot) >/dev/null 2>&1 &');
        await Future<void>.delayed(const Duration(seconds: 10));
      }

      // The next boot takes both: the second NIC has its static address.
      await reboot();
      Map<String, String>? rebooted;
      final deadline = DateTime.now().add(const Duration(minutes: 5));
      while (rebooted?['host'] != '${g.name}-b') {
        // Checked on every pass: a guest that answers with its old hostname
        // never throws, and would otherwise loop until the test's timeout.
        if (DateTime.now().isAfter(deadline)) {
          fail('the guest still answers as ${rebooted?['host']}');
        }
        ip = await ipOf(g);
        try {
          rebooted = await _guestFacts(
            client!, ip, 'sbxe', login.key, 'vda', login.password,
            within: const Duration(seconds: 20),
          );
        } catch (_) {
          if (DateTime.now().isAfter(deadline)) rethrow;
        }
      }
      final addrs = await _guestRun(client!, ip, 'sbxe', login.key, 'ip -4 -o addr show');
      expect(addrs, contains('10.231.79.10/24'), reason: addrs);

      // The password set to expire: read back so, both NICs still there.
      await virt.setCloudInit(
        g,
        saved,
        VirtCloudInitEdit(
          VirtCloudInit(user: 'sbxe', sshKeys: login.publicKey, hostname: '${g.name}-b'),
          passwordExpires: true,
        ),
      );
      final expiring = await virt.cloudInit(g);
      expect((expiring.passwordExpires, expiring.nics, expiring.passwordSet), (true, 2, true));

      // At the next boot, a login is made to change it first: sshd asks for
      // it on a terminal (and refuses a command without one).
      await reboot();
      String? prompt;
      final until = DateTime.now().add(const Duration(minutes: 5));
      while (prompt == null) {
        if (DateTime.now().isAfter(until)) fail('never asked to change the password');
        try {
          ip = await ipOf(g);
          final guest = SSHClient(
            await client!.forwardLocal(ip, 22),
            username: 'sbxe',
            identities: [login.key],
            onVerifyHostKey: (_, _) => true,
          );
          try {
            final shell = await guest.shell(pty: const SSHPtyConfig());
            final text = StringBuffer();
            final sub = shell.stdout.listen((b) => text.write(utf8.decode(b, allowMalformed: true)));
            await Future<void>.delayed(const Duration(seconds: 8));
            await sub.cancel();
            shell.close();
            final t = text.toString();
            if (t.contains('change your password') || t.contains('password has expired')) prompt = t;
          } finally {
            guest.close();
          }
        } catch (_) {}
        if (prompt == null) await Future<void>.delayed(const Duration(seconds: 5));
      }
      // ignore: avoid_print
      print('expired: ${prompt.trim().split('\n').where((l) => l.contains('password')).join(' | ')}');

      await remove((await find(virt, g.name))!, pool);
      await virt.manage(VirtNetworkDelete((await virt.networks()).firstWhere((n) => n.name == net2)));
    }, timeout: const Timeout(Duration(minutes: 20)));

    if (tpm) {
      test('a TPM: swtpm runs it, and the system sees one', () async {
        final path = images.firstWhere((p) => !p.contains('alpine'), orElse: () => images.first);
        final login = await _guestLogin();
        final (g, _, pool) = await make('tpm', path, login, tpm: true);
        final hw = await virt.hardware(g);
        expect(hw.hasTpm, isTrue);
        expect(await sh("pgrep -af swtpm | grep -c '${g.id}' || true"), isNot(startsWith('0')));
        final ip = await ipOf(g);
        await _guestFacts(client!, ip, 'sbxe', login.key, 'vda', login.password);
        expect(await _guestRun(client!, ip, 'sbxe', login.key, 'ls /dev/tpm0 /dev/tpmrm0'), contains('/dev/tpm0'));
        await remove(g, pool);
        // The TPM's state went with the domain.
        expect(await sh("ls -d '/var/lib/libvirt/swtpm/${g.id}' 2>/dev/null || true"), isEmpty);
      }, timeout: const Timeout(Duration(minutes: 10)));
    }
  });
}

Future<void> _pveCloudInit() async {
  final host = e2eEnv('SBM_E2E_PVE_HOST');
  final tokenId = e2eEnv('SBM_E2E_PVE_TOKEN_ID');
  final tokenSecret = e2eEnv('SBM_E2E_PVE_TOKEN_SECRET');
  final imageId = e2eEnv('SBM_E2E_PVE_CLOUD_IMAGE');
  final addr = e2eEnv('SBM_E2E_PVE_CLOUD_ADDR');
  final gw = e2eEnv('SBM_E2E_PVE_CLOUD_GW');
  if ([host, tokenId, tokenSecret, imageId, addr, gw].contains(null)) return;
  final ready = await prepareReachableSshE2e(host!);
  final target = ready.target;
  if (target == null) return;

  group('cloud images: PVE over SSH', () {
    SSHClient? client;
    late PveBackend pve;
    int? vmid;
    final name = 'sbxe2e-ci-${DateTime.now().millisecondsSinceEpoch % 100000}';
    final ip = addr!.split('/').first;
    // Every VM this group made, by VMID and name.
    final made = <(int, String)>[];

    Future<String> sh(String command) async =>
        (await execSshE2e(client!, command, null)).stdout;
    Future<VirtGuest?> find() async => (await pve.load()).guests
        .where((g) => g.kind == VirtGuestKind.qemu && g.vmid == vmid)
        .firstOrNull;

    setUpAll(() async {
      await initRustLibForTest();
      final c = await connectSshE2e(target, ready.identities);
      client = c;
      final d = _pvePaths(target, () => c, '')['over SSH']!.dialer();
      pve = PveBackend(
        serverId: 'e2e-pve-ci',
        config: PveConfig(
          addr: 'https://localhost:8006',
          auth: PveAuth.token,
          tokenId: tokenId,
          tokenSecret: tokenSecret,
        ),
        tunnel: d.loopback,
        connect: d.startConnect,
        onClose: d.close,
        taskPoll: const Duration(milliseconds: 500),
        taskTimeout: const Duration(minutes: 5),
      );
      final e = await _virtErr(pve.load());
      expect(e.type, VirtErrType.certUnconfirmed);
      await pve.confirmCert(e.cert!.fingerprint);
    });
    tearDownAll(() async {
      final c = client;
      if (c == null) return;
      // Only the VMs this group made, and only while they have its names.
      for (final (id, n) in made) {
        if ((await sh('qm config $id 2>/dev/null | grep "^name: "')).contains(n)) {
          await sh('qm stop $id 2>/dev/null; qm destroy $id --purge 2>/dev/null');
        }
      }
      await pve.close();
      c.close();
    });

    test('a VM imported from a cloud image, set up by cloud-init, then '
        'deleted with its volumes', () async {
      final options = await pve.createOptions();
      expect((options.cloudImages, options.cloudInit, options.uefi, options.tpm), (true, true, true, true));
      final snap = await pve.load();
      final node = snap.host.nodes.first.name;
      // A free VMID of the test's range, and an address nothing answers.
      for (var id = 950; id < 1000 && vmid == null; id++) {
        if (snap.guests.any((g) => g.vmid == id)) continue;
        if ((await sh('qm status $id 2>/dev/null; pct status $id 2>/dev/null')).isEmpty) vmid = id;
      }
      expect(vmid, isNotNull);
      made.add((vmid!, name));
      expect(await sh('ping -c 2 -W 1 $ip >/dev/null 2>&1 && echo answered'), isEmpty, reason: '$ip is in use');

      final pools = await pve.storagePools();
      final disks = virtDiskStorages(pools, host: VirtHostKind.pve, kind: VirtGuestKind.qemu, node: node);
      final storage = disks.firstWhere((p) => p.name == 'local-lvm', orElse: () => disks.first);
      VirtVolume? image;
      for (final p in virtImageStorages(pools, host: VirtHostKind.pve, node: node)) {
        image ??= (await pve.volumes(p)).where((v) => v.id == imageId).firstOrNull;
      }
      expect(image, isNotNull, reason: 'no $imageId with import content');
      expect(virtIsCloudImage(image!, VirtHostKind.pve), isTrue);
      final bridge = virtCreateNetworks(await pve.networks(), host: VirtHostKind.pve, node: node)
          .firstWhere((n) => n.name == 'vmbr0');
      final login = await _guestLogin();
      final spec = VirtCreateSpec(
        kind: VirtGuestKind.qemu,
        name: name,
        node: node,
        vmid: vmid,
        cores: 1,
        memoryMiB: 1024,
        storage: storage,
        diskGiB: 8,
        image: image,
        network: bridge,
        bus: 'scsi',
        uefi: true,
        tpm: true,
        cloudInit: VirtCloudInit(
          user: 'sbxe',
          password: login.password,
          sshKeys: login.publicKey,
          address: addr,
          gateway: gw,
          dns: [gw!],
        ),
        // Started below, once PVE's first-boot package upgrade is off: it
        // (`ciupgrade`, on by default) holds cloud-init's final stage on
        // the network, which is not what this checks.
        start: false,
      );
      expect(virtCreateIssue(spec, host: VirtHostKind.pve, guests: snap.guests), isNull);
      final created = await pve.create(spec);
      expect(created.startError, isNull);
      await sh('qm set $vmid --ciupgrade 0');
      await pve.power(await _pveStartable(pve, vmid!, name), VirtPowerAction.start);

      final config = await sh('qm config $vmid');
      expect(config, contains('scsi0: ${storage.name}:vm-$vmid-disk-'));
      expect(config, contains('size=8G'));
      expect(config, contains('scsi1: ${storage.name}:vm-$vmid-cloudinit'));
      expect(config, contains('efidisk0:'));
      expect(config, contains('tpmstate0:'));
      expect(config, contains('ipconfig0: ip=$addr,gw=$gw'));
      // PVE stores a hash of it.
      expect(config, isNot(contains(login.password)));

      final g = (await find())!;
      final hw = await pve.hardware(g);
      expect(hw.disk('scsi1')!.cloudInit, isTrue);

      final facts = await _guestFacts(client!, ip, 'sbxe', login.key, 'sda', login.password);
      expect(facts['host'], name);
      expect(facts['user'], 'sbxe');
      expect(facts['sudo'], 'ok');
      // PVE hashes it itself (SHA-256 crypt): checked on the guest.
      expect(facts['hash'], startsWith(r'$'));
      expect(facts['pw'], 'ok');
      expect(facts['disk'], '${8 << 30}');

      // A CD-ROM drive while it runs: the first free IDE slot, and gone
      // again.
      await pve.changeHardware(g, hw, const VirtHwAddCdrom());
      var hw2 = await pve.hardware(g);
      final drive = hw2.disks.singleWhere((d) => d.kind == VirtHwDiskKind.cdrom && !d.cloudInit);
      expect(drive.key, 'ide2');
      await pve.changeHardware(g, hw2, const VirtHwRemoveDisk(key: 'ide2'));
      hw2 = await pve.hardware(g);
      expect(hw2.disk('ide2'), isNull);

      final running = await _settle(pve, vmid!, (g) => g.state == VirtGuestState.running);
      await pve.power(running, VirtPowerAction.forceStop);
      await _afterStop();
      await _whileLocked(() async => pve.delete((await find())!));
      expect(await find(), isNull);
      expect(await sh('pvesm list ${storage.name} | grep -c "vm-$vmid-" || true'), contains('0'));
      expect(await sh("pvesm list ${imageId!.split(':').first} --content import | grep -c '$imageId' || true"), contains('1'));
    }, timeout: const Timeout(Duration(minutes: 10)));

    test('an image bigger than the disk asked for: its size kept; cloud-init '
        'edited, and taken at a reboot from inside', () async {
      final snap = await pve.load();
      final node = snap.host.nodes.first.name;
      int? id;
      for (var i = 950; i < 1000 && id == null; i++) {
        if (snap.guests.any((g) => g.vmid == i)) continue;
        if ((await sh('qm status $i 2>/dev/null; pct status $i 2>/dev/null')).isEmpty) id = i;
      }
      expect(id, isNotNull);
      final name2 = '$name-k';
      made.add((id!, name2));
      vmid = id;
      expect(await sh('ping -c 2 -W 1 $ip >/dev/null 2>&1 && echo answered'), isEmpty, reason: '$ip is in use');

      final pools = await pve.storagePools();
      final storage = virtDiskStorages(pools, host: VirtHostKind.pve, kind: VirtGuestKind.qemu, node: node)
          .firstWhere((p) => p.name == 'local-lvm');
      VirtVolume? image;
      for (final p in virtImageStorages(pools, host: VirtHostKind.pve, node: node)) {
        image ??= (await pve.volumes(p)).where((v) => v.id == imageId).firstOrNull;
      }
      // The virtual size, not the file's the listing gives.
      final bytes = image!.capacity!;
      final file = int.parse((await sh("stat -c %s \"\$(pvesm path '$imageId')\"")).trim());
      expect(bytes, greaterThan(file));
      expect(bytes, greaterThan(2 << 30));
      final bridge = virtCreateNetworks(await pve.networks(), host: VirtHostKind.pve, node: node)
          .firstWhere((n) => n.name == 'vmbr0');
      final login = await _guestLogin();
      final created = await pve.create(
        VirtCreateSpec(
          kind: VirtGuestKind.qemu,
          name: name2,
          node: node,
          vmid: id,
          cores: 1,
          memoryMiB: 1024,
          storage: storage,
          diskGiB: 2,
          image: image,
          network: bridge,
          bus: 'scsi',
          cloudInit: VirtCloudInit(
            user: 'sbxe',
            password: login.password,
            sshKeys: login.publicKey,
            address: addr,
            gateway: gw,
            dns: [gw!],
          ),
          // Started below, with PVE's first-boot package upgrade off (see
          // the test above).
          start: false,
        ),
      );
      // Kept at the image's size: not cut, not failed, started.
      expect(created.startError, isNull);
      await sh('qm set $id --ciupgrade 0');
      await pve.power(await _pveStartable(pve, id, name2), VirtPowerAction.start);
      expect(created.diskKeptBytes, bytes);
      // PVE prints a whole GiB as `G` and anything else as `M`.
      final written = RegExp(r'size=(\d+)([MG])').firstMatch(await sh('qm config $id | grep "^scsi0:"'))!;
      expect(int.parse(written[1]!) << (written[2] == 'G' ? 30 : 20), bytes);

      final before = await _guestFacts(client!, ip, 'sbxe', login.key, 'sda', login.password);
      expect(before['host'], name2);
      expect(before['sudo'], 'ok');
      expect(before['disk'], '$bytes');
      // ignore: avoid_print
      print('PVE: iid=${before['iid']} hostkey=${before['hostkey']}');

      final g = (await find())!;
      final ci = await pve.cloudInit(g);
      expect((ci.user, ci.address, ci.gateway, ci.passwordSet, ci.network), ('sbxe', addr, gw, true, true));
      expect(ci.sshKeys, [login.publicKey]);
      expect(ci.dns, [gw]);

      final next = await _guestLogin();
      final edit = VirtCloudInitEdit(
        VirtCloudInit(user: 'sbxe', sshKeys: next.publicKey, address: addr, gateway: gw, dns: [gw, '1.1.1.1']),
      );
      expect(virtCloudInitEditIssue(ci, edit, host: VirtHostKind.pve), isNull);
      await pve.setCloudInit(g, ci, edit);
      final after = await pve.cloudInit(g);
      expect(after.sshKeys, [next.publicKey]);
      expect(after.dns, [gw, '1.1.1.1']);
      expect(after.passwordSet, isTrue);
      // The drive was written again at once: nothing waits for a start.
      final pending = await sh('pvesh get /nodes/$node/qemu/$id/cloudinit --output-format json');
      expect(pending, isNot(contains('"pending"')), reason: pending);
      // The same edit from the old read: refused.
      expect((await _virtErr(pve.setCloudInit(g, ci, edit))).type, VirtErrType.conflict);
      expect(await _guestLetsIn(client!, ip, 'sbxe', next.key), isFalse);

      await _guestRun(client!, ip, 'sbxe', login.key, '(sleep 1; sudo -n reboot) >/dev/null 2>&1 &');
      await Future<void>.delayed(const Duration(seconds: 10));
      final rebooted = await _guestFacts(client!, ip, 'sbxe', next.key, 'sda', login.password);
      expect(rebooted['iid'], isNot(before['iid']));
      expect(rebooted['hostkey'], isNot(before['hostkey']));
      // The password kept: set again by the new instance (a new hash, with
      // a salt of its own), the same password.
      expect(rebooted['pw'], 'ok');
      // ignore: avoid_print
      print('PVE shadow hash before ${before['hash']!.substring(0, 3)}, after ${rebooted['hash']!.substring(0, 3)}');
      expect(await _guestRun(client!, ip, 'sbxe', next.key, 'cat /etc/resolv.conf; resolvectl dns 2>/dev/null'), contains('1.1.1.1'));
      final oldKeyIn = await _guestLetsIn(client!, ip, 'sbxe', login.key);
      // ignore: avoid_print
      print('PVE after the edit: iid=${rebooted['iid']} hostkey=${rebooted['hostkey']} old key in: $oldKeyIn');

      final running = await _settle(pve, id, (g) => g.state == VirtGuestState.running);
      await pve.power(running, VirtPowerAction.forceStop);
      await _afterStop();
      await _whileLocked(() async => pve.delete((await find())!));
      expect(await find(), isNull);
      expect(await sh('pvesm list ${storage.name} | grep -c "vm-$id-" || true'), contains('0'));
    }, timeout: const Timeout(Duration(minutes: 15)));
  });
}

/// External snapshots, the disk chain, the configuration diff and PVE's
/// per-storage support (phase 8). Everything it makes is named `sbxe2e*` and
/// removed at the end; the libvirt guest is the test's own, with a qcow2 disk
/// in a pool of its own, and PVE's VMs are made and destroyed within the run.
///
/// - `SBM_E2E_LIBVIRT_HOST`, as the other libvirt groups.
/// - `SBM_E2E_PVE_HOST` + token, as the other PVE groups: the token needs
///   `VM.Audit`, `VM.Snapshot`, `VM.Snapshot.Rollback`, `VM.Config.Memory`
///   (a change to diff against) and `Datastore.AllocateSpace`.
Future<void> _p8Snapshots() async {
  await _p8Libvirt();
  await _p8Pve();
}

Future<void> _p8Libvirt() async {
  final host = e2eEnv('SBM_E2E_LIBVIRT_HOST');
  if (host == null) return;
  final ready = await prepareReachableSshE2e(host);
  final target = ready.target;
  if (target == null) return;

  group('snapshots: external, chain and diff (libvirt over SSH)', () {
    SSHClient? client;
    late LibvirtBackend virt;
    final name = _e2eName('snap');
    // Under /var/lib/libvirt/images: an AppArmor host's `virt-aa-helper`
    // reads any file there, which a revert's new overlay (named without an
    // extension) needs — elsewhere the app refuses the revert.
    final stamp = name.substring(name.lastIndexOf('-') + 1);
    final poolName = 'sbxe2e-p8i-$stamp';
    final poolDir = '/var/lib/libvirt/images/$poolName';
    late VirtStoragePool pool;
    VirtGuest? guest;

    // Two more guests of the run's own: one with two disks, one in a pool
    // outside the directories libvirt's AppArmor helper reads.
    final twoDisks = '$name-2';
    final outside = '$name-o';
    final outsideName = 'sbxe2e-p8o-$stamp';
    final outsideDir = '/var/lib/$outsideName';

    // What this run made, recorded once made: teardown removes these only.
    final ownedGuests = <String>{};
    final ownedPools = <(String, String)>{};

    Future<VirtGuest?> findNamed(String n) async =>
        (await virt.load()).guests.where((g) => g.name == n).firstOrNull;
    Future<VirtGuest?> find() => findNamed(name);

    Future<VirtGuest> settleNamed(String n, bool Function(VirtGuest g) test) async {
      for (var i = 0; i < 60; i++) {
        final g = await findNamed(n);
        if (g != null && test(g)) return g;
        await Future<void>.delayed(const Duration(milliseconds: 500));
      }
      fail('$n never settled');
    }

    Future<VirtGuest> settle(bool Function(VirtGuest g) test) => settleNamed(name, test);

    Future<String> onHost(String command) async {
      final session = await client!.execute(command);
      final (out, err) = await (
        utf8.decodeStream(session.stdout),
        utf8.decodeStream(session.stderr),
      ).wait;
      await session.done;
      expect(session.exitCode, 0, reason: '$command\n$out$err');
      return out;
    }

    setUpAll(() async {
      await initRustLibForTest();
      final c = await connectSshE2e(target, ready.identities);
      client = c;
      virt = LibvirtBackend(
        serverId: 'e2e-libvirt-snap',
        exec: () async => SshExec(c),
      );
      // None of the names is taken: a guest or pool answering to one is
      // someone else's.
      final taken = (await virt.load()).guests.map((g) => g.name).toSet();
      expect(taken.intersection({name, twoDisks, outside}), isEmpty);
      final pools = (await virt.storagePools()).map((p) => p.name).toSet();
      expect(pools.intersection({poolName, outsideName}), isEmpty);
      // A pool of the test's own, so nothing it makes is left in `images`.
      // `mkdir` without `-p`: a directory there already is not this run's.
      await onHost("mkdir '$poolDir'");
      await virt.manage(
        VirtPoolCreate(name: poolName, type: 'dir', source: poolDir),
      );
      ownedPools.add((poolName, poolDir));
      pool = (await virt.storagePools()).firstWhere((p) => p.name == poolName);
    });
    tearDownAll(() async {
      for (final n in ownedGuests) {
        try {
          final g = await findNamed(n);
          if (g != null) {
            if (g.state != VirtGuestState.stopped) {
              await virt.power(g, VirtPowerAction.forceStop);
            }
            await virt.delete((await findNamed(n))!, removeDisks: true);
          }
        } catch (_) {}
      }
      // The pools the run made, now empty: their volumes went with the
      // guests.
      for (final (p, dir) in ownedPools) {
        try {
          await onHost(
            "virsh --connect qemu:///system -q pool-destroy '$p'; "
            "virsh --connect qemu:///system -q pool-undefine '$p'; "
            "rmdir '$dir'",
          );
        } catch (_) {}
      }
      try {
        await virt.close();
      } catch (_) {}
      client?.close();
    });

    test('a disk-only snapshot while running: chain read back, diff, revert',
        () async {
      final snap = await virt.load();
      expect(snap.capabilities.snapshotExternal, isTrue);
      // A guest of the test's own with a qcow2 disk in the test's pool: the
      // run must not touch anyone else's.
      final spec = VirtCreateSpec(
        kind: VirtGuestKind.qemu,
        name: name,
        cores: 1,
        memoryMiB: 256,
        storage: pool,
        diskGiB: 1,
        start: true,
      );
      await virt.create(spec);
      ownedGuests.add(name);
      guest = await settle((g) => g.state == VirtGuestState.running);
      final before = (await virt.snapshotChain(guest!)).disks.single;
      expect(before.isChain, isFalse, reason: 'a plain qcow2 disk to start');
      expect(
        await virt.snapshotSupported(guest!),
        isTrue,
        reason: 'a qcow2 disk can be overlaid',
      );

      // The external snapshot: disk-only, while the guest runs.
      final guestId = guest!.id;
      await virt.createSnapshot(
        guest!,
        name: 'sbxe2e-ext1',
        description: 'external one',
        form: VirtSnapshotForm.external,
      );
      final stillRunning = (await virt.load()).guests
          .firstWhere((g) => g.id == guestId);
      expect(
        stillRunning.state,
        VirtGuestState.running,
        reason: 'a disk-only snapshot does not stop the guest',
      );
      final after = await virt.snapshotChain(stillRunning);
      expect(after.depth, 2);
      expect(after.disks.single.isChain, isTrue);
      expect(after.disks.single.files.first.format, 'qcow2');
      expect(
        after.disks.single.files.first.backing,
        before.files.first.path,
        reason: 'the overlay backs the file the guest was on',
      );
      expect(after.disks.single.files.last.path, before.files.first.path);

      // It is listed like any snapshot, and carries the file it was left on.
      final snaps = await virt.snapshots(stillRunning);
      final ext = snaps.singleWhere((s) => s.name == 'sbxe2e-ext1');
      expect(ext.external, isTrue);
      expect(ext.withMemory, isFalse);
      expect(ext.layers.single.file, after.disks.single.files.first.path);

      // The diff: change the definition, read what differs.
      final hw = await virt.hardware(stillRunning);
      await virt.changeHardware(
        stillRunning,
        hw,
        VirtHwSetMemory(mib: 512),
      );
      final diff = await virt.snapshotDiff(stillRunning, 'sbxe2e-ext1');
      expect(
        diff.any((d) => d.group == VirtSnapDiffGroup.memory),
        isTrue,
        reason: '$diff',
      );
      // Read again from the host, the change is still there.
      expect(
        await virt.snapshotDiff(
          (await virt.load()).guests.firstWhere((g) => g.id == guestId),
          'sbxe2e-ext1',
        ),
        isNotEmpty,
      );

      // A second snapshot deepens the chain.
      await virt.createSnapshot(
        stillRunning,
        name: 'sbxe2e-ext2',
        form: VirtSnapshotForm.external,
      );
      final deeper = await virt.snapshotChain(
        (await virt.load()).guests.firstWhere((g) => g.id == guestId),
      );
      expect(deeper.depth, 3);
      final ext1File = after.disks.single.files.first.path;
      expect(deeper.disks.single.files[1].path, ext1File);

      // Reverting to the newest (a leaf) drops the overlay the guest was
      // writing and starts it on a new one over the file ext2 kept (ext1's
      // overlay): as deep as before, on a file that was not there.
      await virt.revertSnapshot(stillRunning, 'sbxe2e-ext2', start: true);
      final reverted = await settle((g) => g.state == VirtGuestState.running);
      final back = (await virt.snapshotChain(reverted)).disks.single;
      expect(back.files, hasLength(3));
      expect(back.files.first.path, isNot(deeper.disks.single.files.first.path));
      expect(back.files.first.backing, ext1File);
      expect(back.files.first.format, 'qcow2');

      // The first snapshot has a child: its revert is refused by the app's
      // own rule before the host is asked.
      final left = await virt.snapshots(reverted);
      expect(
        left.singleWhere((s) => s.name == 'sbxe2e-ext1').hasChildren(left),
        isTrue,
      );
      expect(
        left.singleWhere((s) => s.name == 'sbxe2e-ext2').layers.single.file,
        back.files.first.path,
        reason: 'the snapshot now names the file the revert made',
      );

      // Deleting it commits the overlay into ext1's, which was a backing
      // file when QEMU started. On an AppArmor host the profile denies that
      // (`deny ... w`, Debian #932456) and the app refuses it before the
      // host is asked — the host would refuse it too, and mark the disk.
      // Elsewhere it goes, and the chain is one shorter.
      final confined = (await onHost(
        'cat /sys/module/apparmor/parameters/enabled 2>/dev/null || true',
      )).trim() == 'Y';
      try {
        await virt.deleteSnapshot(reverted, 'sbxe2e-ext2');
        expect(confined, isFalse, reason: 'the delete went through');
        final shorter = await virt.snapshotChain(
          (await virt.load()).guests.firstWhere((g) => g.id == guestId),
        );
        expect(shorter.depth, 2);
      } on VirtErr catch (e) {
        expect(confined, isTrue, reason: e.message);
        expect(e.type, VirtErrType.unsupported, reason: e.message);
        expect(e.message, contains('#932456'));
        expect(e.message, contains(ext1File));
        expect(
          (await virt.snapshots(reverted)).map((s) => s.name),
          contains('sbxe2e-ext2'),
        );
        // Nothing was sent: no snapshot is marked by a failed delete.
        final marked = await onHost(
          'for s in sbxe2e-ext1 sbxe2e-ext2; do virsh -q snapshot-dumpxml '
          "--domain '$name' --snapshotname \$s; done | "
          'grep -c snapshotDeleteInProgress || true',
        );
        expect(marked.trim(), '0');
      }
    });

    test('pending changes discarded; refused once the guest ran its definition', () async {
      var g = (await find())!;
      expect(g.state, VirtGuestState.running);
      final before = await virt.hardware(g);
      await virt.changeHardware(g, before, VirtHwSetMemory(mib: before.memory.mib + 128));
      final pending = await virt.hardware(g);
      expect(pending.pending.map((p) => p.key), contains('memory'));
      await virt.revertPending(g, pending);
      final back = await virt.hardware(g);
      expect(back.pending, isEmpty);
      expect(back.memory.mib, before.memory.mib);

      // Pending again, read, and then the guest stopped and started — it
      // now runs its definition, and the running XML that was read is not
      // its any more: writing it back would undo the applied change.
      await virt.changeHardware(g, back, VirtHwSetMemory(mib: before.memory.mib + 128));
      final stale = await virt.hardware(g);
      await onHost(
        "virsh --connect qemu:///system -q destroy '$name' && "
        "virsh --connect qemu:///system -q start '$name'",
      );
      g = await settle((g) => g.state == VirtGuestState.running);
      final e = await _virtErr(virt.revertPending(g, stale));
      expect(e.type, VirtErrType.conflict, reason: e.message);
      expect((await virt.hardware(g)).memory.mib, before.memory.mib + 128);
    });

    test('a raw disk is refused before anything is sent', () async {
      final snap = await virt.load();
      final guest = snap.guests.firstWhere((g) => g.name == name);
      // Read the chain of a guest that is not this one: the host's own raw
      // disks are none of this test's business, so what is checked is the
      // rule itself over a chain the app built.
      final chain = await virt.snapshotChain(guest);
      if (chain.refusal case final why?) {
        expect(why, isNotEmpty);
      }
      // The refusal of a raw disk is the parser's own rule, covered by the
      // Rust tests; here it is only that the read answers.
      expect(chain.disks, isNotEmpty);
    });

    test('two writable disks: both overlaid and reverted; an internal '
        'snapshot after the external ones, reverted to; nothing left', () async {
      final spec = VirtCreateSpec(
        kind: VirtGuestKind.qemu,
        name: twoDisks,
        cores: 1,
        memoryMiB: 256,
        storage: pool,
        diskGiB: 1,
      );
      await virt.create(spec);
      ownedGuests.add(twoDisks);
      var g = await settleNamed(twoDisks, (g) => g.state == VirtGuestState.stopped);
      await virt.changeHardware(g, await virt.hardware(g), VirtHwAddDisk(storage: pool, gib: 1));
      await virt.power(g, VirtPowerAction.start);
      g = await settleNamed(twoDisks, (g) => g.state == VirtGuestState.running);
      final plain = await virt.snapshotChain(g);
      expect(plain.disks, hasLength(2));
      expect(plain.disks.every((d) => !d.isChain), isTrue);

      // One external snapshot overlays every writable disk, in the pool.
      await virt.createSnapshot(g, name: 'sbxe2e-m1', form: VirtSnapshotForm.external);
      final m1 = await virt.snapshotChain(g);
      expect(m1.depth, 2);
      for (final (i, d) in m1.disks.indexed) {
        expect(d.isChain, isTrue, reason: d.target);
        expect(d.files.first.backing, plain.disks[i].files.first.path);
        expect(d.files.first.path, startsWith('$poolDir/'));
      }
      final m1Snap = (await virt.snapshots(g)).singleWhere((s) => s.name == 'sbxe2e-m1');
      expect(m1Snap.layers, hasLength(2));

      // Reverted to (a leaf): both disks on new overlays over the files the
      // snapshot kept.
      await virt.revertSnapshot(g, 'sbxe2e-m1', start: true);
      g = await settleNamed(twoDisks, (g) => g.state == VirtGuestState.running);
      final back = await virt.snapshotChain(g);
      for (final (i, d) in back.disks.indexed) {
        expect(d.files, hasLength(2), reason: d.target);
        expect(d.files.first.path, isNot(m1.disks[i].files.first.path));
        expect(d.files.first.backing, plain.disks[i].files.first.path);
      }

      // An internal snapshot on the overlays, with the memory; an external
      // one over it; then back to the internal one — libvirt puts the disks
      // on the files the internal snapshot is in (verified by hand on
      // libvirt 11.3: an internal revert after an external one is allowed).
      await virt.createSnapshot(g, name: 'sbxe2e-i1', form: VirtSnapshotForm.internal);
      await virt.createSnapshot(g, name: 'sbxe2e-m2', form: VirtSnapshotForm.external);
      final m2 = await virt.snapshotChain(g);
      expect(m2.depth, 3);
      final snaps = await virt.snapshots(g);
      final i1 = snaps.singleWhere((s) => s.name == 'sbxe2e-i1');
      expect((i1.external, i1.withMemory), (false, true));
      await virt.revertSnapshot(g, 'sbxe2e-i1');
      g = await settleNamed(twoDisks, (g) => g.state == VirtGuestState.running);
      final onI1 = await virt.snapshotChain(g);
      for (final (i, d) in onI1.disks.indexed) {
        expect(d.files.first.path, back.disks[i].files.first.path, reason: d.target);
      }

      // m2 is now on a branch the guest left: nothing to commit, so no
      // refusal. libvirt deletes it keeping its overlays, which the app
      // deletes with it.
      final m2Files = [for (final d in m2.disks) d.files.first.path];
      await virt.deleteSnapshot(g, 'sbxe2e-m2');
      expect((await virt.snapshots(g)).map((s) => s.name), isNot(contains('sbxe2e-m2')));
      for (final f in m2Files) {
        expect(await onHost("ls '$f' 2>/dev/null || true"), isEmpty, reason: f);
      }

      // Another branch left the same way, kept: deleting the guest takes
      // its overlays below.
      await virt.createSnapshot(g, name: 'sbxe2e-m3', form: VirtSnapshotForm.external);
      final m3Files = [for (final d in (await virt.snapshotChain(g)).disks) d.files.first.path];
      await virt.revertSnapshot(g, 'sbxe2e-i1');
      g = await settleNamed(twoDisks, (g) => g.state == VirtGuestState.running);
      for (final f in m3Files) {
        expect(await onHost("ls '$f'"), contains(f));
      }

      // Shut off, a delete of the external snapshot on the chain is refused
      // on an AppArmor host before anything is sent (the commit would be
      // denied).
      await virt.power(g, VirtPowerAction.forceStop);
      g = await settleNamed(twoDisks, (g) => g.state == VirtGuestState.stopped);
      final confined = (await onHost(
        'cat /sys/module/apparmor/parameters/enabled 2>/dev/null || true',
      )).trim() == 'Y';
      if (confined) {
        final e = await _virtErr(virt.deleteSnapshot(g, 'sbxe2e-m1'));
        expect(e.type, VirtErrType.unsupported, reason: e.message);
        expect(e.message, contains('shut off'));
        expect((await virt.snapshots(g)).map((s) => s.name), contains('sbxe2e-m1'));
      }

      // Deleted with its disks: every file of every snapshot goes, the
      // overlays the internal revert left behind among them.
      await virt.delete(g, removeDisks: true);
      ownedGuests.remove(twoDisks);
      expect(await findNamed(twoDisks), isNull);
      await virt.manage(VirtPoolRefresh(pool));
      final left = [
        for (final v in await virt.volumes((await virt.storagePools()).firstWhere((p) => p.name == poolName)))
          if (v.name.startsWith(twoDisks)) v.path,
      ];
      expect(left, isEmpty);
      expect(await onHost("ls '$poolDir' | grep -c '^$twoDisks' || true"), startsWith('0'));
    }, timeout: const Timeout(Duration(minutes: 5)));

    test('a pool outside the AppArmor helper\'s directories: the revert '
        'refused before anything is sent', () async {
      final confined = (await onHost(
        'cat /sys/module/apparmor/parameters/enabled 2>/dev/null || true',
      )).trim() == 'Y';
      await onHost("mkdir '$outsideDir'");
      await virt.manage(VirtPoolCreate(name: outsideName, type: 'dir', source: outsideDir));
      ownedPools.add((outsideName, outsideDir));
      final opool = (await virt.storagePools()).firstWhere((p) => p.name == outsideName);
      await virt.create(VirtCreateSpec(
        kind: VirtGuestKind.qemu,
        name: outside,
        cores: 1,
        memoryMiB: 256,
        storage: opool,
        diskGiB: 1,
        start: true,
      ));
      ownedGuests.add(outside);
      var g = await settleNamed(outside, (g) => g.state == VirtGuestState.running);
      await virt.createSnapshot(g, name: 'sbxe2e-o1', form: VirtSnapshotForm.external);
      final before = await virt.snapshotChain(g);
      expect(before.depth, 2);
      final top = before.disks.single.files.first.path;
      expect(top, startsWith('$outsideDir/'));
      if (!confined) {
        // Nothing to refuse without AppArmor: the revert goes through.
        await virt.revertSnapshot(g, 'sbxe2e-o1', start: true);
      } else {
        final e = await _virtErr(virt.revertSnapshot(g, 'sbxe2e-o1', start: true));
        expect(e.type, VirtErrType.unsupported, reason: e.message);
        expect(e.message, contains('AppArmor'));
        // Nothing sent: still running, on the same overlay.
        g = (await findNamed(outside))!;
        expect(g.state, VirtGuestState.running);
        expect((await virt.snapshotChain(g)).disks.single.files.first.path, top);
      }
      await virt.power((await findNamed(outside))!, VirtPowerAction.forceStop);
      g = await settleNamed(outside, (g) => g.state == VirtGuestState.stopped);
      await virt.delete(g, removeDisks: true);
      ownedGuests.remove(outside);
      expect(await findNamed(outside), isNull);
      expect(await onHost("ls -A '$outsideDir'"), isEmpty);
      await virt.manage(VirtPoolDelete((await virt.storagePools()).firstWhere((p) => p.name == outsideName)));
      await onHost("rmdir '$outsideDir'");
      ownedPools.remove((outsideName, outsideDir));
    }, timeout: const Timeout(Duration(minutes: 5)));

    test('deleting the guest takes the files its snapshots left', () async {
      final g = await find();
      expect(g, isNotNull);
      if (g!.state != VirtGuestState.stopped) {
        await virt.power(g, VirtPowerAction.forceStop);
      }
      final stopped = await settle((g) => g.state == VirtGuestState.stopped);
      await virt.delete(stopped, removeDisks: true);
      ownedGuests.remove(name);
      expect(await find(), isNull);
      // The pool is the run's own: nothing of the guest is left in it.
      await virt.manage(VirtPoolRefresh(pool));
      final pools = await virt.storagePools();
      final vols = await virt.volumes(pools.firstWhere((p) => p.name == poolName));
      expect(vols, isEmpty, reason: '${vols.map((v) => v.path)}');
    });
  });
}

Future<void> _p8Pve() async {
  final host = e2eEnv('SBM_E2E_PVE_HOST');
  final tokenId = e2eEnv('SBM_E2E_PVE_TOKEN_ID');
  final tokenSecret = e2eEnv('SBM_E2E_PVE_TOKEN_SECRET');
  if (host == null || tokenId == null || tokenSecret == null) return;
  final ready = await prepareReachableSshE2e(host);
  final target = ready.target;
  if (target == null) return;

  group('snapshots: storage support and the config diff (PVE over SSH)', () {
    SSHClient? client;
    late PveBackend pve;
    // Ids PVE hands out as free, never a guessed range: a teardown destroys
    // what is at them.
    late int vmid;
    late String name;
    var made = false;
    VirtGuest? created;

    Future<void> onNode(String command) async {
      final session = await client!.execute(command);
      final (out, err) = await (
        utf8.decodeStream(session.stdout),
        utf8.decodeStream(session.stderr),
      ).wait;
      await session.done;
      if (session.exitCode != 0) fail('$command\n$out$err');
    }

    Future<VirtGuest> settle(bool Function(VirtGuest g) test) async {
      for (var i = 0; i < 60; i++) {
        final g = (await pve.load()).guests
            .where((g) => g.vmid == vmid)
            .firstOrNull;
        if (g != null && test(g)) return g;
        await Future<void>.delayed(const Duration(milliseconds: 500));
      }
      fail('$name never settled');
    }

    String? pin;
    setUpAll(() async {
      await initRustLibForTest();
      final c = await connectSshE2e(target, ready.identities);
      client = c;
      // The same loopback-over-SSH path the other PVE groups use, with the
      // certificate pinned on first use.
      final directAddr =
          e2eEnv('SBM_E2E_PVE_ADDR') ?? 'https://${target.hostname}:8006';
      final entry = _pvePaths(target, () => c, directAddr)['over SSH']!;
      final dialer = entry.dialer();
      pve = PveBackend(
        serverId: 'e2e-pve-p8',
        config: PveConfig(
          addr: entry.addr,
          auth: PveAuth.token,
          tokenId: tokenId,
          tokenSecret: tokenSecret,
          certSha256: pin,
        ),
        tunnel: dialer.loopback,
        connect: dialer.startConnect,
        onClose: dialer.close,
        taskPoll: const Duration(milliseconds: 500),
        taskTimeout: const Duration(minutes: 3),
      );
      final e = await _virtErr(pve.load());
      if (e.type == VirtErrType.certUnconfirmed) {
        await pve.confirmCert(e.cert!.fingerprint);
        pin = pve.config.certSha256;
      }
      // A VM of the test's own on a storage that supports snapshots.
      vmid = (await pve.nextVmid())!;
      name = 'sbxe2e-p8-$vmid';
      await onNode(
        'qm create $vmid --name $name --memory 512 --cores 1 '
        '--net0 virtio,bridge=vmbr0 --scsihw virtio-scsi-pci --ostype l26',
      );
      made = true;
      await onNode('qm set $vmid --scsi0 local-lvm:1');
      created = await settle((_) => true);
    });
    tearDownAll(() async {
      try {
        if (made) {
          await onNode('qm stop $vmid --overrule-shutdown 1 || true');
          await onNode('qm destroy $vmid --purge 1 || true');
        }
      } catch (_) {}
      try {
        await pve.close();
      } catch (_) {}
      client?.close();
    });

    test('a thin storage supports snapshots; the diff reads a real change',
        () async {
      final guest = created!;
      expect(await pve.snapshotSupported(guest), isTrue);
      expect(await pve.snapshotRefusal(guest), isNull);

      await pve.createSnapshot(guest, name: 'sbxe2e-p8a', description: 'one');
      final snaps = await pve.snapshots(guest);
      expect(snaps.any((s) => s.name == 'sbxe2e-p8a'), isTrue);

      // Change the memory in the configuration, then read the diff.
      final hw = await pve.hardware(guest);
      await pve.changeHardware(
        guest,
        hw,
        VirtHwSetMemory(mib: 1024),
      );
      final diff = await pve.snapshotDiff(guest, 'sbxe2e-p8a');
      final mem = diff.where((d) => d.group == VirtSnapDiffGroup.memory);
      expect(mem, isNotEmpty, reason: '$diff');
      expect(mem.first.after, isNotNull);

      await pve.deleteSnapshot(guest, 'sbxe2e-p8a');
      expect(
        (await pve.snapshots(guest)).any((s) => s.name == 'sbxe2e-p8a'),
        isFalse,
      );
    });

    test('a raw disk on a directory storage is refused before the task',
        () async {
      // A second VM whose disk is raw on a `dir` storage: PVE's own feature
      // answer says no, and the app refuses before starting a task.
      final rawId = (await pve.nextVmid())!;
      final rawName = 'sbxe2e-p8r-$rawId';
      final dir = '/var/lib/$rawName';
      // A directory there already is someone else's: the teardown below
      // removes it.
      await onNode('test ! -e $dir');
      await onNode('pvesm add dir $rawName --path $dir --content images');
      addTearDown(() async {
        await onNode('pvesm remove $rawName || true');
        await onNode('rm -rf $dir');
      });
      await onNode('mkdir -p $dir');
      await onNode(
        'qm create $rawId --name $rawName --memory 512 --cores 1 '
        '--net0 virtio,bridge=vmbr0 --scsihw virtio-scsi-pci --ostype l26',
      );
      addTearDown(() async {
        await onNode('qm stop $rawId --overrule-shutdown 1 || true');
        await onNode('qm destroy $rawId --purge 1 || true');
      });
      await onNode('qm set $rawId --scsi0 $rawName:1,format=raw');
      final raw = (await pve.load()).guests
          .where((g) => g.vmid == rawId)
          .firstOrNull;
      expect(raw, isNotNull);
      expect(
        await pve.snapshotSupported(raw!),
        isFalse,
        reason: 'a raw disk on a dir storage cannot be snapshotted',
      );
      final why = await pve.snapshotRefusal(raw);
      expect(why, contains('snapshot feature is not available'));
      expect(why, contains(rawName));
      final e = await _virtErr(pve.createSnapshot(raw, name: 'sbxe2e-p8raw'));
      expect(e.type, VirtErrType.unsupported);
    });
  });
}
