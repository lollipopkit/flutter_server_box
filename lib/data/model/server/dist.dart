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
  coreelec;

  /// The single-colour glyph marking this distribution, or null when none is
  /// shipped for it.
  ///
  /// Null for `armbian` and `coreelec`, which font-logos has no glyph for.
  /// They are not to be filled in from those projects' own sites: the files in
  /// `assets/distro/` are redrawn glyphs released into the public domain, and
  /// copying a project's own artwork is a copyright question with a different
  /// answer. Callers draw a generic mark instead.
  ///
  /// Drawing one of these beside a server's name is nominative use — a mark
  /// used to refer to the thing it identifies, which is what makes it legal
  /// without any project's permission. `assets/distro/README.md` records each
  /// project's policy and the wording it rests on; read it before adding a
  /// glyph, recolouring one, or using these anywhere that could read as an
  /// affiliation.
  String? get iconPath =>
      _withIcon.contains(this) ? 'assets/distro/$name.svg' : null;
}

/// Which of them `assets/distro/` holds a file for.
///
/// A set rather than a `File.existsSync`, because an asset is not a file at
/// runtime, and rather than a switch, because the answer is a property of what
/// is in that directory.
const _withIcon = {
  Dist.debian,
  Dist.ubuntu,
  Dist.centos,
  Dist.fedora,
  Dist.opensuse,
  Dist.kali,
  Dist.wrt,
  Dist.arch,
  Dist.alpine,
  Dist.rocky,
  Dist.deepin,
};

extension DistStringX on String {
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

const _wrts = ['istoreos'];
