import 'dart:async';
import 'dart:convert';

import 'package:fl_lib/fl_lib.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:server_box/core/utils/privileged_exec.dart';
import 'package:server_box/data/model/app/error.dart';
import 'package:server_box/data/model/server/server_exec.dart';
import 'package:server_box/data/model/virt/libvirt.dart';
import 'package:server_box/data/model/virt/virt.dart';
import 'package:server_box/data/model/virt/virt_console.dart';
import 'package:server_box/data/model/virt/virt_detail.dart';
import 'package:server_box/data/model/virt/virt_rates.dart';
import 'package:server_box/data/model/virt/virt_resources.dart';
import 'package:server_box/data/provider/server/single.dart';
import 'package:server_box/data/provider/virt/backend.dart';
import 'package:server_box/src/rust/api/virt.dart' as ffi;

/// libvirt through `virsh`, run by `ServerNotifier.ensureExec()` — so over
/// SSH, over a monitor agent with the `full_access` grant, or on this device.
///
/// Scripts and parsers are `sbm_parser::virt`'s (FFI). Every script is POSIX
/// `sh`, fed to `sh` on stdin, never run as the login shell's command line.
///
/// **Permissions.** `qemu:///system` wants root or the `libvirt` group. When
/// the daemon refuses this account the script runs again through sudo
/// (`PrivilegedExec`): passwordless first, and when that needs a password,
/// [VirtErrType.sudoPasswordRequired] until [provideSudoPassword]. The
/// password travels on sudo's stdin, never in the command, and lives in this
/// object only. Once sudo was needed, later calls go straight to it.
class LibvirtBackend implements VirtBackend {
  LibvirtBackend({
    required this.serverId,
    required Future<ServerExec> Function() exec,
    DateTime Function()? now,
  }) : _exec = exec,
       _now = now ?? DateTime.now;

  factory LibvirtBackend.of(Ref ref, String serverId) => LibvirtBackend(
    serverId: serverId,
    exec: () => ref.read(serverProvider(serverId).notifier).ensureExec(),
  );

  @override
  final String serverId;

  @override
  VirtHostKind get kind => VirtHostKind.libvirt;

  final Future<ServerExec> Function() _exec;
  final DateTime Function() _now;
  final _rates = VirtRateTracker();

  /// This account reaches the daemon only through sudo.
  bool _viaSudo = false;
  String? _sudoPassword;

  /// State codes by guest id from the last [load], for what the mapped state
  /// hides (crashed with the process preserved).
  final _stateCodes = <String, int>{};

  bool get needsSudo => _viaSudo;

  /// The sudo password for this server, typed by the user after
  /// [VirtErrType.sudoPasswordRequired]. Kept in memory for this backend's
  /// life; a rejected one is forgotten.
  void provideSudoPassword(String password) {
    _sudoPassword = password.isEmpty ? null : password;
    _viaSudo = true;
  }

  /// The host probe: whether this server is Proxmox VE, a container, or has
  /// a `virsh` that answers.
  ///
  /// A daemon refusing this account still makes this a libvirt host: the
  /// error is thrown, and the host list counts [VirtErrType.permissionDenied]
  /// and the sudo types as "found".
  Future<VirtHostProbeResult> probe() async {
    final json = await _run(ffi.virtProbeScript(), ffi.parseVirtProbeJson);
    return VirtHostProbeResult.fromJson(_decode(json));
  }

  @override
  Future<VirtSnapshot> load() async {
    final json = await _run(
      ffi.virtOverviewScript(),
      ffi.parseVirtOverviewJson,
    );
    final at = _now();
    final overview = LibvirtOverview.fromJson(_decode(json));
    final guests = <VirtGuest>[];
    final stats = <String, VirtStats>{};
    _stateCodes.clear();
    for (final d in overview.domains) {
      _stateCodes[d.uuid] = d.stateCode;
      guests.add(guestOf(d));
      stats[d.uuid] = _rates.add(d.uuid, sampleOf(d, at));
    }
    _rates.retain(_stateCodes.keys);
    final version = overview.version;
    final hypervisor = [
      version?.hypervisor,
      version?.hypervisorVersion,
    ].nonNulls.join(' ');
    return VirtSnapshot(
      host: VirtHost(
        serverId: serverId,
        kind: VirtHostKind.libvirt,
        version: version?.libvirt,
        hypervisor: hypervisor.isEmpty ? null : hypervisor,
      ),
      guests: guests,
      stats: stats,
      capabilities: const VirtCapabilities(
        pause: true,
        snapshots: true,
        snapshotMemoryRequired: true,
        storage: true,
        network: true,
        serialConsole: true,
        vncConsole: true,
      ),
    );
  }

