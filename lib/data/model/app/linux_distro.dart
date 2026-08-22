/// The Linux systems this app knows how to install, and what differs between
/// them.
///
/// An enum and not a user-supplied descriptor, because every entry carries a
/// digest that has to have been verified by someone. What is fetched here is
/// executable code, and the pin is the only thing that makes downloading it
/// different from running whatever the connection returned — a mirror the user
/// types is allowed to decide *where* the bytes come from and never *which*.
///
/// Adding one is a case here and an arm in each `switch` below; the switches
/// are exhaustive, so the compiler names every place that has to answer for it.
/// What it is not is only code: an entry needs its rootfs verified to actually
/// boot. On Android that is proot, which runs glibc systems as readily as musl
/// ones. On iOS it is the ish-arm64 engine, which took two fixes before a glibc
/// system could install anything:
///
/// - `utimensat` dropped `AT_SYMLINK_NOFOLLOW` before it reached the host, so
///   rpm could not stamp the `/usr/lib/.build-id/**` symlinks it lays down and
///   no package carrying a build id would unpack (ShellBox #20).
/// - `pselect6` read its optional sigmask argument without checking for null.
///   glibc's `select()` passes null there and musl does not, so *every* glibc
///   program had a `select()` that could only answer EFAULT. apt read that as
///   its download method having died and killed a healthy one (ShellBox #21).
///
/// Both are fixed and both are pinned by tests in that repository. Which
/// revision of it a build carries is the `third_party/ish-arm64` gitlink, so a
/// checkout older than those fixes will see the failures above rather than
/// anything wrong here.
enum LinuxDistro {
  alpine,
  ubuntu,
  rocky;

  /// What is stored, and what [fromName] reads back.
  ///
  /// By name rather than by index, because an index silently changes meaning
  /// when a case is inserted and this value outlives the build that wrote it.
  String get id => name;

  /// The one named [id], or [alpine] for anything else.
  ///
  /// Falls back rather than throws: this parses a stored string and a marker
  /// file, and neither is worth losing an installed system over. Alpine is the
  /// fallback because it is the only one any release ever installed.
  static LinuxDistro fromName(String? id) =>
      values.firstWhere((e) => e.id == id, orElse: () => alpine);

  /// What the user sees. A proper noun, so it is not localized.
  String get label => switch (this) {
    LinuxDistro.alpine => 'Alpine',
    LinuxDistro.ubuntu => 'Ubuntu',
    LinuxDistro.rocky => 'Rocky Linux',
  };

  /// The release this build installs.
  ///
  /// What a person would call it, which is not always what the file is named:
  /// Rocky's tarball carries a build date as well, and that lives in
  /// [rootfsUrl] because nothing else has a use for it.
  String get version => switch (this) {
    LinuxDistro.alpine => '3.22.5',
    LinuxDistro.ubuntu => '26.04',
    LinuxDistro.rocky => '9.8',
  };

  /// The branch the packages come from, which is not the same as [version]:
  /// the rootfs is one release off a branch that keeps moving under it.
  ///
  /// Alpine's is 3.22 rather than the newest, and that is not for want of
  /// updating — see [AndroidRootfs] for what apk-tools 3 does under proot.
  ///
  /// Ubuntu's is the suite name rather than a number, which is what apt reads,
  /// and Rocky's is the major version its repository tree is laid out under.
  String get branch => switch (this) {
    LinuxDistro.alpine => 'v3.22',
    LinuxDistro.ubuntu => 'resolute',
    LinuxDistro.rocky => '9',
  };

  /// Where this is fetched from when the user has named no mirror.
  ///
  /// The *package* host. For Alpine and Rocky it serves the rootfs too, so
  /// [rootfsUrl] builds on it; Ubuntu publishes its base tarballs on
  /// `cdimage.ubuntu.com` and its packages on `archive.ubuntu.com`, and the
  /// mirror someone sets is the one they want packages from.
  String get defaultMirror => switch (this) {
    LinuxDistro.alpine => 'https://dl-cdn.alpinelinux.org/alpine',
    LinuxDistro.ubuntu => 'https://archive.ubuntu.com/ubuntu',
    LinuxDistro.rocky => 'https://dl.rockylinux.org/pub/rocky',
  };

  /// Roughly how large [rootfsUrl] is, in megabytes.
  ///
  /// Pinned beside [sha256] rather than read from a `Content-Length`, because
  /// the dialog that shows it is answered before anything is fetched. Worth
  /// showing at all because these are not close: 4 MB against 81 is the
  /// difference between a tap and a decision on a metered connection.
  ///
  /// Rounded up from what the servers report — 3.8, 33.5 and 80.8 — so the
  /// number is never smaller than the download.
  int get approxDownloadMb => switch (this) {
    LinuxDistro.alpine => 4,
    LinuxDistro.ubuntu => 34,
    LinuxDistro.rocky => 81,
  };

  /// What installs software inside it.
  ///
  /// Named in the update warning, because what replacing a system destroys is
  /// whatever this put there. Saying `apk` to someone running Ubuntu names a
  /// command they have never typed.
  String get packageManager => switch (this) {
    LinuxDistro.alpine => 'apk',
    LinuxDistro.ubuntu => 'apt',
    LinuxDistro.rocky => 'dnf',
  };

