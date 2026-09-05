
import 'package:equatable/equatable.dart';
import 'package:fl_lib/fl_lib.dart';
import 'package:server_box/data/model/server/time_seq.dart';


class Disk extends Equatable {
  final String path;
  final String? fsTyp;
  final String mount;
  final int usedPercent;
  final BigInt used;
  final BigInt size;
  final BigInt avail;

  /// Device name (e.g., sda1, nvme0n1p1)
  final String? name;

  /// Internal kernel device name
  final String? kname;

  /// Filesystem UUID
  final String? uuid;

  /// Child disks (partitions)
  final List<Disk> children;

  const Disk({
    required this.path,
    this.fsTyp,
    required this.mount,
    required this.usedPercent,
    required this.used,
    required this.size,
    required this.avail,
    this.name,
    this.kname,
    this.uuid,
    this.children = const [],
  });

  // Parsing implementation migrated to the shared Rust library sbm_parser

  /// Whether this describes storage worth showing, rather than a kernel mount,
  /// a read-only image, a container layer or a swap area.
  ///
  /// The parser drops the rest while reading `lsblk`/`df`. A [Disk] built from
  /// a monitor agent's `disk_details` never went through it, so an agent older
  /// than a given rule still sends what that rule removes.
  ///
  /// [_shouldCalc] is handed a source by `df` and a filesystem type by `lsblk`,
  /// never both, and takes a different branch for each. A [Disk] carries both,
  /// so it is asked with each.
  bool get isStorage =>
      _shouldCalc(path, mount) && _shouldCalc(fsTyp ?? path, mount);

  @override
  List<Object?> get props => [
    path,
    name,
    kname,
    fsTyp,
    mount,
    usedPercent,
    used,
    size,
    avail,
    uuid,
    children,
  ];
}

class DiskIO extends TimeSeq<DiskIOPiece> {
  DiskIO();

  DiskIO.copy(DiskIO source) : super.copy(source) {
    cachedAllSpeed = source.cachedAllSpeed;
  }

  /// `/proc/diskstats` reports in 512-byte units regardless of the drive's
  /// physical sector size
  static const _sectorBytes = 512;

  /// Issue #314: real block devices only, not loop/ram/dm entries
  static const _devPrefixes = ['nvme', 'sd', 'vd', 'hd', 'mmcblk', 'sr'];

  @override
  bool advances(List<DiskIOPiece> next) {
    if (next.isEmpty || now.isEmpty) return true;
    return next.first.time > now.first.time;
  }

  @override
  void onUpdate() {
    final (read, write) = allSpeedBytes;
    cachedAllSpeed = (_fmt(read), _fmt(write));
  }

  /// Bytes per second for [dev]. Either both components are present or both
  /// are `null`: a window with no baseline, no elapsed time, or counters that
  /// went backwards has no rate at all. The old code divided by that
  /// zero-width window and rendered `NaN B/s`; clamping to 0 instead would
  /// have been indistinguishable from a genuinely idle disk.
  (double?, double?) speedBytes(String dev) {
    final searchDev = dev.startsWith('/dev/') ? dev.substring(5) : dev;
    final old = pre.firstWhereOrNull((e) => e.dev == searchDev);
    final new_ = now.firstWhereOrNull((e) => e.dev == searchDev);
    if (old == null || new_ == null) return (null, null);

    final elapsed = elapsedSeconds(old.time, new_.time);
    if (elapsed == null) return (null, null);

    final read = counterDelta(old.sectorsRead, new_.sectorsRead);
    final write = counterDelta(old.sectorsWrite, new_.sectorsWrite);
    if (read == null || write == null) return (null, null);

    return (read * _sectorBytes / elapsed, write * _sectorBytes / elapsed);
  }

  (String?, String?) getSpeed(String dev) {
    final (read, write) = speedBytes(dev);
    return (_fmt(read), _fmt(write));
  }

  /// Summed across real block devices; `null` when none produced a reading
  (double?, double?) get allSpeedBytes {
    double? read, write;
    for (final item in now) {
      if (!_devPrefixes.any(item.dev.startsWith)) continue;
      final (r, w) = speedBytes(item.dev);
      if (r == null || w == null) continue;
      read = (read ?? 0) + r;
      write = (write ?? 0) + w;
    }
    return (read, write);
  }

  (String?, String?) cachedAllSpeed = (null, null);

  static String? _fmt(double? bytesPerSec) =>
      bytesPerSec == null ? null : '${bytesPerSec.bytes2Str}/s';

}

class DiskIOPiece extends TimeSeqIface<DiskIOPiece> {
  final String dev;
  final int sectorsRead;
  final int sectorsWrite;
  final int time;

  DiskIOPiece({
    required this.dev,
    required this.sectorsRead,
    required this.sectorsWrite,
    required this.time,
  });

  @override
  bool same(DiskIOPiece other) => dev == other.dev;
}

