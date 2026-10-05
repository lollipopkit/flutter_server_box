import 'dart:async';
import 'dart:convert';

import 'package:fl_lib/fl_lib.dart';
import 'package:meta/meta.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:server_box/core/utils/local_server.dart';
import 'package:server_box/core/utils/privileged_exec.dart';
import 'package:server_box/core/utils/ssh_exec.dart';
import 'package:server_box/core/utils/sudo_password.dart';
import 'package:server_box/data/model/app/error.dart';
import 'package:server_box/data/model/server/server_exec.dart';
import 'package:server_box/data/model/virt/libvirt.dart';
import 'package:server_box/data/model/virt/virt.dart';
import 'package:server_box/data/model/virt/virt_backup.dart';
import 'package:server_box/data/model/virt/virt_backup_schedule.dart';
import 'package:server_box/data/model/virt/virt_console.dart';
import 'package:server_box/data/model/virt/virt_create.dart';
import 'package:server_box/data/model/virt/virt_detail.dart';
import 'package:server_box/data/model/virt/virt_hardware.dart';
import 'package:server_box/data/model/virt/virt_manage.dart';
import 'package:server_box/data/model/virt/virt_resources.dart';
import 'package:server_box/data/model/virt/virt_rust.dart';
import 'package:server_box/data/provider/server/single.dart';
import 'package:server_box/data/provider/virt/backend.dart';
import 'package:server_box/src/rust/api/create.dart' as cr;
import 'package:server_box/src/rust/api/hardware.dart' as hw;
import 'package:server_box/src/rust/api/pve.dart' show PveError;
import 'package:server_box/src/rust/api/resource.dart' as res;
import 'package:server_box/src/rust/api/script.dart' as script_ffi;
import 'package:server_box/src/rust/api/virt.dart' as ffi;

