/// Opt-in end-to-end test of the Virtualization tab over a `monitor` agent,
/// against real hosts, through the providers the app itself uses: a server
/// that carries *only* agent credentials, put in the store, so
/// `ServerNotifier.ensureExec()` answers `MonitorExec` (`POST /api/v1/exec`),
/// `ServerTcpDialer` relays over `/api/v1/stream/ws`, and the terminal opens
/// the agent's own PTY. No fakes below `VirtHostNotifier`.
///
/// Every group is skipped silently unless its variables are set, in the
/// environment or the workspace-root `.env` (never commit secrets there):
///
/// - `SBM_E2E_MONITOR_USER` (default `admin`): the panel account, the same on
///   every agent below.
/// - `SBM_E2E_MONITOR_LIBVIRT_ADDR`, `SBM_E2E_MONITOR_LIBVIRT_PASSWORD` — an
///   agent on a libvirt host (`https://host:3770`), with
///   `remote_access.full_access` and `[remote_access.terminal] enabled` on.
///   The host needs the domains `virt_real_test.dart` describes
///   (`SBM_E2E_LIBVIRT_RUNNING` / `_PAUSED` / `_STOPPED`, same defaults);
///   only the paused one is changed (resumed and paused again), and the
///   stopped one gets a snapshot `sbxe2e-agent`, deleted again.
///   A group of its own defines a throwaway domain `sbme2e-vncpw-*` (no disk,
///   a VNC display with a made-up password), connects the real VNC engine to
///   it through the authenticated loopback, and removes it again.
/// - `SBM_E2E_MONITOR_SUDO_PASSWORD` — the sudo password of the account the
///   libvirt agent runs as, for an account outside the `libvirt` group (what
///   `install.sh` sets up: an ordinary user). Then the listing goes through
///   `permission_denied` → `sudoPasswordRequired` → sudo, and the serial
///   console is typed as `sudo virsh console`. Unset: the account must reach
///   `qemu:///system` itself, and the sudo path is not exercised.
/// - `SBM_E2E_MONITOR_PVE_ADDR`, `SBM_E2E_MONITOR_PVE_PASSWORD` — an agent on a
///   Proxmox VE node with the same grants. The API is reached through its
///   relay at `https://localhost:8006`. Also needs `SBM_E2E_PVE_TOKEN_ID` and
///   `SBM_E2E_PVE_TOKEN_SECRET` (as in `virt_real_test.dart`), and uses
///   `SBM_E2E_PVE_LXC` (default `200`, **rebooted**, its getty typed into) and
///   `SBM_E2E_PVE_VM` (default `100`, only its VNC console is opened).
///   With `SBM_E2E_PVE_TEST_VM` (and optionally
///   `SBM_E2E_PVE_TEST_VM_ROOT_PASSWORD`) set as in `virt_real_test.dart`,
///   that VM's power cycle, consoles and detail run through the relay too,
///   and it is **left stopped**.
/// - `SBM_E2E_MONITOR_RESTRICTED_ADDR`, `SBM_E2E_MONITOR_RESTRICTED_PASSWORD`
///   (default: the libvirt one) — an agent with `full_access` **off**: the
///   typed refusals for commands and for the relay.
///
/// The "clone" groups clone a throwaway VM of their own (libvirt: a full copy
/// and one with empty disks; PVE: a full clone) and, on PVE, back it up, list
/// the backup, restore it as a new VM and over the VM, and delete it. Every
/// guest and backup they make is deleted again.
///
/// The "create and delete" groups make guests named `sbme2e-*` and delete
/// them again, disks included: a VM on libvirt (in the first pool that takes
/// a disk, with an ISO found in any pool as its CD-ROM), and on PVE a VM (an
/// ISO from a storage holding them, if there is one) and a container (from
/// the first template there is). They touch no other guest.
///
/// With `SBM_E2E_LIBVIRT_CLOUD_IMAGE` (a cloud image's path on the libvirt
/// host; `SBM_E2E_LIBVIRT_DISK_POOL` for the disk's pool) the "cloud-init"
/// group makes a VM `sbme2e-ci-*` from it with a seed, reads the seed back,
/// writes it anew and deletes the VM — through the agent, and so through
/// sudo for an account outside the `libvirt` group.
///
/// The phase-10 groups make a network `sbme2e-net-*` (libvirt) or
/// `sbxe2e*` (PVE), edit it, restart it where the change needs one, and
/// take it away; the libvirt one also discards a pending change from a
/// guest of the run's own. `SBM_E2E_PVE_TOKEN_ID` / `_SECRET` are needed for
/// the PVE group as they are for the other PVE ones, and its server carries
/// the agent's credentials plus that `PveConfig` (the API is reached
/// through the relay at `https://localhost:8006`).
///
/// The PVE group of what earlier runs left unverified also needs
/// `SBM_E2E_PVE_HOST` (the node over the system `ssh`, as root: `qm config`,
/// a disk filled, a cloud image converted, and a root@pam ticket the node
/// issues, which stands in for root's password — PVE gives only that
/// account a raw USB device). With `SBM_E2E_PVE_CLOUD_IMAGE`, `_ADDR` and
/// `_GW` (as in `virt_real_test.dart`) it boots VMs `sbxe2e-l-*` (VMIDs
/// 970-979) from that image — one on SATA with Secure Boot, one from a
/// `vmdk` made of it next to it in the `import` directory — and logs in to
/// them through the agent's relay; with `SBM_E2E_PVE_USB` it adds that
/// device to a **stopped** VM by vendor/product and by address and takes it
/// off again, never starting it. A backup job `sbxe2e-l-*` is made, run and
/// deleted with its backup. Everything it makes is removed.
///
/// Every agent is expected to serve TLS with a certificate this device does
/// not trust (`[server.tls]` with a self-signed pair), so the credential sets
/// `ignoreCert`. Plain HTTP would need both opt-ins (`allowInsecure` here,
/// `terminal.allow_insecure` there) and is not what a deployment should use.
///
/// Run with `flutter test test/e2e/virt_monitor_test.dart`, after
/// `cargo build -p sbm_ffi`.
@Timeout(Duration(minutes: 10))
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:dartssh2/dartssh2.dart';
import 'package:fl_lib/fl_lib.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' as riverpod show Provider;
import 'package:flutter_test/flutter_test.dart';
import 'package:pointycastle/export.dart' show DESedeEngine, KeyParameter;
import 'package:server_box/core/utils/monitor_terminal.dart';
import 'package:server_box/core/utils/privileged_exec.dart';
import 'package:server_box/core/utils/server_tcp.dart';
import 'package:server_box/data/model/app/error.dart';
import 'package:server_box/data/model/server/monitor_http_credential.dart';
import 'package:server_box/data/model/server/pve_config.dart';
import 'package:server_box/data/model/server/server_private_info.dart';
import 'package:server_box/data/model/server/shell_backend.dart';
import 'package:server_box/data/model/virt/virt.dart';
import 'package:server_box/data/model/virt/virt_backup.dart';
import 'package:server_box/data/model/virt/virt_create.dart';
import 'package:server_box/data/model/virt/virt_detail.dart';
import 'package:server_box/data/model/virt/virt_hardware.dart';
import 'package:server_box/data/model/virt/virt_manage.dart';
import 'package:server_box/data/model/virt/virt_resources.dart';
import 'package:server_box/data/provider/remote_desktop.dart';
import 'package:server_box/data/provider/server/single.dart';
import 'package:server_box/data/provider/virt/libvirt_backend.dart';
import 'package:server_box/data/provider/virt/pve_backend.dart';
import 'package:server_box/data/provider/virt/virt.dart';
import 'package:server_box/data/res/store.dart';
import 'package:server_box/data/ssh/terminal_session.dart';
import 'package:server_box/src/rust/api/remote_desktop.dart' as ffi;
import 'package:server_box/view/page/virt/console_connect.dart';

import '../helpers/rust_lib_helper.dart';
import '../helpers/ssh_e2e.dart';
import '../helpers/tunnel_client.dart';

Future<void> main() async {
  TestWidgetsFlutterBinding.ensureInitialized();

  final user = e2eEnv('SBM_E2E_MONITOR_USER') ?? 'admin';
  final libvirt = await _Agent.probe('LIBVIRT', user);
  final pve = await _Agent.probe('PVE', user);
  final restricted = await _Agent.probe(
    'RESTRICTED',
    user,
    fallbackPassword: e2eEnv('SBM_E2E_MONITOR_LIBVIRT_PASSWORD'),
  );
  if (libvirt == null && pve == null && restricted == null) {
    test(
      'virt over monitor e2e',
      () {},
      skip: 'no SBM_E2E_MONITOR_*_ADDR / _PASSWORD pair is set, or no agent answers',
    );
    return;
  }

  late Directory tempDir;
  setUpAll(() async {
    // The binding answers every HttpClient request with a 400 of its own;
    // these requests are the point.
    HttpOverrides.global = null;
    await initRustLibForTest();
    tempDir = await Directory.systemTemp.createTemp('sbm-virt-monitor-');
    Paths.doc = tempDir.path;
    SqliteDb.openInMemory();
    await Stores.init();
  });
  tearDownAll(() async {
    await getIt.reset();
    await SqliteDb.close();
    await tempDir.delete(recursive: true);
  });

  // Before the groups that change the existing guests, and standing alone:
  // `--plain-name 'create and delete'` runs only these.
  if (libvirt != null) _libvirtCreate(libvirt);
  if (libvirt != null) _libvirtCloudInit(libvirt);
  if (libvirt != null) _libvirtVncPassword(libvirt);
  if (libvirt != null) _libvirtHardware(libvirt);
  if (libvirt != null) _libvirtHardwareDevices(libvirt);
  if (libvirt != null) _libvirtClone(libvirt);
  if (libvirt != null) _p10LibvirtNetwork(libvirt);
  if (libvirt != null) _p10LibvirtRevert(libvirt);
  if (pve != null) _p8Pve(pve);
  if (pve != null) _pveCreate(pve);
  if (pve != null) _pveCloneBackup(pve);
  if (pve != null) _p10PveNetwork(pve);
  if (pve != null) _pveHardware(pve);
  if (pve != null) _pveHardwareDevices(pve);
  if (pve != null) _pveUnverified(pve);
  if (libvirt != null) {
    _libvirt(libvirt);
  } else {
    test(
      'libvirt over monitor',
      () {},
      skip: 'SBM_E2E_MONITOR_LIBVIRT_* unset, or its agent is not reachable',
    );
  }
  if (libvirt != null) _p8Libvirt(libvirt);

  if (pve != null) {
    _pve(pve);
    _pveTestVm(pve);
  } else {
    test(
      'PVE over monitor',
      () {},
      skip: 'SBM_E2E_MONITOR_PVE_* unset, or its agent is not reachable',
    );
  }
  if (restricted != null) {
    _restricted(restricted);
  } else {
    test(
      'agent without full access',
      () {},
      skip: 'SBM_E2E_MONITOR_RESTRICTED_* unset, or its agent is not reachable',
    );
  }
}

/// One agent's address and panel login.
class _Agent {
  const _Agent(this.addr, this.user, this.password);

  final String addr;
  final String user;
  final String password;

  static _Agent? fromEnv(String name, String user, {String? fallbackPassword}) {
    final addr = e2eEnv('SBM_E2E_MONITOR_${name}_ADDR');
    final password =
        e2eEnv('SBM_E2E_MONITOR_${name}_PASSWORD') ?? fallbackPassword;
    if (addr == null || password == null) return null;
    return _Agent(addr, user, password);
  }

  /// [fromEnv], and then whether the agent answers at all.
  ///
  /// These agents run on hosts that are virtual machines here, so the common
  /// case of a run that goes nowhere is a host left shut down. Every request
  /// to it then waits out its own timeout, one after another, for as long as
  /// the suite has groups — which reads as a hang. One bounded probe up front
  /// says which it is, and the group is skipped by name.
  ///
  /// A literal host address, so the check does not go through the same
  /// transport the suite is about to exercise.
  static Future<_Agent?> probe(
    String name,
    String user, {
    String? fallbackPassword,
  }) async {
    final agent = fromEnv(name, user, fallbackPassword: fallbackPassword);
    if (agent == null) return null;
    final uri = Uri.tryParse(agent.addr);
    final host = uri?.host;
    if (host == null || host.isEmpty) return agent;
    if (await e2eReachable(host, uri!.port)) return agent;
    // ignore: avoid_print
    print('SBM_E2E_MONITOR_${name}_ADDR ($host:${uri.port}) is not reachable');
    return null;
  }

  MonitorHttpCredential get credential => MonitorHttpCredential(
    addr: addr,
    user: user,
    pwd: password,
    // Self-signed `[server.tls]` on every test agent; see the header.
    ignoreCert: true,
  );

  /// A server reached through this agent and nothing else.
  Spi spi(String id) => Spi(id: id, name: id, monitorHttp: credential);
}

/// A server in the store and a container over it, as the app has them.
class _World {
  _World(this.spi) {
    Stores.server.put(spi);
    container = ProviderContainer();
  }

  final Spi spi;
  late final ProviderContainer container;

  String get id => spi.id;

  ServerNotifier get server => container.read(serverProvider(id).notifier);

  /// The status poll, which is also what reads the agent's grants.
  Future<void> poll() => server.refresh();

  /// The host, held for the length of the group.
  late final ProviderSubscription<VirtHostState> _hold = container.listen(
    virtHostProvider(id),
    (_, _) {},
  );

  VirtHostNotifier get host {
    _hold;
    return container.read(virtHostProvider(id).notifier);
  }

  VirtHostState get state => container.read(virtHostProvider(id));

  VirtGuest guest(bool Function(VirtGuest g) test, String what) =>
      state.data!.guests.firstWhere(test, orElse: () => fail('no $what'));

  /// Refreshes until [test] holds for the guest [what]: libvirt and PVE both
  /// report some changes a moment after the command returns.
  Future<VirtGuest> settle(
    bool Function(VirtGuest g) find,
    String what,
    bool Function(VirtGuest g) test,
  ) async {
    VirtGuest? g;
    for (var i = 0; i < 30; i++) {
      await host.refresh();
      expect(state.error, isNull, reason: '${state.error}');
      // Not listed yet is one more unsettled sample: PVE names a new guest
      // in `/cluster/resources` a moment after the task that made it.
      g = state.data!.guests.where(find).firstOrNull;
      if (g != null && test(g)) return g;
      await Future<void>.delayed(const Duration(milliseconds: 500));
    }
    fail('$what never settled; last: ${g?.state ?? 'not listed'}');
  }

  Future<void> dispose() async {
    container.dispose();
    Stores.server.deleteById(id);
    Stores.pve.remove(id);
  }
}

// -----------------------------------------------------------------------------
// libvirt
// -----------------------------------------------------------------------------

void _libvirt(_Agent agent) {
  final runningName = e2eEnv('SBM_E2E_LIBVIRT_RUNNING') ?? 'cirros-run';
  final pausedName = e2eEnv('SBM_E2E_LIBVIRT_PAUSED') ?? 'cirros-paused';
  final stoppedName = e2eEnv('SBM_E2E_LIBVIRT_STOPPED') ?? 'it\'s-"odd"';
  final sudoPassword = e2eEnv('SBM_E2E_MONITOR_SUDO_PASSWORD');

  group('libvirt over the monitor agent', () {
    late _World w;
    bool byName(VirtGuest g, String name) => g.name == name;

    setUpAll(() => w = _World(agent.spi('e2e-monitor-libvirt')));
    tearDownAll(() async {
      // The paused domain back to paused, whatever a failed test left.
      try {
        final exec = await w.server.ensureExec();
        await PrivilegedExec.run(
          exec,
          'LC_ALL=C virsh --connect qemu:///system -q suspend --domain '
          "'${pausedName.replaceAll("'", r"'\''")}' </dev/null",
          isRoot: false,
          password: sudoPassword,
        );
      } catch (_) {}
      await w.dispose();
    });

    test('the status poll reads the agent\'s grants', () async {
      await w.poll();
      final granted = w.container.read(serverProvider(w.id)).remoteAccess;
      expect(granted?.fullAccess, isTrue, reason: '$granted');
      expect(granted?.terminal, isTrue);
      expect(granted?.stream, isTrue);
    });

    test('ensureExec answers the agent', () async {
      final exec = await w.server.ensureExec();
      final r = await exec.run('id -un; id -Gn');
      expect(r.exitCode, 0, reason: r.stderr);
      // ignore: avoid_print
      print('libvirt agent runs as ${r.stdout.trim().replaceAll('\n', ' / ')}');
    });

    test('the host list finds libvirt through the agent', () async {
      await w.container.read(virtHostsProvider.notifier).probe(w.id);
      final probe = w.container.read(virtHostsProvider).probes[w.id];
      expect(probe?.status, VirtProbeStatus.found, reason: '${probe?.error}');
      expect(w.container.read(virtHostsProvider).hosts[w.id], VirtHostKind.libvirt);
    });

    test('load: through sudo when the agent\'s account is refused', () async {
      await w.host.firstLoad;
      final err = w.state.error;
      if (err == null) {
        // ignore: avoid_print
        print('the agent account reaches libvirt itself; sudo not exercised');
      } else {
        expect(err.type, VirtErrType.sudoPasswordRequired, reason: '$err');
        expect(
          (w.host.backend as LibvirtBackend).needsSudo,
          isTrue,
        );
        if (sudoPassword == null) {
          fail('libvirt wants sudo and SBM_E2E_MONITOR_SUDO_PASSWORD is unset');
        }
        // A wrong one first: refused, and said so.
        await w.host.provideSudoPassword('not-the-password');
        expect(w.state.error?.type, VirtErrType.sudoPasswordRejected);
        await w.host.provideSudoPassword(sudoPassword);
        expect(w.state.error, isNull, reason: '${w.state.error}');
      }

      final snap = w.state.data!;
      expect(snap.host.kind, VirtHostKind.libvirt);
      expect(snap.host.version, isNotNull);
      expect(snap.host.hypervisor, startsWith('QEMU '));
      final byNames = {for (final g in snap.guests) g.name: g};
      expect(byNames.keys, containsAll([runningName, pausedName, stoppedName]));
      final run = byNames[runningName]!;
      expect(run.state, VirtGuestState.running);
      expect(run.vcpu, greaterThan(0));
      expect(run.memBytes, greaterThan(0));
      expect(byNames[pausedName]!.state, VirtGuestState.paused);
      expect(byNames[stoppedName]!.state, VirtGuestState.stopped);
    });

    test('two samples give sane rates', () async {
      await w.host.reconnect();
      if (sudoPassword != null && w.state.error != null) {
        await w.host.provideSudoPassword(sudoPassword);
      }
      final id = w.guest((g) => byName(g, runningName), runningName).id;
      expect(w.state.data!.stats[id]?.cpu, isNull, reason: 'nothing to diff');
      await Future<void>.delayed(const Duration(seconds: 3));
      await w.host.refresh();
      final s = w.state.data!.stats[id]!;
      expect(s.cpu, inInclusiveRange(0, 100));
      expect(s.memUsed, greaterThan(0));
      for (final rate in [s.diskRead, s.diskWrite, s.netIn, s.netOut]) {
        expect(rate, isNotNull);
        expect(rate, inInclusiveRange(0, 100e6));
      }
    });

    test('detail: disks, NICs and a VNC display', () async {
      final run = w.guest((g) => byName(g, runningName), runningName);
      final detail = await w.host.detail(run.id);
      expect(detail.disks, isNotEmpty);
      expect(detail.nics, isNotEmpty);
      expect(detail.display?.protocol, 'vnc');
      expect(detail.consoles, {VirtConsoleKind.text, VirtConsoleKind.vnc});
    });

    test('storage, networks and snapshots through the agent (and sudo)',
        () async {
      final c = w.container;
      final pools = await c.read(virtStoragePoolsProvider(w.id).future);
      final active = pools.firstWhere(
        (p) => p.active && (p.volumeCount ?? 0) > 0,
        orElse: () => fail('no active pool with volumes'),
      );
      final vols = await c.read(
        virtVolumesProvider(w.id, active.id).future,
      );
      expect(vols, isNotEmpty);
      expect(vols.every((v) => v.format != null), isTrue);
      final nets = await c.read(virtNetworksProvider(w.id).future);
      expect(nets.map((n) => n.name), contains('default'));

      // A snapshot of the shut-off domain: taken, listed, deleted.
      final off = w.guest((g) => byName(g, stoppedName), stoppedName);
      await w.host.createSnapshot(off.id, name: 'sbxe2e-agent');
      final taken = await w.host.snapshots(off.id);
      final snap = taken.firstWhere((s) => s.name == 'sbxe2e-agent');
      expect(snap.withMemory, isFalse);
      await w.host.deleteSnapshot(off.id, 'sbxe2e-agent');
      expect(
        (await w.host.snapshots(off.id)).where((s) => s.name == 'sbxe2e-agent'),
        isEmpty,
      );
    });

    test('VNC console: RFB through the agent\'s TCP relay', () async {
      final run = w.guest((g) => byName(g, runningName), runningName);
      final target = await VirtConsoleConnect.vncTarget(
        w.container,
        serverId: w.id,
        guestId: run.id,
      )();
      expect(target.password, isNull);
      final rfb = _RfbReader(
        await connectTunnel(target.tunnel),
      );
      try {
        expect(ascii.decode(await rfb.take(12)), startsWith('RFB 003.00'));
      } finally {
        await rfb.close();
        await target.tunnel.close();
      }
    });

    test('serial console: typed into the agent\'s PTY, Ctrl+] leaves it',
        () async {
      final run = w.guest((g) => byName(g, runningName), runningName);
      final args = await VirtConsoleConnect.textArgs(
        w.container,
        serverId: w.id,
        guest: run,
      );
      final cmd = args.initCmd!;
      final viaSudo = (w.host.backend as LibvirtBackend).needsSudo;
      expect(cmd.startsWith('sudo '), viaSudo);
      expect(args.detachInput, VirtConsoleConnect.serialEscape);

      // What the terminal page does: connect the session's source, open its
      // shell, type the command.
      final session = TerminalSession(source: args.source);
      final backend = await session.connect();
      expect(backend, isA<MonitorShellBackend>());
      final shell = await backend.openShell(width: 80, height: 24);
      final out = _Collector(shell.stdout!);
      try {
        shell.write(utf8.encode('$cmd\r'));
        if (viaSudo) {
          await out.waitFor('password for');
          shell.write(utf8.encode('$sudoPassword\r'));
        }
        await out.waitFor('Escape character is');
        expect(out.text, contains('Connected to domain'));
        out.clear();
        shell.write(args.detachInput!);
        await out.waitFor('\n');
        await Future<void>.delayed(const Duration(milliseconds: 500));
        final marker = 'sbm-e2e-${Random().nextInt(1 << 30)}';
        shell.write(utf8.encode('echo "$marker-' r'$((6*7))"' '\r'));
        await out.waitFor('$marker-42');
      } finally {
        shell.close();
        backend.close();
        await out.cancel();
      }
    });

    test('power: resume and suspend the paused domain', () async {
      final paused = w.guest((g) => byName(g, pausedName), pausedName);
      await w.host.power(paused.id, VirtPowerAction.resume);
      final running = await w.settle(
        (g) => byName(g, pausedName),
        pausedName,
        (g) => g.state == VirtGuestState.running,
      );
      expect(running.stateReason, 'unpaused');
      await w.host.power(running.id, VirtPowerAction.suspend);
      final again = await w.settle(
        (g) => byName(g, pausedName),
        pausedName,
        (g) => g.state == VirtGuestState.paused,
      );
      expect(again.stateReason, 'user');
    });
  });
}

