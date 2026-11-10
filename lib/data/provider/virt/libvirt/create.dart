part of '../libvirt_backend.dart';

/// Creating and deleting guests.
mixin _Create on _LibvirtCore, _Storage, _Snapshots {
  @override
  Future<int?> nextVmid() async => null;

  /// What a new domain can be given (`sbm_virt::libvirt::create::options_of`):
  /// `domcapabilities` for the machine it gets and QEMU's firmware
  /// descriptors, read per call — two round trips, and a host's firmware
  /// does not change under a running app.
  @override
  Future<VirtCreateOptions> createOptions() async {
    final (host, firmware) = await _createHost();
    return cr.virtLibvirtCreateOptions(host: host, firmware: firmware).virt;
  }

  /// `domcapabilities` and the firmware descriptors (best effort: without
  /// them, Secure Boot is not offered).
  Future<(vl.VirtCreateHost, List<vl.FirmwareDescriptor>)> _createHost() async {
    final host = await _run(ffi.virtCreateHostScript(), ffi.virtLibvirtCreateHost);
    var firmware = const <vl.FirmwareDescriptor>[];
    try {
      firmware = await _run(ffi.virtFirmwareScript(), ffi.virtLibvirtFirmware);
    } catch (e, s) {
      Loggers.app.info('Virtualization firmware descriptors: $e', e, s);
    }
    return (host, firmware);
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
    Future<vm.Volume?> volume(VirtPoolVolume? v) async {
      if (v == null) return null;
      final pool = pools.firstWhereOrNull((p) => p.id == v.pool.id);
      if (pool == null) return null;
      final now = (await _volumes(pool)).$1.firstWhereOrNull((x) => x.id == v.volume.id);
      return now?.ffi;
    }
    final media = await volume(spec.media);
    final image = await volume(spec.image);
    final lvSpec = _rule(
      () => cr.virtLibvirtCreateSpec(
        spec: spec.ffi,
        host: host,
        firmware: firmware,
        guests: [for (final g in guests) g.ffi],
        pools: [for (final p in pools) p.ffi],
        networks: [for (final n in networks) n.ffi],
        media: media,
        image: image,
        seedTools: seedTools,
      ),
    );
    final vl.VirtCreateVolumes made;
    try {
      made = await _run(
        _script(() => ffi.virtCreateVolumeScript(spec: lvSpec)),
        ffi.virtLibvirtCreateVolumes,
        action: true,
      );
    } on VirtErr catch (e) {
      throw _existsOr(e);
    }
    final defined = cr.virtLibvirtWithVolumes(spec: lvSpec, made: made);
    final created = await _run(
      _script(() => ffi.virtDefineScript(spec: defined)),
      ffi.virtLibvirtDefineResult,
      action: true,
    );
    return cr.virtLibvirtCreated(spec: defined, made: made, created: created).virt;
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
      final detail = await _run(ffi.virtDomainDetailScript(domain: guest.id), ffi.virtLibvirtDomainDetail);
      final storage = await _listStorage();
      final pools = res.virtLibvirtPools(storage: storage).virt;
      final volumes = [
        for (final p in pools)
          if (p.active)
            cr.VirtPoolVolumes(
              pool: p.id,
              volumes: [for (final v in (await _volumes(p)).$1) v.ffi],
            ),
      ];
      final snapshots = await _snapshotList(guest);
      final chain = cr.virtLibvirtDeleteNeedsChain(snapshots: snapshots) ? await _chainRaw(guest) : null;
      plan = _rule(
        () => cr.virtLibvirtDeletePlan(
          id: guest.id,
          name: guest.name,
          detail: detail,
          storage: storage,
          volumes: volumes,
          snapshots: snapshots,
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
}