  /// Whether [rootfsUrl] is built under the mirror it is given.
  ///
  /// True everywhere but Ubuntu, which publishes its base tarballs on
  /// `cdimage.ubuntu.com` and its packages on `archive.ubuntu.com`. One mirror
  /// string cannot name both, and the one a person sets is the one they want
  /// packages from — so for Ubuntu the setting reaches [repositories] and not
  /// the download.
  ///
  /// Stated here rather than left as a quirk of the `switch` below, because
  /// "the mirror setting does nothing on this path" is exactly the kind of
  /// thing that is only ever discovered by someone whose network needs it.
  bool get rootfsFollowsMirror => this != LinuxDistro.ubuntu;

  /// How the bytes at [rootfsUrl] are compressed.
  LinuxRootfsCompression get compression => switch (this) {
    LinuxDistro.alpine || LinuxDistro.ubuntu => LinuxRootfsCompression.gzip,
    LinuxDistro.rocky => LinuxRootfsCompression.xz,
  };

  /// What is inside once it is decompressed.
  LinuxRootfsLayout get layout => switch (this) {
    LinuxDistro.alpine || LinuxDistro.ubuntu => LinuxRootfsLayout.plain,
    LinuxDistro.rocky => LinuxRootfsLayout.oci,
  };

  /// The digest of what [rootfsUrl] answers, whatever mirror serves it.
  String get sha256 => switch (this) {
    LinuxDistro.alpine =>
      '3fbc6285032ed46821b511292633d7b2a6306a2e254f590e92bdafff56cf2f70',
    LinuxDistro.ubuntu =>
      'b2b46a37324ea1954e93f293fe6d7c2241daf2fc298c4022e6e4caceeed74cab',
    LinuxDistro.rocky =>
      '254dc06377bb63a5ab390cea33c2f26d71c4e0ff6ae1bc8a0fb0fbb86d992e89',
  };

  /// The arm64 rootfs tarball, on [mirror].
  ///
  /// arm64 alone, on both platforms: proot ships for it and nothing else, and
  /// the ish-arm64 engine interprets the architecture it runs on.
  ///
  /// Rocky is named with its build date and not just `.latest.`, which is the
  /// file the same directory also offers. `.latest.` is a moving target and
  /// [sha256] is not: the day Rocky publishes a new build, every install would
  /// start failing its digest check until the app shipped an update. A dated
  /// name pins the two together.
  ///
  /// Ubuntu ignores [mirror] — see [defaultMirror] for why its tarball and its
  /// packages are not on the same host.
  String rootfsUrl(String mirror) => switch (this) {
    LinuxDistro.alpine =>
      '$mirror/$branch/releases/aarch64/'
          'alpine-minirootfs-$version-aarch64.tar.gz',
    LinuxDistro.ubuntu =>
      'https://cdimage.ubuntu.com/ubuntu-base/releases/$version/release/'
          'ubuntu-base-$version-base-arm64.tar.gz',
    LinuxDistro.rocky =>
      '$mirror/$branch/images/aarch64/'
          'Rocky-9-Container-Base-9.8-20260525.0.aarch64.oci.tar.xz',
  };

  /// The file this system's package manager reads, and what to put in it.
  ///
  /// A path and its contents rather than a writer, so that the caller stays the
  /// one thing touching the filesystem. Both parts differ per distribution —
  /// apk reads a list of URLs, apt reads `deb <url> <suite> <components>` — so
  /// neither the name nor the format can be hoisted out of here.
  ///
  /// Ubuntu's is deb822 rather than the one-line `deb ...` form: 26.04 ships
  /// `sources.list.d/ubuntu.sources` and an empty `sources.list`, and writing
  /// the old form to the old path would leave both in play. `Signed-By` has to
  /// name the keyring the image already carries — without it apt rejects the
  /// release file it just fetched, which reads as a broken mirror.
  ///
  /// Rocky's replaces the file holding `baseos`, `appstream` and `crb`, whose
  /// stock version resolves a `mirrorlist=` service. Its siblings
  /// (`rocky-extras.repo` and the rest) are left alone: they are not what an
  /// install pulls from, and rewriting every one of them would mean this
  /// returning a list rather than a file. The variables are written out —
  /// `aarch64` rather than `$basearch` — because there is only one
  /// architecture here and an unexpanded one would be a silent 404.
  ({String path, String content}) repositories(String mirror) => switch (this) {
    LinuxDistro.alpine => (
      path: 'etc/apk/repositories',
      content: '$mirror/$branch/main\n$mirror/$branch/community\n',
    ),
    LinuxDistro.ubuntu => (
      path: 'etc/apt/sources.list.d/ubuntu.sources',
      content:
          'Types: deb\n'
          'URIs: $mirror/\n'
          'Suites: $branch $branch-updates $branch-backports $branch-security\n'
          'Components: main universe restricted multiverse\n'
          'Signed-By: /usr/share/keyrings/ubuntu-archive-keyring.gpg\n',
    ),
    LinuxDistro.rocky => (
      path: 'etc/yum.repos.d/rocky.repo',
      content: [
        for (final repo in const [
          (id: 'baseos', dir: 'BaseOS', name: 'BaseOS'),
          (id: 'appstream', dir: 'AppStream', name: 'AppStream'),
          (id: 'crb', dir: 'CRB', name: 'CRB'),
        ])
          '[${repo.id}]\n'
              'name=Rocky Linux $branch - ${repo.name}\n'
              'baseurl=$mirror/$branch/${repo.dir}/aarch64/os/\n'
              'gpgcheck=1\n'
              'enabled=${repo.id == 'crb' ? 0 : 1}\n'
              'gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-Rocky-$branch\n',
      ].join('\n'),
    ),
  };
}

