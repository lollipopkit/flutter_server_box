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

  DiskInfo.fromJson(Map<String, dynamic> json) {
    mountPath = json["mountPath"].toString();
    mountLocation = json["mountLocation"].toString();
    usedPercent = int.parse(json["usedPercent"]);
    used = json["used"].toString();
    size = json["size"].toString();
    avail = json["avail"].toString();
  }
  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data["mountPath"] = mountPath;
    data["mountLocation"] = mountLocation;
    data["usedPercent"] = usedPercent;
    data["used"] = used;
    data["size"] = size;
    data["avail"] = avail;
    return data;
  }
}