/// libvirt through `virsh`, run by `ServerNotifier.ensureExec()` — so over
/// SSH, over a monitor agent with the `full_access` grant, or on this device.
///
/// Scripts and parsers are `sbm_virt::libvirt`'s (FFI). Every script is POSIX
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
    Future<String?> Function()? knownSudoPassword,
    void Function()? onSudoRejected,
    @visibleForTesting this.seedTools,
    @visibleForTesting this.uploadReadyTimeout = const Duration(seconds: 60),
  }) : _exec = exec,
       _byteExec = byteExec,
       _canStream = canStream,
       _knownSudoPassword = knownSudoPassword,
       _onSudoRejected = onSudoRejected,
       _now = now ?? DateTime.now;

  /// The ISO tools a cloud-init seed may be made with, in order; null: all
  /// of them, in `sbm_virt`'s order. The end-to-end tests narrow it to
  /// make a seed with each tool in turn.
  final List<String>? seedTools;

  /// How long the upload command may take to say it is ready: a shell,
  /// sudo and `read` — seconds at most.
  final Duration uploadReadyTimeout;

  /// Uploads go over whatever of the server carries bytes: its SSH
  /// connection, whichever transport leads for everything else, or this
  /// device's own process.
  factory LibvirtBackend.of(Ref ref, String serverId) {
    bool local() => ref.read(serverProvider(serverId)).spi.local;
    return LibvirtBackend(
      serverId: serverId,
      exec: () => ref.read(serverProvider(serverId).notifier).ensureExec(),
      knownSudoPassword: () => SudoPassword.known(serverId),
      onSudoRejected: () => SudoPassword.forget(serverId),
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
  /// Each guest's last counters, which the next load's usage is diffed
  /// against (`sbm_virt::libvirt::host`).
  final _rates = ffi.LibvirtRates();

  /// This account reaches the daemon only through sudo.
  bool _viaSudo = false;
  String? _sudoPassword;

  /// The sudo password known before this backend asks: one typed for this
  /// server elsewhere this session, or saved with it (`SudoPassword`).
  final Future<String?> Function()? _knownSudoPassword;

  /// Told when sudo refused the password, so it is not offered again.
  final void Function()? _onSudoRejected;
  bool _knownSudoRead = false;

  void _forgetSudoPassword() {
    _sudoPassword = null;
    _onSudoRejected?.call();
  }

  bool get needsSudo => _viaSudo;

  /// The pool types the daemon has a backend for, read once
  /// (`pool-capabilities`); null until read, or where the host could not
  /// say (every type is offered then).
  List<String>? _poolTypes;
  bool _poolTypesRead = false;

  /// [_poolTypes], read on the first [load] that gets this far. A daemon
  /// that gains a backend (LVM installed, the daemon restarted) is seen by
  /// a new backend: this one keeps what it read.
  Future<void> _readPoolTypes() async {
    if (_poolTypesRead) return;
    try {
      _poolTypes = await _run(
        ffi.virtPoolTypesScript(),
        ({required String raw}) async => ffi.parseVirtPoolTypes(raw: raw),
      );
      _poolTypesRead = true;
    } on VirtErr catch (e, s) {
      Loggers.app.info('Virtualization pool capabilities: $e', e, s);
    }
  }

  /// The sudo password for this server, typed by the user after
  /// [VirtErrType.sudoPasswordRequired]. Kept in memory for this backend's
  /// life, and by `SudoPassword` for the session (the provider's
  /// `provideSudoPassword`); a rejected one is forgotten by both.
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
    // Parsed here as well as by [_rates] below: the parse is what tells a
    // refusal [_run] answers with sudo from a listing.
    final raw = await _run(ffi.virtOverviewScript(), ({required String raw}) async {
      await ffi.parseVirtOverviewJson(raw: raw);
      return raw;
    });
    final at = _now();
    await _readPoolTypes();
    final String json;
    try {
      json = _rates.view(
        raw: raw,
        atMs: at.millisecondsSinceEpoch,
        poolTypes: _poolTypes,
        upload: _byteExec != null && (_canStream?.call() ?? false),
      );
    } on ffi.VirtFfiError catch (e) {
      throw _toErr(e);
    }
    return VirtRust.snapshot(jsonDecode(json), serverId: serverId);
  }

  @override
  Future<void> power(VirtGuest guest, VirtPowerAction action) async {
    // A crashed domain's start is a destroy first (`sbm_virt::libvirt::host`).
    final plan = ffi.virtLibvirtPowerPlan(
      stateReason: guest.stateReason,
      offered: [for (final a in guest.actions) _kindOf(a)],
      action: _kindOf(action),
    );
    if (plan == null) {
      throw VirtErr(
        type: VirtErrType.unsupported,
        message: '${action.name} is not offered for ${guest.name}',
      );
    }
    for (final (i, step) in plan.indexed) {
      try {
        await _action(step, guest.id);
      } on VirtErr catch (e) {
        // The destroy before a crashed domain's start: already gone.
        final gone =
            plan.length > 1 &&
            i == 0 &&
            e.cause is ffi.VirtFfiError &&
            (e.cause as ffi.VirtFfiError).kind == ffi.VirtErrorKind.invalidState;
        if (!gone) rethrow;
      }
    }
  }

  static ffi.VirtActionKind _kindOf(VirtPowerAction action) => switch (action) {
    VirtPowerAction.start => ffi.VirtActionKind.start,
    VirtPowerAction.shutdown => ffi.VirtActionKind.shutdown,
    VirtPowerAction.reboot => ffi.VirtActionKind.reboot,
    VirtPowerAction.forceStop => ffi.VirtActionKind.forceStop,
    VirtPowerAction.suspend => ffi.VirtActionKind.suspend,
    VirtPowerAction.resume => ffi.VirtActionKind.resume,
  };

  Future<void> _action(ffi.VirtActionKind kind, String domain) async {
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
  Future<VirtGuestDetail> detail(VirtGuest guest) async => VirtRust.detail(
    _decode(
      await _run(
        ffi.virtDomainDetailScript(domain: guest.id),
        ({required String raw}) async => ffi.virtLibvirtGuestDetail(raw: raw),
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
  Future<List<VirtGuestSnapshot>> snapshots(VirtGuest guest) async =>
      VirtRust.snapshots(jsonDecode(await _snapshotsJson(guest)));

  Future<String> _snapshotsJson(VirtGuest guest) => _run(
    ffi.virtSnapshotsScript(domain: guest.id),
    ({required String raw}) async => ffi.virtLibvirtSnapshots(raw: raw),
  );

  /// The raw chain read (`snap_chain_script`), checked as it is read.
  Future<String> _chainRaw(VirtGuest guest) => _run(
    ffi.virtSnapChainScript(domain: guest.id),
    ({required String raw}) async {
      await ffi.parseVirtSnapChainJson(raw: raw);
      return raw;
    },
  );

  /// The disk chain, each layer named for the snapshot that left the guest
  /// on it, and the pools an overlay can go in
  /// (`sbm_virt::libvirt::host::chain_of`). Three reads: the chain, the
  /// snapshots, and the pools, which the Storage view reads anyway.
  @override
  Future<VirtSnapChain> snapshotChain(VirtGuest guest) async {
    final raw = await _chainRaw(guest);
    final snaps = await _snapshotsJson(guest);
    List<VirtStoragePool> pools;
    try {
      pools = await storagePools();
    } on VirtErr catch (e) {
      Loggers.app.info('libvirt pools for a snapshot overlay: ${e.message}');
      pools = const [];
    }
    try {
      return VirtRust.chain(
        jsonDecode(
          ffi.virtLibvirtChain(
            chainRaw: raw,
            snapshotsJson: snaps,
            pools: [for (final p in pools) virtPoolRef(p)],
          ),
        ),
      );
    } on ffi.VirtFfiError catch (e) {
      throw _toErr(e);
    }
  }

  /// libvirt has nothing to ask: whether a snapshot can be taken is what the
  /// chain's own read says (a disk QEMU opened as raw). A disk the read could
  /// not open refuses only the external form ([VirtSnapChain.externalRefusal]).
  @override
  Future<bool?> snapshotSupported(VirtGuest guest) async =>
      (await snapshotChain(guest)).refusal == null;

  @override
  Future<String?> snapshotRefusal(VirtGuest guest) async =>
      (await snapshotChain(guest)).refusal;

  /// `snapshot-dumpxml`'s `<domain>` against `dumpxml --inactive`, in one
  /// round trip. Only what the view can name is listed (processor, memory,
  /// disks, interfaces, firmware, boot); a device's address, alias and the
  /// file it currently sits on are left out, since libvirt writes those
  /// itself rather than anyone configuring them.
  @override
  Future<List<VirtSnapDiff>> snapshotDiff(VirtGuest guest, String name) async {
    final json = await _run(
      ffi.virtSnapDiffScript(domain: guest.id, name: name),
      ffi.parseVirtSnapDiffJson,
    );
    return [
      for (final d in _decodeList(json))
        VirtSnapDiff(
          group: switch (LibvirtSnapDiff.fromJson(d).group) {
            'cpu' => VirtSnapDiffGroup.cpu,
            'memory' => VirtSnapDiffGroup.memory,
            'disks' => VirtSnapDiffGroup.disks,
            'interfaces' => VirtSnapDiffGroup.nics,
            'firmware' => VirtSnapDiffGroup.firmware,
            'boot' => VirtSnapDiffGroup.boot,
            _ => VirtSnapDiffGroup.other,
          },
          key: LibvirtSnapDiff.fromJson(d).key,
          before: LibvirtSnapDiff.fromJson(d).before,
          after: LibvirtSnapDiff.fromJson(d).after,
        ),
    ];
  }

  /// An internal snapshot: with the memory of an active domain, which QEMU
  /// insists on, so [memory] changes nothing; disks only for a shut-off one.
  /// Every writable disk must be qcow2 — libvirt's refusal says which is not.
  ///
  /// [form] `external` writes a disk-only one instead: an overlay per disk
  /// (in [overlayPool] where one was picked), the guest left running. What
  /// that means for the chain is `sbm_virt::libvirt::snapshot`'s module
  /// comment; the guard is read before anything is sent.
  @override
  Future<void> createSnapshot(
    VirtGuest guest, {
    required String name,
    String? description,
    bool memory = false,
    VirtSnapshotForm form = VirtSnapshotForm.internal,
    String? overlayPool,
  }) async {
    _checkName(name);
    if (form == VirtSnapshotForm.internal) {
      await _action1(
        ffi.virtSnapshotCreateScript(
          domain: guest.id,
          name: name,
          description: description,
        ),
      );
      return;
    }
    // One read of the chain answers both: whether an external snapshot can
    // be taken, and the files the overlays go on.
    final raw = await _chainRaw(guest);
    final why = ffi.virtExternalSnapshotRefusal(
      chainJson: await ffi.parseVirtSnapChainJson(raw: raw),
    );
    if (why != null) {
      throw VirtErr(type: VirtErrType.unsupported, message: why);
    }
    // Where the overlays go. **No pool picked: no `--diskspec` at all** —
    // libvirt then names each overlay `<disk>.<snapshot>` beside the disk it
    // backs. A pool the user picked is resolved to its directory once.
    final dir = overlayPool == null ? null : await _poolTarget(overlayPool);
    final overlays = [
      for (final o in ffi.virtLibvirtOverlays(
        chainRaw: raw,
        name: name,
        dir: dir,
      ))
        (o.target, o.path),
    ];
    await _action1(
      ffi.virtSnapshotExternalScript(
        domain: guest.id,
        name: name,
        description: description,
        overlays: overlays,
      ),
    );
  }

  /// Where a pool keeps its files: its target directory, from the listing
  /// the Storage view already reads. Only an active pool of files
  /// ([virtPoolHoldsFiles]): a pool of block devices has a `/dev/...` target,
  /// and a file written there is not in the pool.
  Future<String> _poolTarget(String pool) async {
    final pools = await storagePools();
    final found = pools.firstWhereOrNull((p) => p.name == pool);
    final path = found?.path;
    if (found == null || path == null || !virtPoolHoldsFiles(found)) {
      throw VirtErr(
        type: VirtErrType.unsupported,
        message: 'Pool $pool has no directory an overlay can go in',
      );
    }
    return path;
  }

  /// Refused before it is sent where the revert would leave the guest
  /// unable to start (`snap_revert_refusal`: an AppArmor host whose helper
  /// cannot read the new overlay libvirt names without an extension) — the
  /// host would fail it after deleting the overlay the guest runs on.
  @override
  Future<void> revertSnapshot(
    VirtGuest guest,
    String name, {
    bool start = false,
  }) async {
    final why = await _run(
      ffi.virtSnapCheckScript(domain: guest.id, name: name),
      ffi.parseVirtSnapRevertRefusal,
    );
    if (why != null) {
      throw VirtErr(type: VirtErrType.unsupported, message: why);
    }
    await _action1(
      ffi.virtSnapshotRevertScript(domain: guest.id, name: name, running: start),
    );
  }

  /// Refused before it is sent where the host's AppArmor profile would deny
  /// the commit it needs (`snap_delete_refusal`): the host would refuse it
  /// too, and then refuse every later delete on that disk.
  ///
  /// A snapshot on a branch the guest left (a revert to an internal
  /// snapshot taken before it) is deleted by libvirt without its overlays,
  /// which nothing names afterwards (`snap_delete_leftovers`): they are
  /// deleted with it, in the same round trip.
  @override
  Future<void> deleteSnapshot(VirtGuest guest, String name) async {
    final check = await _run(
      ffi.virtSnapCheckScript(domain: guest.id, name: name),
      ({required String raw}) async => (
        refusal: await ffi.parseVirtSnapDeleteRefusal(raw: raw),
        leftovers: await ffi.parseVirtSnapDeleteLeftovers(raw: raw),
      ),
    );
    if (check.refusal case final why?) {
      throw VirtErr(type: VirtErrType.unsupported, message: why);
    }
    final leftovers = check.leftovers;
    final all = leftovers.isEmpty ? const <VirtStoragePool>[] : await storagePools();
    final pools = {for (final f in leftovers) ?virtPoolOfFile(all, f)?.name};
    await _run(
      _script(
        () => ffi.virtSnapshotDeleteScript(
          domain: guest.id,
          name: name,
          pools: pools.toList(),
          leftovers: leftovers,
        ),
      ),
      ({required String raw}) async {
        await ffi.parseVirtSnapshotDelete(raw: raw);
        return '';
      },
      action: true,
    );
  }

  static void _checkName(String name) {
    if (virtSnapshotNameIssue(name, const []) != null) {
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

  /// What a new domain can be given (`sbm_virt::libvirt::create::options_of`):
  /// `domcapabilities` for the machine it gets and QEMU's firmware
  /// descriptors, read per call — two round trips, and a host's firmware
  /// does not change under a running app.
  @override
  Future<VirtCreateOptions> createOptions() async {
    final (host, firmware) = await _createHost();
    return VirtRust.createOptions(
      jsonDecode(_rule(() => cr.virtLibvirtCreateOptions(hostJson: host, firmwareJson: firmware))),
    );
  }

  /// `domcapabilities` (`VirtCreateHost` JSON) and the firmware descriptors
  /// (best effort: without them, Secure Boot is not offered).
  Future<(String, String)> _createHost() async {
    final host = await _run(ffi.virtCreateHostScript(), ffi.parseVirtCreateHostJson);
    var firmware = '[]';
    try {
      firmware = await _run(ffi.virtFirmwareScript(), ffi.parseVirtFirmwareJson);
    } catch (e, s) {
      Loggers.app.info('Virtualization firmware descriptors: $e', e, s);
    }
    return (host, firmware);
  }

  /// A rule or a mapping of `sbm_virt`'s, its refusal as a [VirtErr].
  static T _rule<T>(T Function() f) {
    try {
      return f();
    } on PveError catch (e) {
      throw VirtRust.error(e);
    }
  }

  /// Three steps: what the host runs a domain as, the disk — empty, or a
  /// copy of a cloud image — and a cloud-init seed with their paths, then
  /// the domain on them, defined and started when asked. `sbm_virt` checks
  /// the spec against what the host lists now and writes each step
  /// (`sbm_virt::libvirt::create::spec_of`); a cloud-init password reaches
  /// the host as its hash only. A define the host refuses deletes the
  /// volumes again.
  @override
  Future<VirtCreated> create(VirtCreateSpec spec) async {
    final (host, firmware) = await _createHost();
    final guests = (await load()).guests;
    final pools = await storagePools();
    final networks = await this.networks();
    // The volumes the spec names, as their pools list them now.
    Future<String?> volume(VirtPoolVolume? v) async {
      if (v == null) return null;
      final pool = pools.firstWhereOrNull((p) => p.id == v.pool.id);
      if (pool == null) return null;
      final now = (await _volumes(pool)).$1.firstWhereOrNull((x) => x.id == v.volume.id);
      return now == null ? null : jsonEncode(VirtRust.volumeJson(now));
    }
    final mediaJson = await volume(spec.media);
    final imageJson = await volume(spec.image);
    final lvSpec = _rule(
      () => cr.virtLibvirtCreateSpec(
        specJson: jsonEncode(VirtRust.specJson(spec)),
        hostJson: host,
        firmwareJson: firmware,
        guestsJson: jsonEncode([for (final g in guests) VirtRust.guestJson(g)]),
        poolsJson: jsonEncode([for (final p in pools) VirtRust.poolJson(p)]),
        networksJson: jsonEncode([for (final n in networks) VirtRust.networkJson(n)]),
        mediaJson: mediaJson,
        imageJson: imageJson,
        seedTools: seedTools,
      ),
    );
    final String made;
    try {
      made = await _run(
        _script(() => ffi.virtCreateVolumeScript(specJson: lvSpec)),
        ffi.parseVirtCreateVolumesJson,
        action: true,
      );
    } on VirtErr catch (e) {
      throw _existsOr(e);
    }
    final defined = _rule(() => cr.virtLibvirtWithVolumes(specJson: lvSpec, madeJson: made));
    final created = await _run(
      _script(() => ffi.virtDefineScript(specJson: defined)),
      ffi.parseVirtCreateJson,
      action: true,
    );
    return VirtRust.created(
      jsonDecode(_rule(() => cr.virtLibvirtCreated(specJson: defined, madeJson: made, createdJson: created))),
    );
  }

  /// Snapshots' metadata and a managed save go with it; with [removeDisks]
  /// what `sbm_virt::libvirt::create::delete_plan` decides from what is read
  /// here first: the volumes of its writable disks no other domain has and
  /// nothing is made on, its NVRAM, its own cloud-init seed, and the files
  /// its external snapshots left under those disks. Refused while it runs:
  /// `undefine` would leave it running, transient.
  @override
  Future<void> delete(VirtGuest guest, {bool removeDisks = true}) async {
    if (guest.state != VirtGuestState.stopped) {
      throw VirtErr(
        type: VirtErrType.unsupported,
        message: virtCreateIssueText(VirtCreateIssue.notStopped),
      );
    }
    var plan = const cr.VirtDeletePlan(targets: [], pools: [], files: [], kept: []);
    if (removeDisks) {
      final detail = await _run(
        ffi.virtDomainDetailScript(domain: guest.id),
        ffi.parseVirtDomainDetailJson,
      );
      final pools = await storagePools();
      final storage = _storageJson!;
      final volumes = [
        for (final p in pools)
          if (p.active)
            [p.id, [for (final v in (await _volumes(p)).$1) VirtRust.volumeJson(v)]],
      ];
      final snapshots = await _snapshotsJson(guest);
      final chain = _rule(() => cr.virtLibvirtDeleteNeedsChain(snapshotsJson: snapshots))
          ? await _chainRaw(guest)
          : null;
      plan = _rule(
        () => cr.virtLibvirtDeletePlan(
          id: guest.id,
          name: guest.name,
          detailJson: detail,
          storageJson: storage,
          volumesJson: jsonEncode(volumes),
          snapshotsJson: snapshots,
          chainRaw: chain,
        ),
      );
      for (final kept in plan.kept) {
        Loggers.app.warning('Deleting ${guest.name}: $kept');
      }
    }
    await _run(
      _script(
        () => ffi.virtUndefineScript(
          domain: guest.id,
          storage: plan.targets,
          seed: plan.seed,
          pools: plan.pools,
          chain: plan.files,
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
  /// in the pool its source is in — or in [VirtCloneRequest.targetPool] —
  /// then the copy defined on those volumes: a new UUID and MACs, its own
  /// UEFI variables file. Either step failing deletes the volumes it made.
  /// `sbm_virt::libvirt::create::clone_spec_of` checks the request and
  /// reads the disks from the definition read here.
  @override
  Future<String> clone(VirtGuest guest, VirtCloneRequest request) async {
    if (guest.state != VirtGuestState.stopped) {
      throw VirtErr(
        type: VirtErrType.unsupported,
        message: virtCreateIssueText(VirtCreateIssue.notStopped),
      );
    }
    final hardware = await _hardwareRead(guest);
    final guests = (await load()).guests;
    await storagePools();
    final spec = _rule(
      () => cr.virtLibvirtCloneSpec(
        guestJson: jsonEncode(VirtRust.guestJson(guest)),
        hardwareJson: hardware,
        requestJson: jsonEncode(VirtRust.cloneRequestJson(request)),
        guestsJson: jsonEncode([for (final g in guests) VirtRust.guestJson(g)]),
        storageJson: _storageJson!,
      ),
    );
    final List<String> paths;
    try {
      paths = [
        for (final p in jsonDecode(
          await _run(
            _script(() => ffi.virtCloneVolumesScript(specJson: spec)),
            ({required String raw}) async => jsonEncode(await ffi.parseVirtCloneVolumes(raw: raw)),
            action: true,
          ),
        ) as List)
          p as String,
      ];
    } on VirtErr catch (e) {
      throw _existsOr(e);
    }
    final created = _decode(
      await _run(
        _script(
          () => ffi.virtCloneDefineScript(
            baseXml: _decode(hardware)['config_xml'] as String,
            name: request.name,
            disksJson: _rule(() => cr.virtLibvirtCloneDisks(specJson: spec, paths: paths)),
          ),
        ),
        ffi.parseVirtCreateJson,
        action: true,
      ),
    );
    return created['uuid'] as String? ?? request.name;
  }

  /// libvirt has no templates: a domain is a domain, and a copy of one is a
  /// clone. Only `VirtCapabilities.template` (PVE) reaches this.
  @override
  Future<void> makeTemplate(VirtGuest guest) async =>
      throw const VirtErr(type: VirtErrType.unsupported);

  static Never _noBackups() => throw const VirtErr(type: VirtErrType.unsupported);

  @override
  Future<List<VirtBackup>> backups(VirtGuest guest) async => _noBackups();

  @override
  Future<List<VirtBackupJob>> backupJobs(VirtGuest guest) async => const [];

  @override
  Future<List<VirtBackupJob>> allBackupJobs() async => const [];

  @override
  Future<void> editBackupJob(
    VirtBackupJobEdit edit, {
    bool remove = false,
  }) async => _noBackups();

  @override
  Future<VirtScheduleCheck> checkSchedule(String schedule) async =>
      _noBackups();

  @override
  Future<List<VirtStoragePool>> backupStorages(VirtGuest guest) async =>
      const [];

  @override
  Future<List<VirtStoragePool>> allBackupStorages() async => const [];

  @override
  Future<void> backup(VirtGuest guest, VirtBackupRequest request) async =>
      _noBackups();

  @override
  Future<void> runBackupJob(VirtBackupJob job) async => _noBackups();

  @override
  Future<void> restoreBackup(
    VirtGuest guest,
    VirtBackup backup, {
    int? vmid,
    String? storage,
  }) async => _noBackups();

  @override
  Future<void> editBackup(VirtBackup backup, VirtBackupEdit edit) async =>
      _noBackups();

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
  /// domain's disks, which [volumes] needs and does not list again — as
  /// `sbm_virt` gave it, and read.
  LibvirtStorage? _storage;
  String? _storageJson;

  @override
  Future<List<VirtStoragePool>> storagePools() async {
    final json = await _run(ffi.virtStorageScript(), ffi.parseVirtStorageJson);
    _storage = LibvirtStorage.fromJson(_decode(json));
    _storageJson = json;
    return VirtRust.pools(jsonDecode(res.virtLibvirtPools(storageJson: json)));
  }

  /// `vol-dumpxml` for each volume the last [storagePools] listed in [pool]
  /// (listed again when there is none), with the domains whose disks are
  /// those volumes and the volumes made on each, in any active pool.
  ///
  /// A volume libvirt lists but cannot read (its file removed behind
  /// libvirt's back: `vol-list` answers from the pool's cache, `vol-dumpxml`
  /// says "Storage volume not found") means the pool's list is stale: the
  /// pool is refreshed (`pool-refresh`, what libvirt does at its own start)
  /// and read again, once, so the count the pool shows and the volumes
  /// listed agree.
  @override
  Future<List<VirtVolume>> volumes(VirtStoragePool pool) async {
    var pools = await _pools();
    var (read, missing) = await _volumes(pool);
    if (missing && pool.active) {
      await _run(
        _script(
          () => ffi.virtResourceScript(
            opJson: jsonEncode({'op': 'pool_refresh', 'name': pool.id}),
          ),
        ),
        _parseResource,
        action: true,
      );
      pools = await storagePools();
      (read, _) = await _volumes(pool);
    }
    // What is made on each: a base image is attached to nothing, and its
    // clones may be in another pool.
    final every = [...read];
    for (final p in pools) {
      if (p.id == pool.id || !p.active) continue;
      every.addAll((await _volumes(p)).$1);
    }
    return VirtRust.volumes(
      jsonDecode(
        res.virtLibvirtWithBacks(
          volumesJson: jsonEncode([for (final v in read) VirtRust.volumeJson(v)]),
          everyJson: jsonEncode([for (final v in every) VirtRust.volumeJson(v)]),
        ),
      ),
    );
  }

  /// The pools as the last listing has them, listed when there is none.
  Future<List<VirtStoragePool>> _pools() async {
    final json = _storageJson;
    if (json == null) return storagePools();
    return VirtRust.pools(jsonDecode(res.virtLibvirtPools(storageJson: json)));
  }

  /// [pool]'s volumes as the last listing has them, and whether one of them
  /// did not read.
  Future<(List<VirtVolume>, bool)> _volumes(VirtStoragePool pool) async {
    if (_storageJson == null) await storagePools();
    final storageJson = _storageJson!;
    final listed = _storage!.pools
        .firstWhereOrNull((p) => p.name == pool.id)
        ?.volumes;
    if (listed == null || listed.isEmpty) return (const <VirtVolume>[], false);
    final json = await _run(
      ffi.virtVolumesScript(
        pool: pool.id,
        names: [for (final v in listed) v.name],
      ),
      ({required String raw}) async => res.virtLibvirtVolumes(
        raw: raw,
        pool: pool.id,
        storageJson: storageJson,
      ),
    );
    final read = VirtRust.volumes(jsonDecode(json));
    return (read, read.length < listed.length);
  }

  @override
  Future<List<VirtNetwork>> networks() async => VirtRust.networks(
    jsonDecode(
      await _run(
        ffi.virtNetworksScript(),
        ({required String raw}) async => res.virtLibvirtNetworks(raw: raw),
      ),
    ),
  );

  // ---------------------------------------------------------------------------
  // Managing storage and networks
  // ---------------------------------------------------------------------------

  /// Checked against what the host lists now, then made
  /// (`sbm_virt::libvirt::host::resource_script`): an existing network's
  /// edit is its own script (`sbm_virt::libvirt::net`), which rewrites the
  /// definition and, when told to, restarts the network on it, with the
  /// rollback that keeps it up.
  @override
  Future<void> manage(VirtResourceChange change) async {
    try {
      final network = change.scope == 'nets' || change.scope.startsWith('net:');
      final pools = network ? const <VirtStoragePool>[] : await storagePools();
      final pool = switch (change) {
        VirtPoolSetActive(:final pool) ||
        VirtPoolDelete(:final pool) ||
        VirtVolumeCreate(:final pool) ||
        VirtVolumeDelete(:final pool) ||
        VirtVolumeResize(:final pool) ||
        VirtVolumeClone(:final pool) => pools.firstWhereOrNull((p) => p.id == pool.id),
        _ => null,
      };
      final volumes = pool == null ? const <VirtVolume>[] : await this.volumes(pool);
      final networks = network ? await this.networks() : const <VirtNetwork>[];
      final res.VirtResourceScript script;
      try {
        script = res.virtLibvirtResourceScript(
          changeJson: jsonEncode(VirtRust.changeJson(change)),
          poolsJson: jsonEncode([for (final p in pools) VirtRust.poolJson(p)]),
          networksJson: jsonEncode([for (final n in networks) VirtRust.networkJson(n)]),
          volumesJson: jsonEncode([for (final v in volumes) VirtRust.volumeJson(v)]),
        );
      } on PveError catch (e) {
        throw VirtRust.error(e);
      }
      await _run(
        script.script,
        script.net ? _parseNetChange : _parseResource,
        action: true,
      );
    } on VirtErr catch (e) {
      throw _existsOr(e);
    } finally {
      // What a pool holds, and which, is listed again.
      _storage = null;
      _storageJson = null;
    }
  }

  static Future<String> _parseNetChange({required String raw}) async {
    await ffi.parseVirtNetChange(raw: raw);
    return '';
  }

  static Future<String> _parseResource({required String raw}) async {
    ffi.parseVirtResource(raw: raw);
    return '';
  }

  /// libvirt applies every change as it is made.
  @override
  Future<List<VirtNetworkChanges>> networkChanges() async => const [];

  /// A raw volume of the file's size, then the file into it with
  /// `vol-upload` over a channel that carries bytes (see
  /// `sbm_virt::libvirt::manage::vol_upload_command`): through sudo when
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
      _storageJson = null;
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
            script_ffi.sudoPasswordRejected(stderr: err.toString())) {
          rejected = true;
          if (!ready.isCompleted) ready.complete(false);
          session.kill();
        }
      },
      onDone: errDone.complete,
      onError: (Object _) => errDone.complete(),
    );
    var cancelled = false;
    // Completed on cancel, so a read of the file that waits for its next
    // chunk ends too rather than holding the upload until one arrives.
    final stopped = Completer<bool>();
    unawaited(
      cancel?.then((_) {
        cancelled = true;
        if (!ready.isCompleted) ready.complete(false);
        if (!stopped.isCompleted) stopped.complete(false);
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
    // No ready line within [uploadReadyTimeout]: what it printed by then is
    // no answer, and reading it as one would report a refusal.
    var stalled = false;
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
        onTimeout: () {
          stalled = true;
          return false;
        },
      );
      if (go && !cancelled) {
        var sent = 0;
        final chunks = StreamIterator(upload.open());
        try {
          while (await Future.any([chunks.moveNext(), stopped.future]) &&
              !cancelled) {
            final chunk = chunks.current;
            await session.write(chunk);
            sent += chunk.length;
            onProgress?.call(sent);
          }
        } finally {
          // Not awaited: a source stalled mid-read may take its time to let
          // go, and the upload has already ended.
          unawaited(chunks.cancel().catchError((Object _) => null));
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
      _forgetSudoPassword();
      throw const VirtErr(
        type: VirtErrType.sudoPasswordRejected,
        message: 'sudo rejected the password',
      );
    }
    if (stalled) {
      throw VirtErr(
        type: VirtErrType.actionFailed,
        message: 'The upload command was not ready within $uploadReadyTimeout',
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

  @override
  Future<List<VirtStats>?> history(
    VirtGuest guest, {
    VirtHistoryWindow window = VirtHistoryWindow.hour,
  }) async => null;

  @override
  Future<void> reset() async {
    _rates.clear();
    _storage = null;
    _storageJson = null;
  }

  @override
  Future<void> close() async {
    _sudoPassword = null;
    _rates.clear();
    _storage = null;
    _storageJson = null;
  }

  // ---------------------------------------------------------------------------
  // Hardware
  // ---------------------------------------------------------------------------

  /// Both definitions, autostart, the host's CPUs and memory, and each
  /// disk's size, in one round trip, as `sbm_virt` gave them
  /// (`VirtHardwareInfo` JSON, which carries the display passwords and so
  /// stays here). See `sbm_virt::libvirt::hardware_script`.
  Future<String> _hardwareRead(VirtGuest guest) => _run(
    ffi.virtHardwareScript(domain: guest.id),
    ffi.parseVirtHardwareJson,
  );

  /// The persistent definition with what the running one has instead as
  /// pending (`sbm_virt::libvirt::hardware::hardware_of`); its revision is
  /// the definition's SHA-256.
  @override
  Future<VirtHardware> hardware(VirtGuest guest) async {
    final info = await _hardwareRead(guest);
    return VirtRust.hardware(
      jsonDecode(_rule(() => hw.virtLibvirtHardware(infoJson: info, name: guest.name))),
    );
  }

  /// What [change] is checked against and made with: the host's pools, its
  /// networks where a NIC is named, and the volume it names as its pool
  /// lists it now.
  Future<(List<VirtStoragePool>, List<VirtNetwork>, List<VirtVolume>)> _hwListing(
    VirtHwChange change,
  ) async {
    final pools = await storagePools();
    final networks = switch (change) {
      VirtHwAddNic() || VirtHwUpdateNic() => await this.networks(),
      _ => const <VirtNetwork>[],
    };
    final (VirtStoragePool?, VirtVolume?) named = switch (change) {
      VirtHwAttachVolume(:final storage, :final volume) => (storage, volume),
      VirtHwAddCdrom(media: final m?) || VirtHwSetMedia(media: final m?) => (m.pool, m.volume),
      _ => (null, null),
    };
    final volumes = <VirtVolume>[];
    if (named case (final p?, final v?)) {
      final pool = pools.firstWhereOrNull((x) => x.id == p.id);
      if (pool != null) {
        volumes.addAll((await _volumes(pool)).$1.where((x) => x.id == v.id));
      }
    }
    return (pools, networks, volumes);
  }

  /// One `virsh` round trip per change, each made to the persistent
  /// definition and, where the domain runs, to the running one: the running
  /// half failing leaves it for the next start ([VirtHwOutcome.liveError]).
  /// The definitions are read again first, and the change refused when they
  /// are not the ones [base] was read from
  /// (`sbm_virt::libvirt::hardware::change_of`).
  @override
  Future<VirtHwOutcome> changeHardware(
    VirtGuest guest,
    VirtHardware base,
    VirtHwChange change,
  ) async {
    final info = await _hardwareRead(guest);
    final (pools, networks, volumes) = await _hwListing(change);
    final made = _rule(
      () => hw.virtLibvirtHwChange(
        infoJson: info,
        name: guest.name,
        revision: base.revision,
        changeJson: jsonEncode(VirtRust.hwChangeJson(change)),
        poolsJson: jsonEncode([for (final p in pools) VirtRust.poolJson(p)]),
        networksJson: jsonEncode([for (final n in networks) VirtRust.networkJson(n)]),
        volumesJson: jsonEncode([for (final v in volumes) VirtRust.volumeJson(v)]),
      ),
    );
    final read = _decode(info);
    return VirtRust.hwOutcome(
      jsonDecode(
        await _run(
          _script(
            () => ffi.virtHardwareChangeScript(
              domain: guest.id,
              running: read['live'] != null,
              baseXml: read['config_xml'] as String?,
              changeJson: made,
            ),
          ),
          ffi.parseVirtHardwareChangeJson,
          action: true,
        ),
      ),
    );
  }

  /// Discards every pending change: the definition is written again from
  /// the running XML (see [VirtHwRevertPending]), made from [base]'s read.
  @override
  Future<void> revertPending(VirtGuest guest, VirtHardware base) async {
    final info = await _hardwareRead(guest);
    final made = _rule(() => hw.virtLibvirtHwRevert(infoJson: info, revision: base.revision));
    await _run(
      _script(
        () => ffi.virtHardwareChangeScript(
          domain: guest.id,
          running: true,
          baseXml: _decode(info)['config_xml'] as String?,
          changeJson: made,
        ),
      ),
      ({required String raw}) async {
        await ffi.parseVirtHardwareChangeJson(raw: raw);
        return '';
      },
      action: true,
    );
  }

  /// The domain's own seed, read back from its volume (`vol-download`, in
  /// one round trip), with the domain's NICs: the seed is what the system
  /// reads, so it is the source of what is shown.
  Future<({String path, String read, List<String> macs})> _seedRead(VirtGuest guest) async {
    final info = _decode(await _hardwareRead(guest));
    final config = (info['config'] as Map).cast<String, dynamic>();
    final path = config['seed'] as String?;
    if (path == null) {
      throw VirtErr(
        type: VirtErrType.unsupported,
        message: '${guest.name} has no cloud-init seed of this app',
      );
    }
    final read = await _run(
      _script(() => ffi.virtSeedReadScript(seed: path)),
      ffi.parseVirtSeedReadJson,
    );
    final macs = [
      for (final n in (config['nics'] as List? ?? const []).whereType<Map>()) '${n['mac']}',
    ];
    return (path: path, read: read, macs: macs);
  }

  /// The seed as the view shows it: never the hash, only that there is one.
  @override
  Future<VirtCloudInitState> cloudInit(VirtGuest guest) async {
    final seed = await _seedRead(guest);
    return VirtRust.cloudInitState(
      jsonDecode(_rule(() => hw.virtLibvirtCloudInitState(readJson: seed.read, macs: seed.macs))),
    );
  }

  /// A new seed in place of the old, on the same volume (so the domain and
  /// its metadata stay as they are), made from the seed as read now — and
  /// refused as [VirtErrType.conflict] once it changed since [base]'s read.
  /// A new password is hashed in Rust; none keeps the hash the seed has. A
  /// new instance ID, so cloud-init takes it at the next boot.
  @override
  Future<void> setCloudInit(
    VirtGuest guest,
    VirtCloudInitState base,
    VirtCloudInitEdit edit,
  ) async {
    final seed = await _seedRead(guest);
    final ci = _rule(
      () => hw.virtLibvirtCloudInitUpdate(
        readJson: seed.read,
        name: guest.name,
        macs: seed.macs,
        editJson: jsonEncode(VirtRust.cloudInitEditJson(base, edit)),
      ),
    );
    await _run(
      _script(
        () => ffi.virtSeedUpdateScript(
          seed: seed.path,
          revision: base.revision,
          cloudInitJson: ci,
          tools: seedTools,
        ),
      ),
      ({required String raw}) async {
        ffi.parseVirtSeedUpdate(raw: raw);
        return '';
      },
      action: true,
    );
  }

  /// The host's USB and PCI devices (`nodedev-list`), for giving one to a
  /// guest. See `sbm_virt::libvirt::host_devices_script`.
  @override
  Future<VirtHostDevices> hostDevices(VirtGuest guest) async {
    final json = await _run(ffi.virtHostDevicesScript(), ffi.parseVirtHostDevicesJson);
    return VirtRust.hostDevices(jsonDecode(_rule(() => hw.virtLibvirtHostDevices(devicesJson: json))));
  }

  // ---------------------------------------------------------------------------
  // Running scripts
  // ---------------------------------------------------------------------------

  /// Runs [script] and parses its output, going through sudo when the daemon
  /// refuses this account.
  Future<T> _run<T>(
    String script,
    Future<T> Function({required String raw}) parse, {
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

    // Asked once per backend: every call through sudo passes here, and the
    // saved password is behind a rate-limited store.
    if (!_knownSudoRead) {
      _knownSudoRead = true;
      _sudoPassword ??= await _knownSudoPassword?.call();
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
      _forgetSudoPassword();
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

}

/// What one upload attempt came to.
enum _Streamed { done, cancelled, notStarted }
