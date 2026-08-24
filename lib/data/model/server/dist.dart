/// A distribution this app can recognise.
///
/// The name of each case is part of the app's contract with its users: it is
/// what `{DIST}` expands to in a custom logo URL. **Renaming one breaks every
/// URL template pointing at it**, so a case is added, never renamed.
///
/// The app ships no pictures. Recognising a distribution and drawing its mark
/// are separate things, and only the first happens here — the second is an
/// address the user configures, fetched at the point of drawing. See
/// `lib/view/widget/dist_icon.dart` for why.
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
  // `void` is a Dart keyword, so the {DIST} value is `voidlinux`.
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
  netbsd,
  illumos,
  macos,
  windows;

  /// Whether this is a Linux at all.
  ///
  /// Kept because the identification is worth having even where no picture is
  /// drawn: `uname -or` names the BSDs and Darwin, and a caller that wants to
  /// say "not a Linux" should not have to enumerate them.
  bool get isLinux => !_notLinux.contains(this);
}

/// The ones that are not Linux.
const _notLinux = {
  Dist.freebsd,
  Dist.openbsd,
  Dist.netbsd,
  Dist.illumos,
  Dist.macos,
  Dist.windows,
};

/// Which distribution a machine is running, from everything it reported.
///
/// Three sources, asked in order of how much each is worth:
///
/// 1. **`osId`** — `/etc/os-release`'s `ID=`, the identifier that file defines
///    for programs to match on. Exact equality, so there is no ordering to get
///    right and no way for one distribution's id to be found inside another's.
/// 2. **`sysVersion`** — the `PRETTY_NAME` prose, matched by substring. This
///    was the only source until os-release was asked for, and it stays for two
///    reasons: a remote too old to have that file, and a `monitor` agent
///    predating the field, both of which report the prose alone.
/// 3. **`osIdLike`** — `ID_LIKE=`, the base a derivative declares. Last
///    because it names something other than what is installed: it is the right
///    answer only when the first two have none, and then it is a better answer
///    than nothing.
///
/// Ordering 2 before 3 matters: `ID_LIKE` is the *parent*, so a distribution
/// the prose names outright is the more specific of the two. Ubuntu Core is
/// the example — no `ID` this knows, `PRETTY_NAME="Ubuntu Core 22"`.
///
/// One consequence of preferring `ID` is worth stating: Fedora CoreOS sets
/// `ID=fedora` and is read as Fedora, where the prose match read it as CoreOS.
/// Both are true of it; the id is what the distribution itself says.
Dist? resolveDist({
  String? osId,
  String? sysVersion,
  List<String> osIdLike = const [],
}) {
  if (osId != null) {
    final byId = _byOsId[osId.toLowerCase()];
    if (byId != null) return byId;
  }
  final byProse = sysVersion?.dist;
  if (byProse != null) return byProse;
  for (final like in osIdLike) {
    final byLike = _byOsId[like.toLowerCase()];
    if (byLike != null) return byLike;
  }
  return null;
}