class DiskUsage {
  final BigInt used;
  final BigInt size;

  DiskUsage({required this.used, required this.size});

  double get usedPercent {
    // Avoid division by zero
    if (size == BigInt.zero) return 0;
    return used / size * 100;
  }

  /// Find all devs, add their used and size
  static DiskUsage parse(List<Disk> disks) {
    final devs = <String>{};
    var used = BigInt.zero;
    var size = BigInt.zero;

    void visit(Disk disk) {
      if (!disk.isStorage) return;
      // Use a combination of path and kernel name to uniquely identify disks
      // This helps distinguish between multiple physical disks in BTRFS RAID setups
      final uniqueId = '${disk.path}:${disk.kname ?? "unknown"}';
      if (!devs.contains(uniqueId)) {
        devs.add(uniqueId);
        used += disk.used;
        size += disk.size;
      }
      if (disk.used != BigInt.zero || disk.size != BigInt.zero) return;
      for (final child in disk.children) {
        visit(child);
      }
    }

    for (var disk in disks) {
      visit(disk);
    }
    return DiskUsage(used: used, size: size);
  }
}

bool _shouldCalc(String fs, String mount) {
  // Checked before the inclusions below, so that a source spelled like a block
  // device cannot bring these back: a host that exposes many device nodes
  // publishes one devtmpfs row per node, two dozen lines all claiming 0 B used
  // of the same size.
  if (_isKernelMount(mount)) return false;
  if (_isReadOnlyImage(fs, mount)) return false;
  if (_isSwapArea(fs, mount)) return false;

  if (fs.startsWith('/dev')) return true;
  // Some NAS may have mounted path like this `//192.168.1.2/`
  if (fs.startsWith('//')) return true;
  if (mount.startsWith('/mnt')) return true;

  if (_isVirtualFs(fs)) return false;

  return true;
}

/// A kernel-backed filesystem with nothing stored behind it, by exact name.
///
/// Matched exactly rather than by prefix, because [fs] is a *source* under
/// `df` and a source carries user-chosen text: a ZFS pool named `tmpfspool`,
/// or an export from an NFS host named `shm-nas`, each begin with one of these
/// and each is storage.
///
/// `overlay` and `overlayfs` are the current and pre-4.0 spellings of docker's
/// own layers. `fuse-overlayfs` is what a rootless podman or docker mounts,
/// one row per container carrying the host filesystem's own numbers.
///
/// `ramfs` is systemd's credential mounts, one per unit that takes a
/// credential. Most `df` builds report `-` for its usage, which fails to parse
/// and drops the row before any of this; naming it here does not depend on
/// that, since a build reporting `0%` instead leaves a row of 0 B.
///
/// Mirrors `is_virtual_fs` in `crates/sbm_parser/src/types.rs`.
bool _isVirtualFs(String fs) => const {
  'shm',
  'tmpfs',
  'ramfs',
  'devtmpfs',
  'overlay',
  'overlayfs',
  'fuse-overlayfs',
}.contains(fs);

/// A read-only image mounted as a filesystem — a snap's squashfs, the same
/// image handed to a container through `snapfuse`, a mounted ISO — rather than
/// storage anyone manages. Each is full by construction, so it reports 100%
/// and contributes its whole size to the total; a snap-heavy Ubuntu publishes
/// twenty of them, which is the entire device list.
///
/// Matched on the image, never on `/dev/loop`: a loop device carrying a
/// writable filesystem is storage someone mounted on purpose.
///
/// Mirrors `is_read_only_image` in `crates/sbm_parser/src/types.rs`, and takes
/// the same overloaded first argument: a filesystem type where one is known, a
/// source otherwise.
bool _isReadOnlyImage(String fs, String mount) {
  return const {
        'squashfs',
        'erofs',
        'iso9660',
        'snapfuse',
        'fuse.snapfuse',
      }.contains(fs) ||
      mount.startsWith('/snap/') ||
      mount.startsWith('/var/lib/snapd/snap/');
}

/// A swap area, which `lsblk` lists beside filesystems. It has no mount point
/// and no `FSSIZE`, so the row reads `0 B / 0 B`, and swap is reported on its
/// own from `/proc/meminfo` anyway. `df` lists only mounted filesystems and
/// never produces one of these.
bool _isSwapArea(String fs, String mount) => fs == 'swap' || mount == '[SWAP]';

/// `/dev`, `/proc`, `/sys`, and anything mounted inside them.
///
/// `/run` is deliberately absent: several distributions mount removable media
/// under `/run/media/<user>`, which is a disk someone wants to see. The tmpfs
/// rows `/run` otherwise carries are excluded by their source instead.
bool _isKernelMount(String mount) {
  for (final prefix in const ['/dev', '/proc', '/sys']) {
    if (mount == prefix || mount.startsWith('$prefix/')) return true;
  }
  return false;
}
