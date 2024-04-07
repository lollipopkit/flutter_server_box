import 'package:toolbox/core/extension/listx.dart';
import 'package:toolbox/core/extension/numx.dart';
import 'package:toolbox/data/model/server/time_seq.dart';

import '../../res/misc.dart';

class Disk {
  final String dev;
  final String mount;
  final int usedPercent;
  final BigInt used;
  final BigInt size;
  final BigInt avail;

  const Disk({
    required this.dev,
    required this.mount,
    required this.usedPercent,
    required this.used,
    required this.size,
    required this.avail,
  });

  static List<Disk> parse(String raw) {
    final list = <Disk>[];
    final items = raw.split('\n');
    items.removeAt(0);
    var pathCache = '';
    for (var item in items) {
      if (item.isEmpty) {
        continue;
      }
      final vals = item.split(Miscs.numReg);
      if (vals.length == 1) {
        pathCache = vals[0];
        continue;
      }
      if (pathCache != '') {
        vals[0] = pathCache;
        pathCache = '';
      }
      try {
        final dev = vals[0];
        if (!_shouldCalc(dev)) continue;
        list.add(Disk(
          dev: dev,
          mount: vals[5],
          usedPercent: int.parse(vals[4].replaceFirst('%', '')),
          used: BigInt.tryParse(vals[2]) ?? BigInt.zero,
          size: BigInt.tryParse(vals[1]) ?? BigInt.one,
          avail: BigInt.tryParse(vals[3]) ?? BigInt.one,
        ));
      } catch (e) {
        continue;
      }
    }
    return list;
  }
}

class DiskIO extends TimeSeq<List<DiskIOPiece>> {
  DiskIO(super.init1, super.init2);

  @override
  void onUpdate() {
    cachedAllSpeed = _getAllSpeed();
  }

  (double?, double?) _getSpeed(String dev) {
    if (dev.startsWith('/dev/')) dev = dev.substring(5);
    final old = pre.firstWhereOrNull((e) => e.dev == dev);
    final new_ = now.firstWhereOrNull((e) => e.dev == dev);
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
          !item.dev.startsWith('sr')) continue;
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

  double get usedPercent => used / size * 100;

  /// Find all devs, add their used and size
  static DiskUsage parse(List<Disk> disks) {
    final devs = <String>{};
    var used = BigInt.zero;
    var size = BigInt.zero;
    for (var disk in disks) {
      if (!_shouldCalc(disk.dev)) continue;
      if (devs.contains(disk.dev)) continue;
      devs.add(disk.dev);
      used += disk.used;
      size += disk.size;
    }
    return DiskUsage(used: used, size: size);
  }
}

// Some NAS may have mounted path like this `//192.168.1.2/`
bool _shouldCalc(String dev) {
  if (dev.startsWith('/dev')) return true;
  if (dev.startsWith('//')) return true;
  return false;
}
