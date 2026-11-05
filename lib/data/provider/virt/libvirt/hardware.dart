part of '../libvirt_backend.dart';

/// A guest's hardware and cloud-init.
mixin _Hardware on _LibvirtCore, _Storage {
  /// Both definitions, autostart, the host's CPUs and memory, and each
  /// disk's size, in one round trip, as `sbm_virt` gave them (it carries the
  /// display passwords, and so stays here). See
  /// `sbm_virt::libvirt::hardware_script`.
  Future<vl.VirtHardwareInfo> _hardwareRead(VirtGuest guest) =>
      _run(ffi.virtHardwareScript(domain: guest.id), ffi.virtLibvirtHardwareRead);

  /// The persistent definition with what the running one has instead as
  /// pending (`sbm_virt::libvirt::hardware::hardware_of`); its revision is
  /// the definition's SHA-256.
  @override
  Future<VirtHardware> hardware(VirtGuest guest) async {
    final info = await _hardwareRead(guest);
    return hw.virtLibvirtHardware(info: info, name: guest.name).virt;
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
        info: info,
        name: guest.name,
        revision: base.revision,
        change: change.ffi,
        pools: [for (final p in pools) p.ffi],
        networks: [for (final n in networks) n.ffi],
        volumes: [for (final v in volumes) v.ffi],
      ),
    );
    final o = await _run(
      _script(
        () => ffi.virtHardwareChangeScript(
          domain: guest.id,
          running: info.live != null,
          baseXml: info.configXml,
          change: made,
        ),
      ),
      ffi.virtLibvirtHardwareOutcome,
      action: true,
    );
    return VirtHwOutcome(liveError: o.liveError, volumeKept: o.volumeKept);
  }

  /// Discards every pending change: the definition is written again from
  /// the running XML (see [VirtHwRevertPending]), made from [base]'s read.
  @override
  Future<void> revertPending(VirtGuest guest, VirtHardware base) async {
    final info = await _hardwareRead(guest);
    final made = _rule(() => hw.virtLibvirtHwRevert(info: info, revision: base.revision));
    await _run(
      _script(
        () => ffi.virtHardwareChangeScript(
          domain: guest.id,
          running: true,
          baseXml: info.configXml,
          change: made,
        ),
      ),
      ffi.virtLibvirtHardwareOutcome,
      action: true,
    );
  }

  /// The domain's own seed, read back from its volume (`vol-download`, in
  /// one round trip), with the domain's NICs: the seed is what the system
  /// reads, so it is the source of what is shown.
  Future<({String path, vl.VirtSeedRead read, List<String> macs})> _seedRead(VirtGuest guest) async {
    final config = (await _hardwareRead(guest)).config;
    final path = config.seed;
    if (path == null) {
      throw VirtErr(
        type: VirtErrType.unsupported,
        message: '${guest.name} has no cloud-init seed of this app',
      );
    }
    final read = await _run(_script(() => ffi.virtSeedReadScript(seed: path)), ffi.virtLibvirtSeedRead);
    return (path: path, read: read, macs: [for (final n in config.nics) n.mac]);
  }

  /// The seed as the view shows it: never the hash, only that there is one.
  @override
  Future<VirtCloudInitState> cloudInit(VirtGuest guest) async {
    final seed = await _seedRead(guest);
    return hw.virtLibvirtCloudInitState(read: seed.read, macs: seed.macs).virt;
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
        read: seed.read,
        name: guest.name,
        macs: seed.macs,
        edit: edit.ffiFrom(base),
      ),
    );
    await _run(
      _script(
        () => ffi.virtSeedUpdateScript(
          seed: seed.path,
          revision: base.revision,
          cloudInit: ci,
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
    final devices = await _run(ffi.virtHostDevicesScript(), ffi.virtLibvirtHostDevicesRead);
    return hw.virtLibvirtHostDevices(devices: devices).virt;
  }
}