/// How the bytes at [LinuxDistro.rootfsUrl] are compressed.
///
/// Its own axis rather than something read off the file name: what decompresses
/// a download is a decision the unpacking code has to make before it has a
/// name to look at, and a distribution that changed its compression would
/// otherwise change it silently.
enum LinuxRootfsCompression { gzip, xz }

/// What is inside a rootfs download once it is decompressed.
enum LinuxRootfsLayout {
  /// The tar *is* the filesystem. Alpine and Ubuntu publish theirs this way.
  plain,

  /// An OCI image layout: `index.json` names a manifest, the manifest names
  /// layers, and the layers are the filesystem — applied in order, because a
  /// multi-layer image is only correct that way even when today's base image
  /// has one. Rocky publishes no plain rootfs tarball, only this.
  oci,
}

/// One Linux system unpacked on this device.
///
/// A directory under the container plus the marker inside it. The two together
/// are the whole record: no table, no setting listing what exists. A profile
/// deleted from disk therefore cannot linger in a list, and a list cannot
/// promise a tree that is not there.
///
/// [id] is that directory's name and is not in the marker — the directory *is*
/// the id. It is generated rather than typed: a name someone types has to be
/// made unique and made safe for a path, and a label does neither of those
/// jobs any worse for being ordinary text.
///
/// [distro] is a field rather than the id, which is the whole reason this type
/// exists: two Alpines side by side are two profiles of one distribution, and
/// keying the directory by distribution would have made that impossible.
final class LinuxProfile {
  /// The file each profile's directory carries, naming what is in it.
  ///
  /// Hidden, so a shell listing the guest's `/` does not show it.
  static const marker = '.installed';

  final String id;
  final LinuxDistro distro;

  /// What was unpacked. Empty for an install from a build whose marker carried
  /// no version.
  final String version;

  /// What the user sees, and may change. The distribution's own name when
  /// nothing was chosen.
  final String label;

  const LinuxProfile({
    required this.id,
    required this.distro,
    required this.version,
    required this.label,
  });

  LinuxProfile copyWith({String? label, String? version}) => LinuxProfile(
    id: id,
    distro: distro,
    version: version ?? this.version,
    label: label ?? this.label,
  );

  /// Three lines: the distribution, the version, then the label.
  ///
  /// Written by `install`, read when the container is scanned. A file rather
  /// than a setting, because it describes the tree and has to go when the tree
  /// does — a setting would outlive a directory deleted from under the app and
  /// claim an install that is not there.
  /// The label is flattened on the way out: it is the one field a user types,
  /// and a newline in it would write a fourth line that [decode] reads as a
  /// truncated name.
  String encode() =>
      '${distro.id}\n$version\n${label.replaceAll(RegExp(r'[\r\n]+'), ' ')}\n';

  /// The reverse, and every shape a build ever wrote.
  ///
  /// [id] comes from the caller because it is the directory's name.
  ///
  /// TODO(migration residue; remove once no install predates the three-line
  /// marker): the shorter forms below are earlier formats — distribution and
  /// version, a bare version string, and an empty file. The last two read as
  /// Alpine, which is what they were: nothing else was installable then.
  static LinuxProfile decode(String id, String raw) {
    final lines = raw.trim().split('\n').map((e) => e.trim()).toList();
    final distro = lines.length >= 2
        ? LinuxDistro.fromName(lines.first)
        : LinuxDistro.alpine;
    final version = switch (lines.length) {
      0 => '',
      1 => lines.first,
      _ => lines[1],
    };
    final label = lines.length >= 3 && lines[2].isNotEmpty
        ? lines[2]
        : distro.label;
    return LinuxProfile(
      id: id,
      distro: distro,
      version: version,
      label: label,
    );
  }

  /// A directory name for a new profile of [distro], not colliding with
  /// [taken].
  ///
  /// Readable rather than random — someone reading a file listing or a `du`
  /// should be able to tell which is which — and still generated, so nothing
  /// the user types reaches a path.
  static String nextId(LinuxDistro distro, Iterable<String> taken) {
    final used = taken.toSet();
    if (!used.contains(distro.id)) return distro.id;
    for (var n = 2; ; n++) {
      final candidate = '${distro.id}-$n';
      if (!used.contains(candidate)) return candidate;
    }
  }
}