// -----------------------------------------------------------------------------
// A libvirt VNC display with a password
// -----------------------------------------------------------------------------

/// A throwaway domain of its own — no disk, a VNC display with a made-up
/// password — defined, started, and removed again: the existing domains are
/// not touched. Through the app's own path: the console read with
/// `--security-info`, the agent's relay behind an authenticated loopback, and
/// the real VNC engine presenting the tunnel's token and the password.
void _libvirtVncPassword(_Agent agent) {
  final sudoPassword = e2eEnv('SBM_E2E_MONITOR_SUDO_PASSWORD');
  final name = _e2eName('vncpw');
  const password = 'e2e-pw12';

  group('VNC password: libvirt over the monitor agent', () {
    late _World w;

    Future<void> host(String script) async {
      final exec = await w.server.ensureExec();
      final result = await PrivilegedExec.run(
        exec,
        script,
        isRoot: false,
        password: sudoPassword,
      );
      expect(result.exitCode, 0, reason: result.combined);
    }

    setUpAll(() async {
      w = _World(agent.spi('e2e-monitor-libvirt-vncpw'));
      await w.host.firstLoad;
      if (w.state.error?.type == VirtErrType.sudoPasswordRequired &&
          sudoPassword != null) {
        await w.host.provideSudoPassword(sudoPassword);
      }
      await host(
        "cat > /tmp/$name.xml <<'X'\n"
        "<domain type='kvm'>\n"
        '  <name>$name</name>\n'
        "  <memory unit='MiB'>64</memory>\n"
        '  <vcpu>1</vcpu>\n'
        "  <os><type arch='x86_64'>hvm</type></os>\n"
        '  <devices>\n'
        "    <graphics type='vnc' port='-1' autoport='yes' "
        "listen='127.0.0.1' passwd='$password'/>\n"
        '  </devices>\n'
        '</domain>\n'
        'X\n'
        'virsh --connect qemu:///system define /tmp/$name.xml && '
        'rm -f /tmp/$name.xml\n'
        'virsh --connect qemu:///system start $name',
      );
      await w.host.refresh();
    });
    tearDownAll(() async {
      try {
        await host(
          'virsh --connect qemu:///system destroy $name; '
          'virsh --connect qemu:///system undefine $name; true',
        );
      } catch (_) {}
      await w.dispose();
    });

    /// Runs the engine against [target] until it connects or ends.
    Future<ffi.RemoteDesktopEvent> engine(
      RemoteDesktopTarget target, {
      String? password,
    }) async {
      final handle = ffi.RemoteDesktopSessionHandle.startVnc(
        params: ffi.VncSessionParams(
          connectHost: target.tunnel.address.address,
          connectPort: target.tunnel.port,
          accessToken: target.tunnel.accessToken,
          password: password,
          shared: true,
        ),
      );
      final seen = <String>[];
      try {
        while (true) {
          final event = await handle.nextEvent().timeout(
            const Duration(seconds: 20),
          );
          seen.add('${event.runtimeType}');
          switch (event) {
            case ffi.RemoteDesktopEvent_ConnectionState(
                  state: ffi.RemoteDesktopConnectionState.connected,
                ) ||
                ffi.RemoteDesktopEvent_Ended():
              return event!;
            case null:
              fail('the engine stopped without ending: $seen');
            default:
              continue;
          }
        }
      } finally {
        handle.close();
      }
    }

    Future<RemoteDesktopTarget> open() {
      final guest = w.guest((g) => g.name == name, name);
      return VirtConsoleConnect.vncTarget(
        w.container,
        serverId: w.id,
        guestId: guest.id,
      )();
    }

    test('read with --security-info, and the engine gets in with it', () async {
      final target = await open();
      try {
        expect(target.password, password);
        // Another local process, without the tunnel's token, gets nothing.
        final stranger = await Socket.connect(
          target.tunnel.address,
          target.tunnel.port,
        );
        stranger.add(List.filled(32, 0x41));
        final leaked = await stranger
            .fold<int>(0, (n, b) => n + b.length)
            .timeout(const Duration(seconds: 10));
        expect(leaked, 0);

        final event = await engine(target, password: target.password);
        expect(
          event,
          isA<ffi.RemoteDesktopEvent_ConnectionState>(),
          reason: '$event',
        );
      } finally {
        await target.tunnel.close();
      }
    });

    test('a wrong password is an authentication failure', () async {
      final target = await open();
      try {
        final event = await engine(target, password: 'nope');
        expect(
          event,
          isA<ffi.RemoteDesktopEvent_Ended>().having(
            (e) => e.reason,
            'reason',
            ffi.RemoteDesktopEndReason.authenticationFailed,
          ),
        );
      } finally {
        await target.tunnel.close();
      }
    });
  });
}

// -----------------------------------------------------------------------------
// Creating and deleting
// -----------------------------------------------------------------------------

/// A name for a new guest no earlier run left behind.
String _e2eName(String kind) =>
    'sbme2e-$kind-${DateTime.now().millisecondsSinceEpoch % 100000}';

void _libvirtCreate(_Agent agent) {
  final sudoPassword = e2eEnv('SBM_E2E_MONITOR_SUDO_PASSWORD');

  group('create and delete: libvirt over the monitor agent', () {
    late _World w;
    final name = _e2eName('vm');

    setUpAll(() async {
      w = _World(agent.spi('e2e-monitor-libvirt-create'));
      await w.host.firstLoad;
      if (w.state.error?.type == VirtErrType.sudoPasswordRequired &&
          sudoPassword != null) {
        await w.host.provideSudoPassword(sudoPassword);
      }
      expect(w.state.error, isNull, reason: '${w.state.error}');
    });
    tearDownAll(() async {
      // Whatever a failed test left.
      final left = w.state.data?.guests.where((g) => g.name == name);
      for (final g in left ?? const <VirtGuest>[]) {
        try {
          if (g.state != VirtGuestState.stopped) {
            await w.host.power(g.id, VirtPowerAction.forceStop);
            await w.host.refresh();
          }
          await w.host.delete(g.id);
        } catch (_) {}
      }
      await w.dispose();
    });

    test('a VM: disk in a pool, ISO, NIC, started; then deleted with it',
        () async {
      final snap = w.state.data!;
      expect(snap.capabilities.create, isTrue);
      expect(snap.capabilities.deleteKeepsDisks, isTrue);
      final pools = await w.host.storagePools();
      final pool = virtDiskStorages(
        pools,
        host: VirtHostKind.libvirt,
        kind: VirtGuestKind.qemu,
      ).first;
      final media = <VirtVolume>[];
      VirtStoragePool? mediaPool;
      for (final p in virtMediaStorages(
        pools,
        host: VirtHostKind.libvirt,
        kind: VirtGuestKind.qemu,
      )) {
        final isos = (await w.host.volumes(p)).where(
          (v) => virtIsMedia(v, VirtGuestKind.qemu),
        );
        if (isos.isNotEmpty) mediaPool ??= p;
        media.addAll(isos);
      }
      final nets = virtCreateNetworks(
        await w.host.networks(),
        host: VirtHostKind.libvirt,
      );
      final spec = VirtCreateSpec(
        kind: VirtGuestKind.qemu,
        name: name,
        cores: 1,
        memoryMiB: 256,
        storage: pool,
        diskGiB: 1,
        media: _inPool(media.firstOrNull, await w.host.storagePools()),
        network: nets.firstWhereOrNull((n) => n.name == 'default'),
        start: true,
      );
      expect(
        virtCreateIssue(spec, host: VirtHostKind.libvirt, guests: snap.guests),
        isNull,
      );

      final created = await w.host.create(spec);
      expect(created.startError, isNull);
      final g = await w.settle(
        (g) => g.id == created.id,
        name,
        (g) => g.state == VirtGuestState.running,
      );
      expect(g.name, name);
      final detail = await w.host.detail(g.id);
      final disk = detail.disks.firstWhere((d) => d.device == 'disk');
      expect(disk.source, endsWith('/$name.qcow2'));
      expect(disk.format, 'qcow2');
      if (media.isNotEmpty) {
        final cd = detail.disks.firstWhere((d) => d.device == 'cdrom');
        expect(cd.source, media.first.path);
      }
      expect(detail.consoles, containsAll(VirtConsoleKind.values));

      // The same name again: taken, and nothing new on the host.
      final taken = await _virtErr(w.host.create(spec));
      expect(taken.type, VirtErrType.exists);

      // Running: refused, not stopped behind the user's back.
      final running = await _virtErr(w.host.delete(g.id));
      expect(running.type, VirtErrType.unsupported);
      await w.host.power(g.id, VirtPowerAction.forceStop);
      await w.settle(
        (x) => x.id == g.id,
        name,
        (x) => x.state == VirtGuestState.stopped,
      );
      await w.host.delete(g.id);
      expect(w.state.guest(g.id), isNull);
      final vols = await w.host.volumes(pool);
      expect(vols.where((v) => v.name == '$name.qcow2'), isEmpty);
      // The ISO stays.
      if (mediaPool != null) {
        final still = await w.host.volumes(mediaPool);
        expect(still.map((v) => v.name), contains(media.first.name));
      }
    });
  });
}

void _libvirtClone(_Agent agent) {
  final sudoPassword = e2eEnv('SBM_E2E_MONITOR_SUDO_PASSWORD');

  group('clone: libvirt over the monitor agent', () {
    late _World w;
    final name = _e2eName('cl');
    /// What the group makes, whatever a test got to: the cross-pool test's
    /// two as well, which the first test's cleanup leaves alone.
    final names = [
      name,
      '$name-full',
      '$name-empty',
      '$name-cross',
      '$name-cross-src',
    ];

    /// The three the first test makes.
    final ownNames = [name, '$name-full', '$name-empty'];

    /// The pool a copy is sent to by name: `SBM_E2E_LIBVIRT_CROSS_POOL`. Set
    /// it where the host has a second pool that takes volumes; the cross-pool
    /// test skips otherwise.
    final crossPool = e2eEnv('SBM_E2E_LIBVIRT_CROSS_POOL');

    /// The guests this group made, deleted in `tearDownAll` whatever a test
    /// did with them.
    final made = <String>[];

    setUpAll(() async {
      w = _World(agent.spi('e2e-monitor-libvirt-clone'));
      await w.host.firstLoad;
      if (w.state.error?.type == VirtErrType.sudoPasswordRequired &&
          sudoPassword != null) {
        await w.host.provideSudoPassword(sudoPassword);
      }
      expect(w.state.error, isNull, reason: '${w.state.error}');
    });
    tearDownAll(() async {
      await w.host.refresh();
      for (final g in w.state.data?.guests.where((g) => names.contains(g.name)) ??
          const <VirtGuest>[]) {
        try {
          if (g.state != VirtGuestState.stopped) {
            await w.host.power(g.id, VirtPowerAction.forceStop);
            await w.host.refresh();
          }
          await w.host.delete(g.id);
        } catch (_) {}
      }
      await w.dispose();
    });

    test('a copy on copied disks, one on empty disks; the source kept',
        () async {
      expect(w.state.data!.capabilities.clone, isTrue);
      final pools = await w.host.storagePools();
      final pool = virtDiskStorages(
        pools,
        host: VirtHostKind.libvirt,
        kind: VirtGuestKind.qemu,
      ).first;
      final nets = virtCreateNetworks(
        await w.host.networks(),
        host: VirtHostKind.libvirt,
      );
      final created = await w.host.create(
        VirtCreateSpec(
          kind: VirtGuestKind.qemu,
          name: name,
          cores: 1,
          memoryMiB: 128,
          storage: pool,
          diskGiB: 1,
          network: nets.firstWhereOrNull((n) => n.name == 'default'),
        ),
      );
      final src = w.guest((g) => g.id == created.id, name);
      final srcDetail = await w.host.detail(src.id);

      // Running: refused before anything is made.
      await w.host.power(src.id, VirtPowerAction.start);
      await w.settle((g) => g.id == src.id, name, (g) => g.state == VirtGuestState.running);
      final running = await _virtErr(
        w.host.clone(src.id, VirtCloneRequest(name: '$name-full')),
      );
      expect(running.type, VirtErrType.unsupported);
      await w.host.power(src.id, VirtPowerAction.forceStop);
      await w.settle((g) => g.id == src.id, name, (g) => g.state == VirtGuestState.stopped);

      for (final full in [true, false]) {
        final copy = full ? '$name-full' : '$name-empty';
        final id = await w.host.clone(src.id, VirtCloneRequest(name: copy, full: full));
        final g = w.guest((g) => g.id == id, copy);
        expect(g.name, copy);
        expect(g.state, VirtGuestState.stopped);
        final detail = await w.host.detail(g.id);
        final disk = detail.disks.firstWhere((d) => d.device == 'disk');
        expect(disk.source, endsWith('/$copy.qcow2'));
        expect(disk.format, 'qcow2');
        // A MAC of its own.
        expect(
          detail.nics.map((n) => n.mac).toSet().intersection(srcDetail.nics.map((n) => n.mac).toSet()),
          isEmpty,
        );
      }

      // The name taken: refused, nothing made.
      final taken = await _virtErr(
        w.host.clone(src.id, VirtCloneRequest(name: '$name-full')),
      );
      expect(taken.type, VirtErrType.exists);

      for (final n in ownNames.reversed) {
        final g = w.guest((g) => g.name == n, n);
        await w.host.delete(g.id);
      }
      final vols = (await w.host.volumes(
        (await w.host.storagePools()).firstWhere((p) => p.id == pool.id),
      )).map((v) => v.name);
      expect(vols.where((v) => v.startsWith(name)), isEmpty);
    });

    /// A copy whose disks go to a pool the source's are not in: libvirt's
    /// `vol-clone` cannot do that, so the backend copies with
    /// `vol-create-from` and the source's own pool as the input. Skipped
    /// where the host has only one pool that takes a volume.
    test('a copy into another pool', () async {
      final pools = virtDiskStorages(
        await w.host.storagePools(),
        host: VirtHostKind.libvirt,
        kind: VirtGuestKind.qemu,
      );
      final wanted = crossPool;
      final target = pools.firstWhereOrNull((p) => p.name == wanted);
      if (target == null) {
        markTestSkipped('SBM_E2E_LIBVIRT_CROSS_POOL unset or not a pool here');
        return;
      }
      final source = pools.firstWhere((p) => p.id != target.id);
      final created = await w.host.create(
        VirtCreateSpec(
          kind: VirtGuestKind.qemu,
          name: '$name-cross-src',
          cores: 1,
          memoryMiB: 128,
          storage: source,
          diskGiB: 1,
        ),
      );
      made.add(created.id);
      final src = w.guest((g) => g.id == created.id, '$name-cross-src');
      // As the source's pool is *after* the source itself was made: what the
      // clone adds is the difference.
      final before = (await w.host.volumes(
        (await w.host.storagePools()).firstWhere((p) => p.id == source.id),
      )).map((v) => v.id).toSet();

      final id = await w.host.clone(
        src.id,
        VirtCloneRequest(
          name: '$name-cross',
          targetPool: target.name,
        ),
      );
      made.add(id);
      final copy = w.guest((g) => g.id == id, '$name-cross');
      final detail = await w.host.detail(copy.id);
      final disk = detail.disks.firstWhere((d) => d.device == 'disk');
      expect(disk.format, 'qcow2');
      expect(disk.source, contains(target.path ?? target.name));
      // A pool's volume list is a read of its own: what a clone added is
      // there after the host is asked again.
      final fresh = await w.host.storagePools();
      final inTarget = (await w.host.volumes(
        fresh.firstWhere((p) => p.id == target.id),
      )).map((v) => v.name);
      expect(inTarget, contains('$name-cross.qcow2'));
      expect(
        (await w.host.volumes(
          fresh.firstWhere((p) => p.id == source.id),
        )).map((v) => v.id).toSet().difference(before),
        isEmpty,
      );

      for (final g in [copy, src]) {
        await w.host.refresh();
        final fresh = w.state.guest(g.id);
        if (fresh == null) continue;
        await w.host.delete(fresh.id, removeDisks: true);
        made.remove(fresh.id);
      }
      expect(
        (await w.host.volumes(
          (await w.host.storagePools()).firstWhere((p) => p.id == target.id),
        )).map((v) => v.name),
        isNot(contains('$name-cross.qcow2')),
      );
    });
  });
}

/// Phase 10: an existing network edited through the providers — its mode,
/// its address, its DHCP range and its static hosts — and the running one
/// restarted onto the change. Everything is named `sbxe2e*` and removed
/// again.
void _p10LibvirtNetwork(_Agent agent) {
  final sudoPassword = e2eEnv('SBM_E2E_MONITOR_SUDO_PASSWORD');

  group('network editing: libvirt over the monitor agent', () {
    late _World w;
    final name = _e2eName('net');
    // The networks this group made, recorded once made: another run's (or
    // anyone's) under a similar name is not this group's to remove.
    final owned = <String>{};

    /// Takes away every network this group made, whether the test passed or
    /// not: one left behind has its subnet, and the next test's create is
    /// refused for it.
    Future<void> cleanup() async {
      for (final n in await w.host.networks()) {
        if (!owned.contains(n.name)) continue;
        if (n.active) {
          try {
            await w.host.manage(VirtNetworkSetActive(n, active: false));
          } catch (_) {}
        }
        try {
          await w.host.manage(
            VirtNetworkDelete(
              (await w.host.networks()).firstWhere(
                (x) => x.name == n.name,
                orElse: () => n,
              ),
            ),
          );
          owned.remove(n.name);
        } catch (_) {}
      }
    }

    setUpAll(() async {
      w = _World(agent.spi('e2e-monitor-libvirt-net'));
      await w.host.firstLoad;
      if (w.state.error?.type == VirtErrType.sudoPasswordRequired &&
          sudoPassword != null) {
        await w.host.provideSudoPassword(sudoPassword);
      }
      expect(w.state.error, isNull, reason: '${w.state.error}');
      final taken = (await w.host.networks()).map((n) => n.name).toSet();
      expect(taken.intersection({name, '$name-b'}), isEmpty);
    });
    tearDown(cleanup);
    tearDownAll(() async {
      await cleanup();
      await w.dispose();
    });

    test('a NAT network: mode, address, range and static hosts', () async {
      const cidr = '192.168.249.1/24';
      await w.host.manage(
        VirtNetworkCreate(
          name: name,
          mode: 'nat',
          cidr: cidr,
          dhcpStart: '192.168.249.100',
          dhcpEnd: '192.168.249.200',
        ),
      );
      owned.add(name);
      var net = (await w.host.networks()).firstWhere((n) => n.name == name);
      expect((net.active, net.mode), (true, 'nat'));
      expect(net.address, '192.168.249.1');
      expect(net.prefix, 24);
      expect(net.dhcpRange, ('192.168.249.100', '192.168.249.200'));
      expect(net.xml, contains('<forward mode=\'nat\'/>'));
      expect(net.pendingRestart, isFalse);

      // A static host, live: `net-update`, no restart.
      await w.host.manage(
        VirtNetworkEdit(
          net,
          mode: 'nat',
          address: '192.168.249.1',
          prefix: 24,
          dhcpStart: '192.168.249.100',
          dhcpEnd: '192.168.249.200',
          hosts: const [
            VirtNetHost(mac: '52:54:00:aa:bb:e1', ip: '192.168.249.150', name: 'sbxe2e-h1'),
          ],
        ),
      );
      net = (await w.host.networks()).firstWhere((n) => n.name == name);
      expect(net.hosts.single.mac, '52:54:00:aa:bb:e1');
      expect(net.hosts.single.ip, '192.168.249.150');
      expect(net.pendingRestart, isFalse);

      // The address and the range: the definition first, then a restart.
      // The static host moves with it.
      await w.host.manage(
        VirtNetworkEdit(
          net,
          mode: 'nat',
          address: '192.168.250.1',
          prefix: 24,
          dhcpStart: '192.168.250.100',
          dhcpEnd: '192.168.250.200',
          hosts: const [
            VirtNetHost(mac: '52:54:00:aa:bb:e1', ip: '192.168.250.150', name: 'sbxe2e-h1'),
          ],
        ),
      );
      net = (await w.host.networks()).firstWhere((n) => n.name == name);
      // The definition is the new one; the running network is not on it.
      expect(net.address, '192.168.250.1');
      expect(net.pendingRestart, isTrue, reason: 'the running network is on the old definition');

      await w.host.manage(VirtNetworkRestart(net));
      net = (await w.host.networks()).firstWhere((n) => n.name == name);
      expect(net.pendingRestart, isFalse);
      expect(net.hosts.single.ip, '192.168.250.150');

      // A change that only the definition takes until the network is
      // restarted: the mode goes to routed, and stays pending.
      await w.host.manage(
        VirtNetworkEdit(
          net,
          mode: 'route',
          address: '192.168.250.1',
          prefix: 24,
          hosts: net.hosts,
        ),
      );
      net = (await w.host.networks()).firstWhere((n) => n.name == name);
      expect(net.mode, 'route');
      expect(net.pendingRestart, isTrue);
      await w.host.manage(VirtNetworkRestart(net));
      net = (await w.host.networks()).firstWhere((n) => n.name == name);
      expect(net.pendingRestart, isFalse);
      expect(net.mode, 'route');

      // A change made from a read the host has moved past: one edit made
      // from `net` (a static host, live), then another from the same read —
      // refused, and nothing written.
      await w.host.manage(
        VirtNetworkEdit(
          net,
          mode: 'route',
          address: '192.168.250.1',
          prefix: 24,
          hosts: const [
            VirtNetHost(mac: '52:54:00:aa:bb:e2', ip: '192.168.250.151'),
            VirtNetHost(mac: '52:54:00:aa:bb:e1', ip: '192.168.250.150', name: 'sbxe2e-h1'),
          ],
        ),
      );
      final stale = await _virtErr(
        w.host.manage(
          VirtNetworkEdit(
            net,
            mode: 'isolated',
            address: '10.99.99.1',
            prefix: 24,
          ),
        ),
      );
      expect(stale.type, VirtErrType.conflict);
      expect(
        (await w.host.networks()).firstWhere((n) => n.name == name).mode,
        'route',
      );

      // A subnet another network of the host's is on: refused before it is
      // sent.
      final issue = virtResourceIssue(
        VirtNetworkEdit(net, mode: 'nat', address: '192.168.122.9', prefix: 24),
        host: VirtHostKind.libvirt,
        networks: await w.host.networks(),
      );
      expect(issue, VirtResIssue.subnetTaken);

      if ((await w.host.networks()).any((n) => n.name == name && n.active)) {
        await w.host.manage(VirtNetworkSetActive(
          (await w.host.networks()).firstWhere((n) => n.name == name),
          active: false,
        ));
      }
      await w.host.manage(
        VirtNetworkDelete((await w.host.networks()).firstWhere((n) => n.name == name)),
      );
      expect((await w.host.networks()).any((n) => n.name == name), isFalse);
    }, timeout: const Timeout(Duration(minutes: 5)));

    test('an address a guest is on: the restart keeps it up', () async {
      // A refusal at start is rolled back: the host's own subnet is in use.
      const cidr = '192.168.251.1/24';
      final other = '$name-b';
      await w.host.manage(
        VirtNetworkCreate(
          name: other,
          mode: 'nat',
          cidr: cidr,
          dhcpStart: '192.168.251.100',
          dhcpEnd: '192.168.251.200',
        ),
      );
      owned.add(other);
      final net = (await w.host.networks()).firstWhere((n) => n.name == other);
      // The host's own LAN, which libvirt refuses a bridge on: the restart
      // puts the old definition back and starts that.
      final refused = await _virtErr(
        w.host.manage(
          VirtNetworkEdit(
            net,
            mode: 'nat',
            address: '192.168.31.1',
            prefix: 24,
            dhcpStart: '192.168.31.100',
            dhcpEnd: '192.168.31.200',
            restart: true,
          ),
        ),
      );
      expect(refused.type, VirtErrType.actionFailed);
      expect(refused.message, contains('started again as it ran before'));
      final after = (await w.host.networks()).firstWhere((n) => n.name == other);
      expect(after.active, isTrue, reason: 'the network is never left down');
      expect(after.address, '192.168.251.1');
      await w.host.manage(VirtNetworkSetActive(after, active: false));
      await w.host.manage(VirtNetworkDelete(after));
    }, timeout: const Timeout(Duration(minutes: 5)));
  });
}

