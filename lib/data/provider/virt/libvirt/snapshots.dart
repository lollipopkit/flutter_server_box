part of '../libvirt_backend.dart';

/// Snapshots: internal, and external with their chains.
mixin _Snapshots on _LibvirtCore {
  @override
  Future<List<VirtGuestSnapshot>> snapshots(VirtGuest guest) async =>
      (await _snapshotList(guest)).virt;

  Future<List<vv.Snapshot>> _snapshotList(VirtGuest guest) => _run(
    ffi.virtSnapshotsScript(domain: guest.id),
    ({required String raw}) async => ffi.virtLibvirtSnapshots(raw: raw),
  );

  /// The raw chain read (`snap_chain_script`), checked as it is read.
  Future<String> _chainRaw(VirtGuest guest) => _run(
    ffi.virtSnapChainScript(domain: guest.id),
    ({required String raw}) async {
      await ffi.virtSnapChainCheck(raw: raw);
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
    final snaps = await _snapshotList(guest);
    List<VirtStoragePool> pools;
    try {
      pools = await storagePools();
    } on VirtErr catch (e) {
      Loggers.app.info('libvirt pools for a snapshot overlay: ${e.message}');
      pools = const [];
    }
    try {
      return ffi.virtLibvirtChain(
        chainRaw: raw,
        snapshots: snaps,
        pools: [for (final p in pools) virtPoolRef(p)],
      ).virt;
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
    return (await _run(
      ffi.virtSnapDiffScript(domain: guest.id, name: name),
      ({required String raw}) async => ffi.virtLibvirtSnapDiff(raw: raw),
    )).virt;
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
    // Where the overlays go. **No pool picked: no `--diskspec` at all** —
    // libvirt then names each overlay `<disk>.<snapshot>` beside the disk it
    // backs. A pool the user picked is resolved to its directory once.
    final dir = overlayPool == null ? null : await _poolTarget(overlayPool);
    // One read of the chain answers both: whether an external snapshot can
    // be taken, and the files the overlays go on.
    final plan = ffi.virtLibvirtExternalSnapshot(chainRaw: await _chainRaw(guest), name: name, dir: dir);
    if (plan.refusal case final why?) {
      throw VirtErr(type: VirtErrType.unsupported, message: why);
    }
    final overlays = [for (final o in plan.overlays) (o.target, o.path)];
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

  Future<void> _action1(String script) async {
    await _run(script, ({required String raw}) async {
      ffi.parseVirtAction(raw: raw);
      return '';
    }, action: true);
  }
}

void _checkName(String name) {
  if (virtSnapshotNameIssue(name, const []) != null) {
    throw VirtErr(
      type: VirtErrType.unsupported,
      message: 'Not a snapshot name: $name',
    );
  }
}
