enum Dist {
  debian,
  ubuntu,
  centos,
  fedora,
  opensuse,
  kali,
  wrt,
  armbian,
  arch,
  alpine,
  rocky,
  deepin,
  ;
}

extension StringX on String {
  Dist? get dist {
    final lower = toLowerCase();
    for (final dist in Dist.values) {
      if (lower.contains(dist.name)) {
        return dist;
      }
    }
    for (final wrt in _wrts) {
      if (lower.contains(wrt)) {
        return Dist.wrt;
      }
    }
    return null;
  }
}

// Special rules

const _wrts = [
  'istoreos',
];