/// Phase 10: a domain's pending change discarded by redefining it from the
/// running XML, with the NVRAM file and the firmware left as they are.
void _p10LibvirtRevert(_Agent agent) {
  final sudoPassword = e2eEnv('SBM_E2E_MONITOR_SUDO_PASSWORD');

  group('revert pending: libvirt over the monitor agent', () {
    late _World w;
    final name = _e2eName('rev');
    late VirtStoragePool pool;

    setUpAll(() async {
      w = _World(agent.spi('e2e-monitor-libvirt-rev'));
      await w.host.firstLoad;
      if (w.state.error?.type == VirtErrType.sudoPasswordRequired &&
          sudoPassword != null) {
        await w.host.provideSudoPassword(sudoPassword);
      }
      expect(w.state.error, isNull, reason: '${w.state.error}');
      pool = virtDiskStorages(
        await w.host.storagePools(),
        host: VirtHostKind.libvirt,
        kind: VirtGuestKind.qemu,
      ).first;
    });
    tearDownAll(() async {
      for (final g in w.state.data?.guests.where((g) => g.name == name) ?? const <VirtGuest>[]) {
        try {
          if (g.state != VirtGuestState.stopped) {
            await w.host.power(g.id, VirtPowerAction.forceStop);
            await w.host.refresh();
          }
          await w.host.delete(g.id);
        } catch (_) {}
      }
      await w.dispose();
    });

    test('a memory change with the guest running is discarded', () async {
      final options = await w.host.createOptions();
      // UEFI where the host has it: the NVRAM file is what the revert must
      // leave alone.
      final uefi = options.uefi;
      final created = await w.host.create(
        VirtCreateSpec(
          kind: VirtGuestKind.qemu,
          name: name,
          cores: 1,
          memoryMiB: 256,
          storage: pool,
          diskGiB: 1,
          uefi: uefi,
          start: true,
        ),
      );
      expect(created.startError, isNull);
      final g = await w.settle(
        (g) => g.id == created.id,
        name,
        (g) => g.state == VirtGuestState.running,
      );
      final before = await w.host.hardware(g.id);
      expect(before.pending, isEmpty);
      expect(before.firmware?.uefi ?? false, uefi);

      // A change the running guest does not take: it waits.
      final out = await w.host.changeHardware(
        g.id,
        before,
        const VirtHwSetMemory(mib: 768),
      );
      expect(out.liveError, isNull);
      final pending = await w.host.hardware(g.id);
      expect(pending.pending.map((p) => p.key), contains('memory'));
      expect(pending.memory.mib, 768);

      // The revert: the definition is the live XML again.
      await w.host.revertPending(g.id, pending);
      final after = await w.host.hardware(g.id);
      expect(after.pending, isEmpty);
      expect(after.memory.mib, before.memory.mib);
      // Still running, and its own memory is untouched.
      await w.host.refresh();
      expect(w.state.guest(g.id)?.state, VirtGuestState.running);
      await w.host.power(g.id, VirtPowerAction.forceStop);
      await w.settle((x) => x.id == g.id, name, (x) => x.state == VirtGuestState.stopped);
      await w.host.delete(g.id);
    }, timeout: const Timeout(Duration(minutes: 6)));
  });
}

/// Phase 10: a PVE bridge edited through the pending model, applied, and the
/// interface carrying the host's own address refused.
void _p10PveNetwork(_Agent agent) {
  final tokenId = e2eEnv('SBM_E2E_PVE_TOKEN_ID');
  final tokenSecret = e2eEnv('SBM_E2E_PVE_TOKEN_SECRET');
  if (tokenId == null || tokenSecret == null) return;

  group('network editing: PVE over the monitor agent relay', () {
    late _World w;
    // A Linux interface name is at most 15 characters, which PVE checks:
    // `sbme2e-br-82086` is too long for one.
    final name = 'sbxe2e${DateTime.now().millisecondsSinceEpoch % 10000}';
    final node = 'pve';
    // The node's pending configuration is node-wide, and a revert or an apply
    // takes all of it. So this group runs only on a node with nothing
    // pending and no interface of its name, and its cleanup acts only once a
    // test staged something: then whatever is pending is this group's.
    var clean = false;
    var staged = false;

    setUpAll(() async {
      w = _World(agent.spi('e2e-monitor-pve-net'));
      // A server carrying a PVE configuration is a PVE host: the address is
      // resolved on the agent's side of the relay.
      Stores.pve.put(
        w.id,
        PveConfig(
          addr: 'https://localhost:8006',
          auth: PveAuth.token,
          tokenId: tokenId,
          tokenSecret: tokenSecret,
        ),
      );
      await w.host.firstLoad;
      final cert = w.state.error?.cert;
      if (cert != null) await w.host.confirmCert(cert.fingerprint);
      expect(w.state.error, isNull, reason: '${w.state.error}');
      expect(
        (await w.host.networkChanges()).where((c) => c.node == node),
        isEmpty,
        reason: 'network changes are pending on $node already',
      );
      expect(
        (await w.host.networks()).where((n) => n.name == name),
        isEmpty,
        reason: '$name exists already',
      );
      clean = true;
    });
    /// Takes the bridge away, applied or not: one left behind is a bridge on
    /// the host, and a subnet the next run's form refuses. The unapplied
    /// changes are reverted first; a bridge still there after that was
    /// applied, and goes by a deletion of its own, applied — reverting after
    /// staging that deletion would cancel it.
    Future<void> cleanup() async {
      if (!clean || !staged) return;
      try {
        if ((await w.host.networkChanges()).any((c) => c.node == node)) {
          await w.host.manage(VirtNetworkRevert(node));
        }
      } catch (_) {}
      try {
        final left = (await w.host.networks()).where((n) => n.name == name);
        if (left.isNotEmpty) {
          await w.host.manage(VirtNetworkDelete(left.first));
          await w.host.manage(VirtNetworkApply(node));
        }
      } catch (_) {}
    }

    tearDown(cleanup);
    tearDownAll(() async {
      await cleanup();
      await w.dispose();
    });

    test('a bridge: edited pending, applied, and the management one refused', () async {
      staged = true;
      await w.host.manage(
        VirtNetworkCreate(
          name: name,
          mode: 'bridge',
          node: node,
          cidr: '10.88.0.1/24',
          autostart: false,
        ),
      );
      var nets = await w.host.networks();
      var net = nets.firstWhere((n) => n.name == name);
      expect(net.active, isFalse, reason: 'a new PVE bridge waits');
      expect(net.managementEditable, isTrue);

      // Edited while pending: the address and the VLAN flag.
      await w.host.manage(
        VirtNetworkEditBridge(
          net,
          cidr: '10.89.0.1/24',
          vlanAware: false,
          autostart: false,
        ),
      );
      nets = await w.host.networks();
      net = nets.firstWhere((n) => n.name == name);
      expect(net.address, '10.89.0.1');
      expect((await w.host.networkChanges()).map((c) => c.diff).join(), contains(name));

      // Reverted: nothing applied, and the interface is gone from the
      // pending configuration.
      await w.host.manage(VirtNetworkRevert(node));
      expect((await w.host.networks()).any((n) => n.name == name), isFalse);

      // Made again and applied.
      await w.host.manage(
        VirtNetworkCreate(
          name: name,
          mode: 'bridge',
          node: node,
          cidr: '10.88.0.1/24',
          autostart: false,
        ),
      );
      net = (await w.host.networks()).firstWhere((n) => n.name == name);
      await w.host.manage(
        VirtNetworkEditBridge(net, cidr: '10.90.0.1/24', vlanAware: true),
      );
      await w.host.manage(VirtNetworkApply(node));
      net = (await w.host.networks()).firstWhere((n) => n.name == name);
      // What was applied is the configuration: PVE's listing answers with
      // the file it wrote. A bridge with no ports and no `auto` line is not
      // brought up by `ifreload` — that is PVE's own behaviour, and not
      // this app's to change.
      expect(net.address, '10.90.0.1');
      expect(net.vlanAware, isTrue);
      expect(
        net.ports,
        isEmpty,
        reason: 'no port was given, so none was written',
      );

      // Removed and applied.
      await w.host.manage(VirtNetworkDelete(net));
      await w.host.manage(VirtNetworkApply(node));
      expect((await w.host.networks()).any((n) => n.name == name), isFalse);
    }, timeout: const Timeout(Duration(minutes: 5)));

    test('the interface carrying the host address is refused', () async {
      final nets = await w.host.networks();
      final mgmt = nets.where((n) => !n.managementEditable).toList();
      // vmbr0 carries PVE's own address (and a physical interface is never
      // the app's to edit): neither may be written or removed.
      expect(mgmt, isNotEmpty, reason: 'no management interface was found');
      expect(
        mgmt.map((n) => n.name),
        contains('vmbr0'),
        reason: 'the bridge holding the default route is one of them',
      );
      for (final m in mgmt) {
        final e = await _virtErr(
          w.host.manage(VirtNetworkEditBridge(m, cidr: '10.77.0.1/24')),
        );
        expect(e.type, VirtErrType.unsupported, reason: m.name);
        final d = await _virtErr(w.host.manage(VirtNetworkDelete(m)));
        expect(d.type, VirtErrType.unsupported, reason: m.name);
      }
      // Nothing was written, and the node is still reachable: the bridge
      // that carries its own address is untouched.
      final after = (await w.host.networks())
          .firstWhere((n) => n.name == 'vmbr0');
      final before = nets.firstWhere((n) => n.name == 'vmbr0');
      expect(after.address, before.address);
      expect(after.gateway, before.gateway);
      expect(after.active, isTrue);
    }, timeout: const Timeout(Duration(minutes: 3)));
  });
}

/// A cloud image's seed made, read back and written anew through the agent
/// — its account outside the `libvirt` group, so through sudo — and deleted
/// with the VM. Needs `SBM_E2E_LIBVIRT_CLOUD_IMAGE` (a cloud image's path on
/// that host) and an ISO tool there; the disk goes to
/// `SBM_E2E_LIBVIRT_DISK_POOL`, else the image's own pool.
void _libvirtCloudInit(_Agent agent) {
  final sudoPassword = e2eEnv('SBM_E2E_MONITOR_SUDO_PASSWORD');
  final imagePath = e2eEnv('SBM_E2E_LIBVIRT_CLOUD_IMAGE');
  final diskPoolName = e2eEnv('SBM_E2E_LIBVIRT_DISK_POOL');
  if (imagePath == null) return;

  group('cloud-init: libvirt over the monitor agent', () {
    late _World w;
    final name = _e2eName('ci');

    setUpAll(() async {
      w = _World(agent.spi('e2e-monitor-libvirt-ci'));
      await w.host.firstLoad;
      if (w.state.error?.type == VirtErrType.sudoPasswordRequired &&
          sudoPassword != null) {
        await w.host.provideSudoPassword(sudoPassword);
      }
      expect(w.state.error, isNull, reason: '${w.state.error}');
    });
    tearDownAll(() async {
      for (final g in w.state.data?.guests.where((g) => g.name == name) ?? const <VirtGuest>[]) {
        try {
          if (g.state != VirtGuestState.stopped) {
            await w.host.power(g.id, VirtPowerAction.forceStop);
            await w.host.refresh();
          }
          await w.host.delete(g.id);
        } catch (_) {}
      }
      await w.dispose();
    });

    test('a seed made, read back, written anew and deleted, all through sudo', () async {
      final options = await w.host.createOptions();
      expect((options.cloudImages, options.cloudInit), (true, true));
      final pools = await w.host.storagePools();
      VirtVolume? image;
      VirtStoragePool? imagePool;
      for (final p in pools.where((p) => p.active)) {
        final v = (await w.host.volumes(p)).where((v) => v.path == imagePath).firstOrNull;
        if (v != null) (image, imagePool) = (v, p);
      }
      expect(image, isNotNull, reason: 'no volume at $imagePath');
      final pool = diskPoolName == null ? imagePool! : pools.firstWhere((p) => p.name == diskPoolName);
      final net = virtCreateNetworks(await w.host.networks(), host: VirtHostKind.libvirt)
          .firstWhere((n) => n.name == 'default');
      const key = 'ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIA2m8R0nAqFrd3Xb8M2nHpW4eyTZ0QZ0bdU2nHYtR8r0 sbxe2e';
      final spec = VirtCreateSpec(
        kind: VirtGuestKind.qemu,
        name: name,
        cores: 1,
        memoryMiB: 512,
        storage: pool,
        // The image's own size or more: the form refuses to cut one.
        diskGiB: max(2, ((image!.capacity ?? 0) + (1 << 30) - 1) >> 30),
        image: _inPool(image, await w.host.storagePools()),
        network: net,
        uefi: false,
        cloudInit: VirtCloudInit(user: 'sbxe', password: 'pw-${DateTime.now().microsecond}', sshKeys: key, hostname: name),
        start: true,
      );
      expect(virtCreateIssue(spec, host: VirtHostKind.libvirt, guests: w.state.data!.guests), isNull);
      final created = await w.host.create(spec);
      expect(created.startError, isNull);
      final g = await w.settle((g) => g.id == created.id, name, (g) => g.state == VirtGuestState.running);

      // The Settings view's read: the seed, downloaded and parsed.
      final hw = await w.host.hardware(g.id);
      expect(hw.disks.where((d) => d.cloudInit), hasLength(1));
      final ci = await w.container.read(virtCloudInitProvider(w.id, g.id).future);
      expect((ci.user, ci.hostname, ci.passwordSet, ci.network, ci.foreign), ('sbxe', name, true, true, false));
      expect(ci.sshKeys, [key]);

      // Written anew: a new hostname, a static address, the password gone.
      await w.host.setCloudInit(
        g.id,
        ci,
        VirtCloudInitEdit(
          VirtCloudInit(
            user: 'sbxe',
            sshKeys: key,
            hostname: '$name-b',
            address: '192.168.122.240/24',
            gateway: '192.168.122.1',
            dns: const ['192.168.122.1'],
          ),
          removePassword: true,
        ),
      );
      final after = await w.container.read(virtCloudInitProvider(w.id, g.id).future);
      expect((after.hostname, after.address, after.gateway, after.passwordSet), ('$name-b', '192.168.122.240/24', '192.168.122.1', false));
      expect(after.revision, isNot(ci.revision));
      // From the old read: a conflict, and nothing written.
      final stale = await _virtErr(w.host.setCloudInit(g.id, ci, VirtCloudInitEdit(VirtCloudInit(user: 'x', sshKeys: key, hostname: 'x'))));
      expect(stale.type, VirtErrType.conflict);
      expect((await w.container.refresh(virtCloudInitProvider(w.id, g.id).future)).hostname, '$name-b');

      await w.host.power(g.id, VirtPowerAction.forceStop);
      await w.settle((x) => x.id == g.id, name, (x) => x.state == VirtGuestState.stopped);
      await w.host.delete(g.id);
      final vols = (await w.host.volumes(pool)).map((v) => v.name);
      expect(vols, isNot(contains('$name.qcow2')));
      expect(vols, isNot(contains('$name-cidata.iso')));
    }, timeout: const Timeout(Duration(minutes: 8)));
  });
}

void _libvirtHardware(_Agent agent) {
  final sudoPassword = e2eEnv('SBM_E2E_MONITOR_SUDO_PASSWORD');

  group('hardware: libvirt over the monitor agent', () {
    late _World w;
    final name = _e2eName('hw');
    late VirtStoragePool pool;
    late VirtGuest g;

    Future<VirtHardware> hw() => w.host.hardware(g.id);

    setUpAll(() async {
      w = _World(agent.spi('e2e-monitor-libvirt-hw'));
      await w.host.firstLoad;
      if (w.state.error?.type == VirtErrType.sudoPasswordRequired &&
          sudoPassword != null) {
        await w.host.provideSudoPassword(sudoPassword);
      }
      expect(w.state.error, isNull, reason: '${w.state.error}');
      expect(w.state.data!.capabilities.hardware, isTrue);
      expect(w.state.data!.capabilities.hardwareRevert, isFalse);
      final pools = await w.host.storagePools();
      pool = virtDiskStorages(
        pools,
        host: VirtHostKind.libvirt,
        kind: VirtGuestKind.qemu,
      ).first;
      final net = virtCreateNetworks(
        await w.host.networks(),
        host: VirtHostKind.libvirt,
      ).firstWhere((n) => n.name == 'default');
      final created = await w.host.create(
        VirtCreateSpec(
          kind: VirtGuestKind.qemu,
          name: name,
          cores: 1,
          memoryMiB: 256,
          storage: pool,
          diskGiB: 1,
          network: net,
          start: true,
        ),
      );
      g = await w.settle(
        (x) => x.id == created.id,
        name,
        (x) => x.state == VirtGuestState.running,
      );
    });
    tearDownAll(() async {
      final left = w.state.data?.guests.where((x) => x.name == name);
      for (final x in left ?? const <VirtGuest>[]) {
        try {
          if (x.state != VirtGuestState.stopped) {
            await w.host.power(x.id, VirtPowerAction.forceStop);
            await w.host.refresh();
          }
          await w.host.delete(x.id);
        } catch (_) {}
      }
      // A disk kept because the guest never let go of it (it has no OS to
      // answer the unplug) is in no definition any more: deleted by name.
      try {
        final exec = await w.server.ensureExec();
        await PrivilegedExec.run(
          exec,
          "for v in \$(virsh -c qemu:///system -q vol-list --pool '${pool.id}' "
          "| awk '{print \$1}' | grep '^$name-'); do "
          "virsh -c qemu:///system -q vol-delete --pool '${pool.id}' --vol \"\$v\"; done",
          isRoot: false,
          password: sudoPassword,
        );
      } catch (_) {}
      await w.dispose();
    });

    /// [pool]'s volumes as they are now, not as the last listing had them.
    Future<Iterable<String>> volumesNow() async {
      final pools = await w.host.storagePools();
      final now = pools.firstWhere((p) => p.id == pool.id);
      return (await w.host.volumes(now)).map((v) => v.name);
    }

    test('read: both definitions, the host\'s limits, nothing pending',
        () async {
      final h = await hw();
      expect(h.running, isTrue);
      expect(h.cpu.total, 1);
      expect(h.memory.mib, 256);
      expect(h.disks.where((d) => d.kind == VirtHwDiskKind.disk), hasLength(1));
      expect(h.disks.first.size, 1 << 30);
      expect(h.nics, hasLength(1));
      expect(h.pending, isEmpty);
      expect(h.limits.hostCpus, greaterThan(0));
      expect(h.limits.hostMemoryBytes, greaterThan(0));
      expect(h.revision, startsWith('<domain'));
    });

    test('CPU and memory: kept for the next start, shown as pending',
        () async {
      var h = await hw();
      await w.host.changeHardware(
        g.id,
        h,
        const VirtHwSetCpu(sockets: 1, cores: 2, online: 1),
      );
      h = await hw();
      expect((h.cpu.sockets, h.cpu.cores, h.cpu.online), (1, 2, 1));
      // The running domain still has one vCPU of one.
      expect(h.pending.map((p) => p.key), contains('cpu'));

      await w.host.changeHardware(
        g.id,
        h,
        const VirtHwSetMemory(mib: 320, minMib: 256),
      );
      h = await hw();
      expect((h.memory.mib, h.memory.minMib), (320, 256));
      expect(h.pending.map((p) => p.key), contains('memory'));
    });

    test('an edit from an old read is refused, and changes nothing',
        () async {
      final old = await hw();
      // The definition changes after [old] was read …
      await w.host.changeHardware(
        g.id,
        old,
        const VirtHwSetMemory(mib: 384, minMib: 256),
      );
      // … so a CPU change made from [old] would undo it: refused.
      final err = await _virtErr(
        w.host.changeHardware(
          g.id,
          old,
          const VirtHwSetCpu(sockets: 2, cores: 2),
        ),
      );
      expect(err.type, VirtErrType.conflict);
      final h = await hw();
      expect(h.memory.mib, 384);
      expect((h.cpu.sockets, h.cpu.cores), (1, 2));

      // Autostart is no part of the definition: made from anything.
      await w.host.changeHardware(g.id, h, const VirtHwSetAutostart(true));
      expect((await hw()).autostart, isTrue);
      await w.host.changeHardware(g.id, h, const VirtHwSetAutostart(false));
      expect((await hw()).autostart, isFalse);
    });

    test('a disk: added in a pool, grown, removed with its volume', () async {
      var h = await hw();
      final out = await w.host.changeHardware(
        g.id,
        h,
        VirtHwAddDisk(storage: pool, gib: 1),
      );
      h = await hw();
      final added = h.disks.firstWhere(
        (d) => d.kind == VirtHwDiskKind.disk && d.key != 'vda',
      );
      expect(added.source, endsWith('/$name-${added.key}.qcow2'));
      // Hot-plugged, or not (a q35 domain with no free root port): either
      // way the next start has it.
      if (out.liveError != null) {
        expect(h.pending.map((p) => p.key), contains(added.key));
      }

      await w.host.changeHardware(
        g.id,
        h,
        VirtHwGrowDisk(key: added.key, bytes: 2 << 30),
      );
      h = await hw();
      expect(h.disk(added.key)!.size, 2 << 30);
      final shrink = virtHwIssue(h, VirtHwGrowDisk(key: added.key, bytes: 1 << 30));
      expect(shrink, VirtHwIssue.diskShrink);

      final removed = await w.host.changeHardware(
        g.id,
        h,
        VirtHwRemoveDisk(key: added.key, deleteVolume: true),
      );
      h = await hw();
      expect(h.disk(added.key), isNull);
      final vols = await volumesNow();
      // A guest with no OS never lets go of a hot-plugged disk: kept then.
      if (removed.volumeKept) {
        expect(vols, contains('$name-${added.key}.qcow2'));
        expect(h.pending.map((p) => p.key), contains(added.key));
      } else {
        expect(vols, isNot(contains('$name-${added.key}.qcow2')));
      }
    });

    test('a NIC: added, disconnected, removed', () async {
      var h = await hw();
      final net = virtCreateNetworks(
        await w.host.networks(),
        host: VirtHostKind.libvirt,
      ).firstWhere((n) => n.name == 'default');
      await w.host.changeHardware(g.id, h, VirtHwAddNic(network: net));
      h = await hw();
      expect(h.nics, hasLength(2));
      final nic = h.nics.last;
      expect(nic.mac, startsWith('52:54:00:'));
      await w.host.changeHardware(
        g.id,
        h,
        VirtHwUpdateNic(key: nic.key, linkUp: false),
      );
      h = await hw();
      expect(h.nic(nic.key)!.linkUp, isFalse);
      await w.host.changeHardware(g.id, h, VirtHwRemoveNic(key: nic.key));
      h = await hw();
      expect(h.nic(nic.key), isNull);
    });

    test('boot order: per device, pending while it runs', () async {
      var h = await hw();
      final order = [h.nics.first.key, 'vda'];
      await w.host.changeHardware(g.id, h, VirtHwSetBoot(order));
      h = await hw();
      expect(h.boot, order);
      expect(h.pending.map((p) => p.key), contains('boot'));
      expect(
        await _virtErr(w.host.changeHardware(g.id, h, const VirtHwRevert(['boot']))),
        isA<VirtErr>().having((e) => e.type, 'type', VirtErrType.unsupported),
      );
    });

    test('stopped: nothing pending, and the next start has it all', () async {
      await w.host.power(g.id, VirtPowerAction.forceStop);
      await w.settle(
        (x) => x.id == g.id,
        name,
        (x) => x.state == VirtGuestState.stopped,
      );
      final h = await hw();
      expect(h.running, isFalse);
      expect(h.pending, isEmpty);
      expect((h.cpu.cores, h.memory.mib), (2, 384));
      // A stopped domain's disk grows by its file.
      await w.host.changeHardware(
        g.id,
        h,
        VirtHwGrowDisk(key: 'vda', bytes: 2 << 30),
      );
      expect((await hw()).disk('vda')!.size, 2 << 30);
    });

    test('settings: a note with quotes and a leading dash, and a rename '
        'only while stopped', () async {
      var h = await hw();
      expect(h.name, g.name);
      expect(h.protection, isNull);
      const note = '-it\'s "a" note\nsecond line';
      await w.host.changeHardware(g.id, h, const VirtHwSetDescription(note));
      h = await hw();
      expect(h.description, note);
      await w.host.changeHardware(g.id, h, const VirtHwSetDescription(''));
      h = await hw();
      expect(h.description, isNull);

      // Stopped by the test before: renamed, and back.
      expect(h.running, isFalse);
      final renamed = '$name-r';
      await w.host.changeHardware(g.id, h, VirtHwSetName(renamed));
      await w.host.refresh();
      expect(w.state.guest(g.id)?.name, renamed);
      h = await hw();
      await w.host.changeHardware(g.id, h, VirtHwSetName(name));
      await w.host.refresh();
      expect(w.state.guest(g.id)?.name, name);
    });
  });
}

