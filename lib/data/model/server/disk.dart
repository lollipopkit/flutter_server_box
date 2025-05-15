import 'dart:convert';

import 'package:equatable/equatable.dart';
import 'package:fl_lib/fl_lib.dart';
import 'package:server_box/data/model/server/time_seq.dart';

import 'package:server_box/data/res/misc.dart';

class Disk with EquatableMixin {
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

  static List<Disk> parse(String raw) {
    final list = <Disk>[];
    raw = raw.trim();
    try {
      if (raw.startsWith('{')) {
        // Parse JSON output from lsblk command
        final Map<String, dynamic> jsonData = json.decode(raw);
        final List<dynamic> blockdevices = jsonData['blockdevices'] ?? [];

        for (final device in blockdevices) {
          // Process each device
          _processTopLevelDevice(device, list);
        }
      } else {
        // Fallback to the old parsing method in case of non-JSON output
        return _parseWithOldMethod(raw);
      }
    } catch (e) {
      Loggers.app.warning('Failed to parse disk info: $e', e);
    }
    return list;
  }

  /// Process a top-level device and add all valid disks to the list
  static void _processTopLevelDevice(Map<String, dynamic> device, List<Disk> list) {
    final disk = _processDiskDevice(device);
    if (disk != null) {
      list.add(disk);
    }
    
    // For devices with children (like physical disks with partitions),
    // also process each child individually to ensure BTRFS RAID disks are properly handled
    final List<dynamic> childDevices = device['children'] ?? [];
    for (final childDevice in childDevices) {
      final String childPath = childDevice['path']?.toString() ?? '';
      final String childFsType = childDevice['fstype']?.toString() ?? '';
      
      // If this is a BTRFS partition, add it directly to ensure it's properly represented
      if (childFsType == 'btrfs' && childPath.isNotEmpty) {
        final childDisk = _processSingleDevice(childDevice);
        if (childDisk != null) {
          list.add(childDisk);
        }
      }
    }
  }

  /// Process a single device without recursively processing its children
  static Disk? _processSingleDevice(Map<String, dynamic> device) {
    final fstype = device['fstype']?.toString();
    final String mountpoint = device['mountpoint']?.toString() ?? '';
    final String path = device['path']?.toString() ?? '';
    
    if (path.isEmpty || (fstype == null && mountpoint.isEmpty)) {
      return null;
    }
    
    if (!_shouldCalc(fstype ?? '', mountpoint)) {
      return null;
    }

    final sizeStr = device['fssize']?.toString() ?? '0';
    final size = (BigInt.tryParse(sizeStr) ?? BigInt.zero) ~/ BigInt.from(1024);

    final usedStr = device['fsused']?.toString() ?? '0';
    final used = (BigInt.tryParse(usedStr) ?? BigInt.zero) ~/ BigInt.from(1024);

    final availStr = device['fsavail']?.toString() ?? '0';
    final avail = (BigInt.tryParse(availStr) ?? BigInt.zero) ~/ BigInt.from(1024);

    // Parse fsuse% which is usually in the format "45%"
    String usePercentStr = device['fsuse%']?.toString() ?? '0';
    usePercentStr = usePercentStr.replaceAll('%', '');
    final usedPercent = int.tryParse(usePercentStr) ?? 0;

    final name = device['name']?.toString();
    final kname = device['kname']?.toString();
    final uuid = device['uuid']?.toString();

    return Disk(
      path: path,
      fsTyp: fstype,
      mount: mountpoint,
      usedPercent: usedPercent,
      used: used,
      size: size,
      avail: avail,
      name: name,
      kname: kname,
      uuid: uuid,
      children: const [], // No children for direct device
    );
  }

