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

  late String mountPath;
  late String mountLocation;
  late int usedPercent;
  late String used;
  late String size;
  late String avail;

  DiskInfo(
    this.mountPath,
    this.mountLocation,
    this.usedPercent,
    this.used,
    this.size,
    this.avail,
  );
}
