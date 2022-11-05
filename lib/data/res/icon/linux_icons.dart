final linuxIcons = LinuxIcons([
  'ubuntu',
  'arch',
  'centos',
  'debian',
  'fedora',
  'opensuse',
  'kali',
  'wrt',
  'armbian'
]);

class LinuxIcons {
  List<String> db;

  LinuxIcons(this.db);

  String? search(String sysVer) {
    for (var item in db) {
      if (sysVer.toLowerCase().contains(item)) {
        return 'assets/linux/$item.png';
      }
    }
    return null;
  }
}
