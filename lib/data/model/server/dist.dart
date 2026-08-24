/// A distribution this app can recognise and draw a mark for.
///
/// The name of each case is part of the app's contract with its users: it is
/// what `{DIST}` expands to in a custom logo URL. **Renaming one breaks every
/// URL template pointing at it**, so a case is added, never renamed.
enum Dist {
  // The original thirteen, in their original order, because these names have
  // been in users' logo URLs since before the rest of this list existed.
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
  coreelec,

  // Enterprise rebuilds and their upstream.
  rhel,
  almalinux,
  nobara,

  // Debian and Ubuntu derivatives.
  devuan,
  raspbian,
  mint,
  popos,
  elementary,
  zorin,
  mx,
  kubuntu,
  kdeneon,
  biglinux,
  locos,
  lxle,
  vanilla,

  // Arch and its derivatives.
  manjaro,
  endeavour,
  artix,
  garuda,
  cachyos,
  arcolinux,
  archcraft,
  archlabs,
  xerolinux,

  // openSUSE's two editions, which report themselves by edition.
  leap,
  tumbleweed,

  // Security and privacy focused.
  parrot,
  qubes,
  tails,

  // Fully free distributions.
  trisquel,
  parabola,
  hyperbola,
  guix,

  // Independent lineages.
  gentoo,
  nixos,
  // `void` is a Dart keyword, so the glyph and the {DIST} value are both
  // `voidlinux`.
  voidlinux,
  solus,
  slackware,
  mageia,
  mandriva,
  puppy,
  sabayon,
  aosc,
  postmarketos,
  coreos,

  // Not Linux, but a server all the same, and `uname -or` names them.
  freebsd,
  openbsd,
  illumos;

  /// The single-colour glyph marking this one, or null when none is shipped.
  ///
  /// Null only for `armbian` and `coreelec`, which font-logos has no glyph
  /// for. They are not to be filled in from those projects' own sites: the
  /// files in `assets/distro/` are redrawn glyphs released into the public
  /// domain, and copying a project's own artwork is a copyright question with
  /// a different answer. Callers draw the generic mark instead.
  ///
  /// Drawing one of these beside a server's name is nominative use — a mark
  /// used to refer to the thing it identifies, which is what makes it legal
  /// without any project's permission. `assets/distro/README.md` records each
  /// project's policy and the wording it rests on; read it before adding a
  /// glyph, recolouring one, or using these anywhere that could read as an
  /// affiliation.
  String? get iconPath =>
      _withoutIcon.contains(this) ? null : 'assets/distro/$name.svg';
}

/// The two with no glyph. Named the short way round, since almost every case
/// has one.
const _withoutIcon = {Dist.armbian, Dist.coreelec};

/// The generic Linux mark, for a server not yet asked and for the two above.
///
/// A penguin rather than a server outline: what is being said is "some Linux
/// whose flavour is not known", and Tux is what says that. From the same
/// public-domain set as the rest.
const kUnknownDistIcon = 'assets/distro/tux.svg';

extension DistStringX on String {
  /// Which distribution this `PRETTY_NAME` line names, or null.
  ///
  /// The input is `cat /etc/*-release | grep ^PRETTY_NAME`, so it is prose:
  /// `PRETTY_NAME="Red Hat Enterprise Linux 9.4 (Plow)"`. Matching the enum's
  /// own name against it worked only while every supported distribution
  /// happened to be spelled as one lower-case word inside its own
  /// `PRETTY_NAME` — `redhat`, `mint` and `popos` are three that never are.
  Dist? get dist {
    final lower = toLowerCase();
    for (final (dist, needles) in _matchers) {
      for (final needle in needles) {
        if (lower.contains(needle)) return dist;
      }
    }
    return null;
  }
}

