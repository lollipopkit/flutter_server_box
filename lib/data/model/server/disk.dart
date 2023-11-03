import 'package:toolbox/core/extension/numx.dart';
import 'package:toolbox/data/model/server/time_seq.dart';

import '../../res/misc.dart';

class Disk {
  final String dev;
  final String mount;
  final int usedPercent;
  final String used;
  final String size;
  final String avail;

  const Disk({
    required this.dev,
    required this.mount,
    required this.usedPercent,
    required this.used,
    required this.size,
    required this.avail,
  });
}

class DiskIO extends TimeSeq<DiskIOPiece> {
  DiskIO(super.pre, super.now);

  (double?, double?) _getSpeed(String dev) {
    final pres = this.pre.where(
          (element) => element.dev == dev.replaceFirst('/dev/', ''),
        );
    final nows = this.now.where(
          (element) => element.dev == dev.replaceFirst('/dev/', ''),
        );
    if (pres.isEmpty || nows.isEmpty) return (null, null);
    final pre = pres.first;
    final now = nows.first;
    final sectorsRead = now.sectorsRead - pre.sectorsRead;
    final sectorsWrite = now.sectorsWrite - pre.sectorsWrite;
    final time = now.time - pre.time;
    final read = (sectorsRead / time * 512);
    final write = (sectorsWrite / time * 512);
    return (read, write);
  }

  (String?, String?) getSpeed(String dev) {
    final (read_, write_) = _getSpeed(dev);
    if (read_ == null || write_ == null) return (null, null);
    final read = '${read_.convertBytes}/s';
    final write = '${write_.convertBytes}/s';
    return (read, write);
  }

  (String?, String?) getAllSpeed() {
    if (pre.isEmpty || now.isEmpty) return (null, null);
    var (read, write) = (0.0, 0.0);
    for (var pre in pre) {
      final (read_, write_) = _getSpeed(pre.dev);
      read += read_ ?? 0;
      write += write_ ?? 0;
    }
    final readStr = '${read.convertBytes}/s';
    final writeStr = '${write.convertBytes}/s';
    return (readStr, writeStr);
  }

  // Raw:
  //  254       0 vda 584193 186416 40419294 845790 5024458 2028159 92899586 6997559 0 5728372 8143590 0 0 0 0 2006112 300240
  //  254       1 vda1 584029 186416 40412734 845668 5024453 2028159 92899586 6997558 0 5728264 7843226 0 0 0 0 0 0
  //   11       0 sr0 36 0 280 49 0 0 0 0 0 56 49 0 0 0 0 0 0
  //    7       0 loop0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0
  //    7       1 loop1 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0
  //    7       2 loop2 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0
  //    7       3 loop3 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0
  //    7       4 loop4 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0
  //    7       5 loop5 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0
  //    7       6 loop6 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0
  //    7       7 loop7 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0
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

List<Disk> parseDisk(String raw) {
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
      list.add(Disk(
        dev: vals[0],
        mount: vals[5],
        usedPercent: int.parse(vals[4].replaceFirst('%', '')),
        used: vals[2],
        size: vals[1],
        avail: vals[3],
      ));
    } catch (e) {
      continue;
    }
  }
  return list;
}

/// Issue 88
///
/// Due to performance issues,
/// if there is no `Disk.loc == '/' || Disk.loc == '/sysroot'`,
/// return the first [Disk] of [disks].
///
/// If we find out the biggest [Disk] of [disks],
/// the fps may lower than 60.
Disk? findRootDisk(List<Disk> disks) {
  if (disks.isEmpty) return null;
  final roots = disks.where((element) => element.mount == '/');
  if (roots.isEmpty) {
    final sysRoots = disks.where((element) => element.mount == '/sysroot');
    if (sysRoots.isEmpty) {
      return disks.first;
    } else {
      return sysRoots.first;
    }
  } else {
    return roots.first;
  }
}
