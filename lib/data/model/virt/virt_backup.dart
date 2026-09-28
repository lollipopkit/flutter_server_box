import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:server_box/data/model/virt/virt.dart';

part 'virt_backup.freezed.dart';

/// One backup of a guest (PVE `vzdump`), as a backup storage lists it.
@freezed
abstract class VirtBackup with _$VirtBackup {
  const VirtBackup._();

  const factory VirtBackup({
    /// PVE's volid: `local:backup/vzdump-qemu-100-2026_09_24-02_00_00.vma.zst`.
    required String id,

    /// The storage it is on, and the node that lists it.
    required String storage,
    required String node,
    int? vmid,
    DateTime? createdAt,

    /// Bytes.
    int? size,

    /// `vma.zst`, `tar.zst`, ... — what PVE calls the archive's format.
    String? format,
    String? notes,

    /// Kept from pruning and deletion until unprotected.
    @Default(false) bool protected,

    /// `ok` or `failed`, where a verification job has run on it.
    String? verification,
    VirtGuestKind? kind,
  }) = _VirtBackup;

  /// The archive's file name, what the design's File row shows.
  String get fileName {
    final path = id.contains(':') ? id.substring(id.indexOf(':') + 1) : id;
    return path.split('/').last;
  }
}

/// A scheduled backup job (`/cluster/backup`), as the datacenter's Backup
/// view and a guest's Plan group show it. Edited from the datacenter view
/// ([VirtBackupJobEdit]); a guest's Plan group reads the jobs that take it.
@freezed
abstract class VirtBackupJob with _$VirtBackupJob {
  const VirtBackupJob._();

  const factory VirtBackupJob({
    required String id,

    /// PVE's calendar event: `02:00`, `sat 03:00`, `daily`.
    String? schedule,
    String? storage,

    /// `snapshot`, `suspend` or `stop`.
    String? mode,

    /// `zstd`, `lzo`, `gzip`, or none.
    String? compress,

    /// How many are kept, as PVE's retention says it: `keep-last=7`, ...
    String? keep,
    @Default(true) bool enabled,

    /// `all` (every guest on the job's node), the VMIDs it takes, or — with
    /// [pool] — the guests of that pool. PVE's `vmid` is a comma list or
    /// `all`; the two are exclusive.
    @Default(false) bool all,
    @Default(<int>[]) List<int> vmids,

    /// PVE's `exclude`, the VMIDs `all` leaves out.
    @Default(<int>[]) List<int> exclude,

    /// A pool (`VirtBackupJob.pool`), whose guests the job takes.
    String? pool,

    /// The node it runs on; null: every node.
    String? node,

    /// The job's own description (`comment`).
    String? comment,

    /// The notes every backup it makes carries (`notes-template`).
    String? notesTemplate,

    /// `always` or `failure` (PVE's `mailnotification`, deprecated in PVE 9
    /// but still what a job stores and its editor sets).
    String? mailNotification,

    /// The retention, as PVE's `prune-backups` property string:
    /// `keep-last=7,keep-daily=4`.
    String? prune,
  }) = _VirtBackupJob;

  /// What the design's Plan group shows as the guest selection: `All`, the
  /// VMIDs, or the pool.
  String get selectionLabel => pool != null
      ? 'pool:$pool'
      : all
      ? 'all'
      : vmids.isEmpty
      ? '—'
      : vmids.join(',');

  /// Whether this job takes [vmid], a guest on [node]. A job restricted to
  /// a node backs up only the guests there: on any other its selection,
  /// `all` included, takes nothing.
  bool takes(int? vmid, {String? node}) {
    if (vmid == null) return false;
    if (this.node != null && node != null && this.node != node) return false;
    if (pool != null) return false;
    if (all) return !exclude.contains(vmid);
    return vmids.contains(vmid);
  }

  /// Whether this job takes [vmid] and no other guest: a list of exactly
  /// that VMID, not `all`, not a pool. Such a job is the guest's own plan,
  /// which its Plan group edits; any other job is the datacenter's.
  bool takesOnly(int? vmid) =>
      vmid != null &&
      !all &&
      pool == null &&
      exclude.isEmpty &&
      vmids.length == 1 &&
      vmids.single == vmid;
}

/// What the datacenter's Backup view edits: one scheduled job, sent as PVE's
/// own field names. [isNew] makes one (`POST /cluster/backup`); otherwise it
/// is an edit of the job [`id`] names (`PUT /cluster/backup/{id}`).
///
/// The flag is not `id == null`: PVE's own panel lets a new job be given its
/// id, so a create carries one and still has to be a `POST`. A `PUT` of a job
/// that is not there is `no such vzdump job`.
final class VirtBackupJobEdit {
  const VirtBackupJobEdit({
    this.id,
    this.isNew = false,
    required this.node,
    required this.storage,
    required this.schedule,
    this.mode = 'snapshot',
    this.compress = 'zstd',
    this.enabled = true,
    this.all = false,
    this.vmids = const [],
    this.exclude = const [],
    this.pool,
    this.comment,
    this.notesTemplate,
    this.mailNotification = 'failure',
    this.prune,
  });

  /// The job's id: what an edit names, and what a new job is called (PVE
  /// generates one when this is null).
  final String? id;

  /// Makes a job rather than editing one.
  final bool isNew;
  final String? node;
  final String storage;

  /// systemd calendar format, as PVE's own `pve-calendar-event` takes it.
  final String schedule;
  final String mode;
  final String compress;
  final bool enabled;

  /// Every guest on the node (PVE `all`), with [exclude] left out.
  final bool all;
  final List<int> vmids;
  final List<int> exclude;
  final String? pool;
  final String? comment;
  final String? notesTemplate;
  final String? mailNotification;
  final String? prune;
}

/// A backup to take now.
final class VirtBackupRequest {
  const VirtBackupRequest({
    required this.storage,
    this.mode = 'snapshot',
    this.compress = 'zstd',
    this.notes,
    this.protected = false,
    this.prune,
  });

  /// A storage that holds backups (PVE content `backup`), by name.
  final String storage;

  /// `snapshot` (a running guest keeps running), `suspend` or `stop`.
  final String mode;

  /// `zstd`, `lzo`, `gzip` or `0` for none.
  final String compress;
  final String? notes;
  final bool protected;

  /// Retention, PVE's `prune-backups` property string; null for the
  /// storage's or the node's own.
  final String? prune;
}

/// What an existing backup's own fields can be changed to (PVE `PUT
/// .../storage/{id}/content/{volid}`): its notes and its protection.
final class VirtBackupEdit {
  const VirtBackupEdit({required this.notes, required this.protected});

  final String notes;
  final bool protected;
}