void _pveHardware(_Agent agent) {
  final tokenId = e2eEnv('SBM_E2E_PVE_TOKEN_ID');
  final tokenSecret = e2eEnv('SBM_E2E_PVE_TOKEN_SECRET');
  final vmId = e2eEnv('SBM_E2E_PVE_HW_VM');
  final ctId = e2eEnv('SBM_E2E_PVE_HW_CT');
  if (tokenId == null || tokenSecret == null || vmId == null || ctId == null) {
    return;
  }

  group('hardware: PVE over the monitor agent relay', () {
    late _World w;
    late String node;
    late VirtStoragePool storage;
    late VirtNetwork bridge;
    late VirtGuest vm;
    late VirtGuest ct;

    Future<VirtHardware> hw(VirtGuest g) => w.host.hardware(g.id);

    // The guests are the environment's, not this group's: what they were
    // before the first test, and the devices a test added to them, so that
    // teardown puts them back however far a test got.
    final saved = <String, VirtHardware>{};
    final addedDisks = <String, Set<String>>{};
    final addedNics = <String, Set<String>>{};

    /// The keys [after] has and [before] had not: what an add made, rather
    /// than the first device other than the default one, which may be one
    /// the guest already had.
    String addedKey(Iterable<String> before, Iterable<String> after) =>
        after.toSet().difference(before.toSet()).single;

    /// The pending entries this group made: the ones there before it ran
    /// are someone else's, and a removal it staged itself (a running
    /// container's mount point) is kept.
    List<String> ownPending(VirtGuest g, VirtHardware h) {
      final before = {for (final p in saved[g.id]?.pending ?? const <VirtPendingField>[]) p.key};
      final devices = {...?addedDisks[g.id], ...?addedNics[g.id]};
      return [
        for (final p in h.pending)
          if (!before.contains(p.key) && !devices.contains(p.key)) p.key,
      ];
    }

    Future<void> restore(VirtGuest g) async {
      final was = saved[g.id];
      if (was == null) return;
      Future<void> step(VirtHwChange? Function(VirtHardware h) change) async {
        try {
          final h = await hw(g);
          final c = change(h);
          if (c != null) await w.host.changeHardware(g.id, h, c);
        } catch (_) {}
      }

      for (final key in addedDisks[g.id] ?? const <String>{}) {
        await step((h) => h.disk(key) == null ? null : VirtHwRemoveDisk(key: key, deleteVolume: true));
      }
      for (final key in addedNics[g.id] ?? const <String>{}) {
        await step((h) => h.nic(key) == null ? null : VirtHwRemoveNic(key: key));
      }
      await step((h) {
        final keys = ownPending(g, h);
        return keys.isEmpty ? null : VirtHwRevert(keys);
      });
      // What took effect at once (a container's CPU and memory, the
      // settings) is set back to what it was.
      await step((h) => (h.cpu.sockets, h.cpu.cores) == (was.cpu.sockets, was.cpu.cores)
          ? null
          : VirtHwSetCpu(sockets: was.cpu.sockets, cores: was.cpu.cores));
      await step((h) => (h.memory.mib, h.memory.minMib, h.memory.swapMib) ==
              (was.memory.mib, was.memory.minMib, was.memory.swapMib)
          ? null
          : VirtHwSetMemory(mib: was.memory.mib, minMib: was.memory.minMib, swapMib: was.memory.swapMib));
      await step((h) => was.name == null || h.name == was.name ? null : VirtHwSetName(was.name!));
      await step((h) => h.description == was.description
          ? null
          : VirtHwSetDescription(was.description ?? ''));
      await step((h) => h.autostart == was.autostart ? null : VirtHwSetAutostart(was.autostart));
      await step((h) => (h.protection ?? false) == (was.protection ?? false)
          ? null
          : VirtHwSetProtection(was.protection ?? false));
      // A value set back on a running VM waits as a pending one.
      await step((h) {
        final keys = ownPending(g, h);
        return keys.isEmpty ? null : VirtHwRevert(keys);
      });
    }

    setUpAll(() async {
      w = _World(agent.spi('e2e-monitor-pve-hw'));
      Stores.pve.put(
        w.id,
        PveConfig(
          addr: 'https://localhost:8006',
          auth: PveAuth.token,
          tokenId: tokenId,
          tokenSecret: tokenSecret,
        ),
      );
      await w.host.firstLoad;
      final cert = w.state.error?.cert;
      if (cert != null) await w.host.confirmCert(cert.fingerprint);
      expect(w.state.error, isNull, reason: '${w.state.error}');
      final caps = w.state.data!.capabilities;
      expect((caps.hardware, caps.hardwareRevert), (true, true));
      vm = w.guest((g) => g.vmid == int.parse(vmId), 'VM $vmId');
      ct = w.guest((g) => g.vmid == int.parse(ctId), 'container $ctId');
      node = vm.node!;
      storage = virtDiskStorages(
        await w.host.storagePools(),
        host: VirtHostKind.pve,
        kind: VirtGuestKind.qemu,
        node: node,
      ).first;
      bridge = virtCreateNetworks(
        await w.host.networks(),
        host: VirtHostKind.pve,
        node: node,
      ).first;
      saved[vm.id] = await hw(vm);
      saved[ct.id] = await hw(ct);
    });
    tearDownAll(() async {
      await restore(vm);
      await restore(ct);
      await w.dispose();
    });

    test('a VM: read with the node\'s limits and CPU models', () async {
      final h = await hw(vm);
      expect(h.kind, VirtGuestKind.qemu);
      expect(h.running, isTrue);
      expect(h.revision, isNotEmpty);
      expect(h.disk('scsi0')!.size, 1 << 30);
      expect(h.disk('ide2')!.kind, VirtHwDiskKind.cdrom);
      expect(h.nics.map((n) => n.key), contains('net0'));
      expect(h.boot, isNotEmpty);
      expect(h.cpuTypes, contains('host'));
      expect(h.limits.hostCpus, greaterThan(0));
      expect(h.configText, contains('scsi0: '));
    });

    test('a VM: CPU pending while it runs, and reverted', () async {
      var h = await hw(vm);
      await w.host.changeHardware(
        vm.id,
        h,
        const VirtHwSetCpu(sockets: 1, cores: 2),
      );
      h = await hw(vm);
      expect(h.cpu.cores, 2);
      expect(h.pending.map((p) => p.key), contains('cores'));
      await w.host.changeHardware(vm.id, h, const VirtHwRevert(['cores']));
      h = await hw(vm);
      expect(h.cpu.cores, 1);
      expect(h.pending.map((p) => p.key), isNot(contains('cores')));
    });

    test('a VM: memory and its balloon floor', () async {
      var h = await hw(vm);
      await w.host.changeHardware(
        vm.id,
        h,
        const VirtHwSetMemory(mib: 768, minMib: 256),
      );
      h = await hw(vm);
      expect((h.memory.mib, h.memory.minMib), (768, 256));
      expect(h.pending.map((p) => p.key), contains('memory'));
    });

    test('a VM: an edit from an old digest is refused', () async {
      final old = await hw(vm);
      await w.host.changeHardware(vm.id, old, const VirtHwSetAutostart(true));
      final err = await _virtErr(
        w.host.changeHardware(vm.id, old, const VirtHwSetBoot(['ide2'])),
      );
      expect(err.type, VirtErrType.conflict);
      final h = await hw(vm);
      expect(h.autostart, isTrue);
      await w.host.changeHardware(vm.id, h, const VirtHwSetAutostart(false));
    });

    test('settings: a VM\'s name, note, start with the host, protection',
        () async {
      var h = await hw(vm);
      final name0 = h.name!;
      await w.host.changeHardware(vm.id, h, const VirtHwSetName('sb-e2e-set'));
      h = await hw(vm);
      expect(h.name, 'sb-e2e-set');
      // Taken at once, running or not.
      expect(h.pending.map((p) => p.key), isNot(contains('name')));
      await w.host.changeHardware(vm.id, h, VirtHwSetName(name0));
      h = await hw(vm);
      await w.host.changeHardware(
        vm.id,
        h,
        const VirtHwSetDescription('it\'s "a" note\nline two'),
      );
      h = await hw(vm);
      expect(h.description, 'it\'s "a" note\nline two');
      await w.host.changeHardware(vm.id, h, const VirtHwSetDescription(''));
      h = await hw(vm);
      expect(h.description, isNull);
      await w.host.changeHardware(vm.id, h, const VirtHwSetProtection(true));
      h = await hw(vm);
      expect(h.protection, isTrue);
      await w.host.changeHardware(vm.id, h, const VirtHwSetProtection(false));
      expect((await hw(vm)).protection, isFalse);
    });

    test('settings: a running container\'s hostname, taken at once',
        () async {
      var h = await hw(ct);
      final name0 = h.name!;
      await w.host.changeHardware(ct.id, h, const VirtHwSetName('sb-e2e-ct'));
      h = await hw(ct);
      expect(h.name, 'sb-e2e-ct');
      // PVE 9.2 writes a running container's hostname into it at once;
      // nothing waits for a restart.
      expect(h.pending.map((p) => p.key), isNot(contains('hostname')));
      await w.host.changeHardware(ct.id, h, VirtHwSetName(name0));
      expect((await hw(ct)).name, name0);
    });

    test('a VM: a disk added, grown, removed with its volume', () async {
      var h = await hw(vm);
      final before = h.disks.map((d) => d.key);
      await w.host.changeHardware(
        vm.id,
        h,
        VirtHwAddDisk(storage: storage, gib: 1),
      );
      h = await hw(vm);
      final key = addedKey(before, h.disks.map((d) => d.key));
      (addedDisks[vm.id] ??= {}).add(key);
      final added = h.disk(key)!;
      expect(added.kind, VirtHwDiskKind.disk);
      expect(added.size, 1 << 30);
      await w.host.changeHardware(
        vm.id,
        h,
        VirtHwGrowDisk(key: added.key, bytes: 2 << 30),
      );
      h = await hw(vm);
      expect(h.disk(added.key)!.size, 2 << 30);
      final out = await w.host.changeHardware(
        vm.id,
        h,
        VirtHwRemoveDisk(key: added.key, deleteVolume: true),
      );
      final vols = await w.host.volumes(storage);
      final volume = added.source!.split(':').last;
      if (out.volumeKept) {
        expect((await hw(vm)).pending.map((p) => p.key), contains(added.key));
      } else {
        expect((await hw(vm)).disk(added.key), isNull);
        expect(vols.map((v) => v.id), isNot(contains(added.source)));
        expect(vols.map((v) => v.name), isNot(contains(volume)));
      }
    });

    test('a VM: the CD-ROM takes an ISO, and gives it back', () async {
      var h = await hw(vm);
      final isos = <VirtVolume>[];
      for (final p in virtMediaStorages(
        await w.host.storagePools(),
        host: VirtHostKind.pve,
        kind: VirtGuestKind.qemu,
        node: node,
      )) {
        isos.addAll(
          (await w.host.volumes(p)).where(
            (v) => virtIsMedia(v, VirtGuestKind.qemu),
          ),
        );
      }
      if (isos.isEmpty) return;
      await w.host.changeHardware(
        vm.id,
        h,
        VirtHwSetMedia(key: 'ide2', media: _inPool(isos.first, await w.host.storagePools(), node: vm.node)),
      );
      h = await hw(vm);
      expect(h.disk('ide2')!.source, isos.first.id);
      await w.host.changeHardware(vm.id, h, const VirtHwSetMedia(key: 'ide2'));
      expect((await hw(vm)).disk('ide2')!.source, isNull);
    });

    test('a VM: a NIC added, disconnected behind a firewall, removed',
        () async {
      var h = await hw(vm);
      final before = h.nics.map((n) => n.key);
      await w.host.changeHardware(vm.id, h, VirtHwAddNic(network: bridge));
      h = await hw(vm);
      final key = addedKey(before, h.nics.map((n) => n.key));
      (addedNics[vm.id] ??= {}).add(key);
      final nic = h.nic(key)!;
      final mac = nic.mac;
      expect(mac, isNotNull);
      await w.host.changeHardware(
        vm.id,
        h,
        VirtHwUpdateNic(key: nic.key, linkUp: false, firewall: true),
      );
      h = await hw(vm);
      final after = h.nic(nic.key)!;
      expect((after.linkUp, after.firewall, after.mac), (false, true, mac));
      await w.host.changeHardware(vm.id, h, VirtHwRemoveNic(key: nic.key));
      expect((await hw(vm)).nic(nic.key), isNull);
    });

    test('a VM: boot order pending, then everything reverted', () async {
      var h = await hw(vm);
      await w.host.changeHardware(
        vm.id,
        h,
        const VirtHwSetBoot(['ide2', 'scsi0']),
      );
      h = await hw(vm);
      expect(h.boot, ['ide2', 'scsi0']);
      expect(h.pending.map((p) => p.key), contains('boot'));
      await w.host.changeHardware(vm.id, h, VirtHwRevert(ownPending(vm, h)));
      h = await hw(vm);
      expect(ownPending(vm, h), isEmpty);
      expect(h.memory.mib, saved[vm.id]!.memory.mib);
    });

    test('a container: cores, memory and swap, a mount point, a NIC', () async {
      var h = await hw(ct);
      expect(h.kind, VirtGuestKind.lxc);
      expect(h.boot, isNull);
      expect(h.disk('rootfs')!.kind, VirtHwDiskKind.rootfs);
      await w.host.changeHardware(
        ct.id,
        h,
        const VirtHwSetCpu(sockets: 1, cores: 2),
      );
      h = await hw(ct);
      await w.host.changeHardware(
        ct.id,
        h,
        const VirtHwSetMemory(mib: 384, swapMib: 128),
      );
      h = await hw(ct);
      expect((h.cpu.cores, h.memory.mib, h.memory.swapMib), (2, 384, 128));

      final ctStorage = virtDiskStorages(
        await w.host.storagePools(),
        host: VirtHostKind.pve,
        kind: VirtGuestKind.lxc,
        node: node,
      ).first;
      final disksBefore = h.disks.map((d) => d.key);
      await w.host.changeHardware(
        ct.id,
        h,
        VirtHwAddDisk(storage: ctStorage, gib: 1, mountPoint: '/mnt/e2e'),
      );
      h = await hw(ct);
      final mpKey = addedKey(disksBefore, h.disks.map((d) => d.key));
      (addedDisks[ct.id] ??= {}).add(mpKey);
      final mp = h.disk(mpKey)!;
      expect(mp.kind, VirtHwDiskKind.mount);
      expect(mp.mountPoint, '/mnt/e2e');
      final removed = await w.host.changeHardware(
        ct.id,
        h,
        VirtHwRemoveDisk(key: mp.key, deleteVolume: true),
      );
      h = await hw(ct);
      // A running container keeps the mount point until it stops (PVE 9.2):
      // the removal is pending, and its volume kept for then.
      final pending = h.pending.where((p) => p.key == mp.key).firstOrNull;
      if (removed.volumeKept) {
        expect(pending?.delete, isTrue, reason: '${h.pending}');
      } else {
        expect(pending, isNull);
      }
      expect(h.disk(mp.key), isNull);

      final nicsBefore = h.nics.map((n) => n.key);
      await w.host.changeHardware(ct.id, h, VirtHwAddNic(network: bridge));
      h = await hw(ct);
      final nicKey = addedKey(nicsBefore, h.nics.map((n) => n.key));
      (addedNics[ct.id] ??= {}).add(nicKey);
      final nic = h.nic(nicKey)!;
      expect(nic.name, startsWith('eth'));
      await w.host.changeHardware(ct.id, h, VirtHwRemoveNic(key: nic.key));
      h = await hw(ct);
      expect(h.nic(nic.key), isNull);
      // This test's own pending entries only; the staged removal of its
      // mount point stays, and teardown sets the CPU and memory back.
      final own = ownPending(ct, h);
      if (own.isNotEmpty) {
        await w.host.changeHardware(ct.id, h, VirtHwRevert(own));
      }
    });
  });
}