  static Disk? _processDiskDevice(Map<String, dynamic> device) {
    final fstype = device['fstype']?.toString();
    final String mountpoint = device['mountpoint']?.toString() ?? '';

    // For parent devices that don't have a mountpoint themselves
    final String path = device['path']?.toString() ?? '';
    final String mount = mountpoint;
    final List<Disk> childDisks = [];

    // Process children devices recursively
    final List<dynamic> childDevices = device['children'] ?? [];
    for (final childDevice in childDevices) {
      final childDisk = _processDiskDevice(childDevice);
      if (childDisk != null) {
        childDisks.add(childDisk);
      }
    }

    // Handle common filesystem cases or parent devices with children
    if ((fstype != null && _shouldCalc(fstype, mount)) ||
        (childDisks.isNotEmpty && path.isNotEmpty)) {
      final sizeStr = device['fssize']?.toString() ?? '0';
      final size = (BigInt.tryParse(sizeStr) ?? BigInt.zero) ~/ BigInt.from(1024);

      final usedStr = device['fsused']?.toString() ?? '0';
      final used = (BigInt.tryParse(usedStr) ?? BigInt.zero) ~/ BigInt.from(1024);

      final availStr = device['fsavail']?.toString() ?? '0';
      final avail = (BigInt.tryParse(availStr) ?? BigInt.zero) ~/ BigInt.from(1024);

      // Parse fsuse% which is usually in the format "45%"
      String usePercentStr = device['fsuse%']?.toString() ?? '0';
      usePercentStr = usePercentStr.replaceAll('%', '');
      final usedPercent = int.tryParse(usePercentStr) ?? 0;

      final name = device['name']?.toString();
      final kname = device['kname']?.toString();
      final uuid = device['uuid']?.toString();

      return Disk(
        path: path,
        fsTyp: fstype,
        mount: mount,
        usedPercent: usedPercent,
        used: used,
        size: size,
        avail: avail,
        name: name,
        kname: kname,
        uuid: uuid,
        children: childDisks,
      );
    } else if (childDisks.isNotEmpty) {
      // If this is a parent device with no filesystem but has children,
      // return the first valid child instead
      if (childDisks.isNotEmpty) {
        return childDisks.first;
      }
    }

    return null;
  }

  // Fallback to the old parsing method in case JSON parsing fails
  static List<Disk> _parseWithOldMethod(String raw) {
    final list = <Disk>[];
    final items = raw.split('\n');
    if (items.isNotEmpty) items.removeAt(0);
    var pathCache = '';
    for (var item in items) {
      if (item.isEmpty) {
        continue;
      }
      final vals = item.split(Miscs.blankReg);
      if (vals.length == 1) {
        pathCache = vals[0];
        continue;
      }
      if (pathCache != '') {
        vals[0] = pathCache;
        pathCache = '';
      }
      try {
        final fs = vals[0];
        final mount = vals[5];
        if (!_shouldCalc(fs, mount)) continue;
        list.add(Disk(
          path: fs,
          mount: mount,
          usedPercent: int.parse(vals[4].replaceFirst('%', '')),
          used: BigInt.parse(vals[2]) ~/ BigInt.from(1024),
          size: BigInt.parse(vals[1]) ~/ BigInt.from(1024),
          avail: BigInt.parse(vals[3]) ~/ BigInt.from(1024),
        ));
      } catch (e) {
        continue;
      }
    }
    return list;
  }

  @override
  List<Object?> get props =>
      [path, name, kname, fsTyp, mount, usedPercent, used, size, avail, uuid, children];
}

class DiskIO extends TimeSeq<List<DiskIOPiece>> {
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

  static List<DiskIOPiece> parse(String raw, int time) {
    final lines = raw.split('\n');
    if (lines.isEmpty) return [];
    final items = <DiskIOPiece>[];
    for (var item in lines) {
      item = item.trim();
      if (item.isEmpty) continue;
      final vals = item.split(Miscs.blankReg);
      if (vals.length < 10) continue;
      try {
        final dev = vals[2];
        if (dev.startsWith('loop')) continue;
        items.add(DiskIOPiece(
          dev: dev,
          sectorsRead: int.parse(vals[5]),
          sectorsWrite: int.parse(vals[9]),
          time: time,
        ));
      } catch (e) {
        continue;
      }
    }
    return items;
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

  DiskUsage({
    required this.used,
    required this.size,
  });

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
    for (var disk in disks) {
      if (!_shouldCalc(disk.path, disk.mount)) continue;
      // Use a combination of path and kernel name to uniquely identify disks
      // This helps distinguish between multiple physical disks in BTRFS RAID setups
      final uniqueId = '${disk.path}:${disk.kname ?? "unknown"}';
      if (devs.contains(uniqueId)) continue;
      devs.add(uniqueId);
      used += disk.used;
      size += disk.size;
    }
    return DiskUsage(used: used, size: size);
  }
}

bool _shouldCalc(String fs, String mount) {
  // Skip swap partitions
  // if (mount == '[SWAP]') return false;

  // Include standard filesystems
  if (fs.startsWith('/dev')) return true;
  // Some NAS may have mounted path like this `//192.168.1.2/`
  if (fs.startsWith('//')) return true;
  if (mount.startsWith('/mnt')) return true;

  // Include common filesystem types
  // final commonFsTypes = ['ext2', 'ext3', 'ext4', 'xfs', 'btrfs', 'zfs', 'ntfs', 'fat', 'vfat'];
  // if (commonFsTypes.any((type) => fs.toLowerCase() == type)) return true;

  // Skip special filesystems
  // if (fs == 'LVM2_member' || fs == 'crypto_LUKS') return false;
  if (fs.startsWith('shm') || fs.startsWith('overlay') || fs.startsWith('tmpfs')) {
    return false;
  }

  return true;
}