  /// One overview domain as a guest.
  ///
  /// Two libvirt states read differently from what [VirtGuestState] alone
  /// says: `pmsuspended` (7) is paused but not woken by `resume`, so resume
  /// is not offered; `crashed` (6) is stopped, with the QEMU process kept by
  /// `on_crash=preserve`, so [power] destroys it before starting.
  static VirtGuest guestOf(LibvirtDomain d) {
    final state = switch (d.state) {
      'running' => VirtGuestState.running,
      'paused' => VirtGuestState.paused,
      'stopped' => VirtGuestState.stopped,
      'starting' => VirtGuestState.starting,
      'stopping' => VirtGuestState.stopping,
      _ => VirtGuestState.unknown,
    };
    final pmSuspended = d.stateCode == 7;
    final crashed = d.stateCode == 6;
    // Migration holds a domain paused with reason `migration` (2) on the
    // source.
    final migrating = d.stateCode == 3 && d.reasonCode == 2;
    final shown = migrating ? VirtGuestState.migrating : state;
    final actions = VirtPowerAction.offered(
      shown,
      pause: true,
      resumable: !pmSuspended,
    );
    return VirtGuest(
      id: d.uuid,
      name: d.name,
      kind: VirtGuestKind.qemu,
      state: shown,
      stateReason: pmSuspended
          ? 'pmsuspended'
          : crashed
          ? 'crashed'
          : (d.reason == 'unknown' ? null : d.reason),
      vcpu: d.vcpuCurrent ?? d.vcpuMax,
      memBytes: _kib(d.memMaxKib ?? d.memCurrentKib),
      autostart: d.autostart,
      actions: {...actions, if (crashed) VirtPowerAction.forceStop},
    );
  }

  /// One overview domain's counters, for [VirtRateTracker].
  static VirtCounterSample sampleOf(LibvirtDomain d, DateTime at) {
    final c = d.counters;
    int? sum(Iterable<int?> values) {
      final present = values.nonNulls;
      return present.isEmpty ? null : present.reduce((a, b) => a + b);
    }

    // Used memory as the guest sees it, when its balloon driver reports;
    // otherwise what the QEMU process holds on the host.
    final available = c.balloonAvailableKib;
    final unused = c.balloonUnusedKib;
    final used = available != null && unused != null
        ? available - unused
        : c.balloonRssKib;
    final disks = c.blocks.where((b) => b.capacity != null);
    return VirtCounterSample(
      at: at,
      cpuTimeNs: c.cpuTimeNs,
      vcpus: d.vcpuCurrent ?? d.vcpuMax,
      memUsed: _kib(used),
      memTotal: _kib(available ?? d.memCurrentKib ?? d.memMaxKib),
      diskUsed: sum(disks.map((b) => b.allocation)),
      diskTotal: sum(disks.map((b) => b.capacity)),
      diskRead: sum(c.blocks.map((b) => b.rdBytes)),
      diskWrite: sum(c.blocks.map((b) => b.wrBytes)),
      netIn: sum(c.nets.map((n) => n.rxBytes)),
      netOut: sum(c.nets.map((n) => n.txBytes)),
    );
  }

  @override
  Future<void> power(VirtGuest guest, VirtPowerAction action) async {
    if (!guest.actions.contains(action)) {
      throw VirtErr(
        type: VirtErrType.unsupported,
        message: '${action.name} is not offered for ${guest.name}',
      );
    }
    if (action == VirtPowerAction.start && _stateCodes[guest.id] == 6) {
      // Crashed with `on_crash=preserve`: the process is still there, and
      // `start` refuses a domain that has one.
      try {
        await _action(VirtPowerAction.forceStop, guest.id);
      } on VirtErr catch (e) {
        if (e.cause case ffi.VirtFfiError(
          kind: ffi.VirtErrorKind.invalidState,
        )) {
          // Already gone.
        } else {
          rethrow;
        }
      }
    }
    await _action(action, guest.id);
  }

  Future<void> _action(VirtPowerAction action, String domain) async {
    final kind = switch (action) {
      VirtPowerAction.start => ffi.VirtActionKind.start,
      VirtPowerAction.shutdown => ffi.VirtActionKind.shutdown,
      VirtPowerAction.reboot => ffi.VirtActionKind.reboot,
      VirtPowerAction.forceStop => ffi.VirtActionKind.forceStop,
      VirtPowerAction.suspend => ffi.VirtActionKind.suspend,
      VirtPowerAction.resume => ffi.VirtActionKind.resume,
    };
    await _run(
      ffi.virtActionScript(action: kind, domain: domain),
      ({required String raw}) async {
        ffi.parseVirtAction(raw: raw);
        return '';
      },
      action: true,
    );
  }