/// Disk bus and cache, NIC model and MAC, display, firmware and host
/// devices on a temporary domain.
void _libvirtHardwareDevices(_Agent agent) {
  final sudoPassword = e2eEnv('SBM_E2E_MONITOR_SUDO_PASSWORD');

  group('hardware devices: libvirt over the monitor agent', () {
    late _World w;
    final name = _e2eName('hwd');
    late VirtGuest g;

    Future<VirtHardware> hw() => w.host.hardware(g.id);

    setUpAll(() async {
      w = _World(agent.spi('e2e-monitor-libvirt-hwd'));
      await w.host.firstLoad;
      if (w.state.error?.type == VirtErrType.sudoPasswordRequired &&
          sudoPassword != null) {
        await w.host.provideSudoPassword(sudoPassword);
      }
      expect(w.state.error, isNull, reason: '${w.state.error}');
      final pool = virtDiskStorages(
        await w.host.storagePools(),
        host: VirtHostKind.libvirt,
        kind: VirtGuestKind.qemu,
      ).first;
      final net = virtCreateNetworks(
        await w.host.networks(),
        host: VirtHostKind.libvirt,
      ).firstWhere((n) => n.name == 'default');
      final created = await w.host.create(
        VirtCreateSpec(
          kind: VirtGuestKind.qemu,
          name: name,
          cores: 1,
          memoryMiB: 256,
          storage: pool,
          diskGiB: 1,
          network: net,
        ),
      );
      g = await w.settle(
        (x) => x.id == created.id,
        name,
        (x) => x.state == VirtGuestState.stopped,
      );
    });
    tearDownAll(() async {
      for (final x in w.state.data?.guests.where((x) => x.name == name) ?? const <VirtGuest>[]) {
        try {
          if (x.state != VirtGuestState.stopped) {
            await w.host.power(x.id, VirtPowerAction.forceStop);
            await w.host.refresh();
          }
          await w.host.delete(x.id);
        } catch (_) {}
      }
      await w.dispose();
    });

    test('what the host offers, from its domcapabilities', () async {
      final s = (await hw()).support;
      expect(s.buses, contains('sata'));
      expect(s.gpus, contains('virtio'));
      expect(s.protocols, contains('vnc'));
      // ignore: avoid_print
      print('libvirt offers uefi=${s.uefi} secureBoot=${s.secureBoot} tpm=${s.tpm} gpus=${s.gpus}');
    });

    test('a disk to another bus, and a cache mode', () async {
      var h = await hw();
      final disk = h.disks.firstWhere((d) => d.kind == VirtHwDiskKind.disk);
      await w.host.changeHardware(g.id, h, VirtHwUpdateDisk(key: disk.key, bus: 'sata'));
      h = await hw();
      final moved = h.disks.firstWhere((d) => d.kind == VirtHwDiskKind.disk);
      expect((moved.key.startsWith('sd'), moved.bus), (true, 'sata'));
      // The boot order follows the disk: it is still what the guest boots.
      expect(h.boot, contains(moved.key));
      await w.host.changeHardware(g.id, h, VirtHwUpdateDisk(key: moved.key, cache: 'writeback'));
      h = await hw();
      expect(h.disk(moved.key)!.cache, 'writeback');
    });

    test('a NIC\'s model and MAC', () async {
      var h = await hw();
      final nic = h.nics.first;
      await w.host.changeHardware(
        g.id,
        h,
        VirtHwSetNicHardware(key: nic.key, model: 'e1000e', mac: '52:54:00:5b:0e:02'),
      );
      h = await hw();
      expect((h.nics.first.mac, h.nics.first.model), ('52:54:00:5b:0e:02', 'e1000e'));
    });

    test('the display', () async {
      var h = await hw();
      await w.host.changeHardware(g.id, h, const VirtHwSetDisplay(listen: '0.0.0.0', gpu: 'vga'));
      h = await hw();
      expect((h.display!.listen, h.display!.gpu), ('0.0.0.0', 'vga'));
      await w.host.changeHardware(g.id, h, const VirtHwSetDisplay(listen: '127.0.0.1'));
      expect((await hw()).display!.listen, '127.0.0.1');
    });

    test('UEFI with Secure Boot: started on it, then back to BIOS', () async {
      var h = await hw();
      if (!h.support.secureBoot) {
        markTestSkipped('no Secure Boot firmware for this machine type here');
        return;
      }
      await w.host.changeHardware(g.id, h, const VirtHwSetFirmware(uefi: true, secureBoot: true));
      h = await hw();
      expect(h.firmware, const VirtHwFirmware(uefi: true, secureBoot: true));
      await w.host.power(g.id, VirtPowerAction.start);
      g = await w.settle((x) => x.id == g.id, name, (x) => x.state == VirtGuestState.running);
      h = await hw();
      expect((h.running, h.firmware!.secureBoot), (true, true));
      // Running: the firmware is not changed under it.
      expect(virtHwIssue(h, const VirtHwSetFirmware(uefi: false)), VirtHwIssue.stopFirst);
      await w.host.power(g.id, VirtPowerAction.forceStop);
      g = await w.settle((x) => x.id == g.id, name, (x) => x.state == VirtGuestState.stopped);
      await w.host.changeHardware(g.id, await hw(), const VirtHwSetFirmware(uefi: false));
      expect((await hw()).firmware, const VirtHwFirmware(uefi: false));
    });

    test('host devices, and a PCI device on a host without an IOMMU', () async {
      final devs = await w.host.hostDevices(g.id);
      expect(devs.pci, isNotEmpty);
      if (devs.iommu) {
        markTestSkipped('this host has an IOMMU: the refusal is not what it gives');
        return;
      }
      final pci = devs.pci.first;
      var h = await hw();
      await w.host.changeHardware(g.id, h, VirtHwAddDevice(kind: VirtHwDeviceKind.pci, host: pci));
      h = await hw();
      final key = 'pci:${pci.id}';
      expect(h.device(key)?.kind, VirtHwDeviceKind.pci);
      // The definition takes it; the host will not start it, and says why.
      final e = await _virtErr(w.host.power(g.id, VirtPowerAction.start));
      expect(e.message, contains('PCI'));
      await w.host.refresh();
      await w.host.changeHardware(g.id, await hw(), VirtHwRemoveDevice(key: key));
      expect((await hw()).device(key), isNull);
    });
  });
}

/// Disk bus and cache, NIC model and MAC, card, firmware and TPM on a
/// temporary VM, and host devices as a token sees them. Real passthrough is
/// `virt_real_test.dart`'s: making a resource mapping needs root on the node.
void _pveHardwareDevices(_Agent agent) {
  final tokenId = e2eEnv('SBM_E2E_PVE_TOKEN_ID');
  final tokenSecret = e2eEnv('SBM_E2E_PVE_TOKEN_SECRET');
  if (tokenId == null || tokenSecret == null) return;

  group('hardware devices: PVE over the monitor agent relay', () {
    late _World w;
    late VirtStoragePool storage;
    late VirtGuest g;
    final name = _e2eName('hwd');

    Future<VirtHardware> hw() => w.host.hardware(g.id);

    Future<void> stop() async {
      await w.host.refresh();
      if (w.state.guest(g.id)?.state != VirtGuestState.stopped) {
        await w.host.power(g.id, VirtPowerAction.forceStop);
      }
      g = await w.settle((x) => x.id == g.id, name, (x) => x.state == VirtGuestState.stopped);
    }

    setUpAll(() async {
      w = _World(agent.spi('e2e-monitor-pve-hwd'));
      Stores.pve.put(
        w.id,
        PveConfig(
          addr: 'https://localhost:8006',
          auth: PveAuth.token,
          tokenId: tokenId,
          tokenSecret: tokenSecret,
        ),
      );
      await w.host.firstLoad;
      final cert = w.state.error?.cert;
      if (cert != null) await w.host.confirmCert(cert.fingerprint);
      expect(w.state.error, isNull, reason: '${w.state.error}');
      final node = w.state.data!.host.nodes.first.name;
      storage = virtDiskStorages(
        await w.host.storagePools(),
        host: VirtHostKind.pve,
        kind: VirtGuestKind.qemu,
        node: node,
      ).first;
      final bridge = virtCreateNetworks(
        await w.host.networks(),
        host: VirtHostKind.pve,
        node: node,
      ).first;
      final created = await w.host.create(
        VirtCreateSpec(
          kind: VirtGuestKind.qemu,
          name: name,
          node: node,
          vmid: await w.host.nextVmid(),
          cores: 1,
          memoryMiB: 256,
          storage: storage,
          diskGiB: 1,
          network: bridge,
        ),
      );
      g = await w.settle((x) => x.id == created.id, name, (x) => x.state == VirtGuestState.stopped);
    });
    tearDownAll(() async {
      try {
        await stop();
        await w.host.delete(g.id);
      } catch (_) {}
      await w.dispose();
    });

    test('a disk to another bus, the boot order with it, and a cache mode', () async {
      var h = await hw();
      final disk = h.disks.firstWhere((d) => d.kind == VirtHwDiskKind.disk);
      await w.host.changeHardware(g.id, h, VirtHwUpdateDisk(key: disk.key, bus: 'virtio'));
      h = await hw();
      final moved = h.disks.firstWhere((d) => d.kind == VirtHwDiskKind.disk);
      expect(moved.key, startsWith('virtio'));
      expect(h.boot, contains(moved.key));
      await w.host.changeHardware(g.id, h, VirtHwUpdateDisk(key: moved.key, cache: 'writeback'));
      expect((await hw()).disk(moved.key)!.cache, 'writeback');
    });

    test('a NIC\'s model and MAC, and the card', () async {
      var h = await hw();
      await w.host.changeHardware(
        g.id,
        h,
        VirtHwSetNicHardware(key: h.nics.first.key, model: 'e1000e', mac: 'bc:24:11:5b:0e:03'),
      );
      h = await hw();
      expect((h.nics.first.model, h.nics.first.mac?.toLowerCase()), ('e1000e', 'bc:24:11:5b:0e:03'));
      await w.host.changeHardware(g.id, h, const VirtHwSetDisplay(gpu: 'virtio'));
      expect((await hw()).display!.gpu, 'virtio');
    });

    test('UEFI, Secure Boot on and off, and a TPM', () async {
      var h = await hw();
      await w.host.changeHardware(
        g.id,
        h,
        VirtHwSetFirmware(uefi: true, secureBoot: true, storage: storage),
      );
      h = await hw();
      expect(h.firmware!.uefi, isTrue);
      expect(h.firmware!.secureBoot, isTrue);
      await w.host.changeHardware(g.id, h, const VirtHwSetFirmware(uefi: true));
      h = await hw();
      expect((h.firmware!.uefi, h.firmware!.secureBoot), (true, false));
      await w.host.changeHardware(
        g.id,
        h,
        VirtHwAddDevice(kind: VirtHwDeviceKind.tpm, storage: storage),
      );
      h = await hw();
      expect(h.hasTpm, isTrue);
      await w.host.changeHardware(g.id, h, const VirtHwRemoveDevice(key: 'tpmstate0'));
      expect((await hw()).hasTpm, isFalse);
      // Nothing of the variables disks or the TPM state left behind.
      final vols = await w.host.volumes(storage);
      expect(vols.where((v) => v.id.contains('-${g.vmid}-')).length, 2, reason: 'the disk and one EFI disk');
    });

    test('host devices as a token sees them', () async {
      final devs = await w.host.hostDevices(g.id);
      expect(devs.mappingsOnly, isTrue);
      // ignore: avoid_print
      print('PVE host devices: iommu=${devs.iommu} usb=${devs.usb.length} pci=${devs.pci.length}');
    });

  });
}

void _pveCreate(_Agent agent) {
  final tokenId = e2eEnv('SBM_E2E_PVE_TOKEN_ID');
  final tokenSecret = e2eEnv('SBM_E2E_PVE_TOKEN_SECRET');
  if (tokenId == null || tokenSecret == null) return;

  group('create and delete: PVE over the monitor agent relay', () {
    late _World w;
    final created = <String>[];

    setUpAll(() async {
      w = _World(agent.spi('e2e-monitor-pve-create'));
      Stores.pve.put(
        w.id,
        PveConfig(
          addr: 'https://localhost:8006',
          auth: PveAuth.token,
          tokenId: tokenId,
          tokenSecret: tokenSecret,
        ),
      );
      await w.host.firstLoad;
      final cert = w.state.error?.cert;
      if (cert != null) await w.host.confirmCert(cert.fingerprint);
      expect(w.state.error, isNull, reason: '${w.state.error}');
    });
    tearDownAll(() async {
      for (final id in created) {
        final g = w.state.guest(id);
        if (g == null) continue;
        try {
          if (g.state != VirtGuestState.stopped) {
            await w.host.power(id, VirtPowerAction.forceStop);
            await w.host.refresh();
          }
          await w.host.delete(id);
        } catch (_) {}
      }
      await w.dispose();
    });

    /// Stopped by force, then deleted: gone from the list, and no volume of
    /// its VMID left on [storage].
    Future<void> stopAndDelete(VirtGuest g, VirtStoragePool storage) async {
      final running = await _virtErr(w.host.delete(g.id));
      expect(running.type, VirtErrType.unsupported);
      await w.host.power(g.id, VirtPowerAction.forceStop);
      await w.settle(
        (x) => x.id == g.id,
        g.name,
        (x) => x.state == VirtGuestState.stopped,
      );
      await w.host.delete(g.id);
      expect(w.state.guest(g.id), isNull);
      final vols = await w.host.volumes(storage);
      expect(vols.where((v) => v.id.contains('-${g.vmid}-')), isEmpty);
    }

    test('a VM with a serial port and a CD-ROM, started, then deleted',
        () async {
      final snap = w.state.data!;
      expect(snap.capabilities.create, isTrue);
      expect(snap.capabilities.deleteKeepsDisks, isFalse);
      final node = snap.host.nodes.firstWhere((n) => n.online).name;
      final pools = await w.host.storagePools();
      final storage = virtDiskStorages(
        pools,
        host: VirtHostKind.pve,
        kind: VirtGuestKind.qemu,
        node: node,
      ).first;
      final isos = <VirtVolume>[];
      for (final p in virtMediaStorages(
        pools,
        host: VirtHostKind.pve,
        kind: VirtGuestKind.qemu,
        node: node,
      )) {
        isos.addAll(
          (await w.host.volumes(p)).where(
            (v) => virtIsMedia(v, VirtGuestKind.qemu),
          ),
        );
      }
      final bridge = virtCreateNetworks(
        await w.host.networks(),
        host: VirtHostKind.pve,
        node: node,
      ).first;
      final vmid = (await w.host.nextVmid())!;
      final spec = VirtCreateSpec(
        kind: VirtGuestKind.qemu,
        name: _e2eName('vm'),
        node: node,
        vmid: vmid,
        cores: 1,
        memoryMiB: 512,
        storage: storage,
        diskGiB: 1,
        media: _inPool(isos.firstOrNull, await w.host.storagePools(), node: node),
        network: bridge,
        start: true,
      );
      expect(
        virtCreateIssue(spec, host: VirtHostKind.pve, guests: snap.guests),
        isNull,
      );
      final result = await w.host.create(spec);
      created.add(result.id);
      expect(result.id, 'qemu/$vmid');
      expect(result.startError, isNull);
      final g = await w.settle(
        (g) => g.id == result.id,
        spec.name,
        (g) => g.state == VirtGuestState.running,
      );
      final detail = await w.host.detail(g.id);
      expect(detail.consoles, containsAll(VirtConsoleKind.values));
      expect(
        detail.disks.where((d) => d.target == 'scsi0').single.source,
        startsWith('${storage.name}:'),
      );
      if (isos.isNotEmpty) {
        expect(
          detail.disks.where((d) => d.target == 'ide2').single.source,
          isos.first.id,
        );
      }

      // Its VMID again: taken, in PVE's words.
      final taken = await _virtErr(w.host.create(spec));
      expect(taken.type, VirtErrType.exists, reason: '${taken.message}');

      await stopAndDelete(g, storage);
      created.remove(result.id);
    });

    test('a container from a template, with a password, then deleted',
        () async {
      final snap = w.state.data!;
      final node = snap.host.nodes.firstWhere((n) => n.online).name;
      final pools = await w.host.storagePools();
      final storage = virtDiskStorages(
        pools,
        host: VirtHostKind.pve,
        kind: VirtGuestKind.lxc,
        node: node,
      ).first;
      final templates = <VirtVolume>[];
      for (final p in virtMediaStorages(
        pools,
        host: VirtHostKind.pve,
        kind: VirtGuestKind.lxc,
        node: node,
      )) {
        templates.addAll(
          (await w.host.volumes(p)).where(
            (v) => virtIsMedia(v, VirtGuestKind.lxc),
          ),
        );
      }
      if (templates.isEmpty) {
        markTestSkipped('no container template on $node');
        return;
      }
      final bridge = virtCreateNetworks(
        await w.host.networks(),
        host: VirtHostKind.pve,
        node: node,
      ).first;
      final vmid = (await w.host.nextVmid())!;
      final password = List.generate(
        16,
        (_) => 'abcdefghjkmnpqrstuvwxyz23456789'[Random.secure().nextInt(31)],
      ).join();
      final spec = VirtCreateSpec(
        kind: VirtGuestKind.lxc,
        name: _e2eName('ct'),
        node: node,
        vmid: vmid,
        cores: 1,
        memoryMiB: 256,
        storage: storage,
        diskGiB: 1,
        media: _inPool(templates.first, await w.host.storagePools(), node: node),
        network: bridge,
        password: password,
        start: true,
      );
      expect(
        virtCreateIssue(spec, host: VirtHostKind.pve, guests: snap.guests),
        isNull,
      );
      final result = await w.host.create(spec);
      created.add(result.id);
      expect(result.id, 'lxc/$vmid');
      expect(result.startError, isNull);
      final g = await w.settle(
        (g) => g.id == result.id,
        spec.name,
        (g) => g.state == VirtGuestState.running,
      );
      expect(g.kind, VirtGuestKind.lxc);
      final detail = await w.host.detail(g.id);
      expect(
        detail.disks.where((d) => d.target == 'rootfs').single.source,
        startsWith('${storage.name}:'),
      );
      await stopAndDelete(g, storage);
      created.remove(result.id);
    });
  });
}

Future<VirtErr> _virtErr(Future<Object?> future) async {
  try {
    await future;
  } on VirtErr catch (e) {
    return e;
  }
  fail('expected a VirtErr');
}

// -----------------------------------------------------------------------------
// Proxmox VE
// -----------------------------------------------------------------------------

