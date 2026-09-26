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

/// A scheduled backup job (`/cluster/backup`) that takes this guest: the
/// design's Plan group, read only — jobs are the datacenter's, not a
/// guest's.
@freezed
abstract class VirtBackupJob with _$VirtBackupJob {
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
  }) = _VirtBackupJob;
}

/// A backup to take now.
final class VirtBackupRequest {
  const VirtBackupRequest({
    required this.storage,
    this.mode = 'snapshot',
    this.compress = 'zstd',
    this.notes,
    this.protected = false,
  });

  /// A storage that holds backups (PVE content `backup`), by name.
  final String storage;

  /// `snapshot` (a running guest keeps running), `suspend` or `stop`.
  final String mode;

  /// `zstd`, `lzo`, `gzip` or `0` for none.
  final String compress;
  final String? notes;
  final bool protected;
}