  @override
  Future<VirtGuestDetail> detail(VirtGuest guest) async {
    final json = await _run(
      ffi.virtDomainDetailScript(domain: guest.id),
      ffi.parseVirtDomainDetailJson,
    );
    final d = LibvirtDomainDetail.fromJson(_decode(json));
    final xml = d.xml;
    final vnc =
        d.display?.protocol == 'vnc' ||
        xml.graphics.any((g) => g.kind == 'vnc');
    return VirtGuestDetail(
      disks: xml.disks,
      nics: xml.nics,
      graphics: xml.graphics,
      display: d.display,
      consoles: {
        if (xml.hasSerialConsole) VirtConsoleKind.text,
        if (vnc) VirtConsoleKind.vnc,
      },
      description: xml.description,
      arch: xml.arch,
      machine: xml.machine,
    );
  }

  @override
  Future<VirtConsole> console(VirtGuest guest, VirtConsoleKind kind) async {
    switch (kind) {
      case VirtConsoleKind.text:
        return LibvirtSerialConsole(
          command: ffi.virtConsoleCommand(domain: guest.id),
          needsRoot: _viaSudo,
        );
      case VirtConsoleKind.vnc:
        final detail = await this.detail(guest);
        final display = detail.display;
        final port = display?.port;
        if (display == null || display.protocol != 'vnc' || port == null) {
          throw VirtErr(
            type: VirtErrType.unsupported,
            message: display == null
                ? 'No VNC display while ${guest.name} is not running'
                : 'The display is ${display.uri}, not a VNC port',
          );
        }
        return LibvirtVncConsole(host: _dialHost(display.host), port: port);
    }
  }

  /// A listen address as something to dial from the hypervisor: a wildcard
  /// is the hypervisor itself.
  static String _dialHost(String? host) => switch (host) {
    null || '' || '0.0.0.0' || '::' || '[::]' => '127.0.0.1',
    final h => h,
  };

  // ---------------------------------------------------------------------------
  // Snapshots
  // ---------------------------------------------------------------------------

  @override
  Future<List<VirtGuestSnapshot>> snapshots(VirtGuest guest) async {
    final json = await _run(
      ffi.virtSnapshotsScript(domain: guest.id),
      ffi.parseVirtSnapshotsJson,
    );
    return [
      for (final s in _decodeList(json))
        snapshotOf(LibvirtSnapshot.fromJson(s)),
    ];
  }

  static VirtGuestSnapshot snapshotOf(LibvirtSnapshot s) => VirtGuestSnapshot(
    name: s.name,
    parent: s.parent,
    description: s.description,
    createdAt: switch (s.creationTime) {
      final t? => DateTime.fromMillisecondsSinceEpoch(t * 1000),
      null => null,
    },
    current: s.current,
    withMemory: s.memory,
  );

  /// An internal snapshot: with the memory of an active domain, which QEMU
  /// insists on, so [memory] changes nothing; disks only for a shut-off one.
  /// Every writable disk must be qcow2 — libvirt's refusal says which is not.
  @override
  Future<void> createSnapshot(
    VirtGuest guest, {
    required String name,
    String? description,
    bool memory = false,
  }) async {
    _checkName(name);
    await _action1(
      ffi.virtSnapshotCreateScript(
        domain: guest.id,
        name: name,
        description: description,
      ),
    );
  }

  @override
  Future<void> revertSnapshot(
    VirtGuest guest,
    String name, {
    bool start = false,
  }) => _action1(
    ffi.virtSnapshotRevertScript(domain: guest.id, name: name, running: start),
  );

  @override
  Future<void> deleteSnapshot(VirtGuest guest, String name) => _action1(
    ffi.virtSnapshotDeleteScript(domain: guest.id, name: name),
  );

  static void _checkName(String name) {
    if (!virtSnapshotNamePattern.hasMatch(name)) {
      throw VirtErr(
        type: VirtErrType.unsupported,
        message: 'Not a snapshot name: $name',
      );
    }
  }

  Future<void> _action1(String script) async {
    await _run(script, ({required String raw}) async {
      ffi.parseVirtAction(raw: raw);
      return '';
    }, action: true);
  }

  // ---------------------------------------------------------------------------
  // Storage and networks
  // ---------------------------------------------------------------------------

