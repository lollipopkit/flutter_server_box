
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
      if (!_shouldCalc(disk.path, disk.mount)) return;
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
  if (fs.startsWith('/dev')) return true;
  // Some NAS may have mounted path like this `//192.168.1.2/`
  if (fs.startsWith('//')) return true;
  if (mount.startsWith('/mnt')) return true;

  if (fs.startsWith('shm') ||
      fs.startsWith('overlay') ||
      fs.startsWith('tmpfs')) {
    return false;
  }

  return true;
}