extension DistStringX on String {
  /// Which distribution this `PRETTY_NAME` line names, or null.
  ///
  /// The prose half of [resolveDist] — `PRETTY_NAME="Red Hat Enterprise Linux
  /// 9.4 (Plow)"`. Matching the enum's own name against it worked only while
  /// every supported distribution happened to be spelled as one lower-case
  /// word inside its own `PRETTY_NAME` — `redhat`, `mint` and `popos` are
  /// three that never are.
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

/// `/etc/os-release`'s `ID=`, per distribution.
///
/// A flat map and not an ordered list, which is the point of using this field:
/// a missing entry means "not recognised", never "recognised as its base". The
/// values are the ids the distributions set, so several map to one case
/// (`archarm` is Arch on ARM; `sles` and `sled` are SUSE's two enterprise
/// editions of openSUSE).
///
/// **Not every case is here, and that is not a gap to fill by guessing.** A
/// flavour that ships its parent's os-release unchanged has no id of its own —
/// Kubuntu and LXLE both report `ID=ubuntu` — and one whose id nobody has
/// confirmed is left to the prose matcher rather than written down wrong. A
/// wrong entry here is worse than no entry: it is an exact match, so it wins
/// over everything else.
///
/// A duplicated id cannot be written here at all — two equal keys in a `const`
/// map is a compile error — and `test/dist_icon_test.dart` carries the same
/// table the other way round, so an id that stops resolving is a failure
/// rather than a `{DIST}` that quietly expands to nothing.
const _byOsId = <String, Dist>{
  'debian': Dist.debian,
  'ubuntu': Dist.ubuntu,
  'centos': Dist.centos,
  'fedora': Dist.fedora,
  'kali': Dist.kali,
  'alpine': Dist.alpine,
  'rocky': Dist.rocky,
  'deepin': Dist.deepin,
  'coreelec': Dist.coreelec,

  // The plain openSUSE case covers the enterprise editions and the older
  // releases, which predate the per-edition ids below.
  'opensuse': Dist.opensuse,
  'suse': Dist.opensuse,
  'sles': Dist.opensuse,
  'sled': Dist.opensuse,
  'sles_sap': Dist.opensuse,
  'opensuse-microos': Dist.opensuse,
  'opensuse-leap': Dist.leap,
  'opensuse-tumbleweed': Dist.tumbleweed,

  // OpenWrt and the downstreams that rename themselves in it.
  'openwrt': Dist.wrt,
  'lede': Dist.wrt,
  'immortalwrt': Dist.wrt,
  'istoreos': Dist.wrt,

  'rhel': Dist.rhel,
  'almalinux': Dist.almalinux,
  'nobara': Dist.nobara,

  'devuan': Dist.devuan,
  'raspbian': Dist.raspbian,
  'linuxmint': Dist.mint,
  'pop': Dist.popos,
  'elementary': Dist.elementary,
  'zorin': Dist.zorin,
  'mx': Dist.mx,
  'neon': Dist.kdeneon,
  'biglinux': Dist.biglinux,
  'vanilla': Dist.vanilla,

  'arch': Dist.arch,
  'archarm': Dist.arch,
  'manjaro': Dist.manjaro,
  'manjaro-arm': Dist.manjaro,
  'endeavouros': Dist.endeavour,
  'artix': Dist.artix,
  'garuda': Dist.garuda,
  'cachyos': Dist.cachyos,
  'arcolinux': Dist.arcolinux,
  'archcraft': Dist.archcraft,
  'archlabs': Dist.archlabs,
  'xerolinux': Dist.xerolinux,

  'parrot': Dist.parrot,
  'qubes': Dist.qubes,
  'tails': Dist.tails,

  'trisquel': Dist.trisquel,
  'parabola': Dist.parabola,
  'hyperbola': Dist.hyperbola,
  'guix': Dist.guix,

  'gentoo': Dist.gentoo,
  'nixos': Dist.nixos,
  'void': Dist.voidlinux,
  'solus': Dist.solus,
  'slackware': Dist.slackware,
  'mageia': Dist.mageia,
  'mandriva': Dist.mandriva,
  'openmandriva': Dist.mandriva,
  'sabayon': Dist.sabayon,
  'aosc': Dist.aosc,
  'postmarketos': Dist.postmarketos,

  // Container Linux's own id, and Flatcar, its successor. Fedora CoreOS is
  // absent on purpose — it reports `ID=fedora`, and there is no entry that
  // could distinguish it without contradicting what it says of itself.
  'coreos': Dist.coreos,
  'flatcar': Dist.coreos,
};

/// What a `PRETTY_NAME` has to contain, per distribution, **most specific
/// first**.
///
/// The fallback half of [resolveDist], for a remote with no `/etc/os-release`
/// and for a `monitor` agent predating the field. It was the only half until
/// then, and the reason it is no longer the first one asked is written here:
///
/// The order carries meaning and is the whole of the correctness here. Every
/// derivative has to be asked before what it derives from, because that is
/// usually a superstring: "Kubuntu 24.04" contains "ubuntu", "openSUSE Leap
/// 15.6" contains "opensuse", "Archcraft" contains "arch". Asked the other way
/// round, each of those reads as its parent, and `{DIST}` expands to the wrong
/// name.
///
/// A needle is matched with `contains`, so short ones are dangerous: `void`
/// alone matches "Devoid", `mx` matches any name with those letters adjacent.
/// Those carry the word that disambiguates them.
///
/// `test/dist_icon_test.dart` asserts that every case appears here exactly
/// once, which is what catches a case added to the enum and forgotten here —
/// it would otherwise never match anything at all.
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
  (Dist.netbsd, ['netbsd']),
  (Dist.illumos, ['illumos', 'openindiana', 'smartos']),
  // `uname -or` on Darwin, and the marker the Windows path reports.
  (Dist.macos, ['darwin', 'macos', 'mac os']),
  (Dist.windows, ['windows', 'microsoft']),

  // OpenWrt last of the Linuxes: its own name is checked here, and the
  // downstreams that never carry it follow. iStoreOS is one such.
  (Dist.wrt, ['openwrt', 'lede', 'istoreos', 'immortalwrt']),
];