  /// The last storage listing: which volumes each pool has and every
  /// domain's disks, which [volumes] needs and does not list again.
  LibvirtStorage? _storage;

  @override
  Future<List<VirtStoragePool>> storagePools() async {
    final json = await _run(ffi.virtStorageScript(), ffi.parseVirtStorageJson);
    final storage = LibvirtStorage.fromJson(_decode(json));
    _storage = storage;
    return [for (final p in storage.pools) poolOf(p)];
  }

  static VirtStoragePool poolOf(LibvirtPool p) {
    final capacity = p.capacity;
    // An inactive pool reports 0 for everything: unknown, not empty.
    final known = p.active && capacity != null && capacity > 0;
    return VirtStoragePool(
      id: p.name,
      name: p.name,
      type: p.poolType ?? '',
      path: p.target,
      source: p.source,
      capacity: known ? capacity : null,
      used: known ? p.allocation : null,
      available: known ? p.available : null,
      active: p.active,
      autostart: p.autostart,
      volumeCount: p.volumes?.length,
    );
  }

  /// `vol-dumpxml` for each volume the last [storagePools] listed in [pool]
  /// (listed again when there is none), with the domains whose disks are
  /// those volumes.
  @override
  Future<List<VirtVolume>> volumes(VirtStoragePool pool) async {
    var storage = _storage;
    if (storage == null || !storage.pools.any((p) => p.name == pool.id)) {
      await storagePools();
      storage = _storage!;
    }
    final listed = storage.pools
        .firstWhereOrNull((p) => p.name == pool.id)
        ?.volumes;
    if (listed == null || listed.isEmpty) return const [];
    final json = await _run(
      ffi.virtVolumesScript(
        pool: pool.id,
        names: [for (final v in listed) v.name],
      ),
      ffi.parseVirtVolumesJson,
    );
    final disks = storage.disks;
    return [
      for (final v in _decodeList(json))
        volumeOf(LibvirtVolume.fromJson(v), pool.id, disks),
    ];
  }

  static VirtVolume volumeOf(
    LibvirtVolume v,
    String pool,
    List<LibvirtDiskUse> disks,
  ) {
    final path = v.path;
    bool uses(LibvirtDiskUse d) {
      final source = d.source;
      if (source == null) return false;
      if (path != null && source == path) return true;
      // A `type='volume'` disk names its pool and volume instead of a path.
      return d.kind == 'volume' &&
          (source == '$pool/${v.name}' || source == v.name);
    }

    return VirtVolume(
      id: v.name,
      name: v.name,
      path: path,
      format: v.format,
      capacity: v.capacity,
      allocation: v.allocation,
      backing: v.backing,
      users: [
        for (final d in disks)
          if (uses(d)) VirtGuestRef(guestId: d.domain, device: d.target),
      ],
    );
  }

  @override
  Future<List<VirtNetwork>> networks() async {
    final json = await _run(
      ffi.virtNetworksScript(),
      ffi.parseVirtNetworksJson,
    );
    final nets = LibvirtNetworks.fromJson(_decode(json));
    return [for (final n in nets.networks) networkOf(n, nets)];
  }

  /// [n] with the domains that have a NIC on it: by network name, or on its
  /// bridge directly. Addresses from its DHCP leases.
  static VirtNetwork networkOf(LibvirtNetwork n, LibvirtNetworks all) {
    final bridge = n.bridge;
    bool on(LibvirtIfaceUse i) =>
        (i.kind == 'network' && i.source == n.name) ||
        (i.kind == 'bridge' && bridge != null && i.source == bridge);
    return VirtNetwork(
      id: n.name,
      name: n.name,
      mode: n.mode,
      bridge: bridge,
      cidrs: [for (final ip in n.ips) ip.cidr],
      dhcpRanges: [for (final ip in n.ips) ...ip.dhcpRanges],
      ports: n.forwardDevs,
      active: n.active,
      autostart: n.autostart,
      users: [
        for (final i in all.ifaces)
          if (on(i))
            VirtGuestRef(
              guestId: i.domain,
              device: i.interface,
              mac: i.mac,
              ip: all.leases
                  .firstWhereOrNull((l) => l.mac == i.mac)
                  ?.ip,
            ),
      ],
    );
  }

  @override
  Future<List<VirtStats>?> history(
    VirtGuest guest, {
    VirtHistoryWindow window = VirtHistoryWindow.hour,
  }) async => null;

  @override
  Future<void> reset() async {
    _rates.clear();
    _storage = null;
  }

  @override
  Future<void> close() async {
    _sudoPassword = null;
    _rates.clear();
    _storage = null;
  }