void _pveCloneBackup(_Agent agent) {
  final tokenId = e2eEnv('SBM_E2E_PVE_TOKEN_ID');
  final tokenSecret = e2eEnv('SBM_E2E_PVE_TOKEN_SECRET');
  if (tokenId == null || tokenSecret == null) return;

  group('clone and backups: PVE over the monitor agent relay', () {
    late _World w;
    final name = _e2eName('bk');
    final made = <String>[];

    setUpAll(() async {
      w = _World(agent.spi('e2e-monitor-pve-clone'));
      Stores.pve.put(
        w.id,
        PveConfig(
          addr: 'https://localhost:8006',
          auth: PveAuth.token,
          tokenId: tokenId,
          tokenSecret: tokenSecret,
        ),
      );
      await w.host.firstLoad;
      final cert = w.state.error?.cert;
      if (cert != null) await w.host.confirmCert(cert.fingerprint);
      expect(w.state.error, isNull, reason: '${w.state.error}');
    });
    tearDownAll(() async {
      await w.host.refresh();
      for (final id in made) {
        final g = w.state.guest(id);
        if (g == null) continue;
        try {
          for (final b in await w.host.backups(id)) {
            await w.host.deleteBackup(id, b);
          }
        } catch (_) {}
        try {
          if (g.state != VirtGuestState.stopped) {
            await w.host.power(id, VirtPowerAction.forceStop);
            await w.host.refresh();
          }
          await w.host.delete(id);
        } catch (_) {}
      }
      await w.dispose();
    });

    test('a VM cloned, backed up, restored as new and over it, deleted',
        () async {
      final snap = w.state.data!;
      expect((snap.capabilities.clone, snap.capabilities.backup), (true, true));
      final node = snap.host.nodes.firstWhere((n) => n.online).name;
      final storage = virtDiskStorages(
        await w.host.storagePools(),
        host: VirtHostKind.pve,
        kind: VirtGuestKind.qemu,
        node: node,
      ).first;
      final vmid = (await w.host.nextVmid())!;
      final created = await w.host.create(
        VirtCreateSpec(
          kind: VirtGuestKind.qemu,
          name: name,
          node: node,
          vmid: vmid,
          cores: 1,
          memoryMiB: 128,
          storage: storage,
          diskGiB: 1,
        ),
      );
      made.add(created.id);
      final src = w.guest((g) => g.id == created.id, name);

      // Clone: full, a new VMID, stopped.
      final cloneId = await w.host.clone(src.id, VirtCloneRequest(name: '$name-c'));
      made.add(cloneId);
      // `/cluster/resources` names a new guest a moment after its task.
      final clone = await w.settle(
        (g) => g.id == cloneId,
        '$name-c',
        (g) => g.name == '$name-c',
      );
      expect(clone.vmid, isNot(src.vmid));
      final cloneHw = await w.host.hardware(clone.id);
      expect(cloneHw.disks.where((d) => d.kind == VirtHwDiskKind.disk), isNotEmpty);
      // Linked from a guest that is not a template: a full clone all the same.
      expect(src.template, isFalse);

      // Backups: where they can go, taken now, listed.
      final targets = await w.host.backupStorages(src.id);
      expect(targets, isNotEmpty);
      final target = targets.first;
      expect(await w.host.backups(src.id), isEmpty);
      await w.host.backup(src.id, VirtBackupRequest(storage: target.name, mode: 'stop'));
      final backups = await w.host.backups(src.id);
      expect(backups, hasLength(1));
      final b = backups.single;
      expect(b.vmid, src.vmid);
      expect(b.kind, VirtGuestKind.qemu);
      expect(b.fileName, startsWith('vzdump-qemu-${src.vmid}-'));
      expect(b.size, greaterThan(0));
      await w.host.backupJobs(src.id);

      // Restored as a new VM.
      final newVmid = (await w.host.nextVmid())!;
      await w.host.restoreBackup(src.id, b, vmid: newVmid);
      final restored = await w.settle(
        (g) => g.vmid == newVmid,
        'restored $newVmid',
        (g) => g.name == name,
      );
      made.add(restored.id);

      // Over the VM: refused while it runs, done once it is stopped.
      await w.host.power(src.id, VirtPowerAction.start);
      await w.settle((g) => g.id == src.id, name, (g) => g.state == VirtGuestState.running);
      final running = await _virtErr(w.host.restoreBackup(src.id, b));
      expect(running.type, VirtErrType.unsupported);
      await w.host.power(src.id, VirtPowerAction.forceStop);
      await w.settle((g) => g.id == src.id, name, (g) => g.state == VirtGuestState.stopped);
      await w.host.restoreBackup(src.id, b);

      // Deleted: the list is empty again.
      await w.host.deleteBackup(src.id, b);
      expect(await w.host.backups(src.id), isEmpty);

      for (final id in [restored.id, cloneId, src.id]) {
        await w.host.refresh();
        await w.host.delete(id);
        made.remove(id);
      }
    });

    /// A guest turned into a template, cloned from it, and the template
    /// deleted: the state reads as one, no power action is offered, PVE
    /// refuses to start it, and a linked clone shares its base image.
    test('a template: made, cloned, and never started', () async {
      final snap = w.state.data!;
      if (!snap.capabilities.template) {
        markTestSkipped('this host has no templates');
        return;
      }
      final node = snap.host.nodes.firstWhere((n) => n.online).name;
      final storage = virtDiskStorages(
        await w.host.storagePools(),
        host: VirtHostKind.pve,
        kind: VirtGuestKind.qemu,
        node: node,
      ).first;
      final vmid = (await w.host.nextVmid())!;
      final created = await w.host.create(
        VirtCreateSpec(
          kind: VirtGuestKind.qemu,
          name: '$name-tpl',
          node: node,
          vmid: vmid,
          cores: 1,
          memoryMiB: 128,
          storage: storage,
          diskGiB: 1,
        ),
      );
      made.add(created.id);
      // `/cluster/resources` names a new guest a moment after its task, and
      // a previous run's VMID may still be in that list with its old name.
      final src = await w.settle(
        (g) => g.id == created.id,
        '$name-tpl',
        (g) => g.name == '$name-tpl',
      );
      expect(src.template, isFalse);

      // Running: refused before anything is asked.
      await w.host.power(src.id, VirtPowerAction.start);
      await w.settle(
        (g) => g.id == src.id,
        '$name-tpl',
        (g) => g.state == VirtGuestState.running,
      );
      final running = await _virtErr(w.host.makeTemplate(src.id));
      expect(running.type, VirtErrType.unsupported);
      await w.host.power(src.id, VirtPowerAction.forceStop);
      await w.settle(
        (g) => g.id == src.id,
        '$name-tpl',
        (g) => g.state == VirtGuestState.stopped,
      );

      await w.host.makeTemplate(src.id);
      final tpl = await w.settle(
        (g) => g.id == src.id,
        '$name-tpl',
        (g) => g.template,
      );
      // A template offers nothing: no start, no stop, nothing.
      expect(tpl.actions, isEmpty);
      expect(w.state.actionsOf(tpl), isEmpty);
      // PVE refuses the start itself, in its own words.
      final startRefused = await _virtErr(
        w.host.power(tpl.id, VirtPowerAction.start),
      );
      expect(startRefused.type, VirtErrType.unsupported);
      // Making a template of a template is refused here, not by PVE.
      expect((await _virtErr(w.host.makeTemplate(tpl.id))).type, VirtErrType.unsupported);

      // A linked clone shares the template's disks; a full one copies them.
      final linkedId = await w.host.clone(
        tpl.id,
        VirtCloneRequest(name: '$name-linked', full: false),
      );
      made.add(linkedId);
      final linked = await w.settle(
        (g) => g.id == linkedId,
        '$name-linked',
        (g) => g.name == '$name-linked',
      );
      expect(linked.template, isFalse);
      final linkedHw = await w.host.hardware(linked.id);
      expect(
        linkedHw.disks.where((d) => d.kind == VirtHwDiskKind.disk),
        isNotEmpty,
      );
      // A storage and a node cannot be named on a linked clone (PVE refuses
      // both: `parameter 'storage' not allowed for linked clones`), so the
      // form refuses it — and the backend sends neither even if one is
      // passed, which is what makes this clone land at all.
      expect(
        virtCloneStorageIssue(
          storages: await w.host.storagePools(),
          storage: storage.name,
          full: false,
        ),
        VirtCreateIssue.cloneLinkedTarget,
      );
      expect(
        (await w.host.checkSchedule('02:30')).ok,
        isTrue,
        reason: 'the schedule call works on the same account',
      );
      final linkedTargetId = await w.host.clone(
        tpl.id,
        VirtCloneRequest(
          name: '$name-linked-target',
          full: false,
          storage: storage.name,
        ),
      );
      made.add(linkedTargetId);
      final linkedTarget = await w.settle(
        (g) => g.id == linkedTargetId,
        '$name-linked-target',
        (g) => g.name == '$name-linked-target',
      );
      // It shares the template's disk: the storage named was not used.
      expect(linkedTarget.template, isFalse);

      // A full clone of the template, onto the storage it is already on.
      final fullId = await w.host.clone(
        tpl.id,
        VirtCloneRequest(
          name: '$name-tpl-full',
          full: true,
          storage: storage.name,
        ),
      );
      made.add(fullId);
      final full = await w.settle(
        (g) => g.id == fullId,
        '$name-tpl-full',
        (g) => g.name == '$name-tpl-full',
      );
      expect(full.template, isFalse);

      // The clone runs; the template still does not.
      await w.host.power(linked.id, VirtPowerAction.start);
      await w.settle(
        (g) => g.id == linked.id,
        '$name-linked',
        (g) => g.state == VirtGuestState.running,
      );

      for (final id in [linkedTarget.id, linked.id, full.id, tpl.id]) {
        await w.host.refresh();
        final fresh = w.state.guest(id);
        if (fresh == null) continue;
        if (fresh.state != VirtGuestState.stopped) {
          await w.host.power(fresh.id, VirtPowerAction.forceStop);
          await w.host.refresh();
        }
        await w.host.delete(fresh.id);
        made.remove(fresh.id);
      }
    });

    /// The datacenter's backup jobs: made, listed, edited, run now and
    /// deleted, through the app's own calls. The job names this run's guest,
    /// so nothing else is backed up by it.
    test('a backup job: made, edited, run, deleted', () async {
      final snap = w.state.data!;
      if (!snap.capabilities.backupJobs) {
        markTestSkipped('this host has no backup jobs');
        return;
      }
      final node = snap.host.nodes.firstWhere((n) => n.online).name;
      final storages = await w.host.allBackupStorages();
      expect(storages, isNotEmpty, reason: 'no storage takes backups');
      final target = storages.firstWhere((s) => s.node == node);
      final storage = virtDiskStorages(
        await w.host.storagePools(),
        host: VirtHostKind.pve,
        kind: VirtGuestKind.qemu,
        node: node,
      ).first;
      final vmid = (await w.host.nextVmid())!;
      final created = await w.host.create(
        VirtCreateSpec(
          kind: VirtGuestKind.qemu,
          name: '$name-job',
          node: node,
          vmid: vmid,
          cores: 1,
          memoryMiB: 128,
          storage: storage,
          diskGiB: 1,
        ),
      );
      made.add(created.id);
      final src = await w.settle(
        (g) => g.id == created.id,
        '$name-job',
        (g) => g.name == '$name-job',
      );

      // What the host makes of a schedule, before anything is written: the
      // call PVE's own editor's Simulate button makes.
      expect((await w.host.checkSchedule('mon..fri 02:30')).ok, isTrue);
      expect(
        (await w.host.checkSchedule('mon..fri 02:30')).next,
        isNotEmpty,
      );
      final refused = await w.host.checkSchedule('not a schedule');
      expect(refused.ok, isFalse);
      expect(refused.error, isNotNull);

      final before = await w.host.allBackupJobs();
      expect(before.map((j) => j.id), isNot(contains('$name-job')));
      await w.host.editBackupJob(
        VirtBackupJobEdit(
          id: '$name-job',
          isNew: true,
          node: node,
          storage: target.name,
          schedule: 'mon..fri 02:30',
          mode: 'snapshot',
          compress: 'zstd',
          enabled: false,
          vmids: [src.vmid!],
          notesTemplate: 'sb e2e {{guestname}}',
          mailNotification: 'failure',
          prune: 'keep-last=2',
        ),
      );
      // Removed however far the test gets: the group's teardown takes
      // guests and backups, not jobs, and a job left names a VMID that may
      // be handed out again.
      addTearDown(() async {
        try {
          final left = (await w.host.allBackupJobs()).where((j) => j.id == '$name-job');
          if (left.isNotEmpty) {
            await w.host.editBackupJob(_jobEditOf(left.first), remove: true);
          }
        } catch (_) {}
      });
      final jobs = await w.host.allBackupJobs();
      expect(jobs, hasLength(before.length + 1));
      final job = jobs.firstWhere((j) => j.id == '$name-job');
      expect(job.schedule, 'mon..fri 02:30');
      expect(job.storage, target.name);
      expect((job.mode, job.compress), ('snapshot', 'zstd'));
      expect(job.enabled, isFalse);
      expect(job.vmids, [src.vmid]);
      expect(job.takesOnly(src.vmid), isTrue);
      expect(job.notesTemplate, 'sb e2e {{guestname}}');
      expect(job.mailNotification, 'failure');
      expect(job.prune, 'keep-last=2');
      expect(job.node, node);
      // The guest's own Plan group finds it; another VMID does not.
      expect(
        (await w.host.backupJobs(src.id)).map((j) => j.id),
        contains('$name-job'),
      );

      // Edited: the schedule and the mode, and off `all`.
      await w.host.editBackupJob(
        _jobEditOf(job, schedule: 'sat 03:00', mode: 'stop'),
      );
      final edited = (await w.host.allBackupJobs())
          .firstWhere((j) => j.id == '$name-job');
      expect((edited.schedule, edited.mode), ('sat 03:00', 'stop'));

      // Run now: the job's own fields without its schedule.
      await w.host.runBackupJob(edited);
      final backups = await w.host.backups(src.id);
      expect(backups, isNotEmpty, reason: 'the run made no backup');
      for (final b in backups) {
        await w.host.deleteBackup(src.id, b);
      }

      // Deleted, with the guest's own backups left where they were.
      await w.host.editBackupJob(_jobEditOf(edited), remove: true);
      expect(
        (await w.host.allBackupJobs()).map((j) => j.id),
        isNot(contains('$name-job')),
      );

      await w.host.refresh();
      await w.host.delete(src.id);
      made.remove(src.id);
    });
  });
}

/// [job] with the fields named replaced, the rest as they are: what an edit
/// of an existing job is.
VirtBackupJobEdit _jobEditOf(
  VirtBackupJob job, {
  String? schedule,
  String? mode,
}) => VirtBackupJobEdit(
  id: job.id,
  node: job.node,
  storage: job.storage ?? '',
  schedule: schedule ?? job.schedule ?? '',
  mode: mode ?? job.mode ?? 'snapshot',
  compress: job.compress ?? 'zstd',
  enabled: job.enabled,
  all: job.all,
  vmids: job.vmids,
  exclude: job.exclude,
  pool: job.pool,
  comment: job.comment,
  notesTemplate: job.notesTemplate,
  mailNotification: job.mailNotification,
  prune: job.prune,
);

void _pve(_Agent agent) {
  final tokenId = e2eEnv('SBM_E2E_PVE_TOKEN_ID');
  final tokenSecret = e2eEnv('SBM_E2E_PVE_TOKEN_SECRET');
  if (tokenId == null || tokenSecret == null) {
    test(
      'PVE over monitor',
      () {},
      skip: 'SBM_E2E_PVE_TOKEN_ID / _SECRET unset',
    );
    return;
  }
  final lxcId = int.parse(e2eEnv('SBM_E2E_PVE_LXC') ?? '200');
  final vmId = int.parse(e2eEnv('SBM_E2E_PVE_VM') ?? '100');

  group('PVE over the monitor agent relay', () {
    late _World w;
    bool isCt(VirtGuest g) => g.kind == VirtGuestKind.lxc && g.vmid == lxcId;
    bool isVm(VirtGuest g) => g.kind == VirtGuestKind.qemu && g.vmid == vmId;

    setUpAll(() {
      w = _World(agent.spi('e2e-monitor-pve'));
      Stores.pve.put(
        w.id,
        PveConfig(
          // Resolved by the agent, on the node.
          addr: 'https://localhost:8006',
          auth: PveAuth.token,
          tokenId: tokenId,
          tokenSecret: tokenSecret,
        ),
      );
    });
    tearDownAll(() => w.dispose());

    test('certificate: unconfirmed over the relay, confirmed, then loaded',
        () async {
      // No status poll first: the grant has not been read, which is how the
      // tab finds a server at app start. The relay is tried, not refused.
      expect(w.container.read(serverProvider(w.id)).remoteAccess, isNull);
      await w.host.firstLoad;
      final e = w.state.error;
      expect(e?.type, VirtErrType.certUnconfirmed, reason: '$e');
      final fingerprint = e!.cert!.fingerprint;
      await w.host.confirmCert(fingerprint);
      expect(w.state.error, isNull, reason: '${w.state.error}');
      expect(Stores.pve.fetch(w.id)?.certSha256, fingerprint.toLowerCase());

      final snap = w.state.data!;
      expect(snap.host.kind, VirtHostKind.pve);
      expect(snap.host.version, matches(RegExp(r'^\d+\.\d+')));
      expect(snap.host.nodes, isNotEmpty);
      expect(w.guest(isVm, 'VM $vmId').state, VirtGuestState.running);
      expect(w.guest(isCt, 'CT $lxcId').state, VirtGuestState.running);
    });

    test('storage and networks through the relay', () async {
      final c = w.container;
      final pools = await c.read(virtStoragePoolsProvider(w.id).future);
      final images = pools.firstWhere(
        (p) => p.active && p.content.contains('images'),
        orElse: () => fail('no active storage for disk images'),
      );
      final vols = await c.read(virtVolumesProvider(w.id, images.id).future);
      expect(vols.any((v) => v.users.any((u) => u.vmid == vmId)), isTrue);
      final nets = await c.read(virtNetworksProvider(w.id).future);
      final users = {
        for (final n in nets) ...n.users.map((u) => u.vmid),
      };
      expect(users, containsAll([vmId, lxcId]));
    });

    test('power: reboot the container and wait for its task', () async {
      final ct = w.guest(isCt, 'CT $lxcId');
      final before = ct.uptime;
      await w.host.power(ct.id, VirtPowerAction.reboot);
      // `power` ends the task and starts a refresh of its own, which the
      // first of these waits behind.
      final after = await w.settle(
        isCt,
        'CT $lxcId',
        (g) =>
            g.state == VirtGuestState.running &&
            (before == null || (g.uptime != null && g.uptime! < before)),
      );
      expect(after.uptime, isNotNull);
    });

    test('termproxy on the container: login prompt and input', () async {
      final ct = w.guest(isCt, 'CT $lxcId');
      final term = await VirtConsoleConnect.pveTerminal(
        w.container,
        serverId: w.id,
        guestId: ct.id,
      );
      final shell = await term.openShell(width: 80, height: 24);
      final out = _Collector(shell.stdout!);
      try {
        // Right after a reboot getty may not be up yet: keep asking.
        for (var i = 0; i < 20 && !out.text.contains('login:'); i++) {
          shell.write(utf8.encode('\r'));
          await Future<void>.delayed(const Duration(seconds: 1));
        }
        await out.waitFor('login:');
        final marker = 'sbm-e2e-${Random().nextInt(1 << 30)}';
        out.clear();
        shell.write(utf8.encode('$marker\r'));
        await out.waitFor('Password');
        expect(out.text, contains(marker));
        shell.write(utf8.encode('\r'));
      } finally {
        shell.close();
        await out.cancel();
      }
    });

    test('vncproxy: RFB and VNC auth through the relay and websocket',
        () async {
      final vm = w.guest(isVm, 'VM $vmId');
      final target = await VirtConsoleConnect.vncTarget(
        w.container,
        serverId: w.id,
        guestId: vm.id,
      )();
      final password = target.password!;
      expect(password.length, 8);
      final rfb = _RfbReader(
        await connectTunnel(target.tunnel),
      );
      try {
        expect(
          ascii.decode(await rfb.take(12)),
          matches(RegExp(r'^RFB 003\.00\d\n$')),
        );
        rfb.add(ascii.encode('RFB 003.008\n'));
        final count = (await rfb.take(1)).single;
        final types = await rfb.take(count);
        expect(types, contains(2));
        rfb.add([2]);
        rfb.add(_vncResponse(password, await rfb.take(16)));
        final result = ByteData.sublistView(
          Uint8List.fromList(await rfb.take(4)),
        ).getUint32(0);
        expect(result, 0, reason: 'SecurityResult OK');
      } finally {
        await rfb.close();
        await target.tunnel.close();
      }
    });
  });
}

// -----------------------------------------------------------------------------
// Proxmox VE, a QEMU VM of the test's own
// -----------------------------------------------------------------------------

/// The QEMU power cycle, consoles and detail of `SBM_E2E_PVE_TEST_VM` through
/// the agent's relay and the providers, plus the one-action-at-a-time rule
/// `VirtHostNotifier.power` keeps. Leaves the VM stopped.
void _pveTestVm(_Agent agent) {
  final tokenId = e2eEnv('SBM_E2E_PVE_TOKEN_ID');
  final tokenSecret = e2eEnv('SBM_E2E_PVE_TOKEN_SECRET');
  final vmRaw = e2eEnv('SBM_E2E_PVE_TEST_VM');
  if (tokenId == null || tokenSecret == null || vmRaw == null) {
    test(
      'PVE test VM over monitor',
      () {},
      skip: 'SBM_E2E_PVE_TOKEN_ID / _SECRET / SBM_E2E_PVE_TEST_VM unset',
    );
    return;
  }
  final vmid = int.parse(vmRaw);
  final rootPassword = e2eEnv('SBM_E2E_PVE_TEST_VM_ROOT_PASSWORD');

  group('PVE test VM $vmid over the monitor agent relay', () {
    late _World w;
    bool isVm(VirtGuest g) => g.kind == VirtGuestKind.qemu && g.vmid == vmid;
    final what = 'VM $vmid';
    VirtGuest vm() => w.guest(isVm, what);
    Future<VirtGuest> settle(bool Function(VirtGuest g) test) =>
        w.settle(isVm, what, test);

    setUpAll(() async {
      w = _World(agent.spi('e2e-monitor-pve-vm'));
      Stores.pve.put(
        w.id,
        PveConfig(
          addr: 'https://localhost:8006',
          auth: PveAuth.token,
          tokenId: tokenId,
          tokenSecret: tokenSecret,
        ),
      );
      await w.host.firstLoad;
      final e = w.state.error;
      expect(e?.type, VirtErrType.certUnconfirmed, reason: '$e');
      await w.host.confirmCert(e!.cert!.fingerprint);
      expect(w.state.error, isNull, reason: '${w.state.error}');
    });
    tearDownAll(() async {
      // Stopped, whatever a failed test left behind.
      try {
        await w.host.refresh();
        final g = vm();
        if (w.state.actionsOf(g).contains(VirtPowerAction.forceStop)) {
          await w.host.power(g.id, VirtPowerAction.forceStop);
        }
      } finally {
        await w.dispose();
      }
    });

    test('start: running, with the running actions', () async {
      var g = vm();
      if (g.state == VirtGuestState.paused) {
        await w.host.power(g.id, VirtPowerAction.resume);
        g = await settle((g) => g.state == VirtGuestState.running);
      }
      if (g.state == VirtGuestState.running) {
        await w.host.power(g.id, VirtPowerAction.forceStop);
        g = await settle((g) => g.state == VirtGuestState.stopped);
      }
      expect(g.actions, {VirtPowerAction.start});
      // A start straight after a stop meets `qmeventd`'s cleanup holding
      // the config lock for 30 s (docs/dev/virt.md).
      await Future<void>.delayed(const Duration(seconds: 5));
      await w.host.power(g.id, VirtPowerAction.start);
      g = await settle((g) => g.state == VirtGuestState.running);
      expect(g.actions, {
        VirtPowerAction.shutdown,
        VirtPowerAction.reboot,
        VirtPowerAction.forceStop,
        VirtPowerAction.suspend,
      });
    });

    test('detail: disks, NIC, display and both consoles', () async {
      final d = await w.host.detail(vm().id);
      expect(d.disks.map((x) => x.target), containsAll(['scsi0', 'ide2']));
      expect(d.nics.single.model, 'virtio');
      expect(d.nics.single.source, 'vmbr0');
      expect(d.graphics.map((g) => g.kind), ['std']);
      expect(d.consoles, {VirtConsoleKind.vnc, VirtConsoleKind.text});
    });

    test('serial console: getty on ttyS0 through the relay, typed into',
        () async {
      final term = await VirtConsoleConnect.pveTerminal(
        w.container,
        serverId: w.id,
        guestId: vm().id,
      );
      final shell = await term.openShell(width: 80, height: 24);
      final out = _Collector(shell.stdout!);
      try {
        await _serialLogin(shell, out, rootPassword);
      } finally {
        shell.close();
        await out.cancel();
      }
    });

    test('vncproxy: RFB and VNC auth through the relay', () async {
      final target = await VirtConsoleConnect.vncTarget(
        w.container,
        serverId: w.id,
        guestId: vm().id,
      )();
      final rfb = _RfbReader(
        await connectTunnel(target.tunnel),
      );
      try {
        expect(
          ascii.decode(await rfb.take(12)),
          matches(RegExp(r'^RFB 003\.00\d\n$')),
        );
        rfb.add(ascii.encode('RFB 003.008\n'));
        final count = (await rfb.take(1)).single;
        expect(await rfb.take(count), contains(2));
        rfb.add([2]);
        rfb.add(_vncResponse(target.password!, await rfb.take(16)));
        final result = ByteData.sublistView(
          Uint8List.fromList(await rfb.take(4)),
        ).getUint32(0);
        expect(result, 0, reason: 'SecurityResult OK');
      } finally {
        await rfb.close();
        await target.tunnel.close();
      }
    });

    test('one action at a time: a second one while suspending is refused',
        () async {
      final id = vm().id;
      final suspending = w.host.power(id, VirtPowerAction.suspend);
      // In flight: reads as stopping, offers nothing, refuses another.
      expect(w.state.busy[id], VirtPowerAction.suspend);
      expect(w.state.displayState(vm()), VirtGuestState.stopping);
      expect(w.state.actionsOf(vm()), isEmpty);
      try {
        await w.host.power(id, VirtPowerAction.forceStop);
        fail('a second action was accepted');
      } on VirtErr catch (e) {
        expect(e.type, VirtErrType.unsupported);
      }
      await suspending;
      expect(w.state.busy, isEmpty);

      final paused = await settle((g) => g.state == VirtGuestState.paused);
      expect(w.state.actionsOf(paused), {
        VirtPowerAction.resume,
        VirtPowerAction.forceStop,
      });
      await w.host.power(id, VirtPowerAction.resume);
      await settle((g) => g.state == VirtGuestState.running);
    });

    test('reboot: running again with the uptime reset', () async {
      final before = (await settle(
        (g) => (g.uptime?.inSeconds ?? 0) > 5,
      )).uptime!;
      await w.host.power(vm().id, VirtPowerAction.reboot);
      final after = await settle(
        (g) =>
            g.state == VirtGuestState.running &&
            g.uptime != null &&
            g.uptime! < before,
      );
      expect(w.state.actionsOf(after), contains(VirtPowerAction.reboot));
    });

    test('shutdown (ACPI), start, force stop', () async {
      // Past the boot: an ACPI request during it is lost (docs/dev/virt.md).
      for (var i = 0; i < 60 && (vm().uptime?.inSeconds ?? 0) < 30; i++) {
        await Future<void>.delayed(const Duration(seconds: 1));
        await w.host.refresh();
      }
      expect(vm().uptime?.inSeconds, greaterThanOrEqualTo(30));
      await w.host.power(vm().id, VirtPowerAction.shutdown);
      var g = await settle((g) => g.state == VirtGuestState.stopped);
      expect(g.actions, {VirtPowerAction.start});
      await Future<void>.delayed(const Duration(seconds: 5));
      await w.host.power(g.id, VirtPowerAction.start);
      await settle((g) => g.state == VirtGuestState.running);
      await w.host.power(g.id, VirtPowerAction.forceStop);
      g = await settle((g) => g.state == VirtGuestState.stopped);
      expect(g.actions, {VirtPowerAction.start});
    });
  });
}

/// At the guest's serial getty: Enter until `login:`, then a root login with
/// [password] and a command only a shell answers with 42 — or, without one,
/// a marker typed as the login name, which getty answers with a password
/// prompt.
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
  await out.waitFor('#');
  out.clear();
  shell.write(utf8.encode('echo $marker-\$((6*7))\r'));
  await out.waitFor('$marker-42');
  out.clear();
  shell.write(utf8.encode('exit\r'));
  await out.waitFor('login:');
}

// -----------------------------------------------------------------------------
// An agent without full access
// -----------------------------------------------------------------------------

void _restricted(_Agent agent) {
  group('an agent without full access', () {
    test('libvirt: the command is refused as not granted', () async {
      final w = _World(agent.spi('e2e-monitor-restricted-libvirt'));
      try {
        await w.host.firstLoad;
        final e = w.state.error;
        expect(e?.type, VirtErrType.execNotGranted, reason: '$e');
        expect(e?.solution, isNotNull);
        // What the host list makes of it: not a host, and why.
        await w.container.read(virtHostsProvider.notifier).probe(w.id);
        final probe = w.container.read(virtHostsProvider).probes[w.id];
        expect(probe?.status, VirtProbeStatus.failed);
        expect(probe?.error?.type, VirtErrType.execNotGranted);
      } finally {
        await w.dispose();
      }
    });

    for (final polled in [false, true]) {
      test('PVE: the relay is refused as not granted '
          '(grant ${polled ? 'read' : 'not read yet'})', () async {
        final w = _World(
          agent.spi('e2e-monitor-restricted-pve-${polled ? 1 : 0}'),
        );
        try {
          Stores.pve.put(
            w.id,
            const PveConfig(
              addr: 'https://localhost:8006',
              auth: PveAuth.token,
              tokenId: 'nobody@pve!e2e',
              tokenSecret: '00000000-0000-0000-0000-000000000000',
            ),
          );
          if (polled) {
            await w.poll();
            final granted = w.container.read(serverProvider(w.id)).remoteAccess;
            expect(granted?.stream, isFalse, reason: '$granted');
          }
          await w.host.firstLoad;
          final e = w.state.error;
          expect(e?.type, VirtErrType.relayNotGranted, reason: '$e');
          expect(
            (e?.cause as ServerTcpErr?)?.type,
            ServerTcpErrType.relayNotGranted,
          );
        } finally {
          await w.dispose();
        }
      });
    }
  });
}

