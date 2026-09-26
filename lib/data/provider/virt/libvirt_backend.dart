import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:fl_lib/fl_lib.dart';
import 'package:meta/meta.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:server_box/core/utils/local_server.dart';
import 'package:server_box/core/utils/privileged_exec.dart';
import 'package:server_box/core/utils/ssh_exec.dart';
import 'package:server_box/data/model/app/error.dart';
import 'package:server_box/data/model/server/server_exec.dart';
import 'package:server_box/data/model/virt/libvirt.dart';
import 'package:server_box/data/model/virt/virt.dart';
import 'package:server_box/data/model/virt/virt_backup.dart';
import 'package:server_box/data/model/virt/virt_console.dart';
import 'package:server_box/data/model/virt/virt_create.dart';
import 'package:server_box/data/model/virt/virt_detail.dart';
import 'package:server_box/data/model/virt/virt_hardware.dart';
import 'package:server_box/data/model/virt/virt_manage.dart';
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
    Future<ServerByteExec> Function()? byteExec,
    bool Function()? canStream,
    DateTime Function()? now,
    @visibleForTesting this.seedTools,
  }) : _exec = exec,
       _byteExec = byteExec,
       _canStream = canStream,
       _now = now ?? DateTime.now;

  /// The ISO tools a cloud-init seed may be made with, in order; null: all
  /// of them, in `sbm_parser`'s order. The end-to-end tests narrow it to
  /// make a seed with each tool in turn.
  final List<String>? seedTools;

  /// Uploads go over whatever of the server carries bytes: its SSH
  /// connection, whichever transport leads for everything else, or this
  /// device's own process.
  factory LibvirtBackend.of(Ref ref, String serverId) {
    bool local() => ref.read(serverProvider(serverId)).spi.local;
    return LibvirtBackend(
      serverId: serverId,
      exec: () => ref.read(serverProvider(serverId).notifier).ensureExec(),
      canStream: () =>
          local() || ref.read(serverProvider(serverId)).capabilities.byteStream,
      byteExec: () async => local()
          ? LocalServer.exec()
          : SshExec(
              await ref.read(serverProvider(serverId).notifier).ensureShellClient(),
            ),
    );
  }

  @override
  final String serverId;

  @override
  VirtHostKind get kind => VirtHostKind.libvirt;

  final Future<ServerExec> Function() _exec;
  final Future<ServerByteExec> Function()? _byteExec;
  final bool Function()? _canStream;
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
      capabilities: VirtCapabilities(
        pause: true,
        snapshots: true,
        snapshotMemoryRequired: true,
        storage: true,
        network: true,
        serialConsole: true,
        vncConsole: true,
        create: true,
        deleteKeepsDisks: true,
        hardware: true,
        clone: true,
        storageEdit: true,
        poolTypes: const ['dir', 'netfs', 'logical'],
        poolAutostart: true,
        poolDeleteStorage: true,
        volumeResize: true,
        volumeClone: true,
        upload: _byteExec != null && (_canStream?.call() ?? false),
        networkEdit: true,
        networkModes: const ['nat', 'route', 'isolated', 'bridge'],
        networkStart: true,
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
    final d = await _domainDetail(guest);
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

  Future<LibvirtDomainDetail> _domainDetail(VirtGuest guest) async =>
      LibvirtDomainDetail.fromJson(
        _decode(
          await _run(
            ffi.virtDomainDetailScript(domain: guest.id),
            ffi.parseVirtDomainDetailJson,
          ),
        ),
      );

  @override
  Future<VirtConsole> console(VirtGuest guest, VirtConsoleKind kind) async {
    switch (kind) {
      case VirtConsoleKind.text:
        return LibvirtSerialConsole(
          command: ffi.virtConsoleCommand(domain: guest.id),
          needsRoot: _viaSudo,
        );
      case VirtConsoleKind.vnc:
        final info = LibvirtVncConsoleInfo.fromJson(
          _decode(
            await _run(
              ffi.virtVncConsoleScript(domain: guest.id),
              ffi.parseVirtVncConsoleJson,
            ),
          ),
        );
        final display = info.display;
        final port = display?.port;
        if (display == null || display.protocol != 'vnc' || port == null) {
          throw VirtErr(
            type: VirtErrType.unsupported,
            message: display == null
                ? 'No VNC display while ${guest.name} is not running'
                : 'The display is ${display.uri}, not a VNC port',
          );
        }
        return LibvirtVncConsole(
          host: _dialHost(display.host),
          port: port,
          password: info.password,
          passwordKnown: info.passwordKnown,
        );
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
  // Creating and deleting
  // ---------------------------------------------------------------------------

  @override
  Future<int?> nextVmid() async => null;

  /// From `domcapabilities` for the machine a new domain gets (KVM and q35
  /// where the host has them): the buses it has (q35: no IDE), UEFI where
  /// OVMF is installed, a TPM where swtpm is; and whether the host has a
  /// tool to make a cloud-init seed with. A cloud image is a
  /// `vol-create-from` away on any host.
  @override
  Future<VirtCreateOptions> createOptions() async {
    final host = LibvirtCreateHost.fromJson(
      _decode(await _run(ffi.virtCreateHostScript(), ffi.parseVirtCreateHostJson)),
    );
    final caps = host.caps;
    final buses = [
      for (final b in virtCreateBuses)
        if (caps == null
            ? b == 'virtio' || b == 'sata'
            : caps.diskBuses.contains(b) &&
                  !(b == 'ide' && host.machine.contains('q35')))
          b,
    ];
    return VirtCreateOptions(
      buses: buses,
      nicModels: virtCreateNicModels,
      uefi: caps?.efi ?? false,
      tpm: caps?.tpmEmulator ?? false,
      cloudImages: true,
      cloudInit: host.seedTool != null,
      cloudInitMissing: host.seedTool == null
          ? 'genisoimage, xorriso, mkisofs, cloud-localds'
          : null,
    );
  }

  /// Three round trips: what the host runs a domain as (`domcapabilities`:
  /// KVM and q35 where it can), the disk — empty, or a copy of a cloud image
  /// — and a cloud-init seed, with their paths, then the domain on them —
  /// defined, and started when asked. A define the host refuses deletes the
  /// volumes again. See `sbm_parser::virt::create_volume_script`.
  ///
  /// A cloud-init password is hashed here (SHA-512 crypt, a salt from
  /// `Random.secure`): only the hash reaches the host.
  @override
  Future<VirtCreated> create(VirtCreateSpec spec) async {
    if (spec.kind != VirtGuestKind.qemu) {
      throw const VirtErr(type: VirtErrType.unsupported);
    }
    String pathOf(VirtVolume v) =>
        v.path ??
        (throw VirtErr(
          type: VirtErrType.invalidResponse,
          message: 'No path for ${v.name}',
        ));
    final mediaPath = switch (spec.media) {
      final m? => pathOf(m),
      null => null,
    };
    final imagePath = switch (spec.image) {
      final i? => pathOf(i),
      null => null,
    };
    final host = _decode(
      await _run(ffi.virtCreateHostScript(), ffi.parseVirtCreateHostJson),
    );
    final ci = spec.cloudInit;
    // The NIC's MAC is chosen here when cloud-init finds the NIC by it.
    final mac = ci != null && spec.network != null ? _newMac() : null;
    final json = <String, Object?>{
      'name': spec.name,
      'vcpus': spec.cores,
      'memory_mib': spec.memoryMiB,
      'host': host,
      'disk_pool': spec.storage.id,
      'disk_gib': spec.diskGiB,
      'disk_format': virtLibvirtDiskFormat(spec.storage.type),
      'disk_path': null,
      'base_image': imagePath,
      'disk_bus': spec.bus,
      'cdrom': mediaPath,
      'network': spec.network?.name,
      'nic_model': spec.nicModel,
      'mac': mac,
      'efi': spec.uefi,
      'tpm': spec.tpm,
      'cloud_init': ci == null
          ? null
          : cloudInitJson(ci, name: spec.name, mac: mac),
      'seed_path': null,
      'seed_tools': seedTools,
      'start': spec.start,
    };
    final Map<String, dynamic> made;
    try {
      made = _decode(
        await _run(
          _script(() => ffi.virtCreateVolumeScript(specJson: jsonEncode(json))),
          ffi.parseVirtCreateVolumesJson,
          action: true,
        ),
      );
    } on VirtErr catch (e) {
      throw _existsOr(e);
    }
    json['disk_path'] = made['disk_path'];
    json['seed_path'] = made['seed_path'];
    final created = _decode(
      await _run(
        _script(() => ffi.virtDefineScript(specJson: jsonEncode(json))),
        ffi.parseVirtCreateJson,
        action: true,
      ),
    );
    // A copy of a cloud image bigger than asked for keeps its own size.
    final copied = made['copied_bytes'] as int?;
    return VirtCreated(
      // By name when `domuuid` did not answer: virsh takes either.
      id: created['uuid'] as String? ?? spec.name,
      startError: created['start_error'] as String?,
      diskKeptBytes: copied != null && copied > spec.diskGiB * (1 << 30)
          ? copied
          : null,
    );
  }

  /// [ci] as `sbm_parser::virt_cloud_init::VirtCloudInit` JSON for the
  /// domain [name]: the password as its SHA-512 crypt hash — or, where none
  /// was typed, [keepHash] (the seed's own, when it is edited) — the
  /// hostname [name] where none was given, a new instance ID, and the NIC
  /// by [mac].
  ///
  /// The instance ID is new every time: cloud-init runs most of its
  /// modules once per instance, so a seed with the old one would be read
  /// and ignored.
  @visibleForTesting
  static Map<String, Object?> cloudInitJson(
    VirtCloudInit ci, {
    required String name,
    required String? mac,
    String? keepHash,
    Random? random,
  }) {
    final r = random ?? Random.secure();
    const alphabet =
        './0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz';
    final salt = String.fromCharCodes([
      for (var i = 0; i < 16; i++) alphabet.codeUnitAt(r.nextInt(64)),
    ]);
    final password = ci.password ?? '';
    final hex = [
      for (var i = 0; i < 4; i++) r.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ].join();
    final address = ci.address;
    return {
      'user': ci.user,
      'password_hash': password.isEmpty
          ? keepHash
          : _script(() => ffi.virtHashPassword(password: password, salt: salt)),
      'ssh_keys': ci.keys,
      'hostname': ci.hostname ?? name,
      'instance_id': 'iid-${name.replaceAll(RegExp('[^A-Za-z0-9._-]'), '-')}-$hex',
      'network': mac == null
          ? null
          : {
              'mac': mac,
              'ipv4': address == null
                  ? null
                  : {'address': address, 'gateway': ci.gateway},
              'dns': ci.dns,
              'search': [?ci.searchDomain],
            },
    };
  }

  /// Snapshots' metadata and a managed save go with it; with [removeDisks]
  /// the volumes of its writable disks, its NVRAM and its own cloud-init
  /// seed too — not a CD-ROM's image or a read-only disk, which are install
  /// media or shared. Refused while it runs: `undefine` would leave it
  /// running, transient.
  @override
  Future<void> delete(VirtGuest guest, {bool removeDisks = true}) async {
    if (guest.state != VirtGuestState.stopped) {
      throw VirtErr(
        type: VirtErrType.unsupported,
        message: '${guest.name} is not stopped',
      );
    }
    final targets = <String>[];
    String? seed;
    if (removeDisks) {
      final xml = (await _domainDetail(guest)).xml;
      for (final d in xml.disks) {
        final target = d.target;
        if (d.device == 'disk' && !d.readonly && target != null) {
          targets.add(target);
        }
      }
      seed = xml.seed;
    }
    await _run(
      _script(
        () => ffi.virtUndefineScript(
          domain: guest.id,
          storage: targets,
          seed: seed,
        ),
      ),
      ({required String raw}) async {
        ffi.parseVirtUndefine(raw: raw);
        return '';
      },
      action: true,
    );
  }

  // ---------------------------------------------------------------------------
  // Cloning (libvirt has no backups of its own)
  // ---------------------------------------------------------------------------

  /// Two steps, as creating is: each writable disk copied (or made empty)
  /// in the pool its source is in, then the copy defined on those volumes —
  /// a new UUID and MACs, its own UEFI variables file. Either step failing
  /// deletes the volumes it made. A CD-ROM stays on the image it has.
  @override
  Future<String> clone(VirtGuest guest, VirtCloneRequest request) async {
    if (guest.state != VirtGuestState.stopped) {
      throw VirtErr(
        type: VirtErrType.unsupported,
        message: '${guest.name} is not stopped',
      );
    }
    final hw = await hardware(guest);
    final base = _hardware[guest.id]!.configXml;
    final disks = <Map<String, Object?>>[];
    for (final d in hw.disks) {
      if (d.kind != VirtHwDiskKind.disk || d.readonly) continue;
      final source = d.source;
      if (source == null || !source.startsWith('/')) {
        throw VirtErr(
          type: VirtErrType.unsupported,
          message: 'Disk ${d.key} has no file to copy',
        );
      }
      disks.add({
        'target': d.key,
        'source': source,
        'format': d.format == 'qcow2' || d.format == 'raw' ? d.format : null,
      });
    }
    final spec = {
      'source': guest.id,
      'name': request.name,
      'full': request.full,
      'disks': disks,
    };
    final List<Object?> paths;
    try {
      paths = jsonDecode(
        await _run(
          _script(() => ffi.virtCloneVolumesScript(specJson: jsonEncode(spec))),
          ({required String raw}) async =>
              jsonEncode(await ffi.parseVirtCloneVolumes(raw: raw)),
          action: true,
        ),
      ) as List<Object?>;
    } on VirtErr catch (e) {
      throw _existsOr(e);
    }
    final created = _decode(
      await _run(
        _script(
          () => ffi.virtCloneDefineScript(
            baseXml: base,
            name: request.name,
            disksJson: jsonEncode([
              for (var i = 0; i < disks.length; i++) [disks[i]['target'], paths[i]],
            ]),
          ),
        ),
        ffi.parseVirtCreateJson,
        action: true,
      ),
    );
    return created['uuid'] as String? ?? request.name;
  }

  static Never _noBackups() => throw const VirtErr(type: VirtErrType.unsupported);

  @override
  Future<List<VirtBackup>> backups(VirtGuest guest) async => _noBackups();

  @override
  Future<List<VirtBackupJob>> backupJobs(VirtGuest guest) async => const [];

  @override
  Future<List<VirtStoragePool>> backupStorages(VirtGuest guest) async =>
      const [];

  @override
  Future<void> backup(VirtGuest guest, VirtBackupRequest request) async =>
      _noBackups();

  @override
  Future<void> restoreBackup(
    VirtGuest guest,
    VirtBackup backup, {
    int? vmid,
  }) async => _noBackups();

  @override
  Future<void> deleteBackup(VirtGuest guest, VirtBackup backup) async =>
      _noBackups();

  /// A script the parser refused to write: what it was given is this app's
  /// fault, not the host's.
  static String _script(String Function() build) {
    try {
      return build();
    } on ffi.VirtFfiError catch (e) {
      throw VirtErr(type: VirtErrType.unsupported, message: e.message, cause: e);
    }
  }

  static VirtErr _existsOr(VirtErr e) => switch (e.cause) {
    ffi.VirtFfiError(kind: ffi.VirtErrorKind.exists) => VirtErr(
      type: VirtErrType.exists,
      message: e.message == ffi.VirtErrorKind.exists.name ? null : e.message,
      cause: e.cause,
    ),
    _ => e,
  };

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

  // ---------------------------------------------------------------------------
  // Managing storage and networks
  // ---------------------------------------------------------------------------

  @override
  Future<void> manage(VirtResourceChange change) async {
    final op = opJson(change);
    try {
      await _run(
        _script(() => ffi.virtResourceScript(opJson: jsonEncode(op))),
        _parseResource,
        action: true,
      );
    } on VirtErr catch (e) {
      throw _existsOr(e);
    } finally {
      // What a pool holds, and which, is listed again.
      _storage = null;
    }
  }

  static Future<String> _parseResource({required String raw}) async {
    ffi.parseVirtResource(raw: raw);
    return '';
  }

  /// [change] as `sbm_parser::virt_manage::VirtResourceOp` JSON.
  @visibleForTesting
  static Map<String, Object?> opJson(VirtResourceChange change) {
    switch (change) {
      case VirtPoolCreate(:final name, :final type, :final source, :final target, :final autostart):
        return {
          'op': 'pool_create',
          'name': name,
          'pool_type': type,
          'target': switch (type) {
            'dir' => source,
            'netfs' => target,
            _ => null,
          },
          'source': type == 'dir' ? null : source,
          'autostart': autostart,
        };
      case VirtPoolSetActive(:final pool, :final active):
        return {'op': active ? 'pool_start' : 'pool_stop', 'name': pool.id};
      case VirtPoolSetAutostart(:final pool, :final on):
        return {'op': 'pool_autostart', 'name': pool.id, 'on': on};
      case VirtPoolRefresh(:final pool):
        return {'op': 'pool_refresh', 'name': pool.id};
      case VirtPoolDelete(:final pool, :final deleteStorage):
        return {
          'op': 'pool_delete',
          'name': pool.id,
          'active': pool.active,
          'delete_storage': deleteStorage,
        };
      case VirtVolumeCreate(:final pool, :final name, :final gib, :final format):
        return {
          'op': 'vol_create',
          'pool': pool.id,
          'name': name,
          'bytes': gib << 30,
          'format': format,
        };
      case VirtVolumeDelete(:final pool, :final volume):
        return {'op': 'vol_delete', 'pool': pool.id, 'name': volume.name};
      case VirtVolumeResize(:final pool, :final volume, :final bytes):
        return {
          'op': 'vol_resize',
          'pool': pool.id,
          'name': volume.name,
          'bytes': bytes,
        };
      case VirtVolumeClone(:final pool, :final volume, :final name):
        return {
          'op': 'vol_clone',
          'pool': pool.id,
          'name': volume.name,
          'new_name': name,
        };
      case VirtNetworkCreate(
        :final name,
        :final mode,
        :final bridge,
        :final cidr,
        :final dhcpStart,
        :final dhcpEnd,
        :final autostart,
      ):
        final ip = cidr == null || cidr.trim().isEmpty
            ? null
            : cidr.trim().split('/');
        return {
          'op': 'net_create',
          'name': name,
          'mode': mode,
          'bridge': mode == 'bridge' ? bridge?.trim() : null,
          'ipv4': mode == 'bridge' || ip == null
              ? null
              : {
                  'address': ip.first,
                  'prefix': int.parse(ip.last),
                  'dhcp_start': dhcpStart,
                  'dhcp_end': dhcpEnd,
                },
          'autostart': autostart,
        };
      case VirtNetworkSetActive(:final network, :final active):
        return {'op': active ? 'net_start' : 'net_stop', 'name': network.id};
      case VirtNetworkSetAutostart(:final network, :final on):
        return {'op': 'net_autostart', 'name': network.id, 'on': on};
      case VirtNetworkDelete(:final network):
        return {'op': 'net_delete', 'name': network.id, 'active': network.active};
      case VirtNetworkApply() || VirtNetworkRevert():
        // libvirt changes a network when told to: nothing waits.
        throw const VirtErr(type: VirtErrType.unsupported);
    }
  }

  /// libvirt applies every change as it is made.
  @override
  Future<List<VirtNetworkChanges>> networkChanges() async => const [];

  /// A raw volume of the file's size, then the file into it with
  /// `vol-upload` over a channel that carries bytes (see
  /// `sbm_parser::virt_manage::vol_upload_command`): through sudo when
  /// libvirt needs it, the password ahead of the file on the same stdin. A
  /// failed or cancelled upload deletes the volume, which holds part of a
  /// file at best.
  @override
  Future<bool> upload(
    VirtUpload upload, {
    void Function(int sent)? onProgress,
    Future<void>? cancel,
  }) async {
    final open = _byteExec;
    if (open == null || !(_canStream?.call() ?? false)) {
      throw const VirtErr(type: VirtErrType.unsupported);
    }
    final pool = upload.pool.id;
    Future<void> op(Map<String, Object?> json) => _run(
      _script(() => ffi.virtResourceScript(opJson: jsonEncode(json))),
      _parseResource,
      action: true,
    );
    try {
      await op({
        'op': 'vol_create',
        'pool': pool,
        'name': upload.name,
        'bytes': upload.size,
        'format': 'raw',
      });
    } on VirtErr catch (e) {
      throw _existsOr(e);
    }
    var done = false;
    try {
      final exec = await open().catchError(
        (Object e) => throw _unreachable(e),
      );
      // Decided by the volume just made: it went through sudo if libvirt
      // needed it.
      var entry = !_viaSudo
          ? ffi.VirtUploadEntryKind.direct
          : _sudoPassword != null
          ? ffi.VirtUploadEntryKind.sudoPassword
          : ffi.VirtUploadEntryKind.sudoNoPassword;
      var result = await _stream(
        exec,
        upload,
        entry,
        onProgress: onProgress,
        cancel: cancel,
      );
      // sudo did not ask for the password it was given (cached, or
      // NOPASSWD): nothing was written; once more without it.
      if (result == _Streamed.notStarted &&
          entry == ffi.VirtUploadEntryKind.sudoPassword) {
        entry = ffi.VirtUploadEntryKind.sudoNoPassword;
        result = await _stream(
          exec,
          upload,
          entry,
          onProgress: onProgress,
          cancel: cancel,
        );
      }
      switch (result) {
        case _Streamed.done:
          done = true;
          return true;
        case _Streamed.cancelled:
          return false;
        case _Streamed.notStarted:
          throw const VirtErr(
            type: VirtErrType.actionFailed,
            message: 'The upload did not start',
          );
      }
    } finally {
      _storage = null;
      if (!done) {
        try {
          await op({'op': 'vol_delete', 'pool': pool, 'name': upload.name});
        } catch (e, s) {
          Loggers.app.warning('Deleting the unfinished upload ${upload.name}', e, s);
        }
      }
    }
  }

  /// One attempt: the preamble, the go line, and — once the host says it is
  /// ready — the file.
  Future<_Streamed> _stream(
    ServerByteExec exec,
    VirtUpload upload,
    ffi.VirtUploadEntryKind entry, {
    void Function(int sent)? onProgress,
    Future<void>? cancel,
  }) async {
    final command = _script(
      () => ffi.virtVolUploadCommand(
        pool: upload.pool.id,
        name: upload.name,
        entry: entry,
      ),
    );
    final ExecSession session;
    try {
      session = await exec.start(command);
    } catch (e) {
      throw _unreachable(e);
    }
    final marker = ffi.virtUploadReadyMarker();
    final out = StringBuffer();
    final err = StringBuffer();
    final ready = Completer<bool>();
    final outDone = Completer<void>();
    final errDone = Completer<void>();
    final outSub = session.stdout.listen(
      (chunk) {
        out.write(chunk);
        if (!ready.isCompleted && out.toString().contains(marker)) {
          ready.complete(true);
        }
      },
      onDone: outDone.complete,
      onError: (Object _) => outDone.complete(),
    );
    var rejected = false;
    final errSub = session.stderr.listen(
      (chunk) {
        err.write(chunk);
        // A refused password: sudo asks again on the same stdin, and the go
        // line would be its next guess. Nothing more is sent.
        if (entry == ffi.VirtUploadEntryKind.sudoPassword &&
            !rejected &&
            _sudoRejected.any(err.toString().contains)) {
          rejected = true;
          if (!ready.isCompleted) ready.complete(false);
          session.kill();
        }
      },
      onDone: errDone.complete,
      onError: (Object _) => errDone.complete(),
    );
    var cancelled = false;
    unawaited(
      cancel?.then((_) {
        cancelled = true;
        if (!ready.isCompleted) ready.complete(false);
        session.kill();
      }),
    );
    final exited = session.done;
    unawaited(exited.then((_) {
      if (!ready.isCompleted) ready.complete(false);
    }, onError: (Object _) {
      if (!ready.isCompleted) ready.complete(false);
    }));
    int? code;
    try {
      final password = _sudoPassword;
      try {
        if (entry == ffi.VirtUploadEntryKind.sudoPassword &&
            password != null) {
          await session.write(utf8.encode('$password\n'));
        }
        await session.write(utf8.encode('${ffi.virtUploadGoLine()}\n'));
      } catch (_) {
        // The command ended before it read them — the script turning the
        // password away as its go line, sudo refusing: its output says
        // which, and no file follows.
      }
      final go = await ready.future.timeout(
        uploadReadyTimeout,
        onTimeout: () => false,
      );
      if (go && !cancelled) {
        var sent = 0;
        await for (final chunk in upload.open()) {
          if (cancelled) break;
          await session.write(chunk);
          sent += chunk.length;
          onProgress?.call(sent);
        }
      }
      if (!go && !cancelled) {
        // Whatever holds it up, it gets no file: ended here.
        session.kill();
      } else if (!cancelled) {
        await session.closeStdin();
      }
      code = await exited;
    } catch (e) {
      if (cancelled) return _Streamed.cancelled;
      throw _unreachable(e);
    } finally {
      await Future.wait([
        outDone.future,
        errDone.future,
      ]).timeout(const Duration(seconds: 5), onTimeout: () => const []);
      await outSub.cancel();
      await errSub.cancel();
      session.kill();
    }
    if (cancelled) return _Streamed.cancelled;
    final stderr = err.toString();
    if (rejected) {
      _sudoPassword = null;
      throw const VirtErr(
        type: VirtErrType.sudoPasswordRejected,
        message: 'sudo rejected the password',
      );
    }
    try {
      final uploaded = ffi.parseVirtVolUpload(raw: '$out$stderr');
      return uploaded ? _Streamed.done : _Streamed.notStarted;
    } on ffi.VirtFfiError catch (e) {
      if (e.kind == ffi.VirtErrorKind.malformed) {
        // Nothing of the script's: the shell or sudo itself refused.
        throw VirtErr(
          type: entry == ffi.VirtUploadEntryKind.direct
              ? VirtErrType.actionFailed
              : VirtErrType.permissionDenied,
          message: [stderr.trim(), 'exit $code'].where((m) => m.isNotEmpty).join('\n'),
          cause: e,
        );
      }
      throw _toErr(e, action: true);
    }
  }

  /// How long the upload command may take to say it is ready: a shell,
  /// sudo and `read` — seconds at most.
  static const uploadReadyTimeout = Duration(seconds: 60);

  /// What sudo prints when it will not take the password, as
  /// `ServerExecSudo.runWithSudo` watches for.
  static const _sudoRejected = [
    'Sorry, try again.',
    'incorrect password attempt',
  ];

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
  // Hardware
  // ---------------------------------------------------------------------------

  /// The last hardware read per guest: which disks and NICs each definition
  /// has, which a change needs to know to address the right one.
  final _hardware = <String, LibvirtHardwareInfo>{};

  /// One round trip: both definitions, autostart, the host's CPUs and
  /// memory, and each disk's size. See `sbm_parser::virt::hardware_script`.
  @override
  Future<VirtHardware> hardware(VirtGuest guest) async =>
      hardwareOf(await _hardwareInfo(guest), name: guest.name);

  Future<LibvirtHardwareInfo> _hardwareInfo(VirtGuest guest) async {
    final info = LibvirtHardwareInfo.fromJson(
      _decode(
        await _run(
          ffi.virtHardwareScript(domain: guest.id),
          ffi.parseVirtHardwareJson,
        ),
      ),
    );
    return _hardware[guest.id] = info;
  }

  /// [info] as the Hardware view edits it: the persistent definition, with
  /// what the running one has instead as pending.
  @visibleForTesting
  static VirtHardware hardwareOf(LibvirtHardwareInfo info, {String? name}) {
    final c = info.config;
    final hostMem = info.hostMemoryKib;
    return VirtHardware(
      kind: VirtGuestKind.qemu,
      running: info.live != null,
      cpu: _cpuOf(c.cpu),
      memory: VirtHwMemory(
        mib: c.memoryKib ~/ 1024,
        minMib: c.balloon ? c.currentMemoryKib ~/ 1024 : null,
        balloon: c.balloon,
      ),
      disks: [
        for (final d in c.disks)
          if (d.device == 'disk' || d.device == 'cdrom')
            VirtHwDisk(
              key: d.target,
              kind: d.device == 'cdrom'
                  ? VirtHwDiskKind.cdrom
                  : VirtHwDiskKind.disk,
              source: d.source,
              size: d.capacity,
              bus: d.bus,
              format: d.format,
              readonly: d.readonly,
              cache: d.cache,
              cloudInit:
                  d.device == 'cdrom' && c.seed != null && d.source == c.seed,
            ),
      ],
      nics: [
        for (final n in c.nics)
          VirtHwNic(
            key: n.mac,
            mac: n.mac,
            type: n.kind,
            source: n.source,
            model: n.model,
            linkUp: n.linkUp,
          ),
      ],
      boot: c.boot,
      autostart: info.autostart,
      firmware: VirtHwFirmware(uefi: c.efi, secureBoot: c.secureBoot),
      display: VirtHwDisplay(
        protocol: c.graphics?.kind,
        listen: c.graphics?.listen,
        gpu: c.video,
        port: c.graphics?.port,
      ),
      devices: [
        if (c.tpm case final t?)
          VirtHwDevice(
            key: 'tpm',
            kind: VirtHwDeviceKind.tpm,
            detail: [t.model, t.version].nonNulls.join(' · '),
          ),
        for (final h in c.hostdevs)
          VirtHwDevice(
            key: h.key,
            kind: h.kind == 'pci' ? VirtHwDeviceKind.pci : VirtHwDeviceKind.usb,
            detail:
                h.address ??
                (h.vendor != null ? '${h.vendor}:${h.product}' : h.key.substring(4)),
          ),
      ],
      support: supportOf(info.caps),
      name: name,
      description: info.description,
      renameRunning: false,
      pending: pendingOf(c, info.live),
      revision: info.configXml,
      configText: info.configXml.trimRight(),
      limits: VirtHwLimits(
        hostCpus: info.hostCpus,
        hostMemoryBytes: hostMem == null ? null : hostMem * 1024,
      ),
    );
  }

  /// What the host's `domcapabilities` allows this domain, as the view's
  /// choices. Without them (an older libvirt, a refusal), the common ground
  /// every QEMU has.
  @visibleForTesting
  static VirtHwSupport supportOf(LibvirtHwCaps? caps) {
    List<String> pick(List<String>? have, List<String> wanted) => have == null
        ? wanted
        : [for (final w in wanted) if (have.contains(w)) w];
    return VirtHwSupport(
      buses: pick(caps?.diskBuses, const ['virtio', 'scsi', 'sata', 'ide']),
      caches: const ['default', 'none', 'writeback', 'writethrough', 'directsync', 'unsafe'],
      nicModels: const ['virtio', 'e1000e', 'e1000', 'rtl8139'],
      mac: true,
      protocols: pick(caps?.graphics, const ['vnc', 'spice']),
      listen: true,
      gpus: pick(caps?.video, const ['virtio', 'qxl', 'vga', 'cirrus', 'bochs', 'none']),
      uefi: caps?.efi ?? false,
      secureBoot: caps?.secureBoot ?? false,
      tpm: caps?.tpmEmulator ?? false,
      usb: caps?.hostdev ?? false,
      pci: caps?.hostdev ?? false,
    );
  }

  /// Dies and clusters count as threads here: the form sets sockets and
  /// cores, and keeps the rest of the topology as it is.
  static VirtHwCpu _cpuOf(LibvirtHwCpu cpu) => VirtHwCpu(
    sockets: cpu.sockets,
    cores: cpu.cores,
    threads: cpu.threads * cpu.dies * cpu.clusters,
    online: cpu.current < cpu.max ? cpu.current : null,
  );

  /// What the running definition ([live]) has differently from the
  /// persistent one ([config]): the changes the next start makes. libvirt
  /// keeps no list of its own; this is the difference.
  ///
  /// The balloon's current size is not one: it moves while the guest runs,
  /// and is not a change anybody made.
  @visibleForTesting
  static List<VirtPendingField> pendingOf(
    LibvirtHwConfig config,
    LibvirtHwConfig? live,
  ) {
    if (live == null) return const [];
    String cpu(LibvirtHwCpu c) {
      final v = _cpuOf(c);
      final shape = '${v.sockets}×${v.cores}×${v.threads}';
      return c.current < c.max ? '${c.current}/${c.max} ($shape)' : '${c.max} ($shape)';
    }

    String mem(int kib) => '${kib ~/ 1024} MiB';
    String nic(LibvirtHwNic n) =>
        [n.kind, n.source, n.model, if (!n.linkUp) 'link down'].nonNulls.join(' ');
    final out = <VirtPendingField>[];
    if (cpu(config.cpu) != cpu(live.cpu)) {
      out.add(VirtPendingField(key: 'cpu', current: cpu(live.cpu), pending: cpu(config.cpu)));
    }
    if (config.memoryKib != live.memoryKib) {
      out.add(
        VirtPendingField(
          key: 'memory',
          current: mem(live.memoryKib),
          pending: mem(config.memoryKib),
        ),
      );
    }
    final liveDisks = {for (final d in live.disks) d.target: d};
    final configDisks = {for (final d in config.disks) d.target: d};
    for (final d in config.disks) {
      final l = liveDisks[d.target];
      if (l == null) {
        out.add(VirtPendingField(key: d.target, pending: d.source ?? d.device));
      } else if (l.source != d.source) {
        out.add(VirtPendingField(key: d.target, current: l.source, pending: d.source));
      }
    }
    for (final l in live.disks) {
      if (!configDisks.containsKey(l.target)) {
        out.add(VirtPendingField(key: l.target, current: l.source ?? l.device, delete: true));
      }
    }
    final liveNics = {for (final n in live.nics) n.mac: n};
    final configNics = {for (final n in config.nics) n.mac: n};
    for (final n in config.nics) {
      final l = liveNics[n.mac];
      if (l == null) {
        out.add(VirtPendingField(key: n.mac, pending: nic(n)));
      } else if (nic(l) != nic(n)) {
        out.add(VirtPendingField(key: n.mac, current: nic(l), pending: nic(n)));
      }
    }
    for (final l in live.nics) {
      if (!configNics.containsKey(l.mac)) {
        out.add(VirtPendingField(key: l.mac, current: nic(l), delete: true));
      }
    }
    String fw(LibvirtHwConfig c) =>
        c.efi ? (c.secureBoot ? 'UEFI · Secure Boot' : 'UEFI') : 'BIOS';
    if (fw(config) != fw(live)) {
      out.add(VirtPendingField(key: 'firmware', current: fw(live), pending: fw(config)));
    }
    String display(LibvirtHwConfig c) => [
      c.graphics?.kind,
      c.graphics?.listen,
      c.video,
    ].nonNulls.join(' · ');
    if (display(config) != display(live)) {
      out.add(
        VirtPendingField(key: 'display', current: display(live), pending: display(config)),
      );
    }
    final liveDevs = {for (final h in live.hostdevs) h.key, if (live.tpm != null) 'tpm'};
    final configDevs = {for (final h in config.hostdevs) h.key, if (config.tpm != null) 'tpm'};
    for (final k in configDevs.difference(liveDevs)) {
      out.add(VirtPendingField(key: k, pending: k));
    }
    for (final k in liveDevs.difference(configDevs)) {
      out.add(VirtPendingField(key: k, current: k, delete: true));
    }
    String diskHw(LibvirtHwDisk d) => '${d.bus ?? ''} ${d.cache ?? 'default'}';
    for (final d in config.disks) {
      final l = liveDisks[d.target];
      if (l != null && l.source == d.source && diskHw(l) != diskHw(d)) {
        out.add(VirtPendingField(key: d.target, current: diskHw(l), pending: diskHw(d)));
      }
    }
    if (config.boot.join(',') != live.boot.join(',')) {
      out.add(
        VirtPendingField(
          key: 'boot',
          current: live.boot.join(', '),
          pending: config.boot.join(', '),
        ),
      );
    }
    return out;
  }

  /// One `virsh` round trip per change, each made to the persistent
  /// definition and, where the domain runs, to the running one: the running
  /// half failing leaves it for the next start ([VirtHwOutcome.liveError]).
  /// A change that rewrites the definition (CPU, boot order) is made from
  /// [base]'s copy and refused when the host's has changed since.
  @override
  Future<VirtHwOutcome> changeHardware(
    VirtGuest guest,
    VirtHardware base,
    VirtHwChange change,
  ) async {
    final info = _hardware[guest.id];
    if (info == null || info.configXml != base.revision) {
      // Not what this backend read last: the definitions it would address
      // disks and NICs by may be someone else's.
      throw const VirtErr(
        type: VirtErrType.conflict,
        message: 'Read the hardware again',
      );
    }
    final running = info.live != null;
    final json = changeJson(info, base, change, guestName: guest.name, mac: _newMac);
    final outcome = _decode(
      await _run(
        _script(
          () => ffi.virtHardwareChangeScript(
            domain: guest.id,
            running: running,
            baseXml: info.configXml,
            changeJson: jsonEncode(json),
          ),
        ),
        ffi.parseVirtHardwareChangeJson,
        action: true,
      ),
    );
    return VirtHwOutcome(
      liveError: outcome['live_error'] as String?,
      volumeKept: outcome['volume_kept'] as bool? ?? false,
    );
  }

  /// The last seed read per guest, with the password's hash in it: what an
  /// edit keeps when no new password is typed. The hash stays here; the
  /// view is told only that there is one.
  final _seeds = <String, ({String path, Map<String, dynamic> read})>{};

  /// The domain's seed, read back from its volume (`vol-download`, in one
  /// round trip) and parsed in Rust: the seed is what the system reads, so
  /// it is the source of what is shown — nothing is kept beside it. The NIC
  /// is the one its network config names while the domain still has it,
  /// the domain's first otherwise.
  @override
  Future<VirtCloudInitState> cloudInit(VirtGuest guest) async {
    final info = _hardware[guest.id] ?? await _hardwareInfo(guest);
    final path = info.config.seed;
    if (path == null) {
      throw VirtErr(
        type: VirtErrType.unsupported,
        message: '${guest.name} has no cloud-init seed of this app',
      );
    }
    final read = _decode(
      await _run(
        _script(() => ffi.virtSeedReadScript(seed: path)),
        ffi.parseVirtSeedReadJson,
      ),
    );
    _seeds[guest.id] = (path: path, read: read);
    return cloudInitStateOf(read, nicMacs: [for (final n in info.config.nics) n.mac]);
  }

  /// A seed's read ([read], `sbm_parser::virt_cloud_init::VirtSeedRead`
  /// JSON) as the view shows it: never the hash, only that there is one.
  @visibleForTesting
  static VirtCloudInitState cloudInitStateOf(
    Map<String, dynamic> read, {
    required List<String> nicMacs,
  }) {
    final ci = (read['cloud_init'] as Map).cast<String, dynamic>();
    final net = (ci['network'] as Map?)?.cast<String, dynamic>();
    final ipv4 = (net?['ipv4'] as Map?)?.cast<String, dynamic>();
    List<String> strs(Object? v) => [for (final x in (v as List?) ?? const []) '$x'];
    final hostname = ci['hostname'] as String? ?? '';
    final search = strs(net?['search']);
    return VirtCloudInitState(
      user: ci['user'] as String? ?? '',
      sshKeys: strs(ci['ssh_keys']),
      hostname: hostname,
      address: ipv4?['address'] as String?,
      gateway: ipv4?['gateway'] as String?,
      dns: strs(net?['dns']),
      searchDomain: search.firstOrNull,
      passwordSet: ci['password_hash'] != null,
      network: nicMacs.isNotEmpty,
      // The view edits one search domain; more are more than it shows.
      foreign: (read['foreign'] as bool? ?? false) || search.length > 1,
      revision: read['revision'] as String? ?? '',
    );
  }

  /// A new seed in place of the old, on the same volume (so the domain and
  /// its metadata stay as they are), made from [base]'s read — refused as
  /// [VirtErrType.conflict] once the seed changed since. A new password is
  /// hashed here; none keeps the hash the seed has. A new instance ID, so
  /// cloud-init takes it at the next boot.
  @override
  Future<void> setCloudInit(
    VirtGuest guest,
    VirtCloudInitState base,
    VirtCloudInitEdit edit,
  ) async {
    final seed = _seeds[guest.id];
    final info = _hardware[guest.id];
    if (seed == null || info == null || seed.read['revision'] != base.revision) {
      throw const VirtErr(
        type: VirtErrType.conflict,
        message: 'Read the cloud-init settings again',
      );
    }
    final ci = (seed.read['cloud_init'] as Map).cast<String, dynamic>();
    final seedMac = ((ci['network'] as Map?)?['mac'] as String?)?.toLowerCase();
    final macs = [for (final n in info.config.nics) n.mac.toLowerCase()];
    final mac = macs.contains(seedMac) ? seedMac : macs.firstOrNull;
    final json = cloudInitJson(
      edit.values,
      name: guest.name,
      mac: base.network ? mac : null,
      keepHash: edit.removePassword ? null : ci['password_hash'] as String?,
    );
    await _run(
      _script(
        () => ffi.virtSeedUpdateScript(
          seed: seed.path,
          revision: base.revision,
          cloudInitJson: jsonEncode(json),
          tools: seedTools,
        ),
      ),
      ({required String raw}) async {
        ffi.parseVirtSeedUpdate(raw: raw);
        return '';
      },
      action: true,
    );
    _seeds.remove(guest.id);
  }

  /// A MAC in QEMU's locally administered range, `52:54:00`.
  static String _newMac() {
    final r = Random.secure();
    String b() => r.nextInt(256).toRadixString(16).padLeft(2, '0');
    return '52:54:00:${b()}:${b()}:${b()}';
  }

  /// [change] as `sbm_parser::virt::VirtHwChange` JSON, addressed by what
  /// [info]'s two definitions have.
  @visibleForTesting
  static Map<String, Object?> changeJson(
    LibvirtHardwareInfo info,
    VirtHardware base,
    VirtHwChange change, {
    required String guestName,
    required String Function() mac,
  }) {
    final config = info.config;
    final live = info.live;
    LibvirtHwDisk? diskIn(LibvirtHwConfig? c, String target) =>
        c?.disks.where((d) => d.target == target).firstOrNull;
    LibvirtHwNic? nicIn(LibvirtHwConfig? c, String mac) =>
        c?.nics.where((n) => n.mac == mac).firstOrNull;
    switch (change) {
      case VirtHwSetCpu(:final sockets, :final cores, :final online):
        return {'op': 'cpu', 'sockets': sockets, 'cores': cores, 'current': online};
      case VirtHwSetMemory(:final mib, :final minMib):
        return {'op': 'memory', 'memory_mib': mib, 'current_mib': minMib};
      case VirtHwGrowDisk(:final key, :final bytes):
        final disk = diskIn(config, key);
        return {
          'op': 'grow_disk',
          'target': key,
          'bytes': bytes,
          'path': disk?.sourceType == 'file' ? disk?.source : null,
          'live': diskIn(live, key) != null,
        };
      case VirtHwAddDisk(:final storage, :final gib):
        final taken = {
          for (final d in [...config.disks, ...?live?.disks]) d.target,
        };
        final bus = config.disks
                .where((d) => d.device == 'disk')
                .firstOrNull
                ?.bus ??
            'virtio';
        final target = _freeTarget(_busPrefix(bus), taken);
        final format = virtLibvirtDiskFormat(storage.type);
        return {
          'op': 'add_disk',
          'pool': storage.id,
          'volume': '$guestName-$target.${format == 'qcow2' ? 'qcow2' : 'img'}',
          'gib': gib,
          'format': format,
          'target': target,
          'bus': bus,
        };
      case VirtHwAttachVolume(:final volume):
        final path = volume.path;
        if (path == null) {
          throw VirtErr(
            type: VirtErrType.unsupported,
            message: 'No path for ${volume.name}',
          );
        }
        final taken = {
          for (final d in [...config.disks, ...?live?.disks]) d.target,
        };
        final bus = config.disks
                .where((d) => d.device == 'disk')
                .firstOrNull
                ?.bus ??
            'virtio';
        return {
          'op': 'attach_volume',
          'path': path,
          // What the image is, as the pool read it; an ISO's bytes are raw.
          'format': switch (volume.format) {
            final f? when f != 'iso' && f != 'unknown' => f,
            _ => 'raw',
          },
          'target': _freeTarget(_busPrefix(bus), taken),
          'bus': bus,
        };
      case VirtHwRemoveDisk(:final key, :final deleteVolume):
        final disk = diskIn(config, key) ?? diskIn(live, key);
        // A CD-ROM's image, or a read-only disk, is somebody's media: not
        // deleted here whatever was asked.
        final deletable =
            deleteVolume &&
            disk != null &&
            disk.device == 'disk' &&
            !disk.readonly &&
            disk.sourceType == 'file';
        return {
          'op': 'remove_disk',
          'target': key,
          'delete_path': deletable ? disk.source : null,
          'config': diskIn(config, key) != null,
          'live': diskIn(live, key) != null,
        };
      case VirtHwAddCdrom(:final media):
        final taken = {
          for (final d in [...config.disks, ...?live?.disks]) d.target,
        };
        // Where the machine has a controller for one: SATA on q35, IDE on
        // `pc`.
        final bus = (config.machine ?? '').contains('q35') ? 'sata' : 'ide';
        final path = media?.path;
        if (media != null && path == null) {
          throw VirtErr(
            type: VirtErrType.unsupported,
            message: 'No path for ${media.name}',
          );
        }
        return {
          'op': 'add_cdrom',
          'target': _freeTarget(_busPrefix(bus), taken),
          'bus': bus,
          'source': path,
        };
      case VirtHwSetMedia(:final key, :final media):
        final path = media?.path;
        bool touches(LibvirtHwConfig? c) {
          final d = diskIn(c, key);
          // Ejecting an empty drive is refused; there is nothing to do.
          return d != null && (path != null || d.source != null);
        }
        return {
          'op': 'set_media',
          'target': key,
          'source': path,
          'config': touches(config),
          'live': touches(live),
        };
      case VirtHwAddNic(:final network, :final model):
        return {
          'op': 'add_nic',
          'kind': 'network',
          'source': network.name,
          'model': model ?? 'virtio',
          'mac': mac(),
        };
      case VirtHwRemoveNic(:final key):
        return {
          'op': 'remove_nic',
          'mac': key,
          'kind': nicIn(config, key)?.kind,
          'live_kind': nicIn(live, key)?.kind,
        };
      case VirtHwUpdateNic(:final key, :final network, :final linkUp):
        final c = nicIn(config, key);
        final l = nicIn(live, key);
        final current = c ?? l;
        return {
          'op': 'update_nic',
          'mac': key,
          'kind': network != null ? 'network' : current?.kind,
          'source': network?.name ?? current?.source,
          'model': current?.model,
          'link_up': linkUp,
          'boot_order': c?.bootOrder,
          'live_boot_order': l?.bootOrder,
          'config': c != null,
          'live': l != null,
        };
      case VirtHwSetBoot(:final order):
        return {'op': 'boot', 'order': order};
      case VirtHwSetAutostart(:final on):
        return {'op': 'autostart', 'on': on};
      case VirtHwSetDescription(:final text):
        return {'op': 'description', 'text': text};
      case VirtHwSetName(:final name):
        return {'op': 'rename', 'name': name};
      case VirtHwUpdateDisk(:final key, :final bus, :final cache):
        String? to;
        if (bus != null && bus != diskIn(config, key)?.bus) {
          final taken = {
            for (final d in [...config.disks, ...?live?.disks]) d.target,
          };
          to = _freeTarget(_busPrefix(bus), taken);
        }
        return {
          'op': 'update_disk',
          'target': key,
          'new_target': to,
          'bus': to == null ? null : bus,
          'cache': cache,
        };
      case VirtHwSetNicHardware(:final key, :final model, :final mac):
        return {
          'op': 'update_nic_hardware',
          'mac': key,
          'new_mac': mac?.toLowerCase(),
          'model': model,
        };
      case VirtHwSetFirmware(:final uefi, :final secureBoot):
        return {'op': 'firmware', 'efi': uefi, 'secure_boot': uefi && secureBoot};
      case VirtHwSetDisplay(:final protocol, :final listen, :final gpu):
        return {'op': 'display', 'graphics': protocol, 'listen': listen, 'video': gpu};
      case VirtHwAddDevice(:final kind, :final host):
        return {
          'op': 'add_device',
          'device': switch (kind) {
            VirtHwDeviceKind.tpm => {'kind': 'tpm', 'model': 'tpm-crb'},
            VirtHwDeviceKind.usb => {
              'kind': 'usb',
              'vendor': host!.id.split(':').first,
              'product': host.id.split(':').last,
            },
            VirtHwDeviceKind.pci => {'kind': 'pci', 'address': host!.id},
          },
        };
      case VirtHwRemoveDevice(:final key):
        return {'op': 'remove_device', 'key': key};
      case VirtHwSetProtection() || VirtHwRevert():
        throw const VirtErr(type: VirtErrType.unsupported);
    }
  }

  /// Where a bus's disks are named: `vd` for virtio, `hd` for IDE, `sd`
  /// for the rest.
  static String _busPrefix(String bus) => switch (bus) {
    'virtio' => 'vd',
    'ide' => 'hd',
    _ => 'sd',
  };

  /// The host's USB and PCI devices (`nodedev-list`), for giving one to a
  /// guest. See `sbm_parser::virt::host_devices_script`.
  @override
  Future<VirtHostDevices> hostDevices(VirtGuest guest) async {
    final d = LibvirtHostDevices.fromJson(
      _decode(
        await _run(ffi.virtHostDevicesScript(), ffi.parseVirtHostDevicesJson),
      ),
    );
    String name(String? vendor, String? product, String fallback) {
      final n = [vendor, product].nonNulls.join(' ').trim();
      return n.isEmpty ? fallback : n;
    }

    return VirtHostDevices(
      iommu: d.iommu,
      usb: [
        for (final u in d.usb)
          // Root hubs are the host's own, never anyone's to pass through.
          if (u.vendor != '1d6b')
            VirtHostDevice(
              id: '${u.vendor}:${u.product}',
              label: name(u.vendorName, u.productName, '${u.vendor}:${u.product}'),
              detail: '${u.vendor}:${u.product}',
            ),
      ],
      pci: [
        for (final p in d.pci)
          VirtHostDevice(
            id: p.address,
            label: name(p.vendorName, p.productName, p.address),
            detail: p.address,
            iommuGroup: p.iommuGroup,
            groupSize: p.groupSize,
          ),
      ],
    );
  }

  /// `vda`, `vdb`, … `vdz`, then `vdaa`, as libvirt names disks.
  static String _freeTarget(String prefix, Set<String> taken) {
    String name(int i) {
      const a = 97;
      return i < 26
          ? '$prefix${String.fromCharCode(a + i)}'
          : '$prefix${String.fromCharCode(a + i ~/ 26 - 1)}${String.fromCharCode(a + i % 26)}';
    }

    for (var i = 0; i < 26 * 27; i++) {
      if (!taken.contains(name(i))) return name(i);
    }
    throw const VirtErr(type: VirtErrType.unsupported, message: 'No free disk target');
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
      ffi.VirtErrorKind.conflict => VirtErrType.conflict,
      // `exists` too: a snapshot name taken is the action refused, with the
      // host's words. Creating a guest tells it apart itself.
      ffi.VirtErrorKind.domainNotFound ||
      ffi.VirtErrorKind.invalidState ||
      ffi.VirtErrorKind.exists ||
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

/// What one upload attempt came to.
enum _Streamed { done, cancelled, notStarted }
