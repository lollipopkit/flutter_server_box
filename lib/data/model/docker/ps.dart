final _seperator = RegExp('  +');

class DockerPsItem {
  late String containerId;
  late String image;
  late String command;
  late String created;
  late String status;
  late String ports;
  late String name;
  // String? cpu;
  // String? mem;
  // String? net;
  // String? disk;

  DockerPsItem(
    this.containerId,
    this.image,
    this.command,
    this.created,
    this.status,
    this.ports,
    this.name,
  );

  DockerPsItem.fromRawString(String rawString) {
    List<String> parts = rawString.split(_seperator);
    parts = parts.map((e) => e.trim()).toList();

    containerId = parts[0];
    image = parts[1];
    command = parts[2].trim();
    created = parts[3];
    status = parts[4];
    if (running && parts.length > 6) {
      ports = parts[5];
      name = parts[6];
    } else {
      ports = '';
      name = parts[5];
    }
  }

  // void parseStats(String rawString) {
  //   if (rawString.isEmpty) {
  //     return;
  //   }
  //   final parts = rawString.split(_seperator);
  //   if (parts.length != 8) {
  //     return;
  //   }
  //   cpu = parts[2];
  //   mem = parts[3];
  //   net = parts[5];
  //   disk = parts[6];
  // }

  bool get running => status.contains('Up ');

  @override
  String toString() {
    return 'DockerPsItem<$containerId@$name>';
  }
}