  // ---------------------------------------------------------------------------
  // Running scripts
  // ---------------------------------------------------------------------------

  /// Runs [script] and parses its output, going through sudo when the daemon
  /// refuses this account.
  Future<String> _run(
    String script,
    Future<String> Function({required String raw}) parse, {
    bool action = false,
  }) async {
    final ServerExec exec;
    try {
      exec = await _exec();
    } catch (e) {
      throw _unreachable(e);
    }

    ffi.VirtFfiError? refused;
    if (!_viaSudo) {
      final result = await _exec1(() => exec.run(script, entry: 'sh'));
      try {
        return await parse(raw: result.combined);
      } on ffi.VirtFfiError catch (e) {
        if (e.kind != ffi.VirtErrorKind.permissionDenied) {
          throw _toErr(e, action: action);
        }
        Loggers.app.info('virsh refused on $serverId, trying sudo');
        refused = e;
        _viaSudo = true;
      }
    }

    final password = _sudoPassword;
    final result = await _exec1(
      () => PrivilegedExec.run(
        exec,
        script,
        isRoot: false,
        password: password,
      ),
    );
    if (result.exitCode == kSudoPasswordRejected) {
      if (password == null) {
        throw const VirtErr(
          type: VirtErrType.sudoPasswordRequired,
          message: 'sudo needs a password to reach libvirt',
        );
      }
      _sudoPassword = null;
      throw const VirtErr(
        type: VirtErrType.sudoPasswordRejected,
        message: 'sudo rejected the password',
      );
    }
    try {
      return await parse(raw: result.combined);
    } on ffi.VirtFfiError catch (e) {
      // Output that is not the script's is sudo itself failing — not
      // installed, or this account not in sudoers. What the user has to change
      // is libvirt's permission, so that is what is reported, with sudo's
      // words after it.
      if (e.kind == ffi.VirtErrorKind.malformed) {
        throw VirtErr(
          type: VirtErrType.permissionDenied,
          message: [
            ?refused?.message,
            result.combined.trim(),
          ].where((m) => m.isNotEmpty).join('\n'),
          cause: e,
        );
      }
      throw _toErr(e, action: action);
    }
  }

  Future<ExecResult> _exec1(Future<ExecResult> Function() run) async {
    try {
      return await run();
    } catch (e) {
      throw _unreachable(e);
    }
  }

  VirtErr _unreachable(Object e) {
    if (e is VirtErr) return e;
    if (e is ServerTcpErr && e.type == ServerTcpErrType.relayNotGranted) {
      return VirtErr(
        type: VirtErrType.relayNotGranted,
        message: e.message,
        cause: e,
      );
    }
    // The agent was reached and said no. "Could not reach this host" would
    // send the user looking at the network instead of at the agent's config.
    if (e is MonitorHttpErr && e.type == MonitorHttpErrType.notGranted) {
      return VirtErr(
        type: VirtErrType.execNotGranted,
        message: e.message,
        cause: e,
      );
    }
    return VirtErr(type: VirtErrType.unreachable, message: '$e', cause: e);
  }

  static VirtErr _toErr(ffi.VirtFfiError e, {bool action = false}) {
    final type = switch (e.kind) {
      ffi.VirtErrorKind.notInstalled => VirtErrType.notInstalled,
      ffi.VirtErrorKind.permissionDenied => VirtErrType.permissionDenied,
      ffi.VirtErrorKind.connectFailed => VirtErrType.unreachable,
      ffi.VirtErrorKind.malformed => VirtErrType.invalidResponse,
      ffi.VirtErrorKind.domainNotFound ||
      ffi.VirtErrorKind.invalidState ||
      ffi.VirtErrorKind.command =>
        action ? VirtErrType.actionFailed : VirtErrType.unknown,
    };
    return VirtErr(
      type: type,
      message: e.message.isEmpty ? e.kind.name : e.message,
      cause: e,
    );
  }

  static Map<String, dynamic> _decode(String json) {
    try {
      return jsonDecode(json) as Map<String, dynamic>;
    } catch (e) {
      throw VirtErr(
        type: VirtErrType.invalidResponse,
        message: '$e',
        cause: e,
      );
    }
  }

  static List<Map<String, dynamic>> _decodeList(String json) {
    try {
      return (jsonDecode(json) as List).cast<Map<String, dynamic>>();
    } catch (e) {
      throw VirtErr(
        type: VirtErrType.invalidResponse,
        message: '$e',
        cause: e,
      );
    }
  }

  static int? _kib(int? kib) => kib == null ? null : kib * 1024;
}