// -----------------------------------------------------------------------------
// Helpers
// -----------------------------------------------------------------------------

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
    Duration timeout = const Duration(seconds: 30),
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

/// RFB's VNC authentication: the challenge DES-encrypted with the password,
/// each key byte bit-reversed. Single DES is 3DES-EDE with three equal keys.
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

// -----------------------------------------------------------------------------
// External snapshots, the chain and the diff (phase 8)
// -----------------------------------------------------------------------------

/// Over the agent: the whole phase-8 path through the providers, which is what
/// the app runs. `SBM_E2E_LIBVIRT_CLOUD_IMAGE`'s pool is not needed — the
/// guest is made with the create set the other groups use.
void _p8Libvirt(_Agent agent) {
  final sudoPassword = e2eEnv('SBM_E2E_MONITOR_SUDO_PASSWORD');

  group('snapshots: external, chain and diff over the monitor agent', () {
    late _World w;
    final name = _e2eName('snapext');

    setUpAll(() async {
      w = _World(agent.spi('e2e-monitor-libvirt-snapext'));
      await w.host.firstLoad;
      if (w.state.error?.type == VirtErrType.sudoPasswordRequired &&
          sudoPassword != null) {
        await w.host.provideSudoPassword(sudoPassword);
      }
      expect(w.state.error, isNull, reason: '${w.state.error}');
    });
    tearDownAll(() async {
      final left = w.state.data?.guests.where((g) => g.name == name);
      for (final g in left ?? const <VirtGuest>[]) {
        try {
          if (g.state != VirtGuestState.stopped) {
            await w.host.power(g.id, VirtPowerAction.forceStop);
            await w.host.refresh();
          }
          await w.host.delete(g.id);
        } catch (_) {}
      }
      await w.dispose();
    });

    test('a disk-only snapshot while running: the chain, the diff, a revert',
        () async {
      final snap = w.state.data!;
      expect(
        snap.capabilities.snapshotExternal,
        isTrue,
        reason: 'libvirt writes external snapshots',
      );
      final pools = await w.host.storagePools();
      final pool = virtDiskStorages(
        pools,
        host: VirtHostKind.libvirt,
        kind: VirtGuestKind.qemu,
      ).first;
      await w.host.create(
        VirtCreateSpec(
          kind: VirtGuestKind.qemu,
          name: name,
          cores: 1,
          memoryMiB: 256,
          storage: pool,
          diskGiB: 1,
          start: true,
        ),
      );
      final g = await w.settle(
        (x) => x.name == name,
        name,
        (x) => x.state == VirtGuestState.running,
      );

      final before = await w.host.snapshotChain(g.id);
      expect(before.disks, isNotEmpty);
      expect(before.hasOverlays, isFalse);
      expect(await w.host.snapshotRefusal(g.id), isNull);

      await w.host.createSnapshot(
        g.id,
        name: 'sbxe2e-ext',
        form: VirtSnapshotForm.external,
      );
      final running = await w.settle(
        (x) => x.name == name,
        name,
        (x) => x.state == VirtGuestState.running,
      );
      final after = await w.host.snapshotChain(running.id);
      expect(after.hasOverlays, isTrue, reason: 'the guest is on an overlay');
      expect(after.depth, 2);
      expect(
        after.disks.first.files.first.backing,
        before.disks.first.files.first.path,
      );
      expect(after.disks.first.files.first.snap, 'sbxe2e-ext');

      // The listing carries the layer's file.
      final listed = await w.host.snapshots(running.id);
      final ext = listed.singleWhere((s) => s.name == 'sbxe2e-ext');
      expect(ext.external, isTrue);
      expect(ext.withMemory, isFalse);
      expect(ext.layers, isNotEmpty);

      // The diff: a memory change in the definition while the snapshot stays.
      final hw = await w.host.hardware(running.id);
      await w.host.changeHardware(
        running.id,
        hw,
        const VirtHwSetMemory(mib: 384),
      );
      final diff = await w.host.snapshotDiff(running.id, 'sbxe2e-ext');
      expect(
        diff.any((d) => d.group == VirtSnapDiffGroup.memory),
        isTrue,
        reason: '$diff',
      );

      // A second snapshot deepens the chain, and this one deletes cleanly:
      // nothing was reverted behind it, so its layer's file is still there.
      await w.host.createSnapshot(
        running.id,
        name: 'sbxe2e-plain',
        form: VirtSnapshotForm.external,
      );
      final deeper = await w.settle(
        (x) => x.name == name,
        name,
        (x) => x.state == VirtGuestState.running,
      );
      expect((await w.host.snapshotChain(deeper.id)).depth, 3);
      await w.host.deleteSnapshot(deeper.id, 'sbxe2e-plain');
      final lean = w.guest((x) => x.name == name, name);
      expect(
        (await w.host.snapshots(lean.id)).map((s) => s.name),
        isNot(contains('sbxe2e-plain')),
      );
      expect((await w.host.snapshotChain(lean.id)).depth, 2);

      // Reverting to it (a leaf) drops the overlay the guest was writing and
      // starts it on a new one over the file the snapshot kept: two layers.
      await w.host.revertSnapshot(running.id, 'sbxe2e-ext', start: true);
      await w.settle((x) => x.name == name, name, (x) => true);
      final back = w.guest((x) => x.name == name, name);
      final flat = await w.host.snapshotChain(back.id);
      expect(flat.disks.first.files, hasLength(2));
      // The chain is still readable, which is the app's own rule: a guest is
      // never left on one it cannot read back.
      expect(flat.disks.first.isChain, isTrue);
      expect(flat.disks.first.files.first.format, 'qcow2');
      // And the guest is on a file that is there.
      expect(flat.disks.first.files.first.path, isNotEmpty);

      // Deleting the snapshot that was reverted to would commit its overlay
      // into the base, which AppArmor's profile denies QEMU writing (`deny
      // ... w` for a file that was already a backing file when QEMU
      // started; Debian #932456). The app refuses it before the host is
      // asked, which would refuse it too and mark the disk.
      final e = await _virtErr(w.host.deleteSnapshot(back.id, 'sbxe2e-ext'));
      expect(e.type, VirtErrType.unsupported);
      expect(e.message, contains('#932456'));
      expect(
        (await w.host.snapshots(back.id)).map((s) => s.name),
        contains('sbxe2e-ext'),
      );
    });

  });
}

// -----------------------------------------------------------------------------
// PVE: storage support and the config diff (phase 8)
// -----------------------------------------------------------------------------

/// Over the agent's relay. The token needs `VM.Audit`, `VM.Snapshot`,
/// `VM.Snapshot.Rollback`, `VM.Config.Memory` and `Datastore.AllocateSpace`.
void _p8Pve(_Agent agent) {
  final tokenId = e2eEnv('SBM_E2E_PVE_TOKEN_ID');
  final tokenSecret = e2eEnv('SBM_E2E_PVE_TOKEN_SECRET');
  if (tokenId == null || tokenSecret == null) return;

  group('snapshots: storage support and the diff (PVE relay)', () {
    late _World w;
    final name = _e2eName('snappve');
    final made = <String>[];
    /// A directory storage the run added, with the path to remove.
    final madeDir = <(String, String)>[];

    setUpAll(() async {
      w = _World(agent.spi('e2e-monitor-pve-snap'));
      Stores.pve.put(
        w.id,
        PveConfig(
          addr: 'https://localhost:8006',
          auth: PveAuth.token,
          tokenId: tokenId,
          tokenSecret: tokenSecret,
        ),
      );
      await w.host.firstLoad;
      final cert = w.state.error?.cert;
      if (cert != null) await w.host.confirmCert(cert.fingerprint);
      expect(w.state.error, isNull, reason: '${w.state.error}');
    });
    tearDownAll(() async {
      await w.host.refresh();
      for (final id in made) {
        // The listing names a guest a moment after its task: asked again
        // before it is given up on, or its disk outlives the storage.
        var g = w.state.guest(id);
        for (var i = 0; g == null && i < 10; i++) {
          await Future<void>.delayed(const Duration(seconds: 1));
          await w.host.refresh();
          g = w.state.guest(id);
        }
        if (g == null) {
          // ignore: avoid_print
          print('$id was never listed again; left on the node');
          continue;
        }
        try {
          for (final s in await w.host.snapshots(id)) {
            await w.host.deleteSnapshot(id, s.name);
          }
        } catch (_) {}
        try {
          if (g.state != VirtGuestState.stopped) {
            await w.host.power(id, VirtPowerAction.forceStop);
            await w.host.refresh();
          }
          await w.host.delete(id);
        } catch (e) {
          // ignore: avoid_print
          print('$id not deleted: $e');
        }
      }
      for (final (store, path) in madeDir) {
        try {
          final p = (await w.host.storagePools()).firstWhere(
            (x) => x.name == store,
          );
          await w.host.manage(VirtPoolDelete(p, deleteStorage: true));
          // PVE removes the configuration only. The directory it made is
          // root's and the agent's account is not (no sudo on a PVE node):
          // said, so it is removed by hand. The next run reuses the path.
          if (path.startsWith('/var/lib/sbxe2e-')) {
            final r = await (await w.server.ensureExec()).run("rm -rf -- '$path'");
            if (!r.succeeded) {
              // ignore: avoid_print
              print('$path is left on the node (root owns it): ${r.stderr.trim()}');
            }
          }
        } catch (e) {
          // ignore: avoid_print
          print('storage $store not removed: $e');
        }
      }
      await w.dispose();
    });

    test('a thin storage snapshots, and the diff reads a memory change',
        () async {
      final snap = w.state.data!;
      expect(snap.capabilities.snapshotSupported, isTrue);
      final node = snap.host.nodes.firstWhere((n) => n.online).name;
      final storage = virtDiskStorages(
        await w.host.storagePools(),
        host: VirtHostKind.pve,
        kind: VirtGuestKind.qemu,
        node: node,
      ).first;
      final vmid = (await w.host.nextVmid())!;
      await w.host.create(
        VirtCreateSpec(
          kind: VirtGuestKind.qemu,
          name: name,
          node: node,
          vmid: vmid,
          cores: 1,
          memoryMiB: 128,
          storage: storage,
          diskGiB: 1,
          start: true,
        ),
      );
      final g = await w.settle(
        (x) => x.vmid == vmid,
        name,
        (x) => x.state == VirtGuestState.running,
      );
      made.add(g.id);
      // PVE's own answer about this guest's storages.
      expect(
        await w.host.snapshotRefusal(g.id),
        isNull,
        reason: 'a thin volume can be snapshotted',
      );

      await w.host.createSnapshot(g.id, name: 'sbxe2e-p8', description: 'one');
      expect(
        (await w.host.snapshots(g.id)).map((s) => s.name),
        contains('sbxe2e-p8'),
      );

      // A real change in the configuration, then the diff.
      final hw = await w.host.hardware(g.id);
      await w.host.changeHardware(g.id, hw, const VirtHwSetMemory(mib: 256));
      final diff = await w.host.snapshotDiff(g.id, 'sbxe2e-p8');
      final mem = diff.where((d) => d.group == VirtSnapDiffGroup.memory);
      expect(mem, isNotEmpty, reason: '$diff');
      expect(mem.first.before, isNotNull);
      expect(mem.first.after, '256');
      // The listing's own keys are not a difference.
      expect(diff.any((d) => d.key == 'digest'), isFalse);
      expect(diff.any((d) => d.key == 'snaptime'), isFalse);

      await w.host.deleteSnapshot(g.id, 'sbxe2e-p8');
      expect(
        (await w.host.snapshots(g.id)).map((s) => s.name),
        isNot(contains('sbxe2e-p8')),
      );
    });

    test('a raw disk on a directory storage is refused before the task',
        () async {
      final snap = w.state.data!;
      final node = snap.host.nodes.firstWhere((n) => n.online).name;
      final pools = await w.host.storagePools();
      // A directory storage holds files: a disk on one is raw, and PVE's own
      // feature answer says no.
      // The node has no `dir` storage holding images (a file storage holds
      // files, which is the point): one is added for the run and removed at
      // the end, the way the storage groups do it.
      final store = 'sbxe2e-p8dir';
      final path = '/var/lib/$store';
      var dir = pools.firstWhere(
        (p) =>
            p.node == node &&
            p.type == 'dir' &&
            p.content.contains('images') &&
            p.active,
        orElse: () => const VirtStoragePool(
          id: '',
          name: '',
          type: '',
          path: null,
        ),
      );
      if (dir.name.isEmpty) {
        await w.host.manage(
          VirtPoolCreate(
            name: store,
            type: 'dir',
            source: path,
            node: node,
            content: const ['images'],
          ),
        );
        dir = (await w.host.storagePools()).firstWhere(
          (p) => p.name == store && p.node == node,
        );
        madeDir.add((store, path));
      }
      final vmid = (await w.host.nextVmid())!;
      await w.host.create(
        VirtCreateSpec(
          kind: VirtGuestKind.qemu,
          name: _e2eName('snapraw'),
          node: node,
          vmid: vmid,
          cores: 1,
          memoryMiB: 128,
          storage: dir,
          diskGiB: 1,
        ),
      );
      // The listing names a new guest a moment after its task.
      final g = await w.settle((x) => x.vmid == vmid, '$vmid', (x) => true);
      made.add(g.id);
      expect(
        await w.host.snapshotSupported(g.id),
        isFalse,
        reason: 'PVE snapshots a whole volume; a file is not one',
      );
      final why = await w.host.snapshotRefusal(g.id);
      expect(why, contains('snapshot feature is not available'));
      expect(why, contains(dir.name));
      final e = await _virtErr(
        w.host.createSnapshot(g.id, name: 'sbxe2e-p8raw'),
      );
      expect(e.type, VirtErrType.unsupported);
      expect(
        (await w.host.snapshots(g.id)).map((s) => s.name),
        isNot(contains('sbxe2e-p8raw')),
        reason: 'no task was started',
      );
    });
  });
}

// -----------------------------------------------------------------------------
// PVE: what earlier runs left unverified
// -----------------------------------------------------------------------------

/// Runs [command] on the PVE node [host] as the system `ssh` logs in there
/// (root): what the app has no call for — the node's own view of a VM's
/// configuration, a disk filled, a cloud image converted — and never what
/// is under test.
Future<String> _pveNode(String host, String command) async {
  final r = await Process.run('ssh', ['-o', 'BatchMode=yes', host, command]);
  expect(r.exitCode, 0, reason: '$command\n${r.stdout}${r.stderr}');
  return r.stdout as String;
}

/// A dart:io socket as dartssh2's transport: a guest's sshd reached through
/// the agent's relay.
class _RelaySocket implements SSHSocket {
  _RelaySocket(this._socket);

  final Socket _socket;

  @override
  Stream<Uint8List> get stream => _socket;

  @override
  StreamSink<List<int>> get sink => _socket;

  @override
  Future<void> get done => _socket.done;

  @override
  Future<void> close() => _socket.close();

  @override
  void destroy() => _socket.destroy();

  @override
  Future<void> flush() => _socket.flush();
}

/// A key pair and a password for a guest's cloud-init, made for this run.
/// The password is never printed.
Future<({SSHKeyPair key, String publicKey, String password})> _ciLogin() async {
  final dir = await Directory.systemTemp.createTemp('sbxe2e-key');
  addTearDown(() => dir.delete(recursive: true));
  final path = '${dir.path}/id';
  final r = await Process.run('ssh-keygen', ['-q', '-t', 'ed25519', '-N', '', '-C', 'sbxe2e', '-f', path]);
  expect(r.exitCode, 0, reason: '${r.stderr}');
  final rnd = Random.secure();
  return (
    key: SSHKeyPair.fromPem(await File(path).readAsString()).single,
    publicKey: (await File('$path.pub').readAsString()).trim(),
    password: base64Url.encode([for (var i = 0; i < 18; i++) rnd.nextInt(256)]),
  );
}

/// [command] run in the guest [ip] as `sbxe` with [key], through [dialer]
/// (the agent's relay), tried again until the guest lets it in and it
/// prints [until] — a first boot restarts sshd with new host keys, which
/// cuts a session short — or [within] is up.
Future<String> _relayGuestRun(
  ServerTcpDialer dialer,
  String ip,
  SSHKeyPair key,
  String command, {
  String until = '',
  Duration within = const Duration(minutes: 5),
  Duration each = const Duration(seconds: 60),
}) async {
  final deadline = DateTime.now().add(within);
  while (true) {
    Object? error;
    try {
      final guest = SSHClient(
        _RelaySocket(await dialer.connect(ip, 22)),
        username: 'sbxe',
        identities: [key],
        onVerifyHostKey: (_, _) => true,
      );
      try {
        final out = (await execSshE2e(guest, command, null, within: each)).stdout;
        if (out.contains(until)) return out;
        error = 'no "$until" in: $out';
      } finally {
        guest.close();
      }
    } catch (e) {
      error = e;
    }
    if (DateTime.now().isAfter(deadline)) fail('$ip: $error');
    await Future<void>.delayed(const Duration(seconds: 5));
  }
}

/// The relay dialer for a server, as remote desktop and PVE get it.
final _dialerProvider = riverpod.Provider.family<ServerTcpDialer, Spi>(
  (ref, spi) => ServerTcpDialer.of(ref, spi),
);

/// Runs [op] again while PVE refuses it on the guest's config lock (`can't
/// lock file ... got timeout`), for up to a minute: a stop leaves
/// `qmeventd`'s cleanup of the old QEMU process holding it for as long as
/// 30 s (PVE 9.2, see docs/dev/virt.md).
Future<T> _pveWhileLocked<T>(Future<T> Function() op) async {
  final deadline = DateTime.now().add(const Duration(minutes: 1));
  while (true) {
    try {
      return await op();
    } on VirtErr catch (e) {
      if (!(e.message ?? '').contains("can't lock file") || DateTime.now().isAfter(deadline)) rethrow;
      await Future<void>.delayed(const Duration(seconds: 3));
    }
  }
}

/// [bytes] written to [path] in the guest [ip] over SFTP, through [dialer],
/// tried again while the guest's sshd is still being restarted.
Future<void> _relayGuestPut(
  ServerTcpDialer dialer,
  String ip,
  SSHKeyPair key,
  String path,
  Uint8List bytes,
) async {
  final deadline = DateTime.now().add(const Duration(minutes: 2));
  while (true) {
    SSHClient? guest;
    try {
      guest = SSHClient(
        _RelaySocket(await dialer.connect(ip, 22)),
        username: 'sbxe',
        identities: [key],
        onVerifyHostKey: (_, _) => true,
      );
      final sftp = await guest.sftp();
      final file = await sftp.open(
        path,
        mode: SftpFileOpenMode.create | SftpFileOpenMode.write | SftpFileOpenMode.truncate,
      );
      await file.writeBytes(bytes);
      await file.close();
      await sftp.close();
      return;
    } catch (e) {
      if (DateTime.now().isAfter(deadline)) rethrow;
      // ignore: avoid_print
      print('SFTP to $ip: $e; again');
      await Future<void>.delayed(const Duration(seconds: 5));
    } finally {
      guest?.close();
    }
  }
}

