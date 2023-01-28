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