/// What a `PRETTY_NAME` has to contain, per distribution, **most specific
/// first**.
///
/// The order carries meaning and is the whole of the correctness here. Every
/// derivative has to be asked before what it derives from, because that is
/// usually a superstring: "Kubuntu 24.04" contains "ubuntu", "openSUSE Leap
/// 15.6" contains "opensuse", "Archcraft" contains "arch". Asked the other way
/// round, each of those reads as its parent and the derivative's glyph is
/// never drawn.
///
/// A needle is matched with `contains`, so short ones are dangerous: `void`
/// alone matches "Devoid", `mx` matches any name with those letters adjacent.
/// Those carry the word that disambiguates them.
///
/// `test/dist_icon_test.dart` asserts that every case appears here exactly
/// once, which is what catches a case added to the enum and forgotten here —
/// it would otherwise never match anything and silently draw the generic mark.
const _matchers = <(Dist, List<String>)>[
  // Ubuntu flavours, before Ubuntu.
  (Dist.kubuntu, ['kubuntu']),
  (Dist.kdeneon, ['kde neon']),
  (Dist.popos, ['pop!_os', 'pop os', 'pop_os']),
  (Dist.mint, ['linux mint', 'linuxmint']),
  (Dist.elementary, ['elementary']),
  (Dist.zorin, ['zorin']),
  (Dist.biglinux, ['biglinux']),
  (Dist.locos, ['locos']),
  (Dist.lxle, ['lxle']),
  (Dist.vanilla, ['vanilla os']),

  // Debian derivatives, before Debian. Raspberry Pi OS reports itself as
  // Debian on current releases and as Raspbian on older ones; only the latter
  // is distinguishable, so a current one reads as Debian, which it is.
  (Dist.raspbian, ['raspbian', 'raspberry pi']),
  (Dist.devuan, ['devuan']),
  (Dist.kali, ['kali']),
  (Dist.parrot, ['parrot']),
  (Dist.tails, ['tails']),
  (Dist.mx, ['mx linux', 'mxlinux']),
  (Dist.deepin, ['deepin']),
  (Dist.armbian, ['armbian']),
  (Dist.trisquel, ['trisquel']),

  // Arch derivatives, before Arch.
  (Dist.manjaro, ['manjaro']),
  (Dist.endeavour, ['endeavouros', 'endeavour']),
  (Dist.artix, ['artix']),
  (Dist.garuda, ['garuda']),
  (Dist.cachyos, ['cachyos']),
  (Dist.arcolinux, ['arcolinux']),
  (Dist.archcraft, ['archcraft']),
  (Dist.archlabs, ['archlabs']),
  (Dist.xerolinux, ['xerolinux']),
  (Dist.parabola, ['parabola']),

  // openSUSE editions, before openSUSE.
  (Dist.leap, ['opensuse leap']),
  (Dist.tumbleweed, ['opensuse tumbleweed', 'tumbleweed']),

  // Enterprise rebuilds, before CentOS and Fedora.
  (Dist.almalinux, ['almalinux']),
  (Dist.rocky, ['rocky']),
  (Dist.rhel, ['red hat', 'redhat', 'rhel']),
  (Dist.nobara, ['nobara']),
  // "Fedora CoreOS" carries both names, and what it runs like is CoreOS.
  // Flatcar is Container Linux's successor and reports neither of the others.
  (Dist.coreos, ['coreos', 'container linux', 'flatcar']),

  // Everything with a name of its own.
  (Dist.debian, ['debian']),
  (Dist.ubuntu, ['ubuntu']),
  (Dist.centos, ['centos']),
  (Dist.fedora, ['fedora']),
  (Dist.opensuse, ['opensuse', 'suse linux enterprise', 'sles']),
  (Dist.arch, ['arch linux', 'archlinux']),
  (Dist.alpine, ['alpine']),
  (Dist.gentoo, ['gentoo']),
  (Dist.nixos, ['nixos']),
  (Dist.voidlinux, ['void linux']),
  (Dist.solus, ['solus']),
  (Dist.slackware, ['slackware']),
  (Dist.mageia, ['mageia']),
  (Dist.mandriva, ['mandriva']),
  (Dist.puppy, ['puppy linux']),
  (Dist.sabayon, ['sabayon']),
  (Dist.aosc, ['aosc']),
  (Dist.postmarketos, ['postmarketos']),
  (Dist.hyperbola, ['hyperbola']),
  (Dist.guix, ['guix']),
  (Dist.qubes, ['qubes']),
  (Dist.coreelec, ['coreelec']),
  (Dist.freebsd, ['freebsd']),
  (Dist.openbsd, ['openbsd']),
  (Dist.illumos, ['illumos', 'openindiana', 'smartos']),

  // OpenWrt last of the Linuxes: its own name is checked here, and the
  // downstreams that never carry it follow. iStoreOS is one such.
  (Dist.wrt, ['openwrt', 'lede', 'istoreos', 'immortalwrt']),
];
