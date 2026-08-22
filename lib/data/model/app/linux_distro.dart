import 'package:server_box/data/model/app/linux_distros.dart';
import 'package:server_box/data/model/app/rootfs_manifest.dart';

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
  ///
  /// The one getter here that never throws, which is why it checks whether a
  /// manifest has been loaded at all rather than asking for one. A system
  /// installed by an earlier build carries its distribution's name in a marker
  /// file, and that name outlives any manifest that stops describing it — so a
  /// profile whose distribution has been dropped still has something to be
  /// called, and so does one read before `Rootfs.prepare` has run.
  String get label => LinuxDistros.isLoaded
      ? (LinuxDistros.describe(this)?.label ?? _fallbackLabel)
      : _fallbackLabel;

  String get _fallbackLabel => switch (this) {
    LinuxDistro.alpine => 'Alpine',
    LinuxDistro.ubuntu => 'Ubuntu',
    LinuxDistro.rocky => 'Rocky Linux',
  };

  /// What the manifest says about this one.
  ///
  /// Throws when it says nothing. Everything below is about installing, and a
  /// distribution the manifest does not describe is one this build has no
  /// digest for — which is exactly the thing that must not be guessed at.
  RootfsDistro get info {
    final it = LinuxDistros.describe(this);
    if (it == null) {
      throw StateError('The rootfs manifest does not describe $id');
    }
    return it;
  }

  /// Where [release] (or the preferred one) is fetched from, on [mirror].
  String rootfsUrl(String mirror, {RootfsRelease? release}) =>
      (release ?? preferred).source.urlOn(mirror, defaultMirror);

  /// Every release offered, in the order the manifest gives them.
  List<RootfsRelease> get releases => info.releases;

  /// What a plain install gets. The rest are offered beside it.
  RootfsRelease get preferred => info.preferred;

  /// The release this build would install when nothing else is chosen.
  String get version => preferred.version;

  /// What installs software inside it.
  ///
  /// Named in the update warning, because what replacing a system destroys is
  /// whatever this put there. Saying `apk` to someone running Ubuntu names a
  /// command they have never typed.
  String get packageManager => info.packageManager;

  /// Where this is fetched from when the user has named no mirror.
  ///
  /// The *package* host, and one per distribution rather than per release:
  /// Ubuntu's suites all live on the same archive. For Alpine and Rocky it
  /// serves the rootfs too, so [rootfsUrl] builds on it; Ubuntu publishes its
  /// base tarballs on `cdimage.ubuntu.com` and its packages on
  /// `archive.ubuntu.com`, and the mirror someone sets is the one they want
  /// packages from.
  String get defaultMirror => info.defaultMirror;

  /// The file this system's package manager reads, and what to put in it.
  ///
  /// A path and its contents rather than a writer, so that the caller stays the
  /// one thing touching the filesystem. Both parts differ per distribution —
  /// apk reads a list of URLs, apt reads `deb <url> <suite> <components>` — so
  /// neither the name nor the format can be hoisted out of here.
  ///
  /// This is the reason a manifest cannot introduce a distribution this build
  /// has never heard of: the format is code, and a system unpacked without a
  /// working repositories file is one that can install nothing.
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
  ({String path, String content}) repositories(
    String mirror, {
    RootfsRelease? release,
  }) {
    final branch = (release ?? preferred).branch;
    return _repositories(mirror, branch);
  }

  ({String path, String content}) _repositories(String mirror, String branch) =>
      switch (this) {
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

  /// Which release series this was installed from — apt's suite, apk's
  /// branch, dnf's major version.
  ///
  /// Recorded because it is what decides whether an update is an update.
  /// 24.04.3 and 24.04.4 are both `noble` and one replaces the other; 26.04
  /// is `resolute` and replacing one with the other would destroy everything
  /// installed in it while calling itself an update.
  ///
  /// Empty for a system installed before this was written down. Such a
  /// profile is compared against the distribution's preferred release, which
  /// is what every build did before there was more than one.
  final String branch;

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
    this.branch = '',
  });

  LinuxProfile copyWith({String? label, String? version, String? branch}) =>
      LinuxProfile(
        id: id,
        distro: distro,
        version: version ?? this.version,
        label: label ?? this.label,
        branch: branch ?? this.branch,
      );

  /// Four lines: the distribution, the version, the label, then the release
  /// series.
  ///
  /// Written by `install`, read when the container is scanned. A file rather
  /// than a setting, because it describes the tree and has to go when the tree
  /// does — a setting would outlive a directory deleted from under the app and
  /// claim an install that is not there.
  ///
  /// The series is last so that a marker written by a build that had no such
  /// thing still reads correctly — [decode] takes what is there.
  ///
  /// The label is flattened on the way out. It is the one field a user types,
  /// and a newline in it used to write a fourth line that [decode] read as a
  /// truncated name; now that a fourth line means something, it would be read
  /// as a release series instead.
  String encode() =>
      '${distro.id}\n$version\n'
      '${label.replaceAll(RegExp(r'[\r\n]+'), ' ')}\n'
      '$branch\n';

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
    // Absent in every marker written before releases were a thing, which is
    // most of them. Empty rather than guessed: the caller reads it as "this
    // one predates the question" and falls back to the preferred release.
    final branch = lines.length >= 4 ? lines[3] : '';
    return LinuxProfile(
      id: id,
      distro: distro,
      version: version,
      label: label,
      branch: branch,
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
