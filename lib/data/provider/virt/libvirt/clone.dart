part of '../libvirt_backend.dart';

/// Cloning; libvirt has no backups of its own.
mixin _Clone on _LibvirtCore, _Storage, _Hardware {
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
    final storage = await _listStorage();
    final spec = _rule(
      () => cr.virtLibvirtCloneSpec(
        guest: guest.ffi,
        hardware: hardware,
        request: request.ffi,
        guests: [for (final g in guests) g.ffi],
        storage: storage,
      ),
    );
    final List<String> paths;
    try {
      paths = await _run(
        _script(() => ffi.virtCloneVolumesScript(spec: spec)),
        ffi.parseVirtCloneVolumes,
        action: true,
      );
    } on VirtErr catch (e) {
      throw _existsOr(e);
    }
    final created = await _run(
      _script(
        () => ffi.virtCloneDefineScript(
          baseXml: hardware.configXml,
          name: request.name,
          disks: cr.virtLibvirtCloneDisks(spec: spec, paths: paths),
        ),
      ),
      ffi.virtLibvirtDefineResult,
      action: true,
    );
    return created.uuid ?? request.name;
  }

  /// libvirt has no templates: a domain is a domain, and a copy of one is a
  /// clone. Only `VirtCapabilities.template` (PVE) reaches this.
  @override
  Future<void> makeTemplate(VirtGuest guest) async =>
      throw const VirtErr(type: VirtErrType.unsupported);

  @override
  Future<List<VirtBackup>> backups(VirtGuest guest) async => _noBackups();

  @override
  Future<List<VirtBackupJob>> backupJobs(VirtGuest guest) async => const [];

  @override
  Future<List<VirtBackupJob>> allBackupJobs() async => const [];

  @override
  Future<void> editBackupJob(VirtBackupJobEdit edit) async => _noBackups();

  @override
  Future<void> deleteBackupJob(VirtBackupJob job) async => _noBackups();

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
}

Never _noBackups() => throw const VirtErr(type: VirtErrType.unsupported);
