part of '../libvirt_backend.dart';

/// Storage pools, volumes and networks, as listed.
mixin _Storage on _LibvirtCore {
  /// The last storage listing: which volumes each pool has and every
  /// domain's disks, which [volumes] needs and does not list again — as
  /// `sbm_virt` gave it, and read.
  vl.VirtStorage? _storage;

  @override
  Future<List<VirtStoragePool>> storagePools() async {
    final storage = await _run(ffi.virtStorageScript(), ffi.virtLibvirtStorage);
    _storage = storage;
    return res.virtLibvirtPools(storage: storage).virt;
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
          () => ffi.virtResourceScript(op: vl.VirtResourceOp.poolRefresh(name: pool.id)),
        ),
        _parseResource,
        action: true,
      );
      pools = await storagePools();
      (read, _) = await _volumes(pool);
    }
    // What is made on each: a base image is attached to nothing, and its
    // clones may be in another pool. Read at once: the listing above settled
    // whether this account goes through sudo.
    final others = await Future.wait([
      for (final p in pools)
        if (p.id != pool.id && p.active) _volumes(p),
    ]);
    final every = [...read, for (final (volumes, _) in others) ...volumes];
    return res.virtLibvirtWithBacks(
      volumes: [for (final v in read) v.ffi],
      every: [for (final v in every) v.ffi],
    ).virt;
  }

  /// The pools as the last listing has them, listed when there is none.
  Future<List<VirtStoragePool>> _pools() async {
    final storage = _storage;
    if (storage == null) return storagePools();
    return res.virtLibvirtPools(storage: storage).virt;
  }

  /// [pool]'s volumes as the last listing has them, and whether one of them
  /// did not read.
  Future<(List<VirtVolume>, bool)> _volumes(VirtStoragePool pool) async {
    if (_storage == null) await storagePools();
    final storage = _storage!;
    final listed = storage.pools.firstWhereOrNull((p) => p.name == pool.id)?.volumes;
    if (listed == null || listed.isEmpty) return (const <VirtVolume>[], false);
    final read = (await _run(
      ffi.virtVolumesScript(pool: pool.id, names: [for (final v in listed) v.name]),
      ({required String raw}) async => res.virtLibvirtVolumes(raw: raw, pool: pool.id, storage: storage),
    )).virt;
    return (read, read.length < listed.length);
  }

  @override
  Future<List<VirtNetwork>> networks() async => (await _run(
    ffi.virtNetworksScript(),
    ({required String raw}) async => res.virtLibvirtNetworks(raw: raw),
  )).virt;
}
