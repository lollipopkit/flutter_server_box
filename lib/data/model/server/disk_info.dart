import '../../res/misc.dart';

class DiskInfo {
/*
{
  "mountPath": "",
  "mountLocation": "",
  "usedPercent": 0,
  "used": "",
  "size": "",
  "avail": ""
} 
*/

  late String path;
  late String loc;
  late int usedPercent;
  late String used;
  late String size;
  late String avail;

  DiskInfo(
    this.path,
    this.loc,
    this.usedPercent,
    this.used,
    this.size,
    this.avail,
  );
}

List<DiskInfo> parseDisk(String raw) {
  final list = <DiskInfo>[];
  final items = raw.split('\n');
  items.removeAt(0);
  var pathCache = '';
  for (var item in items) {
    if (item.isEmpty) {
      continue;
    }
    final vals = item.split(numReg);
    if (vals.length == 1) {
      pathCache = vals[0];
      continue;
    }
    if (pathCache != '') {
      vals[0] = pathCache;
      pathCache = '';
    }
    list.add(DiskInfo(
      vals[0],
      vals[5],
      int.parse(vals[4].replaceFirst('%', '')),
      vals[2],
      vals[1],
      vals[3],
    ));
  }
  return list;
}
