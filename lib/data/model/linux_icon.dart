class LinuxIcons {
  List<String> db;

  LinuxIcons(this.db);

  String? search(String sysVer) {
    for (var item in db) {
      if (sysVer.contains(item)) {
        return 'assets/linux/$item.png';
      }
    }
    return null;
  }
}
