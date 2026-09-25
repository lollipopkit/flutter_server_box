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
/// The "create and delete" groups make guests named `sbme2e-*` and delete
/// them again, disks included: a VM on libvirt (in the first pool that takes
/// a disk, with an ISO found in any pool as its CD-ROM), and on PVE a VM (an
/// ISO from a storage holding them, if there is one) and a container (from
/// the first template there is). They touch no other guest.
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

import 'package:fl_lib/fl_lib.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pointycastle/export.dart' show DESedeEngine, KeyParameter;
import 'package:server_box/core/utils/monitor_terminal.dart';
import 'package:server_box/core/utils/privileged_exec.dart';
import 'package:server_box/data/model/app/error.dart';
import 'package:server_box/data/model/server/monitor_http_credential.dart';
import 'package:server_box/data/model/server/pve_config.dart';
import 'package:server_box/data/model/server/server_private_info.dart';
import 'package:server_box/data/model/server/shell_backend.dart';
import 'package:server_box/data/model/virt/virt.dart';
import 'package:server_box/data/model/virt/virt_create.dart';
import 'package:server_box/data/model/virt/virt_detail.dart';
import 'package:server_box/data/model/virt/virt_resources.dart';
import 'package:server_box/data/provider/remote_desktop.dart';
import 'package:server_box/data/provider/server/single.dart';
import 'package:server_box/data/provider/virt/libvirt_backend.dart';
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
  final libvirt = _Agent.fromEnv('LIBVIRT', user);
  final pve = _Agent.fromEnv('PVE', user);
  final restricted = _Agent.fromEnv(
    'RESTRICTED',
    user,
    fallbackPassword: e2eEnv('SBM_E2E_MONITOR_LIBVIRT_PASSWORD'),
  );
  if (libvirt == null && pve == null && restricted == null) {
    test(
      'virt over monitor e2e',
      () {},
      skip: 'no SBM_E2E_MONITOR_*_ADDR / _PASSWORD pair is set',
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
  if (libvirt != null) _libvirtVncPassword(libvirt);
  if (pve != null) _pveCreate(pve);
  if (libvirt != null) {
    _libvirt(libvirt);
  } else {
    test('libvirt over monitor', () {}, skip: 'SBM_E2E_MONITOR_LIBVIRT_* unset');
  }
  if (pve != null) {
    _pve(pve);
    _pveTestVm(pve);
  } else {
    test('PVE over monitor', () {}, skip: 'SBM_E2E_MONITOR_PVE_* unset');
  }
  if (restricted != null) {
    _restricted(restricted);
  } else {
    test(
      'agent without full access',
      () {},
      skip: 'SBM_E2E_MONITOR_RESTRICTED_* unset',
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
    late VirtGuest g;
    for (var i = 0; i < 30; i++) {
      await host.refresh();
      expect(state.error, isNull, reason: '${state.error}');
      g = guest(find, what);
      if (test(g)) return g;
      await Future<void>.delayed(const Duration(milliseconds: 500));
    }
    fail('$what never settled; last: ${g.state}');
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
        media: media.firstOrNull,
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
        media: isos.firstOrNull,
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
        media: templates.first,
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
      // the config lock for 30 s (virt.md).
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
      // Past the boot: an ACPI request during it is lost (virt.md).
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
