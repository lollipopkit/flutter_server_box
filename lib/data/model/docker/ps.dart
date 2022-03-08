class DockerPsItem {
  late String containerId;
  late String image;
  late String command;
  late String created;
  late String status;
  late String ports;
  late String name;

  DockerPsItem(this.containerId, this.image, this.command, this.created,
      this.status, this.ports, this.name);

  DockerPsItem.fromRawString(String rawString) {
    final List<String> parts = rawString.split('   ');
    containerId = parts[0];
    image = parts[1];
    command = parts[2];
    created = parts[3];
    status = parts[4];
    ports = parts[5];
    if (running && parts.length == 9) {
      name = parts[8];
    } else {
      name = parts[6];
    }
  }

  bool get running => status.contains('Up ');
}
