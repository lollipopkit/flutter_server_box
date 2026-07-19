
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
  DiskIO(super.init1, super.init2);

  @override
  void onUpdate() {
    cachedAllSpeed = _getAllSpeed();
  }

  (double?, double?) _getSpeed(String dev) {
    // Extract the device name from path if needed
    String searchDev = dev;
    if (dev.startsWith('/dev/')) {
      searchDev = dev.substring(5);
    }

    // Try to find by exact device name first
    final old = pre.firstWhereOrNull((e) => e.dev == searchDev);
    final new_ = now.firstWhereOrNull((e) => e.dev == searchDev);

    if (old == null || new_ == null) return (null, null);
    final sectorsRead = new_.sectorsRead - old.sectorsRead;
    final sectorsWrite = new_.sectorsWrite - old.sectorsWrite;
    final time = new_.time - old.time;
    final read = sectorsRead / time * 512;
    final write = sectorsWrite / time * 512;
    return (read, write);
  }

  (String?, String?) getSpeed(String dev) {
    final (read_, write_) = _getSpeed(dev);
    if (read_ == null || write_ == null) return (null, null);
    final read = '${read_.bytes2Str}/s';
    final write = '${write_.bytes2Str}/s';
    return (read, write);
  }

  (String?, String?) cachedAllSpeed = (null, null);
  (String?, String?) _getAllSpeed() {
    if (pre.isEmpty || now.isEmpty) return (null, null);
    var (read, write) = (0.0, 0.0);
    for (var item in pre) {
      /// Issue #314
      /// Only calc nvme, sd, vd, hd, mmcblk, sr
      if (!item.dev.startsWith('nvme') &&
          !item.dev.startsWith('sd') &&
          !item.dev.startsWith('vd') &&
          !item.dev.startsWith('hd') &&
          !item.dev.startsWith('mmcblk') &&
          !item.dev.startsWith('sr')) {
        continue;
      }
      final (read_, write_) = _getSpeed(item.dev);
      read += read_ ?? 0;
      write += write_ ?? 0;
    }

    final readStr = '${read.bytes2Str}/s';
    final writeStr = '${write.bytes2Str}/s';
    return (readStr, writeStr);
  }

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