void _pveUnverified(_Agent agent) {
  final tokenId = e2eEnv('SBM_E2E_PVE_TOKEN_ID');
  final tokenSecret = e2eEnv('SBM_E2E_PVE_TOKEN_SECRET');
  final nodeHost = e2eEnv('SBM_E2E_PVE_HOST');
  if (tokenId == null || tokenSecret == null || nodeHost == null) return;
  final imageId = e2eEnv('SBM_E2E_PVE_CLOUD_IMAGE');
  final addr = e2eEnv('SBM_E2E_PVE_CLOUD_ADDR');
  final gw = e2eEnv('SBM_E2E_PVE_CLOUD_GW');
  final usbId = e2eEnv('SBM_E2E_PVE_USB');

  group('PVE over the monitor agent relay: Secure Boot, SATA/IDE cloud-init, '
      'vmdk, USB by address, a template refused, a backup job\'s lock', () {
    late _World w;
    late ServerTcpDialer dialer;
    late String node;
    late VirtStoragePool storage;
    late VirtNetwork bridge;
    final run = DateTime.now().millisecondsSinceEpoch % 100000;
    // Every VM this group made, by VMID and name; removed at the end only
    // while it still has that name.
    final made = <(int, String)>[];
    final vmdk = '/var/lib/vz/import/sbxe2e-$run.vmdk';
    // The backup jobs and the files on the node this group made, recorded
    // once made: removed at the end by exact name, never by a pattern
    // another run's would match.
    final jobs = <String>{};
    final files = <String>{};

    Future<String> sh(String command) => _pveNode(nodeHost, command);

    /// A free VMID of the 97x range, as PVE and the node both say.
    Future<int> freeVmid() async {
      await w.host.refresh();
      for (var id = 970; id < 980; id++) {
        if (w.state.data!.guests.any((g) => g.vmid == id)) continue;
        if ((await sh('qm status $id 2>/dev/null; pct status $id 2>/dev/null; true')).isEmpty) return id;
      }
      fail('no free VMID in 970-979');
    }

    Future<VirtGuest> guestOf(int vmid, bool Function(VirtGuest g) test) =>
        w.settle((g) => g.vmid == vmid, 'VM $vmid', test);

    /// Stopped by force where it runs, then deleted through the app.
    Future<void> remove(int vmid) async {
      var g = await guestOf(vmid, (g) => g.actions.isNotEmpty || g.template);
      if (g.state != VirtGuestState.stopped) {
        await w.host.power(g.id, VirtPowerAction.forceStop);
        g = await guestOf(vmid, (g) => g.state == VirtGuestState.stopped);
      }
      await _pveWhileLocked(() => w.host.delete(g.id));
      expect(w.state.guest(g.id), isNull);
      made.removeWhere((m) => m.$1 == vmid);
    }

    Future<VirtVolume> imageVolume(String id) async {
      final pools = await w.host.storagePools();
      for (final p in virtImageStorages(pools, host: VirtHostKind.pve, node: node)) {
        final v = (await w.host.volumes(p)).where((v) => v.id == id).firstOrNull;
        if (v != null) return v;
      }
      fail('no $id with import content');
    }

    setUpAll(() async {
      w = _World(agent.spi('e2e-monitor-pve-unverified'));
      Stores.pve.put(
        w.id,
        PveConfig(
          addr: 'https://localhost:8006',
          auth: PveAuth.token,
          tokenId: tokenId,
          tokenSecret: tokenSecret,
        ),
      );
      await w.poll();
      await w.host.firstLoad;
      final cert = w.state.error?.cert;
      if (cert != null) await w.host.confirmCert(cert.fingerprint);
      expect(w.state.error, isNull, reason: '${w.state.error}');
      node = w.state.data!.host.nodes.firstWhere((n) => n.online).name;
      final disks = virtDiskStorages(
        await w.host.storagePools(),
        host: VirtHostKind.pve,
        kind: VirtGuestKind.qemu,
        node: node,
      );
      storage = disks.firstWhere((p) => p.name == 'local-lvm', orElse: () => disks.first);
      bridge = virtCreateNetworks(await w.host.networks(), host: VirtHostKind.pve, node: node)
          .firstWhere((n) => n.name == 'vmbr0');
      dialer = w.container.read(_dialerProvider(w.spi));
    });
    tearDownAll(() async {
      for (final (id, name) in [...made]) {
        try {
          if ((await sh('qm config $id 2>/dev/null | grep "^name: " || true')).contains(name)) {
            await sh('qm stop $id 2>/dev/null; qm destroy $id --purge 2>/dev/null; true');
          }
        } catch (e) {
          // ignore: avoid_print
          print('teardown of VM $id: $e');
        }
      }
      try {
        for (final j in jobs) {
          await sh("pvesh delete '/cluster/backup/$j' 2>/dev/null; true");
        }
        for (final f in files) {
          await sh("rm -rf -- '$f'");
        }
      } catch (e) {
        // ignore: avoid_print
        print('teardown: $e');
      }
      dialer.close();
      await w.dispose();
    });

    test('Secure Boot on SATA with cloud-init: the keys enrolled and the '
        'firmware enforcing, the cloud-init edit taken at a reboot, and a '
        'shutdown through the guest agent', () async {
      if (imageId == null || addr == null || gw == null) {
        markTestSkipped('SBM_E2E_PVE_CLOUD_IMAGE / _ADDR / _GW unset');
        return;
      }
      final ip = addr.split('/').first;
      expect(await sh('ping -c 2 -W 1 $ip >/dev/null 2>&1 && echo answered || true'), isEmpty, reason: '$ip is in use');
      final options = await w.host.createOptions();
      expect((options.uefi, options.secureBoot), (true, true));
      expect(options.buses, contains('sata'));
      final vmid = await freeVmid();
      final name = 'sbxe2e-l-sb-$run';
      made.add((vmid, name));
      final login = await _ciLogin();
      final spec = VirtCreateSpec(
        kind: VirtGuestKind.qemu,
        name: name,
        node: node,
        vmid: vmid,
        cores: 1,
        memoryMiB: 1024,
        storage: storage,
        diskGiB: 4,
        image: _inPool(await imageVolume(imageId), await w.host.storagePools(), node: node),
        network: bridge,
        bus: 'sata',
        uefi: true,
        secureBoot: true,
        cloudInit: VirtCloudInit(
          user: 'sbxe',
          password: login.password,
          sshKeys: login.publicKey,
          address: addr,
          gateway: gw,
          dns: [gw],
        ),
        // Started below, with PVE's first-boot package upgrade off: the
        // hosts' network is slow, and that is not what this checks.
        start: false,
      );
      expect(virtCreateIssue(spec, host: VirtHostKind.pve, guests: w.state.data!.guests), isNull);
      await w.host.create(spec);
      final config = await sh('qm config $vmid');
      expect(config, contains('sata0: ${storage.name}:vm-$vmid-disk-'));
      // The cloud-init drive on the disk's own bus: Debian's cloud kernel
      // reads SATA, and has no IDE driver.
      expect(config, contains('sata1: ${storage.name}:vm-$vmid-cloudinit'));
      expect(RegExp(r'^efidisk0: .*pre-enrolled-keys=1', multiLine: true).hasMatch(config), isTrue, reason: config);
      expect(config, contains('bios: ovmf'));
      await sh('qm set $vmid --ciupgrade 0');
      var g = await guestOf(vmid, (g) => g.name == name && g.actions.contains(VirtPowerAction.start));
      final hw = await w.host.hardware(g.id);
      expect((hw.firmware!.uefi, hw.firmware!.secureBoot), (true, true));
      expect(hw.disk('sata1')!.cloudInit, isTrue);
      await w.host.power(g.id, VirtPowerAction.start);

      // The firmware says Secure Boot is on (the variable's last byte), and
      // the kernel that booted was the signed one it let through.
      const sbVar = '/sys/firmware/efi/efivars/SecureBoot-8be4df61-93ca-11d2-aa0d-00e098032b8c';
      final first = await _relayGuestRun(
        dialer,
        ip,
        login.key,
        'cloud-init status --wait >/dev/null 2>&1; echo "host=\$(hostname)"; '
        'echo "sb=\$(od -An -t u1 $sbVar | awk \'{print \$NF}\')"; '
        'echo "iid=\$(cat /var/lib/cloud/data/instance-id)"; '
        'echo "sda=\$((\$(cat /sys/block/sda/size) * 512))"',
        until: 'iid=',
      );
      expect(first, contains('host=$name'));
      expect(first, contains('sb=1'), reason: first);
      expect(first, contains('sda=${4 << 30}'));
      final iid = RegExp(r'iid=(\S+)').firstMatch(first)![1];

      // The cloud-init edit on the SATA drive: a new key and a second DNS
      // server, written at once and taken by the next boot.
      g = w.state.guest(g.id)!;
      final ci = await w.host.cloudInit(g.id);
      expect((ci.user, ci.address, ci.network), ('sbxe', addr, true));
      final next = await _ciLogin();
      final edit = VirtCloudInitEdit(
        VirtCloudInit(user: 'sbxe', sshKeys: next.publicKey, address: addr, gateway: gw, dns: [gw, '1.1.1.1']),
      );
      expect(virtCloudInitEditIssue(ci, edit, host: VirtHostKind.pve), isNull);
      await w.host.setCloudInit(g.id, ci, edit);
      expect((await w.host.cloudInit(g.id)).dns, [gw, '1.1.1.1']);
      await _relayGuestRun(dialer, ip, login.key, '(sleep 1; sudo -n reboot) >/dev/null 2>&1 & echo ok', until: 'ok');
      await Future<void>.delayed(const Duration(seconds: 10));
      final rebooted = await _relayGuestRun(
        dialer,
        ip,
        next.key,
        'cloud-init status --wait >/dev/null 2>&1; echo "iid=\$(cat /var/lib/cloud/data/instance-id)"; '
        'cat /etc/resolv.conf; resolvectl dns 2>/dev/null; true',
        until: 'iid=',
      );
      expect(rebooted, isNot(contains('iid=$iid\n')));
      expect(rebooted, contains('1.1.1.1'));

      // The guest agent, from packages the node fetches (its mirror answers
      // in seconds; a guest's first apt run here takes many minutes), copied
      // in over SFTP and installed.
      final debs = (await sh(
        'd=\$(mktemp -d /tmp/sbxe2e-qga.XXXX) && cd \$d && '
        'apt-get -qq download qemu-guest-agent libnuma1 liburing2 libglib2.0-0t64 >/dev/null 2>&1; echo \$d',
      )).trim();
      expect(debs, startsWith('/tmp/sbxe2e-qga.'));
      files.add(debs);
      for (final deb in const LineSplitter().convert(await sh('ls $debs'))) {
        final r = await Process.run('ssh', ['-o', 'BatchMode=yes', nodeHost, "cat '$debs/$deb'"], stdoutEncoding: null);
        expect(r.exitCode, 0, reason: deb);
        await _relayGuestPut(dialer, ip, next.key, '/tmp/$deb', Uint8List.fromList(r.stdout as List<int>));
      }
      await sh("rm -rf '$debs'");
      files.remove(debs);
      final installed = await _relayGuestRun(
        dialer,
        ip,
        next.key,
        'sudo -n dpkg -i /tmp/*.deb >/tmp/qga.log 2>&1; '
        'dpkg-query -W -f=\'\${Status}\' qemu-guest-agent 2>/dev/null; echo; tail -n 5 /tmp/qga.log; echo done',
        until: 'done',
      );
      expect(installed, contains('install ok installed'), reason: installed);
      g = await guestOf(vmid, (g) => g.state == VirtGuestState.running);
      await w.host.power(g.id, VirtPowerAction.shutdown);
      g = await guestOf(vmid, (g) => g.state == VirtGuestState.stopped);
      // `qm set` waits 10 s for the lock a stop's cleanup may hold longer.
      await sh('for i in 1 2 3 4 5 6; do qm set $vmid --agent 1 && exit 0; sleep 5; done; exit 1');
      await _pveWhileLocked(() => w.host.power(g.id, VirtPowerAction.start));
      final deadline = DateTime.now().add(const Duration(minutes: 3));
      while ((await sh('qm agent $vmid ping >/dev/null 2>&1 && echo up || true')).trim() != 'up') {
        if (DateTime.now().isAfter(deadline)) fail('the guest agent never answered');
        await Future<void>.delayed(const Duration(seconds: 3));
      }
      g = await guestOf(vmid, (g) => g.state == VirtGuestState.running);
      await w.host.power(g.id, VirtPowerAction.shutdown);
      g = await guestOf(vmid, (g) => g.state == VirtGuestState.stopped);
      // Who carried it out, as the guest recorded it: the agent logs the
      // call it was given (an ACPI shutdown would leave no such line).
      await _pveWhileLocked(() => w.host.power(g.id, VirtPowerAction.start));
      final log = await _relayGuestRun(
        dialer,
        ip,
        next.key,
        'sudo -n journalctl -b -1 -o cat -u qemu-guest-agent 2>&1; echo done',
        until: 'done',
      );
      expect(log, contains('guest-shutdown called'), reason: log);
      g = await guestOf(vmid, (g) => g.state == VirtGuestState.running);
      await remove(vmid);
      expect(await sh('pvesm list ${storage.name} | grep -c "vm-$vmid-" || true'), contains('0'));
    }, timeout: const Timeout(Duration(minutes: 30)));

    test('a vmdk cloud image: offered, imported, booted', () async {
      if (imageId == null || addr == null || gw == null) {
        markTestSkipped('SBM_E2E_PVE_CLOUD_IMAGE / _ADDR / _GW unset');
        return;
      }
      final ip = addr.split('/').first;
      final qcow2 = (await sh("pvesm path '$imageId'")).trim();
      expect(await sh("test -e '$vmdk' && echo taken || true"), isEmpty, reason: '$vmdk exists already');
      files.add(vmdk);
      await sh("qemu-img convert -O vmdk '$qcow2' '$vmdk'");
      final image = await imageVolume('local:import/${vmdk.split('/').last}');
      expect(image.format, 'vmdk');
      expect(virtIsCloudImage(image, VirtHostKind.pve), isTrue);
      final vmid = await freeVmid();
      final name = 'sbxe2e-l-vmdk-$run';
      made.add((vmid, name));
      final login = await _ciLogin();
      await w.host.create(
        VirtCreateSpec(
          kind: VirtGuestKind.qemu,
          name: name,
          node: node,
          vmid: vmid,
          cores: 1,
          memoryMiB: 1024,
          storage: storage,
          diskGiB: 4,
          image: _inPool(image, await w.host.storagePools(), node: node),
          network: bridge,
          cloudInit: VirtCloudInit(
            user: 'sbxe',
            sshKeys: login.publicKey,
            address: addr,
            gateway: gw,
            dns: [gw],
          ),
        ),
      );
      expect(await sh('qm config $vmid'), contains('scsi0: ${storage.name}:vm-$vmid-disk-'));
      await sh('qm set $vmid --ciupgrade 0');
      final g = await guestOf(vmid, (g) => g.name == name && g.actions.contains(VirtPowerAction.start));
      await w.host.power(g.id, VirtPowerAction.start);
      final out = await _relayGuestRun(
        dialer,
        ip,
        login.key,
        'cloud-init status --wait >/dev/null 2>&1; echo "host=\$(hostname)"; '
        'echo "sda=\$((\$(cat /sys/block/sda/size) * 512))"',
        until: 'sda=',
      );
      expect(out, contains('host=$name'));
      expect(out, contains('sda=${4 << 30}'));
      await remove(vmid);
      await sh("rm -f '$vmdk'");
      files.remove(vmdk);
    }, timeout: const Timeout(Duration(minutes: 15)));

    test('IDE: the disk and the cloud-init drive on it, and the cloud-init edit', () async {
      final vmid = await freeVmid();
      final name = 'sbxe2e-l-ide-$run';
      made.add((vmid, name));
      final login = await _ciLogin();
      await w.host.create(
        VirtCreateSpec(
          kind: VirtGuestKind.qemu,
          name: name,
          node: node,
          vmid: vmid,
          cores: 1,
          memoryMiB: 256,
          storage: storage,
          diskGiB: 1,
          image: _inPool(imageId == null ? null : await imageVolume(imageId), await w.host.storagePools(), node: node),
          network: bridge,
          bus: 'ide',
          cloudInit: VirtCloudInit(user: 'sbxe', sshKeys: login.publicKey),
        ),
      );
      final config = await sh('qm config $vmid');
      expect(config, contains('ide0: ${storage.name}:vm-$vmid-disk-'));
      expect(config, contains('ide2: ${storage.name}:vm-$vmid-cloudinit'));
      final g = await guestOf(vmid, (g) => g.name == name);
      expect((await w.host.hardware(g.id)).disk('ide2')!.cloudInit, isTrue);
      final ci = await w.host.cloudInit(g.id);
      expect((ci.user, ci.address, ci.network), ('sbxe', null, true));
      final edit = VirtCloudInitEdit(
        VirtCloudInit(user: 'sbxe2', sshKeys: login.publicKey, address: '10.231.79.5/24', gateway: '10.231.79.1'),
      );
      expect(virtCloudInitEditIssue(ci, edit, host: VirtHostKind.pve), isNull);
      await w.host.setCloudInit(g.id, ci, edit);
      final after = await w.host.cloudInit(g.id);
      expect((after.user, after.address, after.gateway), ('sbxe2', '10.231.79.5/24', '10.231.79.1'));
      // The drive itself carries it, not only the configuration.
      final drive = await sh('qm cloudinit dump $vmid user; qm cloudinit dump $vmid network');
      expect(drive, contains('sbxe2'));
      expect(drive, contains('10.231.79.5'));
    });

    test('USB by vendor/product and by address on a stopped VM, as root@pam; '
        'never started with it', () async {
      if (usbId == null) {
        markTestSkipped('SBM_E2E_PVE_USB unset');
        return;
      }
      final vmid = made.lastWhere((m) => m.$2.startsWith('sbxe2e-l-ide-'), orElse: () => fail('no IDE VM')).$1;
      // PVE lets only root@pam logged in with a password give a guest a raw
      // USB device. A ticket the node itself issues for root@pam is what
      // stands in for the password: PVE takes a valid ticket as the
      // password of a login (its own web UI renews tickets that way). Read
      // here, never printed.
      final ticket = (await sh(r"perl -MPVE::AccessControl -e 'print PVE::AccessControl::assemble_ticket(q(root@pam))'")).trim();
      final root = PveBackend(
        serverId: 'e2e-pve-root',
        config: const PveConfig(addr: 'https://localhost:8006'),
        user: 'root@pam',
        // What a server logged in to with a password lends PVE.
        sshPassword: ticket,
        tunnel: dialer.loopback,
        connect: dialer.startConnect,
        taskPoll: const Duration(milliseconds: 500),
      );
      addTearDown(root.close);
      final e = await _virtErr(root.load());
      expect(e.type, VirtErrType.certUnconfirmed);
      await root.confirmCert(e.cert!.fingerprint);
      Future<VirtGuest> guest() async => (await root.load()).guests.firstWhere((g) => g.vmid == vmid);
      var g = await guest();
      expect(g.state, VirtGuestState.stopped);

      final devs = await root.hostDevices(g);
      expect(devs.mappingsOnly, isFalse);
      final dev = devs.usb.firstWhere((d) => d.id == usbId, orElse: () => fail('$usbId not listed: ${devs.usb.map((d) => d.id)}'));
      final sysfs = (await sh(
        'for d in /sys/bus/usb/devices/*; do [ "\$(cat \$d/idVendor 2>/dev/null):\$(cat \$d/idProduct 2>/dev/null)" = $usbId ] && basename \$d; done; true',
      )).trim();
      // `1-13`: the bus, then the port chain.
      expect('${dev.usbBus}-${dev.usbPort}', sysfs);

      var hw = await root.hardware(g);
      await root.changeHardware(g, hw, VirtHwAddDevice(kind: VirtHwDeviceKind.usb, host: dev));
      g = await guest();
      hw = await root.hardware(g);
      await root.changeHardware(
        g,
        hw,
        VirtHwAddDevice(kind: VirtHwDeviceKind.usb, host: dev, usbNaming: VirtUsbNaming.address),
      );
      final usb = await sh("qm config $vmid | grep -E '^usb[0-9]+:'");
      expect(usb, contains('usb0: host=$usbId'));
      expect(usb, contains('usb1: host=$sysfs'));
      hw = await root.hardware(await guest());
      expect(hw.devices.where((d) => d.kind == VirtHwDeviceKind.usb).map((d) => d.key), ['usb0', 'usb1']);
      for (final key in ['usb0', 'usb1']) {
        g = await guest();
        await root.changeHardware(g, await root.hardware(g), VirtHwRemoveDevice(key: key));
      }
      expect(await sh("qm config $vmid | grep -cE '^usb[0-9]+:' || true"), contains('0'));
      expect((await guest()).state, VirtGuestState.stopped);
    });

    test('a VM with a snapshot made a template: PVE\'s own refusal, in its words', () async {
      final vmid = made.lastWhere((m) => m.$2.startsWith('sbxe2e-l-ide-'), orElse: () => fail('no IDE VM')).$1;
      var g = await guestOf(vmid, (g) => g.state == VirtGuestState.stopped);
      await w.host.createSnapshot(g.id, name: 'sbxe2e_t');
      // A second app instance, which has never read the snapshot listing:
      // nothing of its own stops the request, and PVE answers it.
      final other = _World(agent.spi('e2e-monitor-pve-unverified-2'));
      addTearDown(other.dispose);
      Stores.pve.put(other.id, Stores.pve.fetch(w.id)!);
      await other.host.firstLoad;
      expect(other.state.error, isNull, reason: '${other.state.error}');
      g = other.guest((x) => x.vmid == vmid, 'VM $vmid');
      final e = await _virtErr(other.host.makeTemplate(g.id));
      // ignore: avoid_print
      print('PVE on a template with a snapshot: ${e.type} ${e.message}');
      expect(e.type, VirtErrType.actionFailed);
      expect(e.message, contains('snapshots'));
      expect(await sh("qm config $vmid | grep -c '^template:' || true"), contains('0'));
      await remove(vmid);
    });

    test("a backup job's run: the guest locked while it runs, every action "
        'refused, then unlocked; the job run as PVE has it (bwlimit)', () async {
      final storages = await w.host.allBackupStorages();
      final target = storages.firstWhere((s) => s.node == node && s.name == 'local', orElse: () => storages.first);
      final vmid = await freeVmid();
      final name = 'sbxe2e-l-bk-$run';
      made.add((vmid, name));
      await w.host.create(
        VirtCreateSpec(
          kind: VirtGuestKind.qemu,
          name: name,
          node: node,
          vmid: vmid,
          cores: 1,
          memoryMiB: 128,
          storage: storage,
          diskGiB: 1,
        ),
      );
      var g = await guestOf(vmid, (g) => g.name == name && g.actions.contains(VirtPowerAction.start));
      // Data a backup has to read and cannot compress away: 384 MiB at
      // 8 MiB/s is some 48 s.
      await sh(r'dd if=/dev/urandom of="$(pvesm path ' "'${storage.name}:vm-$vmid-disk-0'" r')" bs=1M count=384 oflag=direct status=none');
      final id = 'sbxe2e-l-$run';
      expect(
        (await w.host.allBackupJobs()).map((j) => j.id),
        isNot(contains(id)),
        reason: 'the job $id exists already',
      );
      await w.host.editBackupJob(
        VirtBackupJobEdit(
          id: id,
          isNew: true,
          node: node,
          storage: target.name,
          schedule: 'sat 03:00',
          mode: 'stop',
          compress: 'zstd',
          enabled: false,
          vmids: [vmid],
        ),
      );
      jobs.add(id);
      // A field PVE's editor sets and the app's form does not.
      await sh('pvesh set /cluster/backup/$id --bwlimit 8192');
      final job = (await w.host.allBackupJobs()).firstWhere((j) => j.id == id);

      final started = DateTime.now();
      final running = w.host.runBackupJob(job);
      // Another app instance's listing, as anyone else's would see it.
      final other = _World(agent.spi('e2e-monitor-pve-unverified-3'));
      addTearDown(other.dispose);
      Stores.pve.put(other.id, Stores.pve.fetch(w.id)!);
      await other.host.firstLoad;
      final locked = await other.settle((x) => x.vmid == vmid, name, (x) => x.stateReason == 'backup');
      expect(locked.actions, isEmpty);
      final refused = await _virtErr(other.host.power(locked.id, VirtPowerAction.start));
      expect(refused.type, VirtErrType.unsupported);
      await running;
      final took = DateTime.now().difference(started);
      // ignore: avoid_print
      print('backup job run took ${took.inSeconds} s');
      expect(took, greaterThan(const Duration(seconds: 30)), reason: 'the bwlimit was not sent');
      g = await other.settle((x) => x.vmid == vmid, name, (x) => x.stateReason == null);
      expect(g.actions, contains(VirtPowerAction.start));
      expect(await sh("qm config $vmid | grep -c '^lock:' || true"), contains('0'));

      final backups = await w.host.backups(g.id);
      expect(backups, hasLength(1));
      for (final b in backups) {
        await w.host.deleteBackup(g.id, b);
      }
      await w.host.editBackupJob(_jobEditOf(job), remove: true);
      jobs.remove(id);
      await remove(vmid);
    }, timeout: const Timeout(Duration(minutes: 10)));
  });
}

/// [v] with the pool it is listed in: a PVE volid names its storage on
/// [node], a libvirt volume's path its pool's directory.
VirtPoolVolume? _inPool(VirtVolume? v, List<VirtStoragePool> pools, {String? node}) {
  if (v == null) return null;
  final pool = node != null
      ? pools.firstWhere((p) => p.node == node && p.name == v.id.split(':').first)
      : pools.firstWhere((p) => p.path != null && (v.path ?? '').startsWith('${p.path}/'));
  return (pool: pool, volume: v);
}
